import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/gujarat_places_service.dart';

import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../family/member_detail_screen.dart';

/// A browsable, filterable directory with two tabs:
///  - "My family": the user's CONNECTED family component (get_connected_tree),
///    filtered in memory. Deliberately scoped to the component so it can't be
///    used to browse other families — this is the original directory behavior.
///  - "All": every member in the database, paginated via getMembersPage and
///    server-side search. RLS (migration 006) already allows this SELECT, so no
///    new migration is needed.
class DirectoryScreen extends StatefulWidget {
  /// Whether this is the tab currently shown in the home IndexedStack. The
  /// screen is mounted at app start (possibly offline); becoming visible
  /// retries an "All" load that failed then.
  final bool isVisible;

  const DirectoryScreen({super.key, this.isVisible = true});

  /// Test-only seam replacing the online check + getMembersPage fetch.
  @visibleForTesting
  static Future<List<FamilyMember>> Function(int limit, int offset)?
      debugFetchPage;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen>
    with SingleTickerProviderStateMixin {
  static const int _allPageSize = 50; // <= Supabase max_rows cap

  final _searchController = TextEditingController();
  String _query = '';
  String? _villageFilter; // null = all villages (My family tab only)
  String _loadedForId = '';

  late final TabController _tabController;

  // "All" tab pagination state (whole-database list).
  final _allScroll = ScrollController();
  final List<FamilyMember> _all = [];
  int _allOffset = 0;
  bool _allLoading = false;
  bool _allHasMore = true;
  bool _allFailed = false; // last fetch fell back to cache

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allScroll.addListener(_onAllScroll);
    _loadNextAllPage();
  }

