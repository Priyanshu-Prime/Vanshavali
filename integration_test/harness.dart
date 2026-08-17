// Shared setup for Vanshavali end-to-end tests.
//
// Boots the REAL app (the same widget tree production runs) against whatever
// Supabase backend the build was pointed at via --dart-define. The E2E runner
// (scripts/e2e/run_e2e.sh) points it at a local stack. Each test starts from a
// clean slate: local Hive storage cleared and any Supabase session signed out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/main.dart';
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
