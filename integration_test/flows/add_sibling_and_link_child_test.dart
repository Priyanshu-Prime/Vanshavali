// Regression for the migration-010 add-relation hole (scenario 4.1, the gap
// that shipped a broken "add sibling / link existing child" to alpha).
//
// Migration 010's UPDATE policy authorizes a write by reading the target row's
// CURRENT relationships. That silently blocks the write that *creates* a
// relationship — RLS filters the row out, the UPDATE affects 0 rows with NO
// error, and the app reports success while nothing links. It slipped past the
// existing relations test (flows/relations_and_ego_test.dart) because that test
// creates a child with father_id BAKED INTO THE INSERT (a single insert, no
// separate link UPDATE) — so it never exercised the two-step
// createFamilyMember + linkFamilyMembers path the real UI uses.
//
// This test drives that exact two-step path through the REAL local backend
// (real RLS + the migration-011 set_member_parents RPC that fixes it):
//   * add a NEW sibling  -> sibling must inherit self's father
//   * link an EXISTING placeholder as a child -> its father_id must become self
// Both are pure link-UPDATEs with no kinship at write time — the precise shape
// 010 broke and 011 restores.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add sibling + link existing child persist through real RLS',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    // Fresh auth user with a real session, then a real profile of their own
    // (Male, no parents yet). No seeded invite code consumed, so this test
    // never contends with the claim-based tests for the single-use codes.
    await signUp(tester);
    final uid = SupabaseService.currentUser!.id;

    final self = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000e100',
      createdAt: DateTime.now().toUtc(),
      authUserId: uid,
      firstNameEn: 'Self',
      lastNameEn: 'Tester',
      gender: 'Male',
    ));

    // --- Give self a father (updates self's OWN row — allowed even pre-011) ---
    final father = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000e101',
      createdAt: DateTime.now().toUtc(),
      firstNameEn: 'Papa',
      lastNameEn: 'Tester',
      gender: 'Male',
    ));
    await SupabaseService.linkFamilyMembers(
      memberId: self.id,
      relatedMemberId: father.id,
      relationType: RelationType.father,
    );
    expect((await SupabaseService.getFamilyMemberById(self.id))!.fatherId,
        father.id,
        reason: 'father link (own-row update) must persist');

    // --- Add a NEW sibling: the link is a separate UPDATE on the sibling's
    //     row, with no prior kinship -> the exact write 010 silently dropped ---
    final sibling = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000e102',
      createdAt: DateTime.now().toUtc(),
      firstNameEn: 'Bhai',
      lastNameEn: 'Tester',
      gender: 'Male',
    ));
    await SupabaseService.linkFamilyMembers(
      memberId: self.id,
      relatedMemberId: sibling.id,
      relationType: RelationType.sibling,
    );
    expect((await SupabaseService.getFamilyMemberById(sibling.id))!.fatherId,
        father.id,
        reason: 'sibling must inherit self\'s father — this is what regressed');

    // --- Link an EXISTING placeholder as a child: a pure UPDATE on an
    //     unrelated unclaimed node, also blocked by 010 pre-fix ---
    final existing = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000e103',
      createdAt: DateTime.now().toUtc(),
      firstNameEn: 'Beta',
      lastNameEn: 'Tester',
      gender: 'Male',
    ));
    await SupabaseService.linkFamilyMembers(
      memberId: self.id,
      relatedMemberId: existing.id,
      relationType: RelationType.child,
    );
    expect((await SupabaseService.getFamilyMemberById(existing.id))!.fatherId,
        self.id,
        reason: 'linking an existing member as child must set father_id = self');
  });
}