  @override
  void didUpdateWidget(DirectoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && _allFailed) _refreshAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _allScroll.dispose();
    super.dispose();
  }

  void _ensureLoaded(FamilyProvider fp, String? myId) {
    // Keyed on dataVersion too, so an add/edit made elsewhere reloads the list.
    final key = '$myId@${fp.dataVersion}';
    if (myId == null || fp.isLoadingFullTree || _loadedForId == key) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fp.loadFullTree(myId);
        setState(() => _loadedForId = key);
      }
    });
  }

  void _onAllScroll() {
    if (!_allScroll.hasClients) return;
    final pos = _allScroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadNextAllPage();
  }

  /// Loads the next page of the whole-database list. Offline-safe: on failure
  /// (or offline) it falls back to the cached members and flags a gentle notice,
  /// matching the app's degrade-gracefully pattern.
  Future<void> _loadNextAllPage() async {
    if (_allLoading || !_allHasMore) return;
    setState(() => _allLoading = true);
    try {
      final fetch = DirectoryScreen.debugFetchPage;
      if (fetch == null && !await SyncService.isOnline()) {
        _fallbackAllToCache();
        return;
      }
      final page = fetch != null
          ? await fetch(_allPageSize, _allOffset)
          : await SupabaseService.getMembersPage(
              limit: _allPageSize, offset: _allOffset);
      if (!mounted) return;
      setState(() {
        // First page (initial load or refresh) replaces any cached fallback.
        if (_allOffset == 0) _all.clear();
        _all.addAll(page);
        _allOffset += page.length;
        _allHasMore = page.length == _allPageSize;
        _allFailed = false;
        _allLoading = false;
      });
    } catch (e) {
      debugPrint('Directory "All" page load failed: $e');
      _fallbackAllToCache();
    }
  }

  void _fallbackAllToCache() {
    if (!mounted) return;
    // The cache read itself can throw if local storage isn't available (e.g. a
    // widget test with no Hive) — never let it escape, mirroring loadFullTree.
    List<FamilyMember> cached = const [];
    try {
      cached = LocalStorageService.getAllFamilyMembers();
    } catch (_) {}
    setState(() {
      if (_all.isEmpty) _all.addAll(cached);
      _allHasMore = false; // don't keep retrying a dead network on scroll
      _allFailed = true;
      _allLoading = false;
    });
  }

  /// Pull-to-refresh / retry for "All": restart pagination from the top. The
  /// current list stays on screen until the first fresh page replaces it.
  Future<void> _refreshAll() async {
    if (_allLoading) return; // don't reset the offset under an in-flight page
    _allOffset = 0;
    _allHasMore = true;
    return _loadNextAllPage();
  }

  /// Makes a non-scrollable state (loading/empty) pullable too — otherwise a
  /// user who opened the app offline and sees "No members yet" can't retry.
  Widget _pullable(Future<void> Function() onRefresh, Widget child) =>
      RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: c.maxHeight, child: child)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fp = context.watch<FamilyProvider>();
    final me = context.read<AuthProvider>().currentMember;

    _ensureLoaded(fp, me?.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.directory),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.directoryMyFamily),
            Tab(text: l10n.directoryAll),
          ],
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
                          fp.clearSearch();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                // ponytail: fire server search on every tab; the provider
                // debounces (350ms) + caps at pageSize, so the wasted call while
                // on "My family" is negligible for a village-sized dataset.
                fp.searchMembers(v);
                setState(() => _query = v);
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyFamilyTab(fp, me),
                _buildAllTab(fp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- "My family" tab: connected component, in-memory search/filter ----
  Widget _buildMyFamilyTab(FamilyProvider fp, FamilyMember? me) {
    final l10n = context.l10n;
    final locale = context.watch<SettingsProvider>().locale.languageCode;
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
      // Same order as the Everyone tab (server: last_name_en, first_name_en),
      // so families group together on both tabs.
      ..sort((a, b) => '${a.lastNameEn} ${a.firstNameEn}'
          .toLowerCase()
          .compareTo('${b.lastNameEn} ${b.firstNameEn}'.toLowerCase()));

    Future<void> refreshFamily() async {
      if (me != null) await fp.loadFullTree(me.id);
    }

    return Column(
      children: [
        if (villages.isNotEmpty)
          // Sized by the chips themselves: a fixed 44px row squashed the
          // theme's 48dp+ chips and pushed their labels to the bottom edge.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
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
                      label: Text(GujaratPlacesService.displayName(v, locale)),
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
          child: fp.isLoadingFullTree && people.isEmpty
              ? AppWidgets.loading(message: l10n.loading)
              : filtered.isEmpty
                  ? _pullable(
                      refreshFamily,
                      AppWidgets.empty(
                        message: (q.isNotEmpty || _villageFilter != null)
                            ? l10n.noResultsFound
                            : l10n.noMembersYet,
                        icon: Icons.people_outline,
                      ))
                  : RefreshIndicator(
                      onRefresh: refreshFamily,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _memberTile(filtered[i], me, locale),
                      ),
                    ),
        ),
      ],
    );
  }

  // ---- "All" tab: whole database, paginated + server search ----
  Widget _buildAllTab(FamilyProvider fp) {
    final l10n = context.l10n;
    final locale = context.watch<SettingsProvider>().locale.languageCode;
    final me = context.read<AuthProvider>().currentMember;
    final searching = _query.trim().isNotEmpty;

    // While searching, defer to the provider's debounced server search.
    if (searching) {
      final results = fp.searchResults;
      if (fp.isLoading && results.isEmpty) {
        return AppWidgets.loading(message: l10n.loading);
      }
      if (results.isEmpty) {
        return AppWidgets.empty(
            message: l10n.noResultsFound, icon: Icons.search_off);
      }
      return ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, i) => _memberTile(results[i], me, locale),
      );
    }

    if (_all.isEmpty) {
      if (_allLoading) return AppWidgets.loading(message: l10n.loading);
      return _pullable(
          _refreshAll,
          AppWidgets.empty(
              message: l10n.noMembersYet, icon: Icons.people_outline));
    }

    return Column(
      children: [
        if (_allFailed)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Text(
              l10n.showingSavedMembers,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView.builder(
              controller: _allScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _all.length + (_allHasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _all.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _memberTile(_all[i], me, locale);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _memberTile(FamilyMember m, FamilyMember? me, String locale) {
    final l10n = context.l10n;
    final isMe = m.id == me?.id;
    return ListTile(
      leading: CircleAvatar(child: Text(m.initial)),
      title: Text(m.getFullName(locale)),
      subtitle: m.villageOrigin != null && m.villageOrigin!.trim().isNotEmpty
          ? Text(GujaratPlacesService.displayName(m.villageOrigin!, locale))
          : null,
      trailing: isMe
          ? Chip(
              label: Text(l10n.you),
              visualDensity: VisualDensity.compact,
            )
          : (m.isClaimed
              ? const Icon(Icons.verified, size: 18, color: Colors.green)
              : null),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(member: m),
        ),
      ),
    );
  }
}
