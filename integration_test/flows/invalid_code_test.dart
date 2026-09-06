// Flow: signing up with an invalid/unknown invite code (scenario 2.3). A
// typo'd or bogus code must NOT crash and must NOT claim anyone — the account
// is still created and the user falls through to manual profile creation
// ("Complete Your Profile"), where they can create their own node or re-enter
// a correct code.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an unknown invite code falls through to manual profile creation',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    // 'ZZZZZZ' is 6 chars (so the app attempts a claim) but matches no seeded
    // placeholder, so the claim must fail cleanly.
    await signUp(tester, code: 'ZZZZZZ');

    // The account itself was still created (signup succeeded).
    expect(SupabaseService.currentUser, isNotNull,
        reason: 'signup must succeed even when the invite code is invalid');

    // We land on the profile-creation screen, not a crash and not someone
    // else's claimed identity.
    await pumpUntilFound(tester, find.text('Complete Your Profile'));
    expect(find.text('Complete Your Profile'), findsWidgets,
        reason: 'an unknown code must fall through to manual profile creation');
    expect(find.textContaining('Ramesh'), findsNothing,
        reason: 'a bogus code must never claim a seeded placeholder');
  });
}
