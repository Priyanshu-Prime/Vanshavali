import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/transliteration_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/duplicate_match_sheet.dart';
import '../../widgets/gujarati_edit_sheet.dart';
import '../../widgets/village_picker_field.dart';
import '../scan/scan_invite_code_screen.dart';

/// First-time profile creation with an optional photo. Storage RLS (migration
/// 016) only allows writing `<id>/avatar.jpg` once the family_members row
/// exists (can_edit_family_member is FALSE for a missing row), so the row is
/// created FIRST and the photo uploaded + attached afterwards. The photo is
/// optional: its failure never undoes the saved profile.
@visibleForTesting
Future<({bool saved, bool photoFailed})> createProfileThenUploadAvatar(
  AuthProvider auth,
  FamilyMember member,
  Uint8List? avatarBytes, {
  Future<String> Function(String memberId, Uint8List bytes) upload =
      SupabaseService.uploadAvatar,
}) async {
  if (!await auth.createProfile(member)) {
    return (saved: false, photoFailed: false);
  }
  if (avatarBytes == null) return (saved: true, photoFailed: false);
  try {
    final url = await upload(member.id, avatarBytes);
    final created = auth.currentMember ?? member;
    final ok = await auth.updateProfile(created.copyWith(avatarUrl: url));
    return (saved: true, photoFailed: !ok);
  } catch (_) {
    return (saved: true, photoFailed: true);
  }
}

class ProfileFormScreen extends StatefulWidget {
  final FamilyMember? existingMember;
  final bool isCreatingProfile;

  const ProfileFormScreen({
    super.key,
    this.existingMember,
    this.isCreatingProfile = true,
  });

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _firstNameEnController = TextEditingController();
  final _firstNameGuController = TextEditingController();
  final _lastNameEnController = TextEditingController();
  final _lastNameGuController = TextEditingController();
  final _villageController = TextEditingController();
  final _cityController = TextEditingController();
  final _educationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isAlive = true;
  bool _isLoading = false;
  Timer? _firstNameDebounce;
  Timer? _lastNameDebounce;
  String? _invitePreviewName;

  // Member id is fixed up-front (reused for an edit, freshly minted for a new
  // profile). On edit the avatar uploads immediately to '<id>/avatar.jpg'; on
  // creation the picked bytes are held in [_pendingAvatarBytes] and uploaded
  // only after the row exists (see createProfileThenUploadAvatar).
  late final String _memberId;
  String? _pendingAvatarUrl;
  Uint8List? _pendingAvatarBytes;
  bool get _hasPhoto => _pendingAvatarUrl != null || _pendingAvatarBytes != null;
  bool _isUploadingPhoto = false;

