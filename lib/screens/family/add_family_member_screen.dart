import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/translation_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/gujarati_edit_sheet.dart';

// ─────────────────────────────────────────────────────────
//  Pure, testable relation-guard helpers.
//
//  These were extracted from inline logic inside _saveMember() so the
//  cardinality/duplicate/empty-slot rules (see the family-relations skill)
//  can be unit tested without a live Supabase connection or a widget tree.
//  Behavior is unchanged — _saveMember() now calls these instead of
//  duplicating the checks inline.
// ─────────────────────────────────────────────────────────

/// Guards the strictly one-to-one father/mother relations. Returns the
/// blocked relation ('father' or 'mother') if [relation] would create a
/// second father/mother link on [member], or null if the relation is
/// allowed. Spouse is intentionally NOT covered here — see
/// [isSpouseAlreadyLinked] for the multi-entry (remarriage) guard.
///
/// Callers must pass a freshly-fetched [member] (not stale local/provider
/// state) — see the stale-data guard note in the family-relations skill.
String? blockedOneToOneRelation(String relation, FamilyMember member) {
  if (relation == 'father' && member.fatherId != null) return 'father';
  if (relation == 'mother' && member.motherId != null) return 'mother';
  return null;
}

/// Guards spouse (multi-entry / remarriage-supporting) duplicate inserts.
/// Returns true only when [candidateId] is ALREADY present in
/// [currentSpouses] — a genuinely different second (or third...) spouse is
/// always allowed. Callers must pass a freshly-fetched [currentSpouses]
/// list, not stale in-memory state.
bool isSpouseAlreadyLinked(
  List<FamilyMember> currentSpouses,
  String candidateId,
) {
  return currentSpouses.any((s) => s.id == candidateId);
}

/// Guards against creating a father_id/mother_id ancestry cycle. Returns
/// true if setting [targetId]'s father/mother to [candidateId] would make
/// [targetId] its own ancestor (i.e. [candidateId] is already a descendant
/// of [targetId]) — which would happen via "Add Father/Mother" → "Link
/// Existing" → picking someone from the target's own descendant line.
///
/// Nothing in the database enforces this (see docs/claude_handoff/
/// 04_current_risks.md — the tree-*rendering* side was made cycle-safe via
/// buildPedigreeChain's visited-ids guard, but nothing stops a cycle from
/// being CREATED in the first place). This closes that gap at the one
/// place cycles can actually be introduced through the app UI.
///
/// Walks [candidateId]'s own ancestor chain (both father_id and mother_id
/// branches, since either lineage could reach back to the target) via
/// [resolve], looking for [targetId]. [resolve] should check already-loaded
/// data before falling back to a network call — see
/// `FamilyProvider.getMemberById` for the intended implementation. Bounded
/// by [maxVisited] so a pre-existing, unrelated cycle in already-bad data
/// can't turn this into an infinite loop.
Future<bool> wouldCreateAncestryCycle({
  required String targetId,
  required String candidateId,
  required Future<FamilyMember?> Function(String id) resolve,
  int maxVisited = 200,
}) async {
  if (targetId == candidateId) return true; // can't be your own parent
  final visited = <String>{};
  final queue = <String>[candidateId];
  while (queue.isNotEmpty && visited.length < maxVisited) {
    final id = queue.removeAt(0);
    if (!visited.add(id)) continue;
    if (id == targetId) return true;
    final member = await resolve(id);
    if (member == null) continue;
    if (member.fatherId != null) queue.add(member.fatherId!);
    if (member.motherId != null) queue.add(member.motherId!);
  }
  return false;
}

/// Returns the subset of [egoNetwork] that are children of [parentId] AND
/// whose *other*-parent slot is currently empty — i.e. the children that
/// should be offered for linking to a newly-added spouse. A child whose
/// other-parent slot is already filled (e.g. from a prior marriage) must
/// never be offered here, since linking would silently overwrite an
/// existing biological-parent link.
///
/// [isSpouseFather] indicates which slot the new spouse would fill: true
/// means the new spouse is a father figure (so we require `fatherId ==
/// null`), false means mother figure (`motherId == null`).
List<FamilyMember> childrenNeedingOtherParent({
  required List<FamilyMember> egoNetwork,
  required String parentId,
  required bool isSpouseFather,
}) {
  return egoNetwork.where((c) {
    final isChild = c.fatherId == parentId || c.motherId == parentId;
    if (!isChild) return false;
    return isSpouseFather ? c.fatherId == null : c.motherId == null;
  }).toList();
}

