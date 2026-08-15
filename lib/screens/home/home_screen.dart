import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../profile/profile_form_screen.dart';
import '../family/family_tree_screen.dart';
import '../family/add_family_member_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer loading data until after the first frame to avoid conflicts with navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentMember != null) {
      await context.read<FamilyProvider>().loadEgoNetwork(
        authProvider.currentMember!.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      body: Column(
        children: [
          // Offline banner
          if (settingsProvider.isOffline) AppWidgets.offlineBanner(context),

          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const _DashboardTab(),
                const FamilyTreeScreen(),
                _SearchTab(
                  onMemberSelected: (member) async {
                    await context.read<FamilyProvider>().loadEgoNetwork(member.id);
                    if (mounted) setState(() => _currentIndex = 1);
                  },
                ),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_tree_outlined),
            activeIcon: const Icon(Icons.account_tree),
            label: l10n.familyTree,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_outlined),
            activeIcon: const Icon(Icons.search),
            label: l10n.search,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authProvider = context.watch<AuthProvider>();
    final familyProvider = context.watch<FamilyProvider>();
    final member = authProvider.currentMember;
    final settingsProvider = context.watch<SettingsProvider>();
    final locale = settingsProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (settingsProvider.hasPendingSyncs)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => settingsProvider.syncData(),
              tooltip: l10n.syncData,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (member != null) {
            await familyProvider.loadEgoNetwork(member.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              Card(
                child: InkWell(
                  onTap: () {
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
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            member?.initial ?? '?',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member?.getFullName(locale) ?? l10n.unknown,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              if (member?.currentCity != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      member!.currentCity!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // A failed fetch with nothing cached yet would otherwise render
              // as an empty "+" tile per relation, indistinguishable from a
              // genuinely new profile with no family added — surface it.
              if (familyProvider.error != null &&
                  familyProvider.egoNetwork.isEmpty) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            friendlyErrorMessage(context, familyProvider.error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          tooltip: l10n.retry,
                          onPressed: () {
                            if (member != null) {
                              familyProvider.loadEgoNetwork(member.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Family Overview
              Text(
                l10n.myFamily,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),

              // Quick Family Cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _FamilyCard(
                    icon: Icons.man,
                    label: l10n.father,
                    member: familyProvider.father,
                    onAdd: () => _addFamilyMember(context, 'father'),
                    locale: locale,
                  ),
                  _FamilyCard(
                    icon: Icons.woman,
                    label: l10n.mother,
                    member: familyProvider.mother,
                    onAdd: () => _addFamilyMember(context, 'mother'),
                    locale: locale,
                  ),
                  _FamilyCard(
                    icon: Icons.favorite,
                    label: l10n.spouse,
                    member: familyProvider.spouse,
                    onAdd: () => _addFamilyMember(context, 'spouse'),
                    locale: locale,
                  ),
                  _FamilyCard(
                    icon: Icons.child_care,
                    label: l10n.children,
                    count: familyProvider.children.length,
                    onAdd: () => _addFamilyMember(context, 'child'),
                    locale: locale,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Siblings
              if (familyProvider.siblings.isNotEmpty) ...[
                Text(
                  l10n.siblings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: familyProvider.siblings.length,
                    itemBuilder: (context, index) {
                      final sibling = familyProvider.siblings[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _SiblingChip(member: sibling, locale: locale),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFamilyMember(context, null),
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addFamilyMember),
      ),
    );
  }

  void _addFamilyMember(BuildContext context, String? relation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(preselectedRelation: relation),
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic member;
  final int? count;
  final VoidCallback onAdd;
  final String locale;

  const _FamilyCard({
    required this.icon,
    required this.label,
    this.member,
    this.count,
    required this.onAdd,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final hasMember = member != null || (count != null && count! > 0);

    return Card(
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: hasMember
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              if (member != null)
                Text(
                  member.getFullName(locale),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                )
              else if (count != null && count! > 0)
                Text('$count', style: Theme.of(context).textTheme.bodySmall)
              else
                Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiblingChip extends StatelessWidget {
  final dynamic member;
  final String locale;

  const _SiblingChip({required this.member, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                member.initial,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              member.getFullName(locale),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  final void Function(FamilyMember member) onMemberSelected;

  const _SearchTab({required this.onMemberSelected});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final familyProvider = context.watch<FamilyProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final locale = settingsProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.search)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchMembers,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          familyProvider.clearSearch();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                if (value.length >= 2) {
                  familyProvider.searchMembers(value);
                } else {
                  familyProvider.clearSearch();
                }
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: familyProvider.isLoading
                ? AppWidgets.loading()
                : (familyProvider.error != null &&
                      familyProvider.searchResults.isEmpty &&
                      _searchController.text.trim().length >= 2)
                ? AppWidgets.error(
                    context: context,
                    message: friendlyErrorMessage(
                      context,
                      familyProvider.error!,
                    ),
                    onRetry: () =>
                        familyProvider.searchMembers(_searchController.text),
                  )
                : familyProvider.searchResults.isEmpty
                ? AppWidgets.empty(
                    message: l10n.searchMembers,
                    icon: Icons.search,
                  )
                : ListView.builder(
                    itemCount: familyProvider.searchResults.length,
                    itemBuilder: (context, index) {
                      final member = familyProvider.searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            member.initial,
                          ),
                        ),
                        title: Text(member.getFullName(locale)),
                        subtitle: member.currentCity != null
                            ? Text(member.currentCity!)
                            : null,
                        trailing: member.isClaimed
                            ? const Icon(Icons.verified, color: Colors.green)
                            : const Icon(Icons.person_outline),
                        onTap: () => widget.onMemberSelected(member),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
