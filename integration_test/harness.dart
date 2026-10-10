// Shared setup for Vanshavali end-to-end tests.
//
// Boots the REAL app (the same widget tree production runs) against whatever
// Supabase backend the build was pointed at via --dart-define. The E2E runner
// (scripts/e2e/run_e2e.sh) points it at a local stack. Each test starts from a
// clean slate: local Hive storage cleared and any Supabase session signed out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vanshavali/config/app_config.dart';
import 'package:provider/provider.dart';
import 'package:vanshavali/main.dart';
import 'package:vanshavali/providers/family_provider.dart';
import 'package:vanshavali/services/local_storage_service.dart';
import 'package:vanshavali/services/supabase_service.dart';

// Hive type adapters and Supabase.initialize() may only run ONCE per process;
// all tests in a file share one app isolate, so guard the one-time init and
// let each test only reset mutable state below.
bool _servicesInitialized = false;

/// Initializes services (once) and clears all local + session state. Call
/// inside each test before [bootApp]. [skipOnboarding] marks onboarding
/// complete so the test starts at Login unless it specifically wants to
/// exercise onboarding.
Future<void> resetAppState({bool skipOnboarding = true}) async {
  if (!_servicesInitialized) {
    await LocalStorageService.initialize();
    await SupabaseService.initialize();
    _servicesInitialized = true;
  }

  // Sign out any lingering session from a previous test on this emulator.
  try {
    await SupabaseService.signOut();
  } catch (_) {}

  await LocalStorageService.clearAll();
  await LocalStorageService.setOnboardingCompleted(skipOnboarding);
}

