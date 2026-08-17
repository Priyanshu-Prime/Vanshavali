// Smoke tests — prove the E2E plumbing works end to end: the real app boots,
// talks to the (local) Supabase backend, and reaches the expected first screen.
// If these pass, the rig itself is sound and richer flow tests can build on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots to the Login screen when unauthenticated', (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    // LoginScreen shows an email field and a magic-link action.
    final emailField = find.byWidgetPredicate((w) =>
        w is TextField &&
        (w.decoration?.labelText ?? '').toLowerCase().contains('email'));
    expect(emailField, findsWidgets,
        reason: 'Expected the Login screen email field after boot.');
  });

  testWidgets('first-run onboarding shows the language toggle', (tester) async {
    await resetAppState(skipOnboarding: false);
    await bootApp(tester);

    // The onboarding screen leads with the EN/GU toggle; both labels render.
    expect(find.text('English'), findsWidgets);
    expect(find.text('ગુજરાતી'), findsWidgets);
  });
}
