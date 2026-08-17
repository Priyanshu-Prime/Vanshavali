// Flow: relation linking + ego-centric fetch (CLAUDE.md Phase 4 & 5), against a
// REAL local Supabase backend. The pure relation-guard functions are already
// covered by 30 unit tests (test/screens/family/relation_guards_test.dart);
// what those can't cover is the real persistence + RPC wiring:
//   * that createFamilyMember actually links a child and that
//     get_ego_network / getChildren then return it, and
//   * that wouldCreateAncestryCycle works through the REAL getFamilyMemberById
//     resolver walking real rows (the unit tests inject a fake in-memory map).
//
// Seeded tree (supabase/seed.sql):
//   b1 Grandfather <- b2 Father <- b3 Child (invite code TEST04)
//   a1 Ramesh (unrelated placeholder)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/add_family_member_screen.dart'
    show wouldCreateAncestryCycle;
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _grandfather = '00000000-0000-0000-0000-0000000000b1';
const _father = '00000000-0000-0000-0000-0000000000b2';
const _self = '00000000-0000-0000-0000-0000000000b3'; // Child, claimed via TEST04
const _ramesh = '00000000-0000-0000-0000-0000000000a1'; // unrelated
const _newChild = '00000000-0000-0000-0000-0000000000c1'; // created by the test

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Sign up a fresh auth user and claim the seeded Child (b3), so we act with a
  // real session and a real place in the tree. Field order mirrors the proven
  // signup_claim_test (enter "confirm password" before "password", since the
  // "password" substring also matches the confirm field).
  Future<void> claimSelf(WidgetTester tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await tapText(tester, 'Sign Up');
    await tester.pumpAndSettle();
    await enterInField(tester, 'email', uniqueEmail());
    await enterInField(tester, 'confirm password', 'test1234');
    await enterInField(tester, 'password', 'test1234');
    await enterInField(tester, '6-character code', 'TEST04');
    await tapText(tester, 'Sign Up');
    await tester.pumpAndSettle(const Duration(seconds: 10));
  }

  // One test, one claim: TEST04 is single-use, so a second claimSelf in a
  // separate test would fail and leave the client unauthenticated. Both the
  // ego/linking checks and the cycle-guard checks share this one session.
  testWidgets('ego + child linking, and cycle guard via the real DB resolver',
      (tester) async {
    await claimSelf(tester);

    // --- Ego network + add-child (Phase 4/5 persistence & RPC wiring) ---

    // Ego network of self (Child) must contain self and the seeded father.
    final ego0 =
        (await SupabaseService.getEgoCentricNetwork(_self)).map((m) => m.id).toSet();
    expect(ego0, contains(_self), reason: 'ego network must contain self');
    expect(ego0, contains(_father),
        reason: 'ego network must contain the direct father (seed b2)');

    // Add a child of self (self is Male -> occupies the child's father slot).
    await SupabaseService.createFamilyMember(FamilyMember(
      id: _newChild,
      createdAt: DateTime.now().toUtc(),
      firstNameEn: 'NewKid',
      lastNameEn: 'Patel',
      gender: 'Male',
      fatherId: _self,
    ));

    // The new child is now returned by getChildren and by the ego network.
    final kids =
        (await SupabaseService.getChildren(_self)).map((m) => m.id).toSet();
    expect(kids, contains(_newChild),
        reason: 'newly added child must be returned by getChildren');

    final ego1 =
        (await SupabaseService.getEgoCentricNetwork(_self)).map((m) => m.id).toSet();
    expect(ego1, contains(_newChild),
        reason: 'newly added child must appear in the ego network');

    // --- Ancestry-cycle guard against the real getFamilyMemberById resolver ---

    // Setting the grandfather's parent to self (b3) — a descendant of b1 —
    // would make b1 its own ancestor: a cycle, must be blocked.
    expect(
      await wouldCreateAncestryCycle(
        targetId: _grandfather,
        candidateId: _self,
        resolve: SupabaseService.getFamilyMemberById,
      ),
      isTrue,
      reason: 'self (b3) is a descendant of the grandfather (b1) -> cycle',
    );

    // Linking an unrelated existing member as a parent is fine.
    expect(
      await wouldCreateAncestryCycle(
        targetId: _self,
        candidateId: _ramesh,
        resolve: SupabaseService.getFamilyMemberById,
      ),
      isFalse,
      reason: 'Ramesh (a1) is unrelated to self -> no cycle',
    );

    // A member can never be its own parent.
    expect(
      await wouldCreateAncestryCycle(
        targetId: _self,
        candidateId: _self,
        resolve: SupabaseService.getFamilyMemberById,
      ),
      isTrue,
    );
  });
}