  // Onboarding claim request sent: this screen is the app root (nothing to
  // pop back to), so it shows a waiting view until a relative approves.
  bool _awaitingClaim = false;
  // "Create a new profile instead" from the waiting view: the next save must
  // not re-offer the same match.
  bool _skipDuplicateCheck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _memberId = widget.existingMember?.id ?? const Uuid().v4();
    if (widget.existingMember != null) {
      _populateFields(widget.existingMember!);
    }
    // Real-time translation listeners
    _firstNameEnController.addListener(_onFirstNameEnChanged);
    _lastNameEnController.addListener(_onLastNameEnChanged);
  }

  void _populateFields(FamilyMember member) {
    _firstNameEnController.text = member.firstNameEn;
    _firstNameGuController.text = member.firstNameGu ?? '';
    _lastNameEnController.text = member.lastNameEn;
    _lastNameGuController.text = member.lastNameGu ?? '';
    _villageController.text = member.villageOrigin ?? '';
    _cityController.text = member.currentCity ?? '';
    _selectedGender = member.gender;
    _selectedDob = member.dob;
    _isAlive = member.isAlive;
    _pendingAvatarUrl = member.avatarUrl;

    if (member.deepDetails.isNotEmpty) {
      _educationController.text = member.deepDetails['education'] ?? '';
      _occupationController.text = member.deepDetails['occupation'] ?? '';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstNameEnController.removeListener(_onFirstNameEnChanged);
    _lastNameEnController.removeListener(_onLastNameEnChanged);
    _firstNameDebounce?.cancel();
    _lastNameDebounce?.cancel();
    _firstNameEnController.dispose();
    _firstNameGuController.dispose();
    _lastNameEnController.dispose();
    _lastNameGuController.dispose();
    _villageController.dispose();
    _cityController.dispose();
    _educationController.dispose();
    _occupationController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app (e.g. after phoning the relative who approves)
    // re-checks quietly, so the user doesn't have to find the button.
    if (state == AppLifecycleState.resumed && _awaitingClaim) {
      _checkClaim(quiet: true);
    }
  }

  /// Re-reads the profile; an approved claim makes AuthProvider.hasProfile
  /// true and the app root (main.dart) swaps this screen for the dashboard.
  Future<void> _checkClaim({bool quiet = false}) async {
    final auth = context.read<AuthProvider>();
    await auth.refreshCurrentMember();
    if (!mounted || auth.hasProfile || quiet) return;
    showAppSnackBar(context, context.l10n.claimStillWaiting);
  }

  /// Opens the QR scanner; on a successful scan fills the invite-code field
  /// and runs the same preview lookup as manual typing. Manual entry is never
  /// disabled — this is an optional shortcut.
  Future<void> _scanInviteCode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanInviteCodeScreen()),
    );
    if (code == null || !mounted) return;
    _inviteCodeController.text = code;
    _lookupInviteCode(code);
  }

  Future<void> _lookupInviteCode(String code) async {
    if (code.length != 6) {
      setState(() => _invitePreviewName = null);
      return;
    }
    try {
      final member = await SupabaseService.getMemberByInviteCode(code);
      if (mounted) {
        setState(() => _invitePreviewName = member?.fullNameEn);
      }
    } catch (_) {}
  }

  void _onFirstNameEnChanged() {
    _firstNameDebounce?.cancel();
    final text = _firstNameEnController.text.trim();
    if (text.isEmpty) return;
    _firstNameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final translated = await TransliterationService.best(text);
        if (translated != null && mounted) {
          _firstNameGuController.text = translated;
        }
      } catch (_) {}
    });
  }

  void _onLastNameEnChanged() {
    _lastNameDebounce?.cancel();
    final text = _lastNameEnController.text.trim();
    if (text.isEmpty) return;
    _lastNameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final translated = await TransliterationService.best(text);
        if (translated != null && mounted) {
          _lastNameGuController.text = translated;
        }
      } catch (_) {}
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDob ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('en', 'GB'), // Force dd/mm/yyyy format
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  /// Bottom sheet: Camera / Gallery / (Remove if a photo exists). Large
  /// tappable rows, no icon-only controls — matches the low-tech UI rules.
  Future<void> _showPhotoOptions() async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            if (_hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.removePhoto),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    _pendingAvatarUrl = null;
                    _pendingAvatarBytes = null;
                  });
                  // Same as adding: on edit, apply right away, not on Save.
                  if (widget.isCreatingProfile) return;
                  try {
                    await SupabaseService.setAvatarUrl(_memberId, null);
                    await _photoSavedElsewhere();
                  } catch (_) {
                    if (mounted) {
                      showAppSnackBar(context, context.l10n.photoUploadFailedRetry,
                          isError: true);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// The photo was written straight to the row: refresh our own cached profile
  /// (if it's us) and the tree, so every screen shows it without a restart.
  Future<void> _photoSavedElsewhere() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final family = context.read<FamilyProvider>();
    if (auth.currentMember?.id == _memberId) await auth.refreshCurrentMember();
    family.memberChangedElsewhere();
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    // Pick generously, then let the user crop/rotate; the cropper does the
    // final 512px / q70 downscale so the cropped face keeps its detail.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null || !mounted) return;
    final theme = Theme.of(context);
    final cropTitle = context.l10n.cropPhoto;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 70,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: cropTitle,
          toolbarColor: theme.colorScheme.primary,
          toolbarWidgetColor: Colors.white,
          statusBarLight: false,
          activeControlsWidgetColor: theme.colorScheme.primary,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
        ),
        IOSUiSettings(title: cropTitle, aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return; // cancelled the crop screen

    final bytes = await cropped.readAsBytes();
    if (!mounted) return;
    // 300 KB is the bucket's server-side limit (migration 016) — reject here
    // with a clear message rather than letting the upload fail opaquely.
    if (bytes.length > 300 * 1024) {
      showAppSnackBar(context, context.l10n.photoTooLarge, isError: true);
      return;
    }

    if (widget.isCreatingProfile) {
      // No row yet, so storage RLS would reject the upload — hold the bytes
      // and upload after createProfile succeeds.
      setState(() => _pendingAvatarBytes = bytes);
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await SupabaseService.uploadAvatar(_memberId, bytes);
      await SupabaseService.setAvatarUrl(_memberId, url);
      if (!mounted) return;
      setState(() => _pendingAvatarUrl = url);
      await _photoSavedElsewhere();
    } catch (_) {
      // Photo is optional: keep any prior avatar; nothing is saved yet at
      // this point, so just ask them to retry.
      if (mounted) {
        showAppSnackBar(context, context.l10n.photoUploadFailedRetry,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      // The failing field may be scrolled off-screen, which made Save look
      // dead on-device. Say so, and re-check fields live from now on so red
      // errors clear as soon as they're fixed.
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      showAppSnackBar(context, context.l10n.formHasErrors, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();

    // Only for a brand-new profile: an invite code claims an already-existing
    // placeholder (created by a relative) instead of creating a fresh row for
    // the same person. Reachable from here (not just the signup screen) so a
    // magic-link user, or anyone who reaches this screen without having typed
    // a code during signup, still has a way to link to their placeholder.
    if (widget.isCreatingProfile) {
      final code = _inviteCodeController.text.trim().toUpperCase();
      if (code.length == 6) {
        final claimed = await authProvider.claimProfileByCode(code);
        if (!mounted) return;
        if (claimed) {
          setState(() => _isLoading = false);
          showAppSnackBar(context, context.l10n.profileClaimed);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context, true);
          });
          return;
        } else if (authProvider.hasPendingMergeConflict) {
          showAppSnackBar(
            context,
            context.l10n.duplicateProfileFlaggedForReview,
          );
          authProvider.acknowledgeMergeConflict();
          // Fall through — let them save the profile they filled in below
          // rather than leaving them stuck with an unusable form.
        }
        // Invalid/unmatched code: fall through silently to manual profile
        // creation below, same forgiving behavior as the signup screen.
      }
    }

    // ── Duplicate detection: a relative may already have created a placeholder
    // for this same person. Offer to link to it (via an approvable claim
    // request) instead of silently creating a second row. Only for a brand-new
    // profile — an edit isn't a new person. Best-effort: a detection failure
    // must never block a legitimate signup. ──
    if (widget.isCreatingProfile && !_skipDuplicateCheck) {
      List<DuplicateCandidate> candidates;
      try {
        candidates = await SupabaseService.findDuplicateCandidates(
          firstNameEn: _firstNameEnController.text.trim(),
          lastNameEn: _lastNameEnController.text.trim(),
          firstNameGu: _firstNameGuController.text.trim().isEmpty
              ? null
              : _firstNameGuController.text.trim(),
          lastNameGu: _lastNameGuController.text.trim().isEmpty
              ? null
              : _lastNameGuController.text.trim(),
          gender: _selectedGender,
          dob: _selectedDob,
          village: _villageController.text.trim().isEmpty
              ? null
              : _villageController.text.trim(),
        );
      } catch (_) {
        candidates = [];
      }
      if (!mounted) return;
      if (candidates.isNotEmpty) {
        final choice = await showDuplicateMatchSheet(
          context: context,
          candidates: candidates,
        );
        if (!mounted) return;
        if (choice == null) {
          // Dismissed — don't create a possible duplicate behind their back.
          setState(() => _isLoading = false);
          return;
        }
        if (!choice.createNew && choice.selected != null) {
          final match = choice.selected!.member;
          if (match.isClaimed) {
            // Already a real account (likely themselves on another device) —
            // can't claim it, and nothing is flagged: say so plainly.
            setState(() => _isLoading = false);
            showAppSnackBar(
              context,
              context.l10n.duplicateAlreadyClaimed,
            );
            return;
          }
          try {
            await SupabaseService.requestClaim(match.id);
            if (!mounted) return;
            setState(() => _isLoading = false);
            showAppSnackBar(context, context.l10n.claimRequestSent);
            if (!Navigator.canPop(context)) {
              // Onboarding root: popping would leave a blank screen.
              setState(() => _awaitingClaim = true);
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context, true);
            });
            return;
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            showAppSnackBar(
              context,
              friendlyErrorMessage(context, e),
              isError: true,
            );
            return;
          }
        }
        // choice.createNew — fall through to normal creation below.
      }
    }

    final member = FamilyMember(
      id: _memberId,
      createdAt: widget.existingMember?.createdAt ?? DateTime.now(),
      avatarUrl: _pendingAvatarUrl,
      authUserId: widget.existingMember?.authUserId,
      fatherId: widget.existingMember?.fatherId,
      motherId: widget.existingMember?.motherId,
      firstNameEn: _firstNameEnController.text.trim(),
      firstNameGu: _firstNameGuController.text.trim().isEmpty
          ? null
          : _firstNameGuController.text.trim(),
      lastNameEn: _lastNameEnController.text.trim(),
      lastNameGu: _lastNameGuController.text.trim().isEmpty
          ? null
          : _lastNameGuController.text.trim(),
      gender: _selectedGender,
      dob: _selectedDob,
      isAlive: _isAlive,
      villageOrigin: _villageController.text.trim().isEmpty
          ? null
          : _villageController.text.trim(),
      currentCity: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      deepDetails: {
        if (_educationController.text.isNotEmpty)
          'education': _educationController.text.trim(),
        if (_occupationController.text.isNotEmpty)
          'occupation': _occupationController.text.trim(),
        // Preserve has_password across an edit — this form rebuilds
        // deep_details from scratch, and losing this flag on a routine
        // profile edit would wrongly re-trigger the mandatory set-password
        // prompt for someone who already has one.
        if (widget.existingMember?.deepDetails['has_password'] == true)
          'has_password': true,
        // Tag a brand-new profile if the session that created it just
        // proved a password exists (signUpWithEmail) — see
        // AuthProvider.hasPasswordSet / the mandatory set-password prompt.
        if (widget.isCreatingProfile &&
            context.read<AuthProvider>().authenticatedWithPassword)
          'has_password': true,
      },
    );

    bool success;
    var photoFailed = false;

    // Determine if we are editing our own profile or someone else's
    final isOwnProfile =
        widget.isCreatingProfile ||
        (widget.existingMember != null &&
            widget.existingMember!.id == authProvider.currentMember?.id);

    if (widget.isCreatingProfile) {
      final result = await createProfileThenUploadAvatar(
          authProvider, member, _pendingAvatarBytes);
      success = result.saved;
      photoFailed = result.photoFailed;
    } else if (isOwnProfile) {
      success = await authProvider.updateProfile(member);
    } else {
      // Editing another family member — use FamilyProvider
      final familyProvider = context.read<FamilyProvider>();
      success = await familyProvider.updateFamilyMember(member);
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Own-profile saves bypass FamilyProvider, so its tree cache would keep
    // the old copy (seen on-device: new photo missing until manual refresh).
    if (success && isOwnProfile) {
      context.read<FamilyProvider>().memberChangedElsewhere();
    }

    if (success) {
      showAppSnackBar(
        context,
        photoFailed
            ? context.l10n.photoUploadFailed // true now: the row is saved
            : context.l10n.profileCompleted,
        isError: photoFailed,
      );
      // Use addPostFrameCallback to ensure navigation happens after rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } else if (authProvider.error != null) {
      showAppSnackBar(
        context,
        friendlyErrorMessage(context, authProvider.error!),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_awaitingClaim) {
      return ClaimWaitingView(
        onCheckAgain: _checkClaim,
        onCreateNew: () => setState(() {
          _awaitingClaim = false;
          _skipDuplicateCheck = true;
        }),
        onLogout: () async {
          final confirmed = await showConfirmDialog(
            context: context,
            title: l10n.logout,
            message: l10n.confirmLogout,
            isDestructive: true,
          );
          if (confirmed && context.mounted) {
            await context.read<AuthProvider>().signOut();
          }
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCreatingProfile ? l10n.completeProfile : l10n.editProfile,
        ),
        // When creating the mandatory first profile, this screen has no
        // previous route to pop to (it's shown in place of the app's root
        // by AppNavigator) — without an explicit way out, a user who signed
        // up by mistake, or wants to retry with a different invite code, is
        // stuck filling in the whole form with no escape. Mirrors the same
        // sign-out escape hatch already used on SetPasswordScreen.
        actions: widget.isCreatingProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: l10n.logout,
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final confirmed = await showConfirmDialog(
                            context: context,
                            title: l10n.logout,
                            message: l10n.confirmLogout,
                            isDestructive: true,
                          );
                          if (confirmed && context.mounted) {
                            await context.read<AuthProvider>().signOut();
                          }
                        },
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── Profile photo (optional) ──
            Center(
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: _pendingAvatarBytes != null
                              ? MemoryImage(_pendingAvatarBytes!)
                              : _pendingAvatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      _pendingAvatarUrl!) as ImageProvider
                                  : null,
                          child: _isUploadingPhoto
                              ? const CircularProgressIndicator()
                              : (!_hasPhoto
                                  ? Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    )
                                  : null),
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Icon(
                            Icons.photo_camera,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      !_hasPhoto
                          ? l10n.addPhoto
                          : l10n.changePhoto,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Invite Code (optional, new profiles only) ──
            if (widget.isCreatingProfile) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.enterInviteCode,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _inviteCodeController,
                        decoration: InputDecoration(
                          hintText: l10n.enterInviteCodeHint,
                          prefixIcon: const Icon(Icons.key),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        onChanged: _lookupInviteCode,
                      ),
                      // Optional QR shortcut — manual typing above always works.
                      OutlinedButton.icon(
                        onPressed: _scanInviteCode,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(l10n.scanInviteCode),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      if (_invitePreviewName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _invitePreviewName!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Names Section
            SectionCard(
              title: l10n.name,
              children: [
                TextFormField(
                  controller: _firstNameEnController,
                  decoration: InputDecoration(
                    labelText: '${l10n.firstName} *',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value?.isEmpty == true ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameGuController,
                  decoration: InputDecoration(
                    labelText: l10n.firstNameGujarati,
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: l10n.editGujaratiSpelling,
                      onPressed: () async {
                        final result = await showGujaratiEditSheet(
                          context: context,
                          englishText: _firstNameEnController.text,
                          currentGujarati: _firstNameGuController.text,
                        );
                        if (result != null) {
                          _firstNameGuController.text = result;
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameEnController,
                  decoration: InputDecoration(
                    labelText: '${l10n.lastName} *',
                    prefixIcon: const Icon(Icons.family_restroom),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value?.isEmpty == true ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameGuController,
                  decoration: InputDecoration(
                    labelText: l10n.lastNameGujarati,
                    prefixIcon: const Icon(Icons.family_restroom),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: l10n.editGujaratiSpelling,
                      onPressed: () async {
                        final result = await showGujaratiEditSheet(
                          context: context,
                          englishText: _lastNameEnController.text,
                          currentGujarati: _lastNameGuController.text,
                        );
                        if (result != null) {
                          _lastNameGuController.text = result;
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Basic Info Section
            SectionCard(
              title: l10n.basicInformation,
              children: [
                // Gender
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: InputDecoration(
                    labelText: l10n.gender,
                    prefixIcon: const Icon(Icons.wc),
                  ),
                  items: [
                    DropdownMenuItem(value: 'Male', child: Text(l10n.male)),
                    DropdownMenuItem(value: 'Female', child: Text(l10n.female)),
                    DropdownMenuItem(value: 'Other', child: Text(l10n.other)),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedGender = value);
                  },
                ),
                const SizedBox(height: 12),
                // Date of Birth
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.dateOfBirth,
                      prefixIcon: const Icon(Icons.cake_outlined),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDob != null
                          ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
                          : l10n.selectDate,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Living Status
                SwitchListTile(
                  title: Text(_isAlive ? l10n.isAlive : l10n.deceased),
                  value: _isAlive,
                  onChanged: (value) {
                    setState(() => _isAlive = value);
                  },
                  secondary: Icon(
                    _isAlive ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Location Section
            SectionCard(
              title: l10n.location,
              children: [
                VillagePickerField(
                  value: _villageController.text,
                  helperText: _selectedGender == 'Female'
                      ? l10n.villageHintFemale
                      : null,
                  onChanged: (v) =>
                      setState(() => _villageController.text = v ?? ''),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                      ? l10n.villageRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: l10n.currentCity,
                    prefixIcon: const Icon(Icons.location_city),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Additional Info Section
            SectionCard(
              title: l10n.additionalDetails,
              children: [
                TextFormField(
                  controller: _educationController,
                  decoration: InputDecoration(
                    labelText: l10n.education,
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _occupationController,
                  decoration: InputDecoration(
                    labelText: l10n.occupation,
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Save Button
            ElevatedButton(
              onPressed: (_isLoading || _isUploadingPhoto) ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveChanges),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Shown after an onboarding claim request: the user has no profile until a
/// relative approves, so instead of a blank screen they get a plain status
/// and two large actions.
class ClaimWaitingView extends StatefulWidget {
  const ClaimWaitingView({
    super.key,
    required this.onCheckAgain,
    required this.onCreateNew,
    required this.onLogout,
  });

  final Future<void> Function() onCheckAgain;
  final VoidCallback onCreateNew;
  final VoidCallback onLogout;

  @override
  State<ClaimWaitingView> createState() => _ClaimWaitingViewState();
}

class _ClaimWaitingViewState extends State<ClaimWaitingView> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await widget.onCheckAgain();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.claimWaitingTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.hourglass_top, size: 72),
              const SizedBox(height: 16),
              Text(
                l10n.claimWaitingBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l10n.checkAgain),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _checking ? null : widget.onCreateNew,
                  child: Text(l10n.createNewProfileInstead),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
