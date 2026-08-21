// Flow: edit authorization (scenario 4.7). Verifies the kinship rule the backend
// enforces via can_edit_family_member — the single source of truth the UI gate
// and the RLS UPDATE/DELETE policies all use.
//
// Model as of migration 012 (relaxed from the original 010 "direct relatives
// only" rule, which broke building out the tree — you can't add your
// grandfather's father if distant nodes aren't editable):
//   * Your own profile:            editable.
//   * ANY unclaimed node:          editable (any hop distance — the tree is
//                                   communally completable), incl. grandparents
//                                   and unrelated placeholders.
//   * Someone else's CLAIMED node: NOT editable — covered separately by
//                                   flows/claimed_node_edit_guard_test.dart (4.8),
//                                   since the seed has no claimed-other node here.
//
// Uses the seeded tree (supabase/seed.sql):
//   b1 Grandfather -> b2 Father -> b3 Child (invite code TEST04)
//   a1 Ramesh (unrelated, unclaimed)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _self = '00000000-0000-0000-0000-0000000000b3'; // Child (claimed by test)
const _father = '00000000-0000-0000-0000-0000000000b2'; // direct unclaimed
const _grandfather = '00000000-0000-0000-0000-0000000000b1'; // distant unclaimed
const _unrelated = '00000000-0000-0000-0000-0000000000a1'; // Ramesh, unrelated

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('own profile and any unclaimed node are editable (post-012)',
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

    // Grandparent (two hops, unclaimed): editable — tree-building requires it.
    expect(await SupabaseService.canEditMember(_grandfather), isTrue,
        reason: 'A distant unclaimed ancestor must be editable (migration 012).');

    // Unrelated unclaimed node: editable (communal placeholder data).
    expect(await SupabaseService.canEditMember(_unrelated), isTrue,
        reason: 'Any unclaimed node must be editable (migration 012).');
  });
}
