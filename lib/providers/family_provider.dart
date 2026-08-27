import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/family_member.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';

class FamilyProvider extends ChangeNotifier {
  List<FamilyMember> _egoNetwork = [];
  List<SpouseLink> _spouseLinks = [];
  // The entire connected family component for the full-tree view (see
  // get_connected_tree). Separate from the ego network so switching views
  // never drops the other's cached data.
  List<FamilyMember> _fullTree = [];
  List<SpouseLink> _fullTreeSpouseLinks = [];
  bool _isLoadingFullTree = false;
  List<FamilyMember> _searchResults = [];
  FamilyMember? _selectedMember;
  FamilyMember? _centerMember;
  bool _isLoading = false;
  String? _error;

  List<FamilyMember> get egoNetwork => _egoNetwork;
  List<SpouseLink> get spouseLinks => _spouseLinks;
  List<FamilyMember> get fullTree => _fullTree;
  List<SpouseLink> get fullTreeSpouseLinks => _fullTreeSpouseLinks;
  bool get isLoadingFullTree => _isLoadingFullTree;
  List<FamilyMember> get searchResults => _searchResults;
  FamilyMember? get selectedMember => _selectedMember;
  FamilyMember? get centerMember => _centerMember;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get family relations from ego network
  FamilyMember? get father => _centerMember?.fatherId != null
      ? _egoNetwork.where((m) => m.id == _centerMember!.fatherId).firstOrNull
      : null;

  FamilyMember? get mother => _centerMember?.motherId != null
      ? _egoNetwork.where((m) => m.id == _centerMember!.motherId).firstOrNull
      : null;

  /// All spouses of the center member, in link order (supports remarriage —
  /// may be more than one). Prefer this over [spouse] wherever the UI can
  /// show more than a single spouse.
  List<FamilyMember> get spouses =>
      _centerMember == null ? [] : spousesInNetwork(_centerMember!.id);

  /// Convenience single-spouse accessor for call sites that only show one
  /// (e.g. a compact stat card). Returns the first linked spouse, if any
  /// (see [spousesInNetwork] for the co-parent-inference fallback it uses).
  FamilyMember? get spouse =>
      _centerMember == null ? null : spousesInNetwork(_centerMember!.id).firstOrNull;

  /// Spouses of [memberId] found within the currently loaded ego network:
  /// explicit spouse_relationships links, plus — when no explicit link
  /// exists yet — a co-parent inferred from a shared child (legacy/
  /// incomplete data compatibility). Synchronous, no network call; safe to
  /// use in build methods. Every call site that needs spouse resolution
  /// (the [spouse]/[spouses] getters, [getSpousesOf]'s fast path, and the
  /// tree screen) goes through this so the fallback behavior stays uniform.
  List<FamilyMember> spousesInNetwork(String memberId) {
    final ids = _spouseLinks
        .where((l) => l.memberId == memberId || l.spouseId == memberId)
        .map((l) => l.otherId(memberId))
        .toSet();

    for (var m in _egoNetwork) {
      if (m.fatherId == memberId && m.motherId != null) ids.add(m.motherId!);
      if (m.motherId == memberId && m.fatherId != null) ids.add(m.fatherId!);
    }
    ids.remove(memberId);

    return _egoNetwork.where((m) => ids.contains(m.id)).toList();
  }

  List<FamilyMember> get children {
    if (_centerMember == null) return [];
    return _egoNetwork.where((m) =>
        m.fatherId == _centerMember!.id || m.motherId == _centerMember!.id
    ).toList();
  }

  List<FamilyMember> get siblings {
    if (_centerMember == null) return [];
    return _egoNetwork.where((m) {
      if (m.id == _centerMember!.id) return false;
      if (_centerMember!.fatherId != null && m.fatherId == _centerMember!.fatherId) return true;
      if (_centerMember!.motherId != null && m.motherId == _centerMember!.motherId) return true;
      return false;
    }).toList();
  }

  /// Loads the ego-centric network (member + parents + spouses + children +
  /// siblings) for [memberId] — scoped, not the whole village. Online, this
  /// goes through the get_ego_network RPC and the result is cached locally
  /// (upsert, not a wipe-and-replace) so previously visited neighborhoods
  /// stay available offline. See vanshavali-scale-advisor / the ego-fetch
  /// discussion in docs/claude_handoff for why this must never widen to a
  /// full-table fetch — that's what the explicit "Full Sync" setting is for.
  Future<void> loadEgoNetwork(String memberId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        _egoNetwork = await SupabaseService.getEgoCentricNetwork(memberId);
        final ids = _egoNetwork.map((m) => m.id).toList();
        _spouseLinks = await SupabaseService.getSpouseLinksFor(ids);
        // Cache locally (incremental — merges this neighborhood in, doesn't
        // clear previously cached ones).
        await LocalStorageService.saveFamilyMembers(_egoNetwork);
        await LocalStorageService.saveSpouseLinks(_spouseLinks);
      } else {
        _egoNetwork = LocalStorageService.getEgoCentricNetwork(memberId);
        _spouseLinks = _localSpouseLinksFor(_egoNetwork.map((m) => m.id).toList());
      }

