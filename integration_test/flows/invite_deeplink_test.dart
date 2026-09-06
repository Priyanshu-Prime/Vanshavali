// Flow: the WhatsApp invite deep-link journey (docs/whatsapp_invite_flow.md).
//
// The invitee taps an https link → landing page → installs → the page fires
// `vanshavali://invite?code=<CODE>` → the app opens on SignupScreen with the
// code prefilled → claim. This test covers the halves that CAN run headlessly
// against the real local-Supabase backend:
//
//   1. The app's own link builder and parser round-trip: the exact URL the app
//      shares on WhatsApp parses back to the code, and the custom-scheme form
//      the landing page fires parses to the same code.
//   2. That parsed code actually claims the seeded placeholder on the real
//      backend (the same value _handleDeepLink prefills into SignupScreen).
//
// The remaining half — a REAL Android VIEW intent hitting the manifest
// intent-filter and driving _handleDeepLink → a prefilled SignupScreen — cannot
// be simulated in a headless widget test (it needs the app_links plugin to
// receive an actual OS intent). That is verified on-device via
// scripts/e2e/fire_invite_intent.sh and the manual checklist in
// docs/whatsapp_invite_flow.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/deep_link_service.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'an invite link parses to a code that claims the placeholder on the '
      'real backend', (tester) async {
    // The seed places TEST01 = Ramesh (see claim_from_form_test / seed.sql).
    const seededCode = 'TEST01';

    // 1a. The https URL the app shares on WhatsApp parses back to the code.
    final sharedUrl =
        DeepLinkService.buildInviteUrl('Ramesh Placeholder', seededCode);
    final fromHttps = DeepLinkService.parseInviteCodeFromUri(Uri.parse(sharedUrl));
    expect(fromHttps, seededCode,
        reason: 'the shared invite URL must parse back to the invite code');

    // 1b. The custom-scheme URL the landing page's "Open in app" button fires
    //     parses to the same code.
    final fromScheme = DeepLinkService.parseInviteCodeFromUri(
        Uri.parse('vanshavali://invite?code=$seededCode'));
    expect(fromScheme, seededCode,
        reason: 'the vanshavali://invite scheme must parse to the same code');

    // 2. That parsed code claims the placeholder end-to-end on the real backend
    //    — the same value _handleDeepLink prefills into SignupScreen.
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    await signUp(tester, code: fromScheme!);

    await pumpUntilFound(tester, find.textContaining('Ramesh'));
    expect(find.textContaining('Ramesh'), findsWidgets,
        reason: 'claiming with the parsed invite code should land on Home '
            'as the claimed placeholder Ramesh');

    final me = await SupabaseService.getCurrentUserProfile();
    expect(me?.firstNameEn, 'Ramesh',
        reason: 'the code parsed from the invite link must claim the '
            'placeholder, not create a new profile');
  });
}
