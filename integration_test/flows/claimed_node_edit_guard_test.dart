// Flow: claimed-node edit guard (security property for migration 010).
//
// Property under test: the ORIGINAL creator of a placeholder node must NOT be
// able to edit that node once someone else has CLAIMED it — even though before
// the claim they could, and even though it is still their direct relative.
//
// A real user reported editing their father's node AFTER the father claimed it;
// we believe that was a pre-010 build. This drives the current code end-to-end
// against real Supabase + RLS to PROVE the hole is closed.
//
// Seeded tree (supabase/seed.sql):
//   b1 Grandfather -> b2 Father (invite code TEST05) -> b3 Child (TEST04)
//
// Steps:
//   1. User B signs up and claims TEST05 -> becomes the Father (b2).
//   2. Reset session; User A signs up and claims TEST04 -> becomes the Child
//      (b3). A is now the active session, and the Father (b2) is A's direct
//      parent but is now CLAIMED (by B).
//   3. Assert can_edit_family_member(b2) is FALSE for A.
//   4. Assert the actual UPDATE does not persist (RLS rejects it).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _self = '00000000-0000-0000-0000-0000000000b3'; // Child, claimed by user A
const _father = '00000000-0000-0000-0000-0000000000b2'; // claimed by user B

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a node claimed by someone else is not editable by its creator',
      (tester) async {
    // --- User B claims the FATHER (b2) via TEST05. ---
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester, code: 'TEST05');

    // --- User A claims the CHILD (b3) via TEST04; A becomes the active session. ---
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester, code: 'TEST04');

    // Positive control: prove A's session is actually live and the guard
    // discriminates (true in the allowed direction). Without this, a `false`
    // below could be a trivial false — e.g. no session (currentUser == null
    // short-circuits canEditMember to false) — rather than the real guard.
    expect(
      await SupabaseService.canEditMember(_self),
      isTrue,
      reason: 'session must be live: A must be able to edit their own node',
    );

    // The RPC (single source of truth for the UI gate + RLS UPDATE policy) must
    // deny editing the now-claimed father, even though A is the father's child.
    expect(
      await SupabaseService.canEditMember(_father),
      isFalse,
      reason:
          'a node claimed by someone else must not be editable, even by its '
          'original creator',
    );

    // Prove the actual write does not persist (defence-in-depth: even if the UI
    // gate were bypassed, the RLS UPDATE policy must reject the mutation).
    final before = await SupabaseService.getFamilyMemberById(_father);
    expect(before, isNotNull, reason: 'seeded father node must exist');
    try {
      await SupabaseService.updateFamilyMember(
        before!.copyWith(currentCity: 'HACKED'),
      );
    } catch (_) {
      // An error here is an acceptable outcome — RLS may throw rather than
      // silently affect zero rows. Either way the value must not have changed.
    }
    final after = await SupabaseService.getFamilyMemberById(_father);
    expect(
      after!.currentCity,
      isNot('HACKED'),
      reason: 'RLS must reject editing a claimed non-self node',
    );
  });
}
