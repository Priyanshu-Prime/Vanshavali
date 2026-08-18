// Flow: signup + invite-code claim (scenarios 2.1, 2.4 in
// docs/test_scenarios.md). Exercises the exact path that broke live during
// alpha: create a brand-new account, enter a valid invite code, and expect to
// land straight on Home as the claimed person — NO second password prompt, NO
// "invalid code" error, NO dropped-back-to-full-profile-entry.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // These caught a real intermittent claim-race bug: claimProfileByCode's
  // post-claim `_currentMember!` was nulled by the concurrent signedIn
  // profile-load between awaits, crashing a claim that had already succeeded
  // server-side. Fixed in auth_provider.dart by capturing the claimed member
  // into a local; these are the regression guard.
  testWidgets('signup with a valid invite code claims the placeholder',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    await signUp(tester, code: 'TEST01');

    // Expected end state: on Home, showing the claimed person's name, and
    // NOT stuck on the set-password screen or profile-creation form.
    await pumpUntilFound(tester, find.textContaining('Ramesh'));
    expect(find.textContaining('Ramesh'), findsWidgets,
        reason: 'Expected to land on Home as the claimed placeholder Ramesh.');
    expect(find.text('Set a Password'), findsNothing,
        reason: 'A just-claimed account must not be asked to set a password.');
  });

  testWidgets('an invite code is single-use', (tester) async {
    // First user claims TEST03 successfully.
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester, code: 'TEST03');
    await pumpUntilFound(tester, find.textContaining('Mohan'));
    expect(find.textContaining('Mohan'), findsWidgets,
        reason: 'First claim of TEST03 should succeed.');

    // Second, different user tries the same code — must not silently succeed.
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester, code: 'TEST03');

    // The second account was created (signup succeeds) but the code is spent,
    // so they should be on profile creation, NOT viewing Mohan's identity.
    expect(find.textContaining('Mohan'), findsNothing,
        reason: 'A spent invite code must not claim the placeholder again.');
  });
}
