import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../family/member_detail_screen.dart';

/// A browsable, filterable directory of everyone in the user's CONNECTED family
/// (the same connected component the full-tree view shows — see
/// get_connected_tree). Deliberately scoped to the component: people in a
/// separate, unconnected tree never appear here, so it can't be used to browse
/// other families' data. Replaces the old whole-database Search, which leaked
/// across trees.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _villageFilter; // null = all villages
  String _loadedForId = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _ensureLoaded(FamilyProvider fp, String? myId) {
    if (myId == null || fp.isLoadingFullTree || _loadedForId == myId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fp.loadFullTree(myId);
        setState(() => _loadedForId = myId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fp = context.watch<FamilyProvider>();
    final me = context.read<AuthProvider>().currentMember;
    final locale = context.watch<SettingsProvider>().locale.languageCode;

    _ensureLoaded(fp, me?.id);

    final people = fp.fullTree;
    final villages = (people
            .map((m) => m.villageOrigin)
            .whereType<String>()
            .where((v) => v.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort());

    final q = _query.trim().toLowerCase();
    final filtered = people.where((m) {
      if (_villageFilter != null && m.villageOrigin != _villageFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.getFullName('en').toLowerCase().contains(q) ||
          m.getFullName('gu').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.getFullName(locale).compareTo(b.getFullName(locale)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.directory),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: fp.isLoadingFullTree
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox.shrink(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchByName,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (villages.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(l10n.allVillages),
                      selected: _villageFilter == null,
                      onSelected: (_) => setState(() => _villageFilter = null),
                    ),
                  ),
                  for (final v in villages)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(v),
                        selected: _villageFilter == v,
                        onSelected: (_) => setState(() => _villageFilter = v),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.peopleCount(filtered.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? AppWidgets.empty(
                    message: fp.isLoadingFullTree
                        ? l10n.loading
                        : l10n.noResultsFound,
                    icon: Icons.people_outline,
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final m = filtered[i];
                      final isMe = m.id == me?.id;
                      return ListTile(
                        leading: CircleAvatar(child: Text(m.initial)),
                        title: Text(m.getFullName(locale)),
                        subtitle: m.villageOrigin != null &&
                                m.villageOrigin!.trim().isNotEmpty
                            ? Text(m.villageOrigin!)
                            : null,
                        trailing: isMe
                            ? Chip(
                                label: Text(l10n.you),
                                visualDensity: VisualDensity.compact,
                              )
                            : (m.isClaimed
                                ? const Icon(Icons.verified,
                                    size: 18, color: Colors.green)
                                : null),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberDetailScreen(member: m),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
