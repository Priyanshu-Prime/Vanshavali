@Tags(['golden'])
library;

// Renders the full-tree view with a rich fake family to a golden PNG so the
// layout (clean generational rows + couples + children hanging under them) can
// be eyeballed. Not a strict pixel assertion — generated with --update-goldens
// and inspected.
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

FamilyMember _m(String id, String name,
        {String? f, String? mo, String g = 'Male', String? dob}) =>
    FamilyMember(
      id: id,
      createdAt: DateTime(2020),
      firstNameEn: name,
      lastNameEn: 'Fam',
      gender: g,
      fatherId: f,
      motherId: mo,
      authUserId: id == 'me' ? 'auth-me' : null,
      dob: dob == null ? null : DateTime.parse(dob),
    );

void main() {
  testWidgets('full tree layout golden', (tester) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gp1 = _m('gp1', 'Grandpa');
    final gp2 = _m('gp2', 'Grandma', g: 'Female');
    final dad = _m('dad', 'Dad', f: 'gp1', mo: 'gp2', dob: '1960-01-01');
    final uncle = _m('uncle', 'Uncle', f: 'gp1', mo: 'gp2', dob: '1962-01-01');
    final mom = _m('mom', 'Mom', g: 'Female');
    final aunt = _m('aunt', 'Aunt', g: 'Female');
    final me = _m('me', 'Me', f: 'dad', mo: 'mom', dob: '1990-01-01');
    final sis = _m('sis', 'Sister', f: 'dad', mo: 'mom', g: 'Female', dob: '1992-01-01');
    final bro = _m('bro', 'Brother', f: 'dad', mo: 'mom', dob: '1994-01-01');
    final cousin = _m('cousin', 'Cousin', f: 'uncle', mo: 'aunt', dob: '1991-01-01');
    final spouse = _m('spouse', 'Spouse', g: 'Female');
    final kid = _m('kid', 'Kid', f: 'me', mo: 'spouse', dob: '2015-01-01');

    final members = [gp1, gp2, dad, uncle, mom, aunt, me, sis, bro, cousin, spouse, kid];
    final links = [
      SpouseLink(memberId: 'gp1', spouseId: 'gp2'),
      SpouseLink(memberId: 'dad', spouseId: 'mom'),
      SpouseLink(memberId: 'uncle', spouseId: 'aunt'),
      SpouseLink(memberId: 'me', spouseId: 'spouse'),
    ];

    final familyProvider = FamilyProvider();
    familyProvider.debugSetFullTreeForTesting(fullTree: members, spouseLinks: links);
    familyProvider.setCenterMember(me);

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
          home: FamilyTreeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Zoom out so the whole tree fits in frame for the golden.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(find.byType(FamilyTreeScreen),
        matchesGoldenFile('goldens/full_tree.png'));
  });
}