/// Pumps the real app and lets initial async work (auth check, initial
/// navigation) settle. Use a long timeout because the first frame does a
/// network round-trip to the (local) backend.
Future<void> bootApp(WidgetTester tester) async {
  await tester.pumpWidget(const VanshavaliApp());
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

/// Enters text into the TextFormField whose decoration label/hint contains
/// [labelSubstring] (case-insensitive). Fails clearly if none match.
Future<void> enterInField(
  WidgetTester tester,
  String labelSubstring,
  String value,
) async {
  final field = find.byWidgetPredicate((w) {
    if (w is! TextField) return false;
    final d = w.decoration;
    final hay = '${d?.labelText ?? ''} ${d?.hintText ?? ''}'.toLowerCase();
    return hay.contains(labelSubstring.toLowerCase());
  });
  expect(
    field,
    findsWidgets,
    reason: 'No text field matching "$labelSubstring" was found on screen.',
  );
  await tester.enterText(field.first, value);
  await tester.pumpAndSettle();
}

/// Taps the first tappable (Button/InkWell/widget) whose visible text contains
/// [textSubstring], case-insensitive.
Future<void> tapText(WidgetTester tester, String textSubstring) async {
  final match = find.byWidgetPredicate((w) {
    if (w is Text) {
      final t = (w.data ?? '').toLowerCase();
      return t.contains(textSubstring.toLowerCase());
    }
    return false;
  });
  expect(
    match,
    findsWidgets,
    reason: 'No tappable text containing "$textSubstring" was found.',
  );
  await tester.tap(match.first);
  await tester.pumpAndSettle();
}

/// A short, unique email so repeated signup tests never collide (auth users
/// persist in the local DB across a run until the next `db reset`).
String uniqueEmail() =>
    'e2e_${DateTime.now().microsecondsSinceEpoch}@example.com';

/// Pumps frames until [finder] matches at least one widget, or [timeout]
/// elapses. Use for "the screen eventually shows X" assertions where the app
/// does async work (claim + profile load + navigation) after the action
/// settles, so a bare expect right after would race the render.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Robustly drives Login → Sign Up → submit, optionally claiming an invite
/// [code]. Returns once the post-signup session is live (or fails clearly).
///
/// Why this isn't just a few tapText calls: after the last field is filled the
/// soft keyboard covers the submit button, so a plain tap silently MISSES and
/// the form never submits — the session then never establishes and later reads
/// run as `anon`. We scroll the actual ElevatedButton into view and tap the
/// widget (not ambiguous "Sign Up" text, which also matches the screen header),
/// then wait for auth.currentUser to appear.
Future<void> signUp(
  WidgetTester tester, {
  String? code,
  String? email,
  String password = 'test1234',
}) async {
  await tapText(tester, 'Sign Up'); // Login screen -> Sign Up screen.
  await tester.pumpAndSettle();

  await enterInField(tester, 'email', email ?? uniqueEmail());
  await enterInField(tester, 'confirm password', password);
  await enterInField(tester, 'password', password);
  // Code is optional: with none, the app creates the account and routes to
  // manual profile creation instead of claiming a placeholder.
  if (code != null && code.isNotEmpty) {
    await enterInField(tester, '6-character code', code);
  }

  // Scroll the submit button above the keyboard/fold before tapping it.
  final submit = find.byType(ElevatedButton);
  expect(submit, findsWidgets, reason: 'signup submit button not found');
  // Close the keyboard and wait for its insets to finish animating out, or
  // the button moves between ensureVisible and tap and the tap misses.
  FocusManager.instance.primaryFocus?.unfocus();
  for (var i = 0; i < 20 && tester.view.viewInsets.bottom > 0; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(submit.last);
  await tester.pumpAndSettle();
  await tester.tap(submit.last);
  await tester.pumpAndSettle(const Duration(seconds: 10));

  // The session propagates to the Supabase client slightly after the tree
  // settles; wait for it so the first direct (non-RPC) table read isn't anon.
  for (var i = 0; i < 20 && SupabaseService.currentUser == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

/// A second Supabase client with its OWN in-memory session, so a test can act
/// as another user (relative approving a claim, a stranger, seeding) without
/// touching the app's session. Implicit flow: PKCE would need async storage.
SupabaseClient isolatedClient() => SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

/// Signs [client] up as a fresh password user and returns the auth uid.
Future<String> apiSignUp(SupabaseClient client, String email,
    {String password = 'test1234'}) async {
  // Retry transport errors only: right after install the emulator's network
  // is occasionally not up yet ("Network is unreachable").
  AuthResponse? res;
  for (var attempt = 1; res == null; attempt++) {
    try {
      res = await client.auth.signUp(email: email, password: password);
    } on AuthRetryableFetchException {
      if (attempt >= 5) rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  expect(res.session, isNotNull, reason: 'local signup must return a session');
  return res.user!.id;
}

/// Picks [value] in the ancestral-village picker via its state-wide search.
/// Scrolls the (lazy) form until the field is built, opens the sheet, types
/// the name and taps the first hit (exact matches rank first).
Future<void> pickVillage(WidgetTester tester, String value) async {
  final field = find.text('Select village');
  await tester.scrollUntilVisible(field, 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await enterInField(tester, 'search district', value);
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

/// Selects [option] in the form's gender dropdown (scrolling it into view).
Future<void> pickGender(WidgetTester tester, String option) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.scrollUntilVisible(dropdown, 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(dropdown.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Scrolls the lazy form to its bottom Save button and taps it.
Future<void> tapFormSave(WidgetTester tester) async {
  final save = find.byType(ElevatedButton);
  await tester.scrollUntilVisible(save, 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(save.last);
  await tester.pump(const Duration(seconds: 1));
}

/// Taps the bottom-navigation tab labelled [label] (not same-text app bars).
Future<void> tapNavTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar), matching: find.text(label)));
  await tester.pump(const Duration(seconds: 1));
}

/// Waits for in-flight FamilyProvider loads to finish. Call at the end of a
/// test that lands on Home: tearing the app down mid-load makes the provider
/// notify after dispose, which fails the test after it already passed.
Future<void> waitForFamilyIdle(WidgetTester tester) async {
  final fp = Provider.of<FamilyProvider>(
      tester.element(find.byType(Scaffold).first),
      listen: false);
  for (var i = 0; i < 50 && (fp.isLoading || fp.isLoadingFullTree); i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pump(const Duration(milliseconds: 500));
}
