// Widget tests for the two-tab Directory (My family / Everyone).
//
// Scope kept to what runs without a live backend or Hive: the "My family" tab
// renders the injected connected component and its empty state, and switching
// to the "Everyone" tab shows a different view. The "Everyone" tab's paginated
// network fetch fires in initState; without DirectoryScreen.debugFetchPage it
// stays pending in a backend-less test (spinner), and with the seam a test
// can drive failure -> retry deterministically.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/auth_provider.dart';
import 'package:vanshavali/providers/family_provider.dart';
import 'package:vanshavali/providers/settings_provider.dart';
import 'package:vanshavali/screens/directory/directory_screen.dart';
import 'package:vanshavali/theme/app_theme.dart';

FamilyMember _member(String id, String first) => FamilyMember(
      id: id,
      createdAt: DateTime(2020, 1, 1),
      firstNameEn: first,
      lastNameEn: 'Person',
      gender: 'Male',
    );

Widget _app(List<FamilyMember> fullTree,
    {ThemeData? theme, bool isVisible = true}) {
  final me = _member('me', 'Me');
  final familyProvider = FamilyProvider()
    ..debugSetFullTreeForTesting(fullTree: fullTree);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
          value: AuthProvider.forTesting(currentMember: me)),
      ChangeNotifierProvider<FamilyProvider>.value(value: familyProvider),
      ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider.forTesting()),
    ],
    child: MaterialApp(
      theme: theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('gu')],
      home: DirectoryScreen(isVisible: isVisible),
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<FamilyMember> fullTree,
    {ThemeData? theme}) async {
  await tester.pumpWidget(_app(fullTree, theme: theme));
  await tester.pumpAndSettle();
}

// WCAG 2.x relative luminance / contrast ratio.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color fg, Color bg) {
  final f = _lum(Color.alphaBlend(fg, bg));
  final b = _lum(bg);
  return (max(f, b) + 0.05) / (min(f, b) + 0.05);
}

Color _labelColor(WidgetTester tester, String label) => tester
    .renderObject<RenderParagraph>(find.text(label))
    .text
    .style!
    .color!;

void main() {
  tearDown(() => DirectoryScreen.debugFetchPage = null);

  // AppTheme builds GoogleFonts styles, which try to fetch fonts over the
  // network (unavailable in tests) and fail asynchronously. Only colors are
  // asserted here, so swallow those font-load errors.
  final themes = runZonedGuarded(
    () => {'light': AppTheme.lightTheme, 'dark': AppTheme.darkTheme},
    (_, _) {},
  )!;

  testWidgets('renders both tabs and lists the connected family in "My family"',
      (tester) async {
    await _pump(tester, [_member('a', 'Alice'), _member('b', 'Bob')]);

    expect(find.text('My family'), findsOneWidget);
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Alice Person'), findsOneWidget);
    expect(find.text('Bob Person'), findsOneWidget);
  });

  testWidgets('empty "My family" shows the friendly empty state',
      (tester) async {
    await _pump(tester, const []);

    expect(find.text('No members yet'), findsOneWidget);
  });

  testWidgets('switching to the "Everyone" tab shows a different view',
      (tester) async {
    await _pump(tester, [_member('a', 'Alice')]);
    // My family tab shows Alice.
    expect(find.text('Alice Person'), findsOneWidget);

    await tester.tap(find.text('Everyone'));
    // Don't settle: with no backend the page fetch stays pending, so the tab
    // sits on its loading spinner. Pump a couple of frames for the animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Alice Person'), findsNothing);
  });

  // Owner complaint: "the other tab is not visible". The TabBar sits on the
  // AppBar, so its labels must contrast with the AppBar background.
  for (final entry in themes.entries) {
    testWidgets('tab labels contrast with the AppBar (${entry.key} theme)',
        (tester) async {
      await _pump(tester, [_member('a', 'Alice')], theme: entry.value);

      final bar = tester
          .widget<Material>(find
              .descendant(
                  of: find.byType(AppBar), matching: find.byType(Material))
              .first)
          .color!;
      final selected = _labelColor(tester, 'My family');
      final unselected = _labelColor(tester, 'Everyone');

      expect(_contrast(selected, bar), greaterThanOrEqualTo(4.5),
          reason: 'selected tab label');
      expect(_contrast(unselected, bar), greaterThanOrEqualTo(3.0),
          reason: 'unselected tab label');
    });
  }

  testWidgets('"Everyone" pull-to-refresh retries after an offline failure',
      (tester) async {
    var calls = 0;
    DirectoryScreen.debugFetchPage = (limit, offset) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return [_member('z', 'Zed')];
    };
    await _pump(tester, [_member('a', 'Alice')]);
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    // First load failed with an empty cache -> friendly empty state.
    expect(calls, 1);
    expect(find.text('No members yet'), findsOneWidget);

    await tester.fling(
        find.text('No members yet'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Zed Person'), findsOneWidget);
  });

  testWidgets('a failed "Everyone" load retries when the tab becomes visible',
      (tester) async {
    var calls = 0;
    DirectoryScreen.debugFetchPage = (limit, offset) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return [_member('z', 'Zed')];
    };
    await tester.pumpWidget(_app([_member('a', 'Alice')], isVisible: false));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.pumpWidget(_app([_member('a', 'Alice')], isVisible: true));
    await tester.pumpAndSettle();
    expect(calls, 2);

    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();
    expect(find.text('Zed Person'), findsOneWidget);
  });
}
