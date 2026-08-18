import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/deep_link_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../profile/profile_form_screen.dart';
import 'add_family_member_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final FamilyMember member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  String? _inviteCode;
  bool _loadingCode = false;

  // Whether the current user may edit THIS node. Only your own profile, or an
  // unclaimed direct relative (father/mother/child/spouse/sibling), is
  // editable — enforced by RLS (migration 010) and mirrored here so the edit
  // affordance never appears for a node the backend would reject. Defaults to
  // false; resolved in initState.
  bool _canEdit = false;

  FamilyMember get member => widget.member;

  @override
  void initState() {
    super.initState();
    _resolveCanEdit();
    if (!member.isClaimed) _loadInviteCode();
    // Ensure the loaded ego network is actually centered on the member this
    // screen is showing, not whatever was last centered (e.g. "Self" from
    // the tree screen). Without this, navigating here via "View Profile"
    // (which doesn't recenter) leaves relation lookups on this screen —
    // and any add/remove-relation refresh triggered from here — reading a
    // stale, wrongly-scoped network.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FamilyProvider>().loadEgoNetwork(member.id);
    });
  }

  Future<void> _resolveCanEdit() async {
    final me = context.read<AuthProvider>().currentMember;
    // Own profile is always editable, and works offline (no round-trip).
    if (me != null && me.id == member.id) {
      setState(() => _canEdit = true);
      return;
    }
    // A claimed node that isn't mine is never editable — skip the call.
    if (member.isClaimed) return;
    // Unclaimed: ask the backend (authoritative; also covers spouse kinship).
    // Defaults to false on error/offline, which is the safe direction.
    try {
      final allowed = await SupabaseService.canEditMember(member.id);
      if (mounted) setState(() => _canEdit = allowed);
    } catch (_) {
      // Leave _canEdit false.
    }
  }

  Future<void> _loadInviteCode() async {
    setState(() => _loadingCode = true);
    try {
      final code = await SupabaseService.generateInviteCode(member.id);
      if (mounted) {
        setState(() {
          _inviteCode = code;
          _loadingCode = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsProvider = context.watch<SettingsProvider>();
    final locale = settingsProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.viewProfile),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.editProfile,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileFormScreen(
                      existingMember: member,
                      isCreatingProfile: false,
                    ),
                  ),
                );
              },
            ),
          if (!member.isClaimed)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: l10n.share,
              onPressed: () => _shareInvite(context),
            ),
          if (!member.isClaimed)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteProfile,
              onPressed: () => _showDeleteConfirmation(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        member.initial,
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.getFullName(locale),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (locale == 'gu' && member.firstNameGu != null)
                            Text(
                              member.fullNameEn,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                member.isClaimed
                                    ? Icons.verified
                                    : Icons.person_outline,
                                size: 16,
                                color: member.isClaimed
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                member.isClaimed
                                    ? l10n.verifiedMember
                                    : l10n.unclaimedProfile,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Details Cards
            _DetailCard(
              title: l10n.basicInformation,
              children: [
                if (member.gender != null)
                  _DetailRow(
                    icon: Icons.wc,
                    label: l10n.gender,
                    value: member.gender == 'Male'
                        ? l10n.male
                        : member.gender == 'Female'
                        ? l10n.female
                        : l10n.other,
                  ),
                if (member.dob != null)
                  _DetailRow(
                    icon: Icons.cake_outlined,
                    label: l10n.dateOfBirth,
                    value:
                        '${member.dob!.day.toString().padLeft(2, '0')}/${member.dob!.month.toString().padLeft(2, '0')}/${member.dob!.year}',
                  ),
                _DetailRow(
                  icon: member.isAlive ? Icons.favorite : Icons.favorite_border,
                  label: l10n.status,
                  value: member.isAlive ? l10n.isAlive : l10n.deceased,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (member.villageOrigin != null || member.currentCity != null)
              _DetailCard(
                title: l10n.location,
                children: [
                  if (member.villageOrigin != null)
                    _DetailRow(
                      icon: Icons.home_outlined,
                      label: l10n.villageOrigin,
                      value: member.villageOrigin!,
                    ),
                  if (member.currentCity != null)
                    _DetailRow(
                      icon: Icons.location_city,
                      label: l10n.currentCity,
                      value: member.currentCity!,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),

            if (member.deepDetails.isNotEmpty)
              _DetailCard(
                title: l10n.additionalDetails,
                children: [
                  if (member.deepDetails['education'] != null)
                    _DetailRow(
                      icon: Icons.school_outlined,
                      label: l10n.education,
                      value: member.deepDetails['education'],
                    ),
                  if (member.deepDetails['occupation'] != null)
                    _DetailRow(
                      icon: Icons.work_outline,
                      label: l10n.occupation,
                      value: member.deepDetails['occupation'],
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),

            // Family Relations Section
            _buildFamilyRelationsSection(context, member),
            const SizedBox(height: AppSpacing.md),

            // Invite Card for unclaimed profiles
            if (!member.isClaimed) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_add,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.inviteMember,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.inviteDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // ── Invite Code ──
                      Center(
                        child: Column(
                          children: [
                            Text(
                              l10n.inviteCode,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            if (_loadingCode)
                              const SizedBox(
                                height: 32,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (_inviteCode != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _inviteCode!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 6,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                        ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  IconButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _inviteCode!),
                                      );
                                      showAppSnackBar(context, l10n.codeCopied);
                                    },
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: l10n.inviteCode,
                                  ),
                                ],
                              ),
                            // Scannable QR of the bare code — the invitee can
                            // scan it from inside their app instead of typing.
                            // The text code above stays as the fallback.
                            if (_inviteCode != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: QrImageView(
                                  data: _inviteCode!,
                                  version: QrVersions.auto,
                                  size: 160,
                                  backgroundColor: Colors.white,
                                  semanticsLabel: l10n.inviteQrCode,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copyInviteMessage(context),
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(l10n.copyInviteLink),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _shareInvite(context),
                              icon: const Icon(Icons.share, size: 18),
                              label: Text(l10n.share),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns the invite code, loading it first if a load isn't already in
  /// flight (initState kicks one off, but these actions — the share icon in
  /// particular — are reachable before that finishes).
  Future<String?> _ensureInviteCode() async {
    if (_inviteCode != null) return _inviteCode;
    if (_loadingCode) return null;
    await _loadInviteCode();
    return _inviteCode;
  }

  void _copyInviteMessage(BuildContext context) async {
    final code = await _ensureInviteCode();
    if (code == null || !context.mounted) return;
    final locale = context.read<SettingsProvider>().locale.languageCode;
    final text = DeepLinkService.generateInviteText(
      member.getFullName(locale),
      code,
      locale,
    );
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackBar(context, context.l10n.linkCopied);
  }

  void _shareInvite(BuildContext context) async {
    final code = await _ensureInviteCode();
    if (code == null || !context.mounted) return;
    final locale = context.read<SettingsProvider>().locale.languageCode;
    final text = DeepLinkService.generateInviteText(
      member.getFullName(locale),
      code,
      locale,
    );
    SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProfile),
        content: Text(
          l10n.confirmDeleteMember(
            member.getFullName(
              context.read<SettingsProvider>().locale.languageCode,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteProfile(context);
    }
  }

  Future<void> _deleteProfile(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final familyProvider = context.read<FamilyProvider>();
      final success = await familyProvider.deleteFamilyMember(member.id);

      if (context.mounted) {
        if (success) {
          showAppSnackBar(
            context,
            l10n.memberDeleted(
              member.getFullName(
                context.read<SettingsProvider>().locale.languageCode,
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          showAppSnackBar(
            context,
            l10n.failedToDelete(
              friendlyErrorMessage(context, familyProvider.error ?? ''),
            ),
            isError: true,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(context, e),
          isError: true,
        );
      }
    }
  }

  Widget _buildFamilyRelationsSection(
    BuildContext context,
    FamilyMember member,
  ) {
    final familyProvider = context.watch<FamilyProvider>();
    final authProvider = context.read<AuthProvider>();
    final locale = context.read<SettingsProvider>().locale.languageCode;
    final l10n = context.l10n;

    // Get related family members from the ego network
    final father = familyProvider.egoNetwork
        .where((m) => member.fatherId != null && m.id == member.fatherId)
        .firstOrNull;

    final mother = familyProvider.egoNetwork
        .where((m) => member.motherId != null && m.id == member.motherId)
        .firstOrNull;

    // Spouse is multi-entry (remarriage) — show all, not just one.
    final spouses = familyProvider.spousesInNetwork(member.id);

    final children = familyProvider.egoNetwork
        .where((m) => m.fatherId == member.id || m.motherId == member.id)
        .toList();

    final siblings = familyProvider.egoNetwork.where((m) {
      if (m.id == member.id) return false;
      if (member.fatherId != null && m.fatherId == member.fatherId) return true;
      if (member.motherId != null && m.motherId == member.motherId) return true;
      return false;
    }).toList();

    // Allow adding relations for unclaimed members or own profile
    final isOwnProfile = member.id == authProvider.currentMember?.id;
    final canAddRelations = !member.isClaimed || isOwnProfile;

    final hasRelations =
        father != null ||
        mother != null ||
        spouses.isNotEmpty ||
        children.isNotEmpty ||
        siblings.isNotEmpty;

    // If no relations and can't add any, hide the section
    if (!hasRelations && !canAddRelations) {
      return const SizedBox.shrink();
    }

    return _DetailCard(
      title: l10n.familyRelations,
      children: [
        // ── Father ──
        if (father != null)
          _FamilyRelationTile(
            relation: l10n.father,
            member: father,
            locale: locale,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberDetailScreen(member: father),
              ),
            ),
          ),
        if (father == null && canAddRelations)
          _AddRelationTile(
            label: l10n.addFather,
            icon: Icons.person_add,
            onTap: () => _navigateToAddMember(context, member, 'father'),
          ),

        // ── Mother ──
        if (mother != null)
          _FamilyRelationTile(
            relation: l10n.mother,
            member: mother,
            locale: locale,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberDetailScreen(member: mother),
              ),
            ),
          ),
        if (mother == null && canAddRelations)
          _AddRelationTile(
            label: l10n.addMother,
            icon: Icons.person_add,
            onTap: () => _navigateToAddMember(context, member, 'mother'),
          ),

        // ── Spouse(s) — multi-entry (remarriage), always shown as a list ──
        if (spouses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.spouses} (${spouses.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ...spouses.map(
            (s) => _FamilyRelationTile(
              relation: '',
              member: s,
              locale: locale,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: s),
                ),
              ),
              onRemove: canAddRelations
                  ? () => _confirmRemoveSpouse(context, member, s)
                  : null,
            ),
          ),
        ],
        // Always offered — a person can gain another spouse (remarriage),
        // this is never hidden after the first one is added.
        if (canAddRelations)
          _AddRelationTile(
            label: l10n.addSpouse,
            icon: Icons.favorite_border,
            onTap: () => _navigateToAddMember(context, member, 'spouse'),
          ),

        // ── Children ──
        if (children.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.children} (${children.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ...children.map(
            (child) => _FamilyRelationTile(
              relation: '',
              member: child,
              locale: locale,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: child),
                ),
              ),
            ),
          ),
        ],
        if (canAddRelations)
          _AddRelationTile(
            label: l10n.addChild,
            icon: Icons.child_care,
            onTap: () => _navigateToAddMember(context, member, 'child'),
          ),

        // ── Siblings ──
        if (siblings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.siblings} (${siblings.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ...siblings.map(
            (sibling) => _FamilyRelationTile(
              relation: '',
              member: sibling,
              locale: locale,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: sibling),
                ),
              ),
            ),
          ),
        ],
        if (canAddRelations)
          _AddRelationTile(
            label: l10n.addSibling,
            icon: Icons.group_add,
            onTap: () => _navigateToAddMember(context, member, 'sibling'),
          ),
      ],
    );
  }

  /// Navigate to AddFamilyMemberScreen for the given member.
  void _navigateToAddMember(
    BuildContext context,
    FamilyMember member,
    String relation,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final isOwnProfile = member.id == authProvider.currentMember?.id;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(
          preselectedRelation: relation,
          targetMember: isOwnProfile ? null : member,
        ),
      ),
    );

    // If a member was added, refresh the ego network so this screen updates.
    // Always reload for `member` (the profile this screen shows) rather than
    // trusting the provider's current centerMember — this screen may have
    // been reached without recentering (e.g. via "View Profile"), so
    // centerMember isn't guaranteed to be `member`.
    if (result == true && context.mounted) {
      await context.read<FamilyProvider>().loadEgoNetwork(member.id);
    }
  }

  /// Lets a user correct a mistaken spouse link. Only removes the
  /// spouse_relationships edge — does NOT delete either member's profile.
  Future<void> _confirmRemoveSpouse(
    BuildContext context,
    FamilyMember member,
    FamilyMember spouseMember,
  ) async {
    final l10n = context.l10n;
    final locale = context.read<SettingsProvider>().locale.languageCode;

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.removeSpouse,
      message: l10n.confirmRemoveSpouse(spouseMember.getFullName(locale)),
      confirmText: l10n.remove,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final familyProvider = context.read<FamilyProvider>();
    final success = await familyProvider.removeSpouse(
      member.id,
      spouseMember.id,
    );
    if (!context.mounted) return;

    if (success) {
      showAppSnackBar(context, l10n.spouseRemoved);
    } else {
      showAppSnackBar(
        context,
        l10n.failedToDelete(
          friendlyErrorMessage(context, familyProvider.error ?? ''),
        ),
        isError: true,
      );
    }
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SectionCard(title: title, children: children);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyRelationTile extends StatelessWidget {
  final String relation;
  final FamilyMember member;
  final String locale;
  final VoidCallback onTap;

  /// When set, shows a large-touch-target remove/unlink action (used to let
  /// a user correct a mistaken spouse link). Null hides the action entirely.
  final VoidCallback? onRemove;

  const _FamilyRelationTile({
    required this.relation,
    required this.member,
    required this.locale,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: Text(
                  member.initial,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (relation.isNotEmpty)
                      Text(
                        relation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    Text(
                      member.getFullName(locale),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (!member.isClaimed)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              context.l10n.unclaimed,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.link_off),
                  tooltip: context.l10n.removeSpouse,
                  color: Theme.of(context).colorScheme.error,
                  onPressed: onRemove,
                ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRelationTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddRelationTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