class AddFamilyMemberScreen extends StatefulWidget {
  final String? preselectedRelation;

  /// When set, relations are added for this member instead of the logged-in user.
  final FamilyMember? targetMember;

  const AddFamilyMemberScreen({
    super.key,
    this.preselectedRelation,
    this.targetMember,
  });

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameEnController = TextEditingController();
  final _firstNameGuController = TextEditingController();
  final _lastNameEnController = TextEditingController();
  final _lastNameGuController = TextEditingController();
  final _existingMemberSearchController = TextEditingController();

  String? _selectedRelation;
  String? _selectedGender;
  bool _isLoading = false;
  bool _linkExisting = false;
  Timer? _firstNameDebounce;
  Timer? _lastNameDebounce;
  FamilyMember? _selectedExistingMember;

  /// Freshly-fetched copy of the effective member (from Supabase).
  FamilyMember? _freshMember;

  /// Spouse(s) the effective member already has, shown as context when
  /// 'spouse' is the selected relation so an additional spouse isn't added
  /// blind (this project supports remarriage — never a silent replace).
  List<FamilyMember> _currentSpouses = [];

  late List<String> _relations;

  /// The member we are adding relations for (target or self).
  /// Uses the freshly-fetched copy when available.
  FamilyMember? get _effectiveMember {
    if (_freshMember != null) return _freshMember;
    final auth = context.read<AuthProvider>();
    return widget.targetMember ?? auth.currentMember;
  }

  /// Whether we are operating on someone other than the logged-in user.
  bool get _isTargetMode => widget.targetMember != null;

