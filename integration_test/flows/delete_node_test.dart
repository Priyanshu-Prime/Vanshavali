// Delete authorization (migration 013): you may delete any UNCLAIMED node and
// your OWN claimed profile, but never someone else's claimed node. Drives the
// real delete path against the real backend so the silent-0-rows delete bug
// (a DELETE filtered by RLS returns no error) can't come back.
//
// The "someone else's claimed node is undeletable" half is enforced by the same
// can_edit_family_member used for edits, which flows/claimed_node_edit_guard_test
// already proves returns false for a claimed other — so it isn't re-tested here.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete an unclaimed node, then delete your own profile',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester);
    final uid = SupabaseService.currentUser!.id;

    final self = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000ed00',
      createdAt: DateTime.now().toUtc(),
      authUserId: uid,
      firstNameEn: 'Self',
      lastNameEn: 'Del',
      gender: 'Male',
    ));

    // 1. Delete an unclaimed placeholder — must actually be gone.
    final placeholder = await SupabaseService.createFamilyMember(FamilyMember(
      id: '00000000-0000-0000-0000-00000000ed01',
      createdAt: DateTime.now().toUtc(),
      firstNameEn: 'Ghost',
      lastNameEn: 'Del',
      gender: 'Male',
    ));
    await SupabaseService.deleteFamilyMember(placeholder.id);
    expect(await SupabaseService.getFamilyMemberById(placeholder.id), isNull,
        reason: 'unclaimed node must be deleted from the backend');

    // 2. Delete your OWN claimed profile — allowed only for the owner (013).
    await SupabaseService.deleteFamilyMember(self.id);
    expect(await SupabaseService.getFamilyMemberById(self.id), isNull,
        reason: 'own claimed profile must be deletable by its owner');
  });
}
