// Widget tests for the two-tab Directory (My family / All).
//
// Scope kept to what runs without a live backend or Hive: the "My family" tab
// renders the injected connected component and its empty state, and switching
// to the "All" tab shows a different view. The "All" tab's paginated network
// fetch fires in initState but degrades to the (guarded) empty cache in a
// backend-less test, so it lands on its friendly empty state rather than
// hanging on a spinner.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/auth_provider.dart';
import 'package:vanshavali/providers/family_provider.dart';
import 'package:vanshavali/providers/settings_provider.dart';
import 'package:vanshavali/screens/directory/directory_screen.dart';

FamilyMember _member(String id, String first) => FamilyMember(
      id: id,
      createdAt: DateTime(2020, 1, 1),
      firstNameEn: first,
      lastNameEn: 'Person',
      gender: 'Male',
    );

Future<void> _pump(WidgetTester tester, List<FamilyMember> fullTree) async {
  final me = _member('me', 'Me');
  final familyProvider = FamilyProvider()
    ..debugSetFullTreeForTesting(fullTree: fullTree);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider.forTesting(currentMember: me)),
        ChangeNotifierProvider<FamilyProvider>.value(value: familyProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider.forTesting()),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('gu')],
        home: DirectoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders both tabs and lists the connected family in "My family"',
      (tester) async {
    await _pump(tester, [_member('a', 'Alice'), _member('b', 'Bob')]);

    expect(find.text('My family'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Alice Person'), findsOneWidget);
    expect(find.text('Bob Person'), findsOneWidget);
  });

  testWidgets('empty "My family" shows the friendly empty state',
      (tester) async {
    await _pump(tester, const []);

    expect(find.text('No members yet'), findsOneWidget);
  });

  testWidgets('switching to the "All" tab shows a different view',
      (tester) async {
    await _pump(tester, [_member('a', 'Alice')]);
    // My family tab shows Alice.
    expect(find.text('Alice Person'), findsOneWidget);

    await tester.tap(find.text('All'));
    // Don't settle: with no backend the All-tab page fetch stays pending, so
    // the tab sits on its loading spinner (the intended loading state). Pump a
    // couple of frames to drive the tab-switch animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Now on the All tab: it shows the loading state, and the My-family-only
    // member is no longer shown.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Alice Person'), findsNothing);
  });
}
