import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_member.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  FamilyMember? _currentMember;
  String? _error;
  String? _pendingInviteMemberId;

  /// The auth-state-change subscription opened in [_init]. Held so it can be
  /// cancelled in [dispose] — without this, the stream keeps delivering events
  /// (e.g. a sign-out) to a disposed provider and calling notifyListeners on
  /// it, which throws "used after being disposed". Harmless in production
  /// where this provider lives for the whole app, but a real leak surfaced by
  /// the E2E rig repeatedly mounting/unmounting the app.
  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false;

  /// True after a [claimProfile]/[claimProfileByCode] attempt failed
  /// specifically because the caller already has their own claimed profile
  /// (a relative separately created an unclaimed placeholder for the same
  /// real person). The conflict has already been recorded in
  /// `merge_requests` (see [SupabaseService.flagDuplicateForMerge]) by the
  /// time this is true — this flag exists purely so the UI can show a
  /// distinct, reassuring "flagged for review" message instead of the
  /// generic [error] string. Cleared by [acknowledgeMergeConflict].
  bool _hasPendingMergeConflict = false;

  AuthStatus get status => _status;
  User? get user => _user;
  FamilyMember? get currentMember => _currentMember;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get hasProfile => _currentMember != null;
  String? get pendingInviteMemberId => _pendingInviteMemberId;
  bool get hasPendingMergeConflict => _hasPendingMergeConflict;

  /// True once a password has been established for this session (a fresh
  /// signUpWithEmail/signInWithEmail just proved one exists). Used only to
  /// tag a brand-new profile with `has_password: true` at creation time in
  /// ProfileFormScreen — for an existing profile, [hasPasswordSet] (backed
  /// by deep_details) is the source of truth instead.
  bool _authenticatedWithPassword = false;
  bool get authenticatedWithPassword => _authenticatedWithPassword;

  /// Whether the current member's account has ever had a password set.
  /// Magic-link-only accounts have none. Supabase's client SDK doesn't
  /// expose "does this identity have a password" directly, so this is
  /// tracked in `deep_details['has_password']` on the profile itself —
  /// see [setPassword] and the self-healing check in [signInWithEmail].
  /// Drives the mandatory set-password prompt in AppNavigator.
  bool get hasPasswordSet => _currentMember?.deepDetails['has_password'] == true;

  AuthProvider() {
    _init();
  }

  /// Test-only seam: skips `_init()`, which touches
  /// `SupabaseService.currentUser`/`authStateChanges` — both require a live
  /// `Supabase.initialize()` call that hasn't happened in a plain widget
  /// test. Optionally seeds [currentMember]/[status] directly. Not used by
  /// any production code path.
  @visibleForTesting
  AuthProvider.forTesting({FamilyMember? currentMember, AuthStatus? status}) {
    _currentMember = currentMember;
    _status = status ?? AuthStatus.unauthenticated;
  }

  Future<void> _init() async {
    _status = AuthStatus.loading;
    notifyListeners();

    // Check current session
    _user = SupabaseService.currentUser;
    
    if (_user != null) {
      await _loadCurrentMemberProfile();
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }

    // Listen to auth state changes. Store the subscription so dispose() can
    // cancel it, and bail if we've been disposed mid-event.
    _authSubscription = SupabaseService.authStateChanges.listen((event) async {
      if (_disposed) return;
      if (event.event == AuthChangeEvent.signedIn) {
        _user = event.session?.user;
        await _loadCurrentMemberProfile();
        _status = AuthStatus.authenticated;
      } else if (event.event == AuthChangeEvent.signedOut) {
        _user = null;
        _currentMember = null;
        _status = AuthStatus.unauthenticated;
      }
      if (_disposed) return;
      notifyListeners();
    });

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentMemberProfile() async {
    try {
      // Try online first
      if (await SyncService.isOnline()) {
        try {
          _currentMember = await SupabaseService.getCurrentUserProfile();
          if (_currentMember != null) {
            await LocalStorageService.saveFamilyMember(_currentMember!);
            await LocalStorageService.setCurrentMemberId(_currentMember!.id);
          }
          return;
        } catch (e) {
          // connectivity_plus reported "online" (radio/Wi-Fi up) but the
          // actual request failed — routine on this app's target rural
          // network conditions. Without this fallback, _currentMember stays
          // null, an existing user gets routed into "Complete Your Profile,"
          // and saving that form creates a duplicate family_members row
          // (the exact bug this session already fixed once for signup —
          // see docs/claude_handoff/04_current_risks.md). Fall through to
          // the same local-cache path used when genuinely offline instead.
          debugPrint('Online profile fetch failed, falling back to local cache: $e');
          _error = e.toString();
        }
      }

      // Offline, or the online fetch above failed.
      final memberId = LocalStorageService.getCurrentMemberId();
      if (memberId != null) {
        _currentMember = LocalStorageService.getFamilyMember(memberId);
      }
    } catch (e) {
      debugPrint('Error in _loadCurrentMemberProfile: $e');
      _error = e.toString();
    }
  }

  /// Refresh the current member from the database to pick up
  /// relationship changes (father_id, mother_id, spouse_id).
  Future<void> refreshCurrentMember() async {
    if (_currentMember == null) return;
    try {
      if (await SyncService.isOnline()) {
        final fresh = await SupabaseService.getFamilyMemberById(_currentMember!.id);
        if (fresh != null) {
          _currentMember = fresh;
          await LocalStorageService.saveFamilyMember(fresh);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing current member: $e');
      _error = e.toString();
    }
  }

  void setPendingInvite(String? memberId) {
    _pendingInviteMemberId = memberId;
    notifyListeners();
  }

  Future<bool> signInWithMagicLink(String email) async {
    try {
      // Do NOT set _status to loading — sending a magic link is just an email
      // dispatch. The user should remain on the login screen with a toast.
      _error = null;

      await SupabaseService.signInWithMagicLink(email);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in signInWithMagicLink: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final response = await SupabaseService.signUpWithEmail(email, password);
      _user = response.user;

      // `response.user` is populated as soon as the auth row is created,
      // even when the Supabase project requires email confirmation — but
      // `response.session` (and therefore SupabaseService.currentUser,
      // which every RLS-gated call keys off) stays null until the user
      // clicks that confirmation link. Treating a non-null `_user` alone as
      // "signed in" here is what produced the alpha-test incident: the app
      // called itself authenticated, then claimProfileByCode/getCurrentUserProfile
      // silently no-opped on the missing session and returned null instead
      // of throwing, which read to the tester as an "invalid/expired code"
      // followed by being dropped back into full profile entry.
      if (_user != null && response.session == null) {
        _status = AuthStatus.unauthenticated;
        _error = 'vanshavali_email_confirmation_required';
        notifyListeners();
        return false;
      }

      if (_user != null) {
        // Defense in depth on top of SupabaseService's identities check:
        // always load whatever profile actually exists for this user before
        // deciding this was a fresh signup. Unlike signInWithEmail, this
        // method previously skipped this call entirely, so a signup that
        // silently resolved to an existing account left _currentMember null
        // and the app routed to profile creation — producing a duplicate
        // family_members row. Never skip this again.
        await _loadCurrentMemberProfile();
        _status = AuthStatus.authenticated;
        // A password was just provided — ProfileFormScreen reads this to
        // tag a brand-new profile's deep_details accordingly.
        _authenticatedWithPassword = true;

        // If there's a pending invite, try to claim it (only relevant for a
        // genuinely new account with no profile yet).
        if (_pendingInviteMemberId != null && _currentMember == null) {
          await claimProfile(_pendingInviteMemberId!);
        }

        // Self-heal: see _tagHasPasswordIfNeeded's doc comment. Covers the
        // case where _currentMember was just loaded above (an existing
        // profile). The signup-form invite-code claim (claimProfileByCode,
        // called separately by SignupScreen after this method returns) tags
        // itself via the same helper.
        await _tagHasPasswordIfNeeded();
      } else {
        _status = AuthStatus.unauthenticated;
      }

      notifyListeners();
      return _user != null;
    } catch (e) {
      debugPrint('Error in signUpWithEmail: $e');
      _error = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final response = await SupabaseService.signInWithEmail(email, password);
      _user = response.user;
      
      if (_user != null) {
        await _loadCurrentMemberProfile();
        _status = AuthStatus.authenticated;
        _authenticatedWithPassword = true;

        // Self-heal: a successful password sign-in conclusively proves a
        // password exists, even if deep_details was never tagged (e.g. an
        // account created before has_password tracking existed). Do this
        // quietly rather than routing them through the set-password prompt
        // for a password they already have.
        await _tagHasPasswordIfNeeded();

        // If there's a pending invite, try to claim it
        if (_pendingInviteMemberId != null && _currentMember == null) {
          await claimProfile(_pendingInviteMemberId!);
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }

      notifyListeners();
      return _user != null;
    } catch (e) {
      debugPrint('Error in signInWithEmail: $e');
      _error = e.toString();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Sets a password on the current (already-authenticated) account —
  /// for a magic-link-only account that has never had one. Updates
  /// `deep_details['has_password']` on the profile so [hasPasswordSet]
  /// reflects it immediately, which clears the mandatory set-password
  /// prompt in AppNavigator.
  Future<bool> setPassword(String password) async {
    try {
      _error = null;
      await SupabaseService.updatePassword(password);
      _authenticatedWithPassword = true;

      if (_currentMember != null) {
        final success = await updateProfile(_currentMember!.copyWith(
          deepDetails: {..._currentMember!.deepDetails, 'has_password': true},
        ));
        return success;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in setPassword: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
      await LocalStorageService.clearAll();
      _user = null;
      _currentMember = null;
      _status = AuthStatus.unauthenticated;
      _authenticatedWithPassword = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in signOut: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Tags the current profile's `deep_details['has_password']` when the
  /// live session has just proven a password exists (signUpWithEmail /
  /// signInWithEmail set [_authenticatedWithPassword]) but the profile
  /// itself doesn't reflect that yet. Needed after EVERY path that can
  /// populate [_currentMember] with a password-authenticated session —
  /// including claimProfile/claimProfileByCode, which only set
  /// `auth_user_id` and otherwise inherit whatever (usually empty)
  /// `deep_details` the placeholder already had. Without this, a user who
  /// claims an invite during signup gets wrongly dropped onto the mandatory
  /// SetPasswordScreen right after already choosing a password — the exact
  /// incident reported live during alpha testing.
  Future<void> _tagHasPasswordIfNeeded() async {
    if (_currentMember != null && _authenticatedWithPassword && !hasPasswordSet) {
      await updateProfile(_currentMember!.copyWith(
        deepDetails: {..._currentMember!.deepDetails, 'has_password': true},
      ));
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _error = null;
      await SupabaseService.resetPassword(email);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in resetPassword: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createProfile(FamilyMember member) async {
    try {
      _error = null;
      
      final newMember = member.copyWith(authUserId: _user?.id);
      
      if (await SyncService.isOnline()) {
        _currentMember = await SupabaseService.createFamilyMember(newMember);
      } else {
        _currentMember = newMember;
        await LocalStorageService.addPendingSync(
          newMember.id,
          'create',
          newMember.toJson(),
        );
      }
      
      await LocalStorageService.saveFamilyMember(_currentMember!);
      await LocalStorageService.setCurrentMemberId(_currentMember!.id);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in createProfile: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(FamilyMember member) async {
    try {
      _error = null;
      
      if (await SyncService.isOnline()) {
        _currentMember = await SupabaseService.updateFamilyMember(member);
      } else {
        _currentMember = member.copyWith(isPendingSync: true);
        await LocalStorageService.addPendingSync(
          member.id,
          'update',
          member.toJson(),
        );
      }
      
      await LocalStorageService.saveFamilyMember(_currentMember!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in updateProfile: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> claimProfile(String memberId) async {
    try {
      _error = null;
      _hasPendingMergeConflict = false;

      if (await SyncService.isOnline()) {
        final claimed = await SupabaseService.claimProfile(memberId);
        _currentMember = claimed;
        if (claimed != null) {
          // See claimProfileByCode: work off the local `claimed` so the
          // concurrent signedIn profile-load can't null _currentMember between
          // these awaits and crash a claim that already succeeded server-side.
          await LocalStorageService.saveFamilyMember(claimed);
          await LocalStorageService.setCurrentMemberId(claimed.id);
          _pendingInviteMemberId = null;
          _currentMember = claimed;
          await _tagHasPasswordIfNeeded();
          notifyListeners();
          return true;
        }
      }

      return false;
    } on PostgrestException catch (e) {
      if (_isAlreadyHasProfileError(e)) {
        // The invitee already has their own claimed profile — this is not
        // a generic failure, it's a duplicate-person collision. Flag it for
        // manual review instead of just erroring.
        await _flagDuplicateForMerge(memberId);
        return false;
      }
      debugPrint('Error in claimProfile: $e');
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error in claimProfile: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> claimProfileByCode(String code) async {
    try {
      _error = null;
      _hasPendingMergeConflict = false;

      if (await SyncService.isOnline()) {
        final claimed = await SupabaseService.claimProfileByCode(code);
        _currentMember = claimed;
        if (claimed != null) {
          // Work off the local `claimed`, not the `_currentMember!` field:
          // the awaits below yield, and the signedIn authStateChanges listener
          // fires _loadCurrentMemberProfile() concurrently, which can null
          // _currentMember mid-flow — intermittently crashing the just-
          // succeeded claim with "Null check operator used on a null value"
          // (the server claim had already committed, so the user was silently
          // dropped into a claim-failed state).
          await LocalStorageService.saveFamilyMember(claimed);
          await LocalStorageService.setCurrentMemberId(claimed.id);
          _pendingInviteMemberId = null;
          // Re-assert our claimed member in case the concurrent profile load
          // above resolved to null (it races the freshly-committed claim).
          _currentMember = claimed;
          await _tagHasPasswordIfNeeded();
          notifyListeners();
          return true;
        }
      }

      return false;
    } on PostgrestException catch (e) {
      if (_isAlreadyHasProfileError(e)) {
        // Unlike claimProfile, we only have the invite CODE here, not the
        // duplicate placeholder's id — the RPC's "already has a profile"
        // guard fires before it ever looks up the code. Resolve the id via
        // the same read-only preview RPC the signup screen already uses.
        try {
          final duplicate = await SupabaseService.getMemberByInviteCode(code);
          if (duplicate != null) {
            await _flagDuplicateForMerge(duplicate.id);
            return false;
          }
        } catch (lookupError) {
          debugPrint(
            'Error resolving duplicate id for merge flag: $lookupError',
          );
        }
        // Couldn't resolve which placeholder it was — fall back to
        // surfacing the (still user-unfriendly, but non-silent) error.
        _error = e.message;
        notifyListeners();
        return false;
      }
      debugPrint('Error in claimProfileByCode: $e');
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      debugPrint('Error in claimProfileByCode: $e');
      debugPrintStack(stackTrace: stackTrace, label: 'claimProfileByCode');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Matches the exact `RAISE EXCEPTION` text used by both `claim_profile`
  /// and `claim_profile_by_code` (see supabase/migrations/001_initial_schema.sql
  /// and 002_invite_code.sql) when the calling user already has a claimed
  /// profile of their own.
  bool _isAlreadyHasProfileError(PostgrestException e) =>
      e.message.toLowerCase().contains('already has a profile');

  /// Records the duplicate-profile conflict via [SupabaseService.flagDuplicateForMerge]
  /// and sets [hasPendingMergeConflict] so the UI can show a distinct,
  /// reassuring message. Does NOT merge or reassign any data — see the RPC's
  /// doc comment in migration 009 for why that's deliberately out of scope.
  Future<void> _flagDuplicateForMerge(String duplicatePlaceholderId) async {
    try {
      await SupabaseService.flagDuplicateForMerge(duplicatePlaceholderId);
      _hasPendingMergeConflict = true;
      _error = null;
    } catch (flagError) {
      // Flagging itself failed (e.g. offline) — don't leave the user with
      // silence; fall back to the raw error so friendlyErrorMessage still
      // has something to work with.
      debugPrint('Error flagging duplicate for merge: $flagError');
      _error = flagError.toString();
    }
    notifyListeners();
  }

  /// Clears [hasPendingMergeConflict] once the UI has shown its message.
  void acknowledgeMergeConflict() {
    _hasPendingMergeConflict = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
