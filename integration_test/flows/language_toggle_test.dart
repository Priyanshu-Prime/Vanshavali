// Flow: the onboarding language toggle actually switches EN -> GU (scenario
// 5.1). The smoke test only checks both labels render; this taps the Gujarati
// segment and verifies the UI text truly re-renders in Gujarati — the app's
// bilingual support is a hard requirement.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../harness.dart';

// onboardingTitle1 in each locale (app_en.arb / app_gu.arb).
const _titleEn = 'Discover Your Roots';
const _titleGu = 'તમારા મૂળ શોધો';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the Gujarati toggle switches the UI to Gujarati',
      (tester) async {
    await resetAppState(skipOnboarding: false); // show onboarding
    await bootApp(tester);

    // Starts in English.
    expect(find.text(_titleEn), findsWidgets,
        reason: 'onboarding should start in English');
    expect(find.text(_titleGu), findsNothing);

    // Tap the Gujarati segment of the language toggle.
    await tapText(tester, 'ગુજરાતી');

    // The onboarding title re-renders in Gujarati, and the English one is gone.
    await pumpUntilFound(tester, find.text(_titleGu));
    expect(find.text(_titleGu), findsWidgets,
        reason: 'the UI must switch to Gujarati after tapping ગુજરાતી');
    expect(find.text(_titleEn), findsNothing,
        reason: 'the English title should no longer be shown');
  });
}