  @override
  void initState() {
    super.initState();
    _selectedRelation = widget.preselectedRelation;

    // Auto-set gender based on relation
    if (_selectedRelation == 'father') {
      _selectedGender = 'Male';
    } else if (_selectedRelation == 'mother') {
      _selectedGender = 'Female';
    }

    // Pre-fill last name only for same-surname relations (father, child, sibling)
    // Do NOT pre-fill for spouse or mother (different maiden/family name)
    final authProvider = context.read<AuthProvider>();
    final member = widget.targetMember ?? authProvider.currentMember;
    if (member != null && _shouldPrefillSurname(_selectedRelation)) {
      _lastNameEnController.text = member.lastNameEn;
      _lastNameGuController.text = member.lastNameGu ?? '';
    }

    // Real-time translation listeners
    _firstNameEnController.addListener(_onFirstNameEnChanged);
    _lastNameEnController.addListener(_onLastNameEnChanged);

    // Compute available relations (filter out already-filled ones)
    _relations = _computeAvailableRelations(member);

    // If preselected relation was filtered out, clear it
    if (_selectedRelation != null && !_relations.contains(_selectedRelation)) {
      _selectedRelation = null;
    }

    // Fetch fresh data from server to ensure relation guards are accurate
    _refreshMemberFromServer(member);

    // Ensure the provider's ego network is actually scoped to the effective
    // member, not whatever was centered before this screen opened — this
    // screen can be reached for a non-centered member (e.g. long-pressing a
    // sibling node on the tree), and without this, egoNetwork-based lookups
    // later in this screen (the spouse-add children-linking prompt, in
    // particular) would read the wrong person's neighborhood. Same fix as
    // member_detail_screen.dart's initState.
    if (member != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<FamilyProvider>().loadEgoNetwork(member.id);
      });
    }

    if (_selectedRelation == 'spouse') {
      _loadCurrentSpouses();
    }
  }

  /// Loads the effective member's current spouse(s) so the UI can show them
  /// as context when adding another one (multi-entry relation).
  Future<void> _loadCurrentSpouses() async {
    final effectiveMember = _effectiveMember;
    if (effectiveMember == null) return;
    final familyProvider = context.read<FamilyProvider>();
    final spouses = await familyProvider.getSpousesOf(effectiveMember.id);
    if (!mounted) return;
    setState(() => _currentSpouses = spouses);
  }

  /// Fetch the latest member data from Supabase and update the available
  /// relations dropdown so stale local data can't allow duplicates.
  Future<void> _refreshMemberFromServer(FamilyMember? localMember) async {
    if (localMember == null) return;
    try {
      final fresh = await SupabaseService.getFamilyMemberById(localMember.id);
      if (fresh != null && mounted) {
        setState(() {
          _freshMember = fresh;
          _relations = _computeAvailableRelations(fresh);
          // If the currently selected relation is no longer available, reset it
          if (_selectedRelation != null &&
              !_relations.contains(_selectedRelation)) {
            _selectedRelation = null;
          }
        });
      }
    } catch (_) {
      // Fall back to local data (already set)
    }
  }

  List<String> _computeAvailableRelations(FamilyMember? member) {
    final available = <String>[];
    if (member?.fatherId == null) available.add('father');
    if (member?.motherId == null) available.add('mother');
    // Spouse is multi-entry (remarriage) — always offered, never hidden
    // after the first one. The duplicate guard in _saveMember blocks only
    // re-adding the exact same person, not a second spouse in general.
    available.add('spouse');
    available.add('child');
    available.add('sibling');
    return available;
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
    _existingMemberSearchController.dispose();
    super.dispose();
  }

  void _onFirstNameEnChanged() {
    _firstNameDebounce?.cancel();
    final text = _firstNameEnController.text.trim();
    if (text.isEmpty) return;
    _firstNameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final translated = await TranslationService.translateToGujarati(text);
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
        final translated = await TranslationService.translateToGujarati(text);
        if (translated != null && mounted) {
          _lastNameGuController.text = translated;
        }
      } catch (_) {}
    });
  }

  /// Returns true if the given relation should have the same surname
  /// as the effective member (paternal surname inheritance).
  bool _shouldPrefillSurname(String? relation) {
    // Spouse and mother typically have different maiden surnames
    return relation != 'spouse' && relation != 'mother';
  }

  void _onRelationChanged(String? value) {
    setState(() {
      _selectedRelation = value;
      // Auto-set gender based on relation
      if (value == 'father') {
        _selectedGender = 'Male';
      } else if (value == 'mother') {
        _selectedGender = 'Female';
      }

      // Clear or restore surname based on relation type
      final member = _effectiveMember;
      if (_shouldPrefillSurname(value)) {
        // Restore surname from effective member
        if (member != null && _lastNameEnController.text.isEmpty) {
          _lastNameEnController.text = member.lastNameEn;
          _lastNameGuController.text = member.lastNameGu ?? '';
        }
      } else {
        // Clear surname for spouse/mother (they have different surnames)
        _lastNameEnController.clear();
        _lastNameGuController.clear();
      }

      if (value != 'spouse') {
        _currentSpouses = [];
      }
    });

    if (value == 'spouse') {
      _loadCurrentSpouses();
    }
  }

  RelationType _getRelationType() {
    switch (_selectedRelation) {
      case 'father':
        return RelationType.father;
      case 'mother':
        return RelationType.mother;
      case 'spouse':
        return RelationType.spouse;
      case 'child':
        return RelationType.child;
      case 'sibling':
        return RelationType.sibling;
      default:
        return RelationType.child;
    }
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    if (_selectedRelation == null) {
      showAppSnackBar(context, l10n.pleaseSelectRelationship, isError: true);
      return;
    }

    // Gender is mandatory for child and sibling
    if ((_selectedRelation == 'child' || _selectedRelation == 'sibling') &&
        !_linkExisting &&
        _selectedGender == null) {
      showAppSnackBar(context, l10n.pleaseSelectGender, isError: true);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final familyProvider = context.read<FamilyProvider>();

    // ── Re-fetch fresh data from server before guard checks ──
    final localMember = widget.targetMember ?? authProvider.currentMember;
    if (localMember != null) {
      try {
        final fresh = await SupabaseService.getFamilyMemberById(localMember.id);
        if (!mounted) return;
        if (fresh != null) {
          _freshMember = fresh;
        }
      } catch (_) {
        if (!mounted) return;
      }
    }
    final effectiveMember = _effectiveMember;

    if (effectiveMember == null) {
      showAppSnackBar(context, l10n.completeProfileFirst, isError: true);
      return;
    }

    // ── Guard: prevent duplicate father / mother (strictly one-to-one) ──
    final blockedRelation = blockedOneToOneRelation(
      _selectedRelation!,
      effectiveMember,
    );
    if (blockedRelation == 'father') {
      showAppSnackBar(context, l10n.alreadyExists(l10n.father), isError: true);
      return;
    }
    if (blockedRelation == 'mother') {
      showAppSnackBar(context, l10n.alreadyExists(l10n.mother), isError: true);
      return;
    }

    // ── Guard: linking an EXISTING member as father/mother must not create
    // an ancestry cycle (picking one of the target's own descendants). Only
    // relevant for "link existing" — a brand-new member can't already be
    // anyone's descendant. See wouldCreateAncestryCycle's doc comment. ──
    if ((_selectedRelation == 'father' || _selectedRelation == 'mother') &&
        _linkExisting &&
        _selectedExistingMember != null) {
      final isCycle = await wouldCreateAncestryCycle(
        targetId: effectiveMember.id,
        candidateId: _selectedExistingMember!.id,
        resolve: familyProvider.getMemberById,
      );
      if (!mounted) return;
      if (isCycle) {
        showAppSnackBar(
          context,
          l10n.ancestryCycleBlocked(_selectedExistingMember!.fullNameEn),
          isError: true,
        );
        return;
      }
    }

    // ── Guard: spouse is multi-entry (remarriage) — only block re-adding
    // the exact same pair, not a second spouse in general. Re-fetch the
    // current spouse list rather than trusting in-memory state, same
    // stale-data principle as the father/mother guards above. ──
    if (_selectedRelation == 'spouse' &&
        _linkExisting &&
        _selectedExistingMember != null) {
      final currentSpouses = await familyProvider.getSpousesOf(
        effectiveMember.id,
      );
      if (!mounted) return;
      final alreadyLinked = isSpouseAlreadyLinked(
        currentSpouses,
        _selectedExistingMember!.id,
      );
      if (alreadyLinked) {
        showAppSnackBar(
          context,
          l10n.spouseAlreadyLinked(_selectedExistingMember!.fullNameEn),
          isError: true,
        );
        return;
      }
    }

    // ── Confirmation dialog ──
    final nameToShow = _linkExisting && _selectedExistingMember != null
        ? _selectedExistingMember!.fullNameEn
        : '${_firstNameEnController.text.trim()} ${_lastNameEnController.text.trim()}';

    final relationLabel = _getRelationLabel(_selectedRelation!, l10n);
    final confirmMessage = _isTargetMode
        ? l10n.confirmAddMemberTarget(
            nameToShow,
            effectiveMember.fullNameEn,
            relationLabel,
          )
        : l10n.confirmAddMemberSelf(nameToShow, relationLabel);

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.confirm,
      message: confirmMessage,
      confirmText: l10n.add,
    );
    if (!confirmed) return;

    // ── For "child" relation: ask who the other parent is ──
    FamilyMember? otherParent;
    bool createNewOtherParent = false;
    String? newOtherParentFirstNameEn;
    String? newOtherParentLastNameEn;

    if (_selectedRelation == 'child') {
      final otherParentResult = await _askForOtherParent(
        effectiveMember,
        familyProvider,
      );
      if (otherParentResult == null) {
        // User cancelled the bottom sheet
        return;
      }
      otherParent = otherParentResult.existingMember;
      createNewOtherParent = otherParentResult.createNew;
      newOtherParentFirstNameEn = otherParentResult.newFirstName;
      newOtherParentLastNameEn = otherParentResult.newLastName;
    }

    setState(() => _isLoading = true);

    try {
      // ── If we need to create a new other parent first ──
      if (_selectedRelation == 'child' && createNewOtherParent) {
        final otherParentGender = effectiveMember.gender == 'Male'
            ? 'Female'
            : 'Male';
        final newParent = FamilyMember(
          id: const Uuid().v4(),
          createdAt: DateTime.now(),
          firstNameEn: newOtherParentFirstNameEn ?? l10n.unknown,
          lastNameEn: newOtherParentLastNameEn ?? effectiveMember.lastNameEn,
          gender: otherParentGender,
        );
        final createdParent = await familyProvider.createFamilyMember(
          newParent,
        );
        if (createdParent == null) {
          throw Exception('Failed to create other parent');
        }
        // Link as spouse to the effective member
        final linkedOtherParent = await familyProvider.linkFamilyMember(
          memberId: effectiveMember.id,
          relatedMemberId: createdParent.id,
          relationType: RelationType.spouse,
        );
        if (!linkedOtherParent) {
          throw Exception('Failed to link other parent as spouse');
        }
        otherParent = createdParent;
      }

      // ── Create or link the child ──
      String childId;

      if (_linkExisting && _selectedExistingMember != null) {
        childId = _selectedExistingMember!.id;
        // Link existing member as child
        final linked = await familyProvider.linkFamilyMember(
          memberId: effectiveMember.id,
          relatedMemberId: childId,
          relationType: _getRelationType(),
        );
        if (!linked) throw Exception('Failed to link existing member');
      } else {
        // Create new member
        final newMember = FamilyMember(
          id: const Uuid().v4(),
          createdAt: DateTime.now(),
          firstNameEn: _firstNameEnController.text.trim(),
          firstNameGu: _firstNameGuController.text.trim().isEmpty
              ? null
              : _firstNameGuController.text.trim(),
          lastNameEn: _lastNameEnController.text.trim(),
          lastNameGu: _lastNameGuController.text.trim().isEmpty
              ? null
              : _lastNameGuController.text.trim(),
          gender: _selectedGender,
          // Set parent links based on relation
          fatherId:
              _selectedRelation == 'child' && effectiveMember.gender == 'Male'
              ? effectiveMember.id
              : null,
          motherId:
              _selectedRelation == 'child' && effectiveMember.gender == 'Female'
              ? effectiveMember.id
              : null,
        );

        final created = await familyProvider.createFamilyMember(newMember);
        if (created == null) throw Exception('Failed to create member');
        childId = created.id;

        // Link the new member
        final linked = await familyProvider.linkFamilyMember(
          memberId: effectiveMember.id,
          relatedMemberId: childId,
          relationType: _getRelationType(),
        );
        if (!linked) throw Exception('Failed to link new member');
      }

      // ── Set the other parent on the child ──
      if (_selectedRelation == 'child' && otherParent != null) {
        final otherRelationType = otherParent.gender == 'Male'
            ? RelationType.father
            : RelationType.mother;
        final linkedOtherParent = await familyProvider.linkFamilyMember(
          memberId: childId,
          relatedMemberId: otherParent.id,
          relationType: otherRelationType,
        );
        if (!linkedOtherParent) {
          throw Exception('Failed to link other parent to child');
        }
      }

      // ── After adding a spouse, offer to link existing children ──
      // Best-effort: the primary spouse add above already succeeded, so a
      // failure linking one of several chosen children shouldn't throw and
      // discard that success — just surface it instead of reporting a plain
      // "added" success when a chosen link silently didn't happen.
      var someChildLinksFailed = false;
      if (_selectedRelation == 'spouse' && mounted) {
        final spouseId = childId; // ID of the newly added/linked spouse
        // Determine what parent role the new spouse fills
        final isSpouseFather = effectiveMember.gender == 'Female';
        final parentRelation = isSpouseFather
            ? RelationType.father
            : RelationType.mother;

        // Find children of the effective member missing the other parent
        final existingChildren = childrenNeedingOtherParent(
          egoNetwork: familyProvider.egoNetwork,
          parentId: effectiveMember.id,
          isSpouseFather: isSpouseFather,
        );

        if (existingChildren.isNotEmpty) {
          final toLink = await _askLinkChildrenToSpouse(existingChildren);
          if (toLink != null && toLink.isNotEmpty) {
            for (final child in toLink) {
              final linked = await familyProvider.linkFamilyMember(
                memberId: child.id,
                relatedMemberId: spouseId,
                relationType: parentRelation,
              );
              if (!linked) someChildLinksFailed = true;
            }
          }
        }
      }

      // Refresh the auth member so relationship IDs stay in sync
      await authProvider.refreshCurrentMember();

      if (mounted) {
        showAppSnackBar(
          context,
          someChildLinksFailed
              ? l10n.familyMemberAddedPartial
              : l10n.familyMemberAdded,
          isError: someChildLinksFailed,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(context, e),
          isError: true,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Shows a dialog asking which existing children should be linked to the
  /// newly-added spouse. Returns the list of children to link, or null/empty
  /// if the user cancels.
  Future<List<FamilyMember>?> _askLinkChildrenToSpouse(
    List<FamilyMember> children,
  ) async {
    if (!mounted) return null;
    final l10n = context.l10n;

    // All children are pre-selected
    final selected = Set<String>.from(children.map((c) => c.id));

    return showModalBottomSheet<List<FamilyMember>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final theme = Theme.of(ctx);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      l10n.linkChildrenToSpouse,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.linkChildrenToSpouseDesc,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ...children.map(
                      (child) => CheckboxListTile(
                        value: selected.contains(child.id),
                        title: Text(child.fullNameEn),
                        onChanged: (v) {
                          setSt(() {
                            if (v == true) {
                              selected.add(child.id);
                            } else {
                              selected.remove(child.id);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, <FamilyMember>[]),
                            child: Text(l10n.skip),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final result = children
                                  .where((c) => selected.contains(c.id))
                                  .toList();
                              Navigator.pop(ctx, result);
                            },
                            child: Text(l10n.confirm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a bottom sheet asking the user to pick the other parent for a child.
  /// Returns null if the user dismisses the sheet (cancel).
  Future<_OtherParentResult?> _askForOtherParent(
    FamilyMember parent,
    FamilyProvider familyProvider,
  ) async {
    // Fetch spouses / co-parents
    final spouses = await familyProvider.getSpousesOf(parent.id);

    if (!mounted) return null;

    final otherParentLabel = parent.gender == 'Male'
        ? context.l10n.mother
        : context.l10n.father;

    return showModalBottomSheet<_OtherParentResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _OtherParentPicker(
        spouses: spouses,
        otherParentLabel: otherParentLabel,
        defaultLastName: parent.lastNameEn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final familyProvider = context.watch<FamilyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isTargetMode
              ? '${l10n.addFamilyMember} — ${widget.targetMember!.firstNameEn}'
              : l10n.addFamilyMember,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Relation Selection
            SectionCard(
              title: l10n.relationship,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _relations.map((relation) {
                    final isSelected = _selectedRelation == relation;
                    return ChoiceChip(
                      label: Text(_getRelationLabel(relation, l10n)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _onRelationChanged(relation);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Context: existing spouse(s), shown so adding another spouse
            // is clearly additive, never a silent replace.
            if (_selectedRelation == 'spouse' &&
                _currentSpouses.isNotEmpty) ...[
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.addingAdditionalSpouse,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.currentSpousesLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentSpouses
                            .map(
                              (s) => Chip(
                                avatar: CircleAvatar(
                                  child: Text(
                                    s.initial,
                                  ),
                                ),
                                label: Text(s.fullNameEn),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Toggle: Create New or Link Existing
            SectionCard(
              title: l10n.addMethod,
              titleSpacing: AppSpacing.sm,
              children: [
                RadioGroup<bool>(
                  groupValue: _linkExisting,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _linkExisting = value);
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text(l10n.createNew),
                          value: false,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text(l10n.linkExisting),
                          value: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_linkExisting) ...[
              // Search and select existing member
              SectionCard(
                title: l10n.searchMembers,
                children: [
                  TextField(
                    controller: _existingMemberSearchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchMembers,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        familyProvider.searchMembers(value);
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  if (familyProvider.searchResults.isEmpty &&
                      _existingMemberSearchController.text.trim().length >= 2)
                    AppWidgets.empty(
                      message: l10n.noResultsFound,
                      icon: Icons.search_off,
                    )
                  else if (familyProvider.searchResults.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: familyProvider.searchResults.length,
                      itemBuilder: (context, index) {
                        final member = familyProvider.searchResults[index];
                        final isSelected =
                            _selectedExistingMember?.id == member.id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            child: Text(
                              member.initial,
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                          ),
                          title: Text(member.fullNameEn),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                          onTap: () {
                            setState(() => _selectedExistingMember = member);
                          },
                        );
                      },
                    ),
                ],
              ),
            ] else ...[
              // Create new member form
              SectionCard(
                title: l10n.name,
                children: [
                  TextFormField(
                    controller: _firstNameEnController,
                    decoration: InputDecoration(
                      labelText: '${l10n.firstName} *',
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: InputDecoration(labelText: l10n.gender),
                    items: [
                      DropdownMenuItem(value: 'Male', child: Text(l10n.male)),
                      DropdownMenuItem(
                        value: 'Female',
                        child: Text(l10n.female),
                      ),
                      DropdownMenuItem(value: 'Other', child: Text(l10n.other)),
                    ],
                    validator:
                        (_selectedRelation == 'child' ||
                            _selectedRelation == 'sibling')
                        ? (value) =>
                              value == null ? l10n.pleaseSelectGender : null
                        : null,
                    onChanged:
                        (_selectedRelation == 'father' ||
                            _selectedRelation == 'mother')
                        ? null
                        : (value) {
                            setState(() => _selectedGender = value);
                          },
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveMember,
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

  String _getRelationLabel(String relation, dynamic l10n) {
    switch (relation) {
      case 'father':
        return l10n.father;
      case 'mother':
        return l10n.mother;
      case 'spouse':
        return l10n.spouse;
      case 'child':
        return l10n.children;
      case 'sibling':
        return l10n.siblings;
      default:
        return relation;
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Data class for the other-parent selection result
// ─────────────────────────────────────────────────────────
class _OtherParentResult {
  /// An existing spouse / co-parent chosen by the user.
  final FamilyMember? existingMember;

  /// True if the user wants to create a brand-new other parent.
  final bool createNew;

  /// Name fields for the new other parent (only when [createNew] is true).
  final String? newFirstName;
  final String? newLastName;

  const _OtherParentResult({
    this.existingMember,
    this.createNew = false,
    this.newFirstName,
    this.newLastName,
  });

  /// Convenience: user chose to skip.
  const _OtherParentResult.skip()
    : existingMember = null,
      createNew = false,
      newFirstName = null,
      newLastName = null;
}

// ─────────────────────────────────────────────────────────
//  Bottom-sheet widget: pick the other parent
// ─────────────────────────────────────────────────────────
class _OtherParentPicker extends StatefulWidget {
  final List<FamilyMember> spouses;
  final String otherParentLabel; // e.g. "Mother" or "Father"
  final String defaultLastName;

  const _OtherParentPicker({
    required this.spouses,
    required this.otherParentLabel,
    required this.defaultLastName,
  });

  @override
  State<_OtherParentPicker> createState() => _OtherParentPickerState();
}

class _OtherParentPickerState extends State<_OtherParentPicker> {
  bool _showNewParentForm = false;
  final _newFirstNameController = TextEditingController();
  final _newLastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newLastNameController.text = widget.defaultLastName;
  }

  @override
  void dispose() {
    _newFirstNameController.dispose();
    _newLastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.whoIsThe(widget.otherParentLabel),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(l10n.selectOtherParent, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),

            // ── Existing spouses ──
            if (widget.spouses.isNotEmpty) ...[
              ...widget.spouses.map(
                (spouse) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        spouse.initial,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(spouse.fullNameEn),
                    subtitle: Text(
                      spouse.isClaimed ? l10n.verified : l10n.unclaimed,
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(
                      context,
                      _OtherParentResult(existingMember: spouse),
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
            ],

            // ── "Someone else" → inline form ──
            if (!_showNewParentForm) ...[
              ListTile(
                leading: Icon(
                  Icons.person_add,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  widget.spouses.isEmpty
                      ? l10n.addRelation(widget.otherParentLabel)
                      : l10n.someoneElse,
                ),
                subtitle: Text(l10n.createNewProfile),
                onTap: () => setState(() => _showNewParentForm = true),
              ),
            ] else ...[
              Text(
                l10n.newRelation(widget.otherParentLabel),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newFirstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.firstNameRequired,
                  isDense: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newLastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.lastNameRequired,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final first = _newFirstNameController.text.trim();
                    final last = _newLastNameController.text.trim();
                    if (first.isEmpty || last.isEmpty) {
                      showAppSnackBar(
                        context,
                        l10n.enterBothNames,
                        isError: true,
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      _OtherParentResult(
                        createNew: true,
                        newFirstName: first,
                        newLastName: last,
                      ),
                    );
                  },
                  child: Text(l10n.addRelation(widget.otherParentLabel)),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ── Skip ──
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pop(context, const _OtherParentResult.skip()),
                child: Text(l10n.skipOtherParent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
