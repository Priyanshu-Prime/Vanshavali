import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/transliteration_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/gujarati_edit_sheet.dart';
import '../scan/scan_invite_code_screen.dart';

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

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
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

  @override
  void initState() {
    super.initState();
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

    if (member.deepDetails.isNotEmpty) {
      _educationController.text = member.deepDetails['education'] ?? '';
      _occupationController.text = member.deepDetails['occupation'] ?? '';
    }
  }

  @override
  void dispose() {
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

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

    final member = FamilyMember(
      id: widget.existingMember?.id ?? const Uuid().v4(),
      createdAt: widget.existingMember?.createdAt ?? DateTime.now(),
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

    // Determine if we are editing our own profile or someone else's
    final isOwnProfile =
        widget.isCreatingProfile ||
        (widget.existingMember != null &&
            widget.existingMember!.id == authProvider.currentMember?.id);

    if (widget.isCreatingProfile) {
      success = await authProvider.createProfile(member);
    } else if (isOwnProfile) {
      success = await authProvider.updateProfile(member);
    } else {
      // Editing another family member — use FamilyProvider
      final familyProvider = context.read<FamilyProvider>();
      success = await familyProvider.updateFamilyMember(member);
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      showAppSnackBar(context, context.l10n.profileCompleted);
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
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
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
                TextFormField(
                  controller: _villageController,
                  decoration: InputDecoration(
                    labelText: l10n.villageOrigin,
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
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
              onPressed: _isLoading ? null : _saveProfile,
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