      _centerMember = _egoNetwork.where((m) => m.id == memberId).firstOrNull;
    } catch (e) {
      debugPrint('Error in loadEgoNetwork: $e');
      _error = e.toString();
      // Local fallback — stays scoped to this neighborhood, same as above,
      // not a dump of the entire local cache.
      _egoNetwork = LocalStorageService.getEgoCentricNetwork(memberId);
      _spouseLinks = _localSpouseLinksFor(_egoNetwork.map((m) => m.id).toList());
      _centerMember = _egoNetwork.where((m) => m.id == memberId).firstOrNull;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Loads the ENTIRE connected family component (see get_connected_tree,
  /// migration 014) for the full-tree view — every relative reachable from
  /// [rootId] through parents, children, and marriages. Online-only for the
  /// authoritative component; offline it falls back to whatever whole set is
  /// cached locally (still correct, just possibly stale/partial). This is a
  /// deliberate full-component fetch, distinct from the routine ego load.
  Future<void> loadFullTree(String rootId) async {
    _isLoadingFullTree = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        _fullTree = await SupabaseService.getConnectedTree(rootId);
        final ids = _fullTree.map((m) => m.id).toList();
        _fullTreeSpouseLinks = await SupabaseService.getSpouseLinksFor(ids);
        await LocalStorageService.saveFamilyMembers(_fullTree);
        await LocalStorageService.saveSpouseLinks(_fullTreeSpouseLinks);
      } else {
        _fullTree = LocalStorageService.getAllFamilyMembers();
        _fullTreeSpouseLinks =
            _localSpouseLinksFor(_fullTree.map((m) => m.id).toList());
      }
    } catch (e) {
      debugPrint('Error in loadFullTree: $e');
      _error = e.toString();
      _fullTree = LocalStorageService.getAllFamilyMembers();
      _fullTreeSpouseLinks =
          _localSpouseLinksFor(_fullTree.map((m) => m.id).toList());
    }

    _isLoadingFullTree = false;
    notifyListeners();
  }

  // Separate pool for the Pedigree view. get_ego_network/loadEgoNetwork above
  // only ever returns one generation of parents (by design, for the default
  // tree view) — nowhere near enough to resolve a multi-generation pedigree
  // chain, which needs grandparents/great-grandparents that were never
  // fetched at all. See get_ancestor_chain (migration 005) and
  // buildPedigreeChain in family_tree_screen.dart.
  List<FamilyMember> _ancestorChain = [];
  List<FamilyMember> get ancestorChain => _ancestorChain;
  // Which member the currently-loaded ancestorChain was fetched for, so
  // callers can tell fresh data from stale (e.g. after re-centering) without
  // duplicating that tracking themselves.
  String? _ancestorChainForId;
  String? get ancestorChainForId => _ancestorChainForId;
  bool _isLoadingAncestors = false;
  bool get isLoadingAncestors => _isLoadingAncestors;

  /// Fetches [memberId]'s multi-generation ancestor set for the Pedigree
  /// view. Online-only — offline, [ancestorChainForId] simply never becomes
  /// [memberId], and the pedigree screen falls back to [egoNetwork] (one
  /// generation) rather than showing nothing, matching this app's general
  /// "degrade gracefully offline" pattern elsewhere.
  Future<void> loadAncestorChain(String memberId) async {
    _isLoadingAncestors = true;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        _ancestorChain = await SupabaseService.getAncestorChain(memberId);
        _ancestorChainForId = memberId;
      }
    } catch (e) {
      debugPrint('Error in loadAncestorChain: $e');
      _error = e.toString();
    }

    _isLoadingAncestors = false;
    notifyListeners();
  }

  List<SpouseLink> _localSpouseLinksFor(List<String> ids) {
    final links = <SpouseLink>[];
    final seenPairs = <String>{};
    for (final id in ids) {
      for (final otherId in LocalStorageService.getSpouseIdsOf(id)) {
        final pairKey = ([id, otherId]..sort()).join('_');
        if (seenPairs.add(pairKey)) {
          links.add(SpouseLink(memberId: id, spouseId: otherId));
        }
      }
    }
    return links;
  }

  void setCenterMember(FamilyMember member) {
    _centerMember = member;
    notifyListeners();
  }

  /// Test-only seam: directly injects an ego network + spouse links (and
  /// optionally a center member) without going through [loadEgoNetwork],
  /// which is entangled with live SupabaseService/LocalStorageService/
  /// SyncService calls. Lets pure resolution logic (spousesInNetwork,
  /// spouses, getSpousesOf's network-only path, children, siblings) be unit
  /// tested against a fixture without a live backend. Not used by any
  /// production code path.
  @visibleForTesting
  void debugSetNetworkForTesting({
    required List<FamilyMember> egoNetwork,
    List<SpouseLink> spouseLinks = const [],
    FamilyMember? centerMember,
    bool? isLoading,
  }) {
    _egoNetwork = egoNetwork;
    _spouseLinks = spouseLinks;
    _centerMember = centerMember;
    if (isLoading != null) _isLoading = isLoading;
    notifyListeners();
  }

  /// Test-only seam: directly injects an ancestor chain (as if
  /// [loadAncestorChain] had already resolved it for [forId]) without a live
  /// backend. Lets the Pedigree view's pool-selection logic be tested
  /// against a fixture with more generations than [debugSetNetworkForTesting]
  /// alone could provide (egoNetwork only ever has one generation of
  /// parents, by design). Not used by any production code path.
  @visibleForTesting
  void debugSetAncestorChainForTesting({
    required List<FamilyMember> ancestorChain,
    required String forId,
  }) {
    _ancestorChain = ancestorChain;
    _ancestorChainForId = forId;
    notifyListeners();
  }

  void selectMember(FamilyMember? member) {
    _selectedMember = member;
    notifyListeners();
  }

  Future<void> searchMembers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        _searchResults = await SupabaseService.searchFamilyMembers(query);
      } else {
        _searchResults = LocalStorageService.searchFamilyMembers(query);
      }
    } catch (e) {
      debugPrint('Error in searchMembers: $e');
      _error = e.toString();
      _searchResults = LocalStorageService.searchFamilyMembers(query);
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  /// Returns all spouses / co-parents of [memberId] (supports remarriage —
  /// may be more than one). Uses the loaded ego network + spouse links first
  /// (fast, no round trip, includes co-parent inference — see
  /// [spousesInNetwork]), then falls back to server/local cache.
  Future<List<FamilyMember>> getSpousesOf(String memberId) async {
    final fromNetwork = spousesInNetwork(memberId);
    if (fromNetwork.isNotEmpty) return fromNetwork;

    // Fallback: query server, or local cache if offline — or if the device
    // reports "online" but the request itself fails (a timeout on this
    // app's target rural network conditions, not a clean "no connection").
    // Every other read in this file falls back to cache on a thrown
    // exception; this one previously didn't, so a flaky connection threw
    // all the way up to the UI instead of degrading gracefully.
    try {
      if (await SyncService.isOnline()) {
        return await SupabaseService.getSpousesOf(memberId);
      }
    } catch (e) {
      debugPrint('Error in getSpousesOf: $e');
    }
    return LocalStorageService.getSpouseIdsOf(memberId)
        .map((id) => LocalStorageService.getFamilyMember(id))
        .whereType<FamilyMember>()
        .toList();
  }

  Future<FamilyMember?> createFamilyMember(FamilyMember member) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      FamilyMember newMember;
      
      if (await SyncService.isOnline()) {
        newMember = await SupabaseService.createFamilyMember(member);
      } else {
        newMember = member.copyWith(isPendingSync: true);
        await LocalStorageService.addPendingSync(
          member.id,
          'create',
          member.toJson(),
        );
      }

      await LocalStorageService.saveFamilyMember(newMember);
      
      // Refresh ego network if we have a center
      if (_centerMember != null) {
        await loadEgoNetwork(_centerMember!.id);
      }

      _isLoading = false;
      notifyListeners();
      return newMember;
    } catch (e) {
      debugPrint('Error in createFamilyMember: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update an existing family member (not the logged-in user's own profile).
  Future<bool> updateFamilyMember(FamilyMember member) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        await SupabaseService.updateFamilyMember(member);
      } else {
        await LocalStorageService.addPendingSync(
          member.id,
          'update',
          member.toJson(),
        );
      }
      await LocalStorageService.saveFamilyMember(member);

      // Refresh ego network so the UI picks up the change
      if (_centerMember != null) {
        await loadEgoNetwork(_centerMember!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in updateFamilyMember: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> linkFamilyMember({
    required String memberId,
    required String relatedMemberId,
    required RelationType relationType,
    bool autoLinkSpouse = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        await SupabaseService.linkFamilyMembers(
          memberId: memberId,
          relatedMemberId: relatedMemberId,
          relationType: relationType,
          autoLinkSpouse: autoLinkSpouse,
        );
      } else {
        // Queue for retry on the next sync — without this, a relation link
        // (father/mother/spouse/child/sibling) made offline only updates the
        // local cache and is silently lost the next time loadEgoNetwork
        // re-fetches from Supabase and overwrites it with server data that
        // never received the link.
        await LocalStorageService.addPendingSync(
          memberId,
          'link',
          {
            'related_member_id': relatedMemberId,
            'relation_type': relationType.name,
            'auto_link_spouse': autoLinkSpouse,
          },
          dedupeKey: '${memberId}_link_${relationType.name}_$relatedMemberId',
        );
      }

      // Update local storage
      final member = LocalStorageService.getFamilyMember(memberId);
      if (member != null) {
        FamilyMember updatedMember;
        switch (relationType) {
          case RelationType.father:
            updatedMember = member.copyWith(fatherId: relatedMemberId);
            break;
          case RelationType.mother:
            updatedMember = member.copyWith(motherId: relatedMemberId);
            break;
          case RelationType.spouse:
            // Spouse isn't a field on FamilyMember (supports remarriage —
            // stored as edges, see SpouseLink); the member row itself is
            // unchanged, only the local adjacency cache gains an edge.
            await LocalStorageService.saveSpouseLinks([
              SpouseLink(memberId: memberId, spouseId: relatedMemberId),
            ]);
            updatedMember = member;
            break;
          case RelationType.child:
            final relatedMember = LocalStorageService.getFamilyMember(relatedMemberId);
            if (relatedMember != null) {
              if (member.gender == 'Male') {
                await LocalStorageService.saveFamilyMember(
                  relatedMember.copyWith(fatherId: memberId)
                );
              } else {
                await LocalStorageService.saveFamilyMember(
                  relatedMember.copyWith(motherId: memberId)
                );
              }
            }
            updatedMember = member;
            break;
          case RelationType.sibling:
            final relatedMember = LocalStorageService.getFamilyMember(relatedMemberId);
            if (relatedMember != null) {
              await LocalStorageService.saveFamilyMember(
                relatedMember.copyWith(
                  fatherId: member.fatherId,
                  motherId: member.motherId,
                )
              );
            }
            updatedMember = member;
            break;
        }
        await LocalStorageService.saveFamilyMember(updatedMember);
      }

      // Refresh ego network
      if (_centerMember != null) {
        await loadEgoNetwork(_centerMember!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in linkFamilyMember: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFamilyMember(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        await SupabaseService.deleteFamilyMember(id);
      } else {
        await LocalStorageService.addPendingSync(id, 'delete', {});
      }

      await LocalStorageService.deleteFamilyMember(id);

      // Refresh ego network
      if (_centerMember != null && _centerMember!.id != id) {
        await loadEgoNetwork(_centerMember!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in deleteFamilyMember: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Removes a mistaken spousal link between [memberId] and [spouseId]
  /// (either direction — the underlying delete is order-independent). Does
  /// NOT delete either member's profile, only the spouse_relationships edge.
  Future<bool> removeSpouse(String memberId, String spouseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.isOnline()) {
        await SupabaseService.removeSpouseLink(memberId, spouseId);
      }

      await LocalStorageService.removeSpouseLinkLocal(memberId, spouseId);

      // Refresh ego network
      if (_centerMember != null) {
        await loadEgoNetwork(_centerMember!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in removeSpouse: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<FamilyMember?> getMemberById(String id) async {
    // First check ego network
    final inNetwork = _egoNetwork.where((m) => m.id == id).firstOrNull;
    if (inNetwork != null) return inNetwork;

    // Check local
    final local = LocalStorageService.getFamilyMember(id);
    if (local != null) return local;

    // Fetch from server — a thrown exception here (device reports "online"
    // but the request itself fails) previously propagated uncaught; this is
    // called from the ancestry-cycle guard in add_family_member_screen.dart,
    // where an uncaught exception would surface as a raw crash instead of
    // the guard just treating an unresolvable ancestor as "not a cycle" (the
    // same behavior as a genuinely-missing id, which the guard already
    // handles by design).
    try {
      if (await SyncService.isOnline()) {
        return await SupabaseService.getFamilyMemberById(id);
      }
    } catch (e) {
      debugPrint('Error in getMemberById: $e');
    }

    return null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
