import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/auth_provider.dart';
import 'package:vanshavali/providers/family_provider.dart';
import 'package:vanshavali/providers/settings_provider.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';
import 'package:vanshavali/services/gujarat_places_service.dart';

const _places = '''
{"source":"t","districts":[
  {"name":"Ahmadabad","gu":"અમદાવાદ","code":"474","talukas":[]}
]}
''';

FamilyMember _member(String id, String gender, {String? fatherId}) =>
    FamilyMember(
      id: id,
      createdAt: DateTime(2020, 1, 1),
      fatherId: fatherId,
      firstNameEn: 'Test',
      lastNameEn: id,
      gender: gender,
      villageOrigin: 'Ahmadabad',
    );

Future<void> _pump(WidgetTester tester, String locale) async {
  final focus = _member('focus', 'Male', fatherId: 'father');
  final father = _member('father', 'Male');
  final child = _member('child', 'Female', fatherId: 'focus');
  final family = FamilyProvider()
    ..debugSetNetworkForTesting(
      egoNetwork: [focus, father, child],
      spouseLinks: const [],
      centerMember: focus,
    );
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
          value: AuthProvider.forTesting(currentMember: focus)),
      ChangeNotifierProvider<FamilyProvider>.value(value: family),
      ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider.forTesting(locale: Locale(locale))),
    ],
    // UI chrome stays English so 'Nearby' can be tapped; the tree reads the
    // content locale from SettingsProvider, which is what the app switches.
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en'), Locale('gu')],
      home: FamilyTreeScreen(),
    ),
  ));
  await tester.pump();
  await tester.tap(find.text('Nearby'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GujaratPlacesService.loadFromJson(_places));

  testWidgets('tree node shows the Gujarati village when locale is gu',
      (tester) async {
    await _pump(tester, 'gu');
    expect(find.text('અમદાવાદ'), findsWidgets);
    expect(find.text('Ahmadabad'), findsNothing);
  });

  testWidgets('tree node keeps the English village when locale is en',
      (tester) async {
    await _pump(tester, 'en');
    expect(find.text('Ahmadabad'), findsWidgets);
    expect(find.text('અમદાવાદ'), findsNothing);
  });
}
