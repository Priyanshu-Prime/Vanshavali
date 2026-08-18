// Flow: the profile-creation screen has a working sign-out escape hatch
// (scenario 3.3) — a user who lands there (e.g. signed up but hasn't built a
// profile) must never be dead-ended; the logout action returns them to Login.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logout from the profile-creation screen is not a dead-end',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    await signUp(tester); // no code -> "Complete Your Profile"
    await pumpUntilFound(tester, find.text('Complete Your Profile'));
    expect(SupabaseService.currentUser, isNotNull);

    // Tap the logout action in the AppBar, then confirm the dialog ("Continue").
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Signed out and off the creation form — the escape hatch works.
    for (var i = 0; i < 20 && SupabaseService.currentUser != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(SupabaseService.currentUser, isNull,
        reason: 'logout must clear the session');
    expect(find.text('Complete Your Profile'), findsNothing,
        reason: 'the creation form should be gone after logout');
  });
}
