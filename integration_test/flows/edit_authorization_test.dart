// Flow: edit authorization (scenario 4.x / migration 010). After claiming a
// profile, verify the kinship rule the backend enforces: you may edit your own
// profile and a direct UNCLAIMED relative (parent/child/spouse/sibling), but
// NOT a more-distant relative (e.g. grandparent) and NOT an unrelated node.
//
// Uses the seeded tree (supabase/seed.sql):
//   b1 Grandfather -> b2 Father -> b3 Child (invite code TEST04)
//   a1 Ramesh (unrelated, unclaimed)
// The test signs up and claims TEST04 (becoming "Child"), then checks the
// can_edit_family_member RPC (the single source of truth the UI gate and the
// RLS UPDATE policy both use).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _self = '00000000-0000-0000-0000-0000000000b3'; // Child (claimed by test)
const _father = '00000000-0000-0000-0000-0000000000b2'; // direct unclaimed
const _grandfather = '00000000-0000-0000-0000-0000000000b1'; // NOT direct
const _unrelated = '00000000-0000-0000-0000-0000000000a1'; // Ramesh, unrelated

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit is allowed only for self + direct unclaimed relatives',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    // Sign up and claim TEST04 (the Child node) so we're authenticated with a
    // real place in the seeded tree.
    await signUp(tester, code: 'TEST04');

    // Own profile: editable.
    expect(await SupabaseService.canEditMember(_self), isTrue,
        reason: 'You must be able to edit your own profile.');

    // Direct unclaimed parent: editable.
    expect(await SupabaseService.canEditMember(_father), isTrue,
        reason: 'A direct unclaimed parent must be editable.');

    // Grandparent (two hops): NOT editable.
    expect(await SupabaseService.canEditMember(_grandfather), isFalse,
        reason: 'A grandparent is not a direct relative — must not be editable.');

    // Unrelated node: NOT editable.
    expect(await SupabaseService.canEditMember(_unrelated), isFalse,
        reason: 'An unrelated node must never be editable.');
  });
}
