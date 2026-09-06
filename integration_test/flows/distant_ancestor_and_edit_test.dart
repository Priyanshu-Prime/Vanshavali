// Regression guard for the "can't build out distant parts of the tree" class of
// bug (migrations 010 -> 011 -> 012). These are the writes that repeatedly
// slipped through because earlier tests either baked links into the INSERT or
// exercised only DIRECT ±1 relatives — never a node several hops away, which is
// exactly what tree-building is.
//
// Real report this pins down: a user could not add his grandfather's father.
// The placeholder was created but the link UPDATE was silently filtered by RLS
// (the grandfather is 2 hops away, not a direct relative), so the node never
// appeared in the tree.
//
// Drives the REAL two-step create-then-link path against the REAL local backend
// (RLS + set_member_parents RPC + the relaxed can_edit_family_member), building
// a 4-generation chain as a fresh user and then reaching UP past the direct
// relatives:
//   self -> father (direct)  -> grandfather (2 hops) -> great-grandfather
// and asserts each link, the DISTANT-ancestor link, and a DISTANT content edit
// all persist. No seeded invite code is consumed, so it never contends with the
// claim-based tests for the single-use codes.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper: create an unclaimed placeholder with no links.
  Future<FamilyMember> placeholder(String id, String first) =>
      SupabaseService.createFamilyMember(FamilyMember(
        id: id,
        createdAt: DateTime.now().toUtc(),
        firstNameEn: first,
        lastNameEn: 'Chain',
        gender: 'Male',
      ));

  Future<String?> fatherOf(String id) async =>
      (await SupabaseService.getFamilyMemberById(id))!.fatherId;

  testWidgets('build + edit a multi-generation chain past direct relatives',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester);
    final uid = SupabaseService.currentUser!.id;

    final self = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000ea00',
      createdAt: DateTime.now().toUtc(),
      authUserId: uid,
      firstNameEn: 'Self',
      lastNameEn: 'Chain',
      gender: 'Male',
    ));

    final father = await placeholder('00000000-0000-0000-0000-00000000ea01', 'Father');
    final grandfather = await placeholder('00000000-0000-0000-0000-00000000ea02', 'Grand');
    final greatGrand = await placeholder('00000000-0000-0000-0000-00000000ea03', 'Great');

    // 1. father of self — updates self's OWN row (direct).
    await SupabaseService.linkFamilyMembers(
      memberId: self.id, relatedMemberId: father.id, relationType: RelationType.father);
    expect(await fatherOf(self.id), father.id, reason: 'father of self must persist');

    // 2. father of father (grandfather) — updates the father's row; father is a
    //    DIRECT relative of self, so allowed even under the 010 policy.
    await SupabaseService.linkFamilyMembers(
      memberId: father.id, relatedMemberId: grandfather.id, relationType: RelationType.father);
    expect(await fatherOf(father.id), grandfather.id, reason: 'grandfather link must persist');

    // 3. father of grandfather (great-grandfather) — the grandfather is 2 hops
    //    from self, NOT a direct relative. THIS is the write that regressed.
    await SupabaseService.linkFamilyMembers(
      memberId: grandfather.id, relatedMemberId: greatGrand.id, relationType: RelationType.father);
    expect(await fatherOf(grandfather.id), greatGrand.id,
        reason: 'DISTANT ancestor link (grandfather -> great-grandfather) must persist');

    // 4. Editing a DISTANT unclaimed node's own details must also persist
    //    (the member-detail edit path, governed by the same policy).
    await SupabaseService.updateFamilyMember(grandfather.copyWith(firstNameEn: 'GrandEdited'));
    expect((await SupabaseService.getFamilyMemberById(grandfather.id))!.firstNameEn,
        'GrandEdited', reason: 'editing a distant unclaimed node must persist');
  });
}
