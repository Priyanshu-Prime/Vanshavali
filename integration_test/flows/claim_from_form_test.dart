// Flow: claiming from the profile-completion screen, not the signup screen
// (scenario 2.2). A user who signed up without a code (or via magic link) can
// still enter their invite code on "Complete Your Profile" and claim their
// placeholder. Note _saveProfile validates the name fields BEFORE attempting
// the claim, so the form must be filled even though a successful claim then
// replaces those values with the placeholder's. Also re-exercises the claim
// path fixed for the race crash, via this second entry point.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('claiming with an invite code on the profile form works',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    await signUp(tester); // no code -> manual profile creation
    await pumpUntilFound(tester, find.text('Complete Your Profile'));

    // Name fields must be filled to pass form validation before the claim.
    await enterInField(tester, 'first name *', 'Temp');
    await enterInField(tester, 'last name *', 'Placeholder');
    // Enter a valid code in the form's invite-code field.
    await enterInField(tester, '6-character code', 'TEST01');

    // Save -> claims TEST01 (Ramesh) instead of creating the typed profile.
    final save = find.byType(ElevatedButton);
    await tester.scrollUntilVisible(
      save,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // Landed on Home as the claimed placeholder, not the typed "Temp".
    await pumpUntilFound(tester, find.textContaining('Ramesh'));
    expect(find.textContaining('Ramesh'), findsWidgets,
        reason: 'claiming on the form should land on Home as Ramesh');

    final me = await SupabaseService.getCurrentUserProfile();
    expect(me?.firstNameEn, 'Ramesh',
        reason: 'the claim must win over the typed-in name');
  });
}
