import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import '../models/family_member.dart';
import '../models/user_preferences.dart';
import 'supabase_service.dart';

class LocalStorageService {
  static late Box<FamilyMember> _familyMembersBox;
  static late Box<dynamic> _userPrefsBox;
  static late Box<Map> _pendingSyncBox;
  // Denormalized spouse adjacency: memberId -> list of spouse ids (edges are
  // stored in both directions so lookups are O(1) either way). Spouse links
  // aren't a FamilyMember field (see spouse_relationships in Supabase), so
  // they need their own local cache to support offline tree rendering.
  static late Box<List> _spouseLinksBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(FamilyMemberAdapter());

    // Open boxes
    _familyMembersBox = await Hive.openBox<FamilyMember>(AppConfig.familyMembersBox);
    _userPrefsBox = await Hive.openBox(AppConfig.userPrefsBox);
    _pendingSyncBox = await Hive.openBox<Map>(AppConfig.pendingSyncBox);
    _spouseLinksBox = await Hive.openBox<List>(AppConfig.spouseLinksBox);
  }

  // ==================== FAMILY MEMBERS ====================

  static Future<void> saveFamilyMember(FamilyMember member) async {
    await _familyMembersBox.put(member.id, member);
  }

  static Future<void> saveFamilyMembers(List<FamilyMember> members) async {
    final Map<String, FamilyMember> membersMap = {
      for (var m in members) m.id: m
    };
    await _familyMembersBox.putAll(membersMap);
  }

  static FamilyMember? getFamilyMember(String id) {
    return _familyMembersBox.get(id);
  }

  static List<FamilyMember> getAllFamilyMembers() {
    return _familyMembersBox.values.toList();
  }

  static List<FamilyMember> searchFamilyMembers(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _familyMembersBox.values.where((member) {
      return member.firstNameEn.toLowerCase().contains(lowercaseQuery) ||
          member.lastNameEn.toLowerCase().contains(lowercaseQuery) ||
          (member.firstNameGu?.contains(query) ?? false) ||
          (member.lastNameGu?.contains(query) ?? false);
    }).toList();
  }

  static List<FamilyMember> getEgoCentricNetwork(String memberId) {
    final member = getFamilyMember(memberId);
    if (member == null) return [];

    final Set<String> relatedIds = {memberId};
    if (member.fatherId != null) relatedIds.add(member.fatherId!);
    if (member.motherId != null) relatedIds.add(member.motherId!);
    relatedIds.addAll(getSpouseIdsOf(memberId));

    // Add children + siblings
    for (var m in _familyMembersBox.values) {
      // Children of center
      if (m.fatherId == memberId || m.motherId == memberId) {
        relatedIds.add(m.id);
      }
      // Siblings: share a parent with center
      if (m.id != memberId) {
        if (member.fatherId != null && m.fatherId == member.fatherId) {
          relatedIds.add(m.id);
        }
        if (member.motherId != null && m.motherId == member.motherId) {
          relatedIds.add(m.id);
        }
      }
    }

    return _familyMembersBox.values
        .where((m) => relatedIds.contains(m.id))
        .toList();
  }

  static List<FamilyMember> getChildren(String memberId) {
    return _familyMembersBox.values
        .where((m) => m.fatherId == memberId || m.motherId == memberId)
        .toList();
  }

  static List<FamilyMember> getSiblings(String memberId) {
    final member = getFamilyMember(memberId);
    if (member == null) return [];

    return _familyMembersBox.values.where((m) {
      if (m.id == memberId) return false;
      if (member.fatherId != null && m.fatherId == member.fatherId) return true;
      if (member.motherId != null && m.motherId == member.motherId) return true;
      return false;
    }).toList();
  }

  static Future<void> deleteFamilyMember(String id) async {
    await _familyMembersBox.delete(id);
  }

  static Future<void> clearFamilyMembers() async {
    await _familyMembersBox.clear();
  }

  // ==================== SPOUSE LINKS ====================

  /// Merge spouse links into the local adjacency cache (additive — does not
  /// remove existing links, so partial/incremental syncs don't lose data).
  static Future<void> saveSpouseLinks(List<SpouseLink> links) async {
    for (final link in links) {
      await _addAdjacency(link.memberId, link.spouseId);
      await _addAdjacency(link.spouseId, link.memberId);
    }
  }

  static Future<void> _addAdjacency(String id, String otherId) async {
    final existing = (_spouseLinksBox.get(id)?.cast<String>() ?? <String>[]).toSet();
    if (existing.add(otherId)) {
      await _spouseLinksBox.put(id, existing.toList());
    }
  }

  static Future<void> removeSpouseLinkLocal(String memberId, String spouseId) async {
    final aLinks = (_spouseLinksBox.get(memberId)?.cast<String>() ?? <String>[]).toSet();
    aLinks.remove(spouseId);
    await _spouseLinksBox.put(memberId, aLinks.toList());

    final bLinks = (_spouseLinksBox.get(spouseId)?.cast<String>() ?? <String>[]).toSet();
    bLinks.remove(memberId);
    await _spouseLinksBox.put(spouseId, bLinks.toList());
  }

  static List<String> getSpouseIdsOf(String memberId) {
    return _spouseLinksBox.get(memberId)?.cast<String>() ?? <String>[];
  }

  static Future<void> clearSpouseLinks() async {
    await _spouseLinksBox.clear();
  }

  // ==================== PENDING SYNC ====================

  static Future<void> addPendingSync(
    String memberId,
    String action,
    Map<String, dynamic> data, {
    String? dedupeKey,
  }) async {
    await _pendingSyncBox.put(dedupeKey ?? '${memberId}_$action', {
      'member_id': memberId,
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<dynamic, dynamic>> getPendingSyncs() {
    return _pendingSyncBox.values.toList();
  }

  /// Same data as [getPendingSyncs] but keyed by the actual Hive box key, so
  /// a caller can remove exactly the entry it processed — needed for actions
  /// stored under a `dedupeKey` (e.g. 'link'), where the key can't be
  /// reconstructed from `'${memberId}_$action'` alone.
  static Map<dynamic, Map<dynamic, dynamic>> getPendingSyncEntries() {
    return Map<dynamic, Map<dynamic, dynamic>>.from(_pendingSyncBox.toMap());
  }

  static Future<void> removePendingSync(String key) async {
    await _pendingSyncBox.delete(key);
  }

  static Future<void> clearPendingSyncs() async {
    await _pendingSyncBox.clear();
  }

  static bool hasPendingSyncs() {
    return _pendingSyncBox.isNotEmpty;
  }

  // ==================== USER PREFERENCES ====================

  static Future<void> saveUserPreferences(UserPreferences prefs) async {
    await _userPrefsBox.putAll(prefs.toJson());
  }

  static UserPreferences getUserPreferences() {
    return UserPreferences(
      locale: _userPrefsBox.get('locale'),
      isDarkMode: _userPrefsBox.get('is_dark_mode', defaultValue: false),
      lastSyncTime: _userPrefsBox.get('last_sync_time'),
      hasCompletedOnboarding: _userPrefsBox.get('has_completed_onboarding', defaultValue: false),
      currentUserId: _userPrefsBox.get('current_user_id'),
      currentMemberId: _userPrefsBox.get('current_member_id'),
    );
  }

  static Future<void> setLocale(String locale) async {
    await _userPrefsBox.put('locale', locale);
  }

  static String? getLocale() {
    return _userPrefsBox.get('locale');
  }

  static Future<void> setDarkMode(bool isDarkMode) async {
    await _userPrefsBox.put('is_dark_mode', isDarkMode);
  }

  static bool getDarkMode() {
    return _userPrefsBox.get('is_dark_mode', defaultValue: false);
  }

  static Future<void> setLastSyncTime(DateTime time) async {
    await _userPrefsBox.put('last_sync_time', time.toIso8601String());
  }

  static DateTime? getLastSyncTime() {
    final timeStr = _userPrefsBox.get('last_sync_time');
    if (timeStr == null) return null;
    return DateTime.parse(timeStr);
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _userPrefsBox.put('has_completed_onboarding', completed);
  }

  static bool hasCompletedOnboarding() {
    return _userPrefsBox.get('has_completed_onboarding', defaultValue: false);
  }

  static Future<void> setCurrentMemberId(String? memberId) async {
    await _userPrefsBox.put('current_member_id', memberId);
  }

  static String? getCurrentMemberId() {
    return _userPrefsBox.get('current_member_id');
  }

  static Future<void> clearAll() async {
    await _familyMembersBox.clear();
    await _userPrefsBox.clear();
    await _pendingSyncBox.clear();
    await _spouseLinksBox.clear();
  }
}

class SyncService {
  static Future<bool> isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.isNotEmpty && !connectivity.contains(ConnectivityResult.none);
  }

  static Stream<List<ConnectivityResult>> get connectivityStream => 
      Connectivity().onConnectivityChanged;

  /// Sync local data with Supabase
  static Future<void> syncData() async {
    if (!await isOnline()) return;

    // First, push pending changes
    await _pushPendingChanges();

    // Then, pull latest data
    await _pullLatestData();

    // Update last sync time
    await LocalStorageService.setLastSyncTime(DateTime.now());
  }

  static Future<void> _pushPendingChanges() async {
    final pendingSyncs = LocalStorageService.getPendingSyncEntries();

    for (final entry in pendingSyncs.entries) {
      final key = entry.key;
      final sync = entry.value;
      try {
        final action = sync['action'] as String;
        final data = sync['data'] as Map;
        final memberId = sync['member_id'] as String;

        switch (action) {
          case 'create':
            final member = FamilyMember.fromJson(Map<String, dynamic>.from(data));
            await SupabaseService.createFamilyMember(member);
            break;
          case 'update':
            final member = FamilyMember.fromJson(Map<String, dynamic>.from(data));
            await SupabaseService.updateFamilyMember(member);
            break;
          case 'delete':
            await SupabaseService.deleteFamilyMember(memberId);
            break;
          case 'link':
            final relatedMemberId = data['related_member_id'] as String;
            final relationType =
                RelationType.values.byName(data['relation_type'] as String);
            await SupabaseService.linkFamilyMembers(
              memberId: memberId,
              relatedMemberId: relatedMemberId,
              relationType: relationType,
              // Older queued items predate this flag; default to linking.
              autoLinkSpouse: data['auto_link_spouse'] as bool? ?? true,
            );
            break;
        }

        await LocalStorageService.removePendingSync(key.toString());
      } catch (e) {
        // Keep pending sync for retry
        debugPrint('SyncService Sync error: $e');
        dev.log('Sync error: $e', name: 'SyncService');
      }
    }
  }

  /// Pulls changes since the last sync, plus a fresh copy of all spousal
  /// links (that table is one row per marriage across the whole tree, not
  /// per person, so re-pulling it in full on every explicit sync is cheap —
  /// unlike family_members, it has no per-row modified timestamp to filter on).
  static Future<void> _pullLatestData() async {
    try {
      final lastSync = LocalStorageService.getLastSyncTime();
      final members = await SupabaseService.getAllFamilyMembers(
        modifiedAfter: lastSync,
      );
      await LocalStorageService.saveFamilyMembers(members);

      final links = await SupabaseService.getAllSpouseLinks();
      await LocalStorageService.saveSpouseLinks(links);
    } catch (e) {
      debugPrint('SyncService Pull error: $e');
      dev.log('Pull error: $e', name: 'SyncService');
    }
  }

  /// Full sync - explicit, user-initiated bulk download of the whole tree
  /// for offline browsing (e.g. sync once on wifi, then browse anywhere in
  /// the village without a connection). This is intentionally NOT the path
  /// used for routine tree navigation — that goes through
  /// FamilyProvider/getEgoCentricNetwork and stays scoped to the neighborhood
  /// actually being viewed. This button is a deliberate, occasional bulk
  /// operation the user asks for, not an implicit per-view fetch.
  static Future<void> fullSync() async {
    if (!await isOnline()) return;

    // Fetch everything before touching the local cache. Clearing first (the
    // previous order) meant a failed fetch — a plausible mid-sync connection
    // drop on this app's target network conditions — left the user with an
    // empty offline cache and no error surfaced, silently destroying the
    // "browse anywhere in the village without a connection" data this whole
    // feature exists to provide. Callers are expected to catch and surface
    // failures; see SettingsProvider.fullSync.
    final members = await SupabaseService.getAllFamilyMembers();
    final links = await SupabaseService.getAllSpouseLinks();

    await LocalStorageService.clearFamilyMembers();
    await LocalStorageService.clearSpouseLinks();
    await LocalStorageService.saveFamilyMembers(members);
    await LocalStorageService.saveSpouseLinks(links);
    await LocalStorageService.setLastSyncTime(DateTime.now());
  }
}
