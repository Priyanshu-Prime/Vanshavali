import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/family_member.dart';

class SupabaseService {
  /// Test-only seam: every method in this class goes through [client]
  /// rather than `Supabase.instance.client` directly, so a test can swap in
  /// a mocktail `MockSupabaseClient` here instead of needing a live
  /// Supabase.initialize() call. SupabaseService is intentionally kept
  /// fully static (touched from dozens of call sites across the app) rather
  /// than converted to an injectable instance — this single field is the
  /// minimal seam needed to make it mockable without that larger refactor.
  /// Always null in production. Reset to null after each test.
  @visibleForTesting
  static SupabaseClient? debugClientOverride;

  static SupabaseClient get client =>
      debugClientOverride ?? Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  
  static bool get isAuthenticated => currentUser != null;

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // ==================== AUTH ====================

  /// Sign in with magic link (email)
  static Future<void> signInWithMagicLink(String email) async {
    await client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: SupabaseConfig.redirectUrl,
    );
  }

  /// Sign up with email and password.
  ///
  /// Supabase's `signUp()` does not cleanly error when the email already has
  /// an account (e.g. from a prior magic-link login) — this is deliberate
  /// anti-enumeration behavior on Supabase's end: it silently attaches the
  /// new password to the EXISTING auth user and returns a normal-looking
  /// success. Left unchecked, this app previously treated that as a fresh
  /// signup and routed to profile creation, producing a second
  /// `family_members` row for the same `auth_user_id` — a real incident,
  /// see docs/claude_handoff. An empty `identities` list on the returned
  /// user is Supabase's documented signal that no new identity was created,
  /// i.e. the email was already registered; treat that as a hard failure.
  static Future<AuthResponse> signUpWithEmail(String email, String password) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseConfig.redirectUrl,
    );
    if (response.user != null && (response.user!.identities?.isEmpty ?? true)) {
      throw const AuthException('vanshavali_email_already_registered');
    }
    return response;
  }

  /// Set or change the password for the currently signed-in user. Used to
  /// let a magic-link-only account (no password ever set) gain password
  /// login, via the Settings screen — never via the public signup screen,
  /// which must only ever create brand-new accounts (see [signUpWithEmail]).
  static Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Sign in with email and password
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Reset password
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseConfig.redirectUrl,
    );
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ==================== FAMILY MEMBERS ====================

  /// Get current user's family member profile
  static Future<FamilyMember?> getCurrentUserProfile() async {
    if (currentUser == null) return null;
    
    final response = await client
        .from('family_members')
        .select()
        .eq('auth_user_id', currentUser!.id)
        .maybeSingle();
    
    if (response == null) return null;
    return FamilyMember.fromJson(response);
  }

  /// Create a new family member
  static Future<FamilyMember> createFamilyMember(FamilyMember member) async {
    final response = await client
        .from('family_members')
        .insert(member.toJson())
        .select()
        .single();
    
    return FamilyMember.fromJson(response);
  }

  /// Update a family member
  static Future<FamilyMember> updateFamilyMember(FamilyMember member) async {
    final response = await client
        .from('family_members')
        .update(member.toJson())
        .eq('id', member.id)
        .select()
        .single();
    
    return FamilyMember.fromJson(response);
  }

  /// Get family member by ID
  static Future<FamilyMember?> getFamilyMemberById(String id) async {
    final response = await client
        .from('family_members')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    return FamilyMember.fromJson(response);
  }

  /// Get ego-centric network (member + parents + all spouses + children +
  /// siblings). Delegates entirely to the `get_ego_network` RPC so the graph
  /// logic (including multi-spouse traversal) lives in one place, server-side,
  /// instead of being duplicated/drifting between SQL and Dart.
  static Future<List<FamilyMember>> getEgoCentricNetwork(String memberId) async {
    final response = await client.rpc(
      'get_ego_network',
      params: {'center_member_id': memberId},
    );

    return (response as List)
        .map((json) => FamilyMember.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Multi-generation ancestor set for the Pedigree view, via the
  /// `get_ancestor_chain` RPC (see migration 005). get_ego_network above
  /// only ever returns one generation of parents by design — nowhere near
  /// enough to resolve a "father's father's father" pedigree chain — so the
  /// pedigree screen needs this separate, deeper fetch instead. Returns both
  /// the paternal and maternal branches so switching the Paternal/Maternal
  /// toggle client-side doesn't need a re-fetch.
  static Future<List<FamilyMember>> getAncestorChain(
    String memberId, {
    int maxGenerations = 6,
  }) async {
    final response = await client.rpc(
      'get_ancestor_chain',
      params: {
        'center_member_id': memberId,
        'max_generations': maxGenerations,
      },
    );

    return (response as List)
        .map((json) => FamilyMember.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get children of a member
  static Future<List<FamilyMember>> getChildren(String memberId) async {
    final response = await client
        .from('family_members')
        .select()
        .or('father_id.eq.$memberId,mother_id.eq.$memberId');

    return (response as List)
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  /// Get siblings of a member
  static Future<List<FamilyMember>> getSiblings(String memberId) async {
    final member = await getFamilyMemberById(memberId);
    if (member == null) return [];

    if (member.fatherId == null && member.motherId == null) return [];

    String filter = '';
    if (member.fatherId != null) {
      filter = 'father_id.eq.${member.fatherId}';
    }
    if (member.motherId != null) {
      if (filter.isNotEmpty) filter += ',';
      filter += 'mother_id.eq.${member.motherId}';
    }

    final response = await client
        .from('family_members')
        .select()
        .or(filter)
        .neq('id', memberId);

    return (response as List)
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  /// Search family members
  static Future<List<FamilyMember>> searchFamilyMembers(String query) async {
    final response = await client
        .from('family_members')
        .select()
        .or('first_name_en.ilike.%$query%,last_name_en.ilike.%$query%,first_name_gu.ilike.%$query%,last_name_gu.ilike.%$query%')
        .limit(AppConfig.pageSize);

    return (response as List)
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  /// Get all spouses (current or former) of a given member, plus any
  /// co-parent implied by a shared child even if never explicitly linked.
  static Future<List<FamilyMember>> getSpousesOf(String memberId) async {
    final spouseIds = <String>{};

    // 1. Explicit spousal links (supports multiple, e.g. remarriage)
    for (final link in await getSpouseLinksFor([memberId])) {
      spouseIds.add(link.otherId(memberId));
    }

    // 2. Co-parents: find children of this member, collect the other parent
    // (covers data entered before a spousal link was made explicit)
    final childrenResponse = await client
        .from('family_members')
        .select('father_id, mother_id')
        .or('father_id.eq.$memberId,mother_id.eq.$memberId');

    for (var row in (childrenResponse as List)) {
      final fid = row['father_id'] as String?;
      final mid = row['mother_id'] as String?;
      if (fid != null && fid != memberId) spouseIds.add(fid);
      if (mid != null && mid != memberId) spouseIds.add(mid);
    }

    if (spouseIds.isEmpty) return [];

    final spouseResponse = await client
        .from('family_members')
        .select()
        .inFilter('id', spouseIds.toList());

    return (spouseResponse as List)
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  /// Get spousal-link edges touching any of the given member ids. Used to
  /// figure out which members in an already-fetched set are each other's
  /// spouses (the flat member list alone doesn't say — unlike father/mother,
  /// spouse is no longer a field on FamilyMember).
  static Future<List<SpouseLink>> getSpouseLinksFor(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];

    final idList = memberIds.join(',');
    final response = await client
        .from('spouse_relationships')
        .select('member_id, spouse_id')
        .or('member_id.in.($idList),spouse_id.in.($idList)');

    return (response as List)
        .map((json) => SpouseLink.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Link two members as spouses. Safe to call even if they're already
  /// linked — the unique pair constraint makes this idempotent.
  static Future<void> addSpouseLink(String memberId, String spouseId) async {
    try {
      await client.from('spouse_relationships').insert({
        'member_id': memberId,
        'spouse_id': spouseId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation — the pair is already linked, not an error.
      if (e.code != '23505') rethrow;
    }
  }

  /// Remove a spousal link between two members, regardless of which side
  /// was originally stored as member_id vs spouse_id.
  static Future<void> removeSpouseLink(String memberId, String spouseId) async {
    await client
        .from('spouse_relationships')
        .delete()
        .or('and(member_id.eq.$memberId,spouse_id.eq.$spouseId),'
            'and(member_id.eq.$spouseId,spouse_id.eq.$memberId)');
  }

  /// Get every spousal link. Only for the explicit "Full Sync" / offline-prep
  /// path (see SyncService) — the table is small (one row per marriage across
  /// the whole tree, not per person), so this is a deliberate bulk read, not
  /// the routine per-view fetch that ego-network loading must avoid.
  static Future<List<SpouseLink>> getAllSpouseLinks() async {
    final response = await client.from('spouse_relationships').select('member_id, spouse_id');
    return (response as List)
        .map((json) => SpouseLink.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Claim a profile (link auth user to existing family member).
  ///
  /// Goes through the `claim_profile` RPC (migration 001) rather than a
  /// direct table UPDATE — the direct-write version used to skip the "user
  /// already has a profile" guard the RPC enforces, letting a user who
  /// already has one claim a second, producing exactly the kind of
  /// duplicate-profile row a past incident already hit once. The RPC raises
  /// a PostgrestException (not a null return) on either failure case
  /// ("already has a profile" / "not found or already claimed") — callers
  /// already wrap this in try/catch (see AuthProvider.claimProfile).
  static Future<FamilyMember?> claimProfile(String memberId) async {
    if (currentUser == null) return null;

    final response = await client.rpc(
      'claim_profile',
      params: {'profile_id': memberId},
    );

    if (response == null) return null;
    return FamilyMember.fromJson(response as Map<String, dynamic>);
  }

  /// Link family members
  static Future<void> linkFamilyMembers({
    required String memberId,
    required String relatedMemberId,
    required RelationType relationType,
  }) async {
    switch (relationType) {
      case RelationType.father:
        await client
            .from('family_members')
            .update({'father_id': relatedMemberId})
            .eq('id', memberId);
        // Auto-link spouse between father and existing mother
        final memberAfterFather = await getFamilyMemberById(memberId);
        if (memberAfterFather?.motherId != null) {
          await _ensureSpouseLink(relatedMemberId, memberAfterFather!.motherId!);
        }
        break;
      case RelationType.mother:
        await client
            .from('family_members')
            .update({'mother_id': relatedMemberId})
            .eq('id', memberId);
        // Auto-link spouse between mother and existing father
        final memberAfterMother = await getFamilyMemberById(memberId);
        if (memberAfterMother?.fatherId != null) {
          await _ensureSpouseLink(memberAfterMother!.fatherId!, relatedMemberId);
        }
        break;
      case RelationType.spouse:
        await addSpouseLink(memberId, relatedMemberId);
        break;
      case RelationType.child:
        // Determine if current user is father or mother
        final currentMember = await getFamilyMemberById(memberId);
        if (currentMember?.gender == 'Male') {
          await client
              .from('family_members')
              .update({'father_id': memberId})
              .eq('id', relatedMemberId);
        } else {
          await client
              .from('family_members')
              .update({'mother_id': memberId})
              .eq('id', relatedMemberId);
        }
        break;
      case RelationType.sibling:
        // Share parents
        final currentMember = await getFamilyMemberById(memberId);
        if (currentMember != null) {
          final updates = <String, dynamic>{};
          if (currentMember.fatherId != null) {
            updates['father_id'] = currentMember.fatherId;
          }
          if (currentMember.motherId != null) {
            updates['mother_id'] = currentMember.motherId;
          }
          if (updates.isNotEmpty) {
            await client
                .from('family_members')
                .update(updates)
                .eq('id', relatedMemberId);
          }
        }
        break;
    }
  }

  /// Ensure two members are linked as spouses (no-op if already linked —
  /// addSpouseLink is idempotent via the unique pair constraint).
  static Future<void> _ensureSpouseLink(String idA, String idB) async {
    await addSpouseLink(idA, idB);
  }

  /// Delete a family member
  static Future<void> deleteFamilyMember(String id) async {
    await client.from('family_members').delete().eq('id', id);
  }

  /// Get all family members (for offline sync).
  ///
  /// [modifiedAfter] filters on `updated_at` (migration 006), not
  /// `created_at` — `created_at` never changes after a row is inserted, so
  /// filtering on it meant incremental sync silently missed every edit made
  /// on another device (renames, relationship changes, deceased toggles):
  /// it would only ever pick up brand-new rows. `updated_at` is bumped by a
  /// DB trigger on every UPDATE, so this now actually reflects "changed
  /// since I last synced."
  static Future<List<FamilyMember>> getAllFamilyMembers({
    DateTime? modifiedAfter,
  }) async {
    var query = client.from('family_members').select();

    if (modifiedAfter != null) {
      query = query.gte('updated_at', modifiedAfter.toIso8601String());
    }

    final response = await query;
    return (response as List)
        .map((json) => FamilyMember.fromJson(json))
        .toList();
  }

  // ==================== INVITE CODES ====================

  /// Generate a random 6-character alphanumeric invite code
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded I, O, 0, 1 to avoid confusion
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Generate and save an invite code for a member.
  /// If the member already has a code, returns the existing one.
  static Future<String> generateInviteCode(String memberId) async {
    // Check if member already has a code
    final existing = await getFamilyMemberById(memberId);
    if (existing?.inviteCode != null) return existing!.inviteCode!;

    // Generate a unique code (retry on collision)
    for (int attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      try {
        await client
            .from('family_members')
            .update({'invite_code': code})
            .eq('id', memberId)
            .isFilter('auth_user_id', null); // Only set on unclaimed profiles
        return code;
      } catch (e) {
        // Unique constraint violation — retry with a new code
        if (attempt == 4) rethrow;
      }
    }
    throw Exception('Failed to generate unique invite code');
  }

  /// Look up an unclaimed member by invite code, via the
  /// `get_member_by_invite_code` RPC (migration 002).
  ///
  /// Must go through a SECURITY DEFINER RPC, not a direct table read: this
  /// is called from the invite-preview screen BEFORE the viewer has signed
  /// in (they're deciding whether to sign up), and reads now require
  /// authentication (see migration 006) — a direct table query would return
  /// nothing for a logged-out viewer. The RPC bypasses RLS/grants like the
  /// claim RPCs do, and is explicitly granted to `anon` for this reason.
  static Future<FamilyMember?> getMemberByInviteCode(String code) async {
    final response = await client.rpc(
      'get_member_by_invite_code',
      params: {'code': code.toUpperCase()},
    );

    if (response == null) return null;
    return FamilyMember.fromJson(response as Map<String, dynamic>);
  }

  /// Claim a profile using an invite code, via the `claim_profile_by_code`
  /// RPC (migration 002) — see [claimProfile]'s doc comment for why this
  /// must not be a direct table write (skips the "already has a profile"
  /// guard, enabling the same duplicate-profile bug class).
  static Future<FamilyMember?> claimProfileByCode(String code) async {
    if (currentUser == null) return null;

    final response = await client.rpc(
      'claim_profile_by_code',
      params: {'code': code.toUpperCase()},
    );

    if (response == null) return null;
    return FamilyMember.fromJson(response as Map<String, dynamic>);
  }

  /// Flag a duplicate profile for manual merge review, via the
  /// `flag_duplicate_for_merge` RPC (migration 009).
  ///
  /// Called when [claimProfile]/[claimProfileByCode] fails specifically
  /// because the calling user already has a claimed profile of their own —
  /// i.e. a relative separately created an unclaimed placeholder for the
  /// same real person. This does NOT merge or reassign any data; it only
  /// records the conflict (existing profile id + duplicate placeholder id)
  /// in `merge_requests` for the project owner to resolve manually via SQL.
  /// [duplicatePlaceholderId] is the id of the unclaimed row the caller was
  /// trying to claim.
  static Future<void> flagDuplicateForMerge(
    String duplicatePlaceholderId,
  ) async {
    await client.rpc(
      'flag_duplicate_for_merge',
      params: {'duplicate_placeholder_id': duplicatePlaceholderId},
    );
  }
}
