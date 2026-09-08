@Tags(['golden'])
library;

// Golden: pivot the full tree onto the mother, verifying it re-roots into a
// clean maternal-lineage tree (her parents at top, her siblings, you below).
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

FamilyMember _m(String id, String name, {String? f, String? mo, String g = 'Male', String? dob}) =>
    FamilyMember(id: id, createdAt: DateTime(2020), firstNameEn: name, lastNameEn: 'Fam',
        gender: g, fatherId: f, motherId: mo, authUserId: id == 'me' ? 'auth-me' : null,
        dob: dob == null ? null : DateTime.parse(dob));

void main() {
  testWidgets('pivot to mother renders her lineage', (tester) async {
    tester.view.physicalSize = const Size(1700, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gp1 = _m('gp1', 'Ramesh'), gp2 = _m('gp2', 'Sita', g: 'Female');
    final dad = _m('dad', 'Mahesh', f: 'gp1', mo: 'gp2', dob: '1960-01-01');
    final mgp1 = _m('mgp1', 'Mohan'), mgp2 = _m('mgp2', 'Gita', g: 'Female');
    final mom = _m('mom', 'Rekha', f: 'mgp1', mo: 'mgp2', g: 'Female', dob: '1961-01-01');
    final maunt = _m('maunt', 'Meena', f: 'mgp1', mo: 'mgp2', g: 'Female', dob: '1964-01-01');
    final me = _m('me', 'Priya', f: 'dad', mo: 'mom', g: 'Female', dob: '1990-01-01');
    final sis = _m('sis', 'Anjali', f: 'dad', mo: 'mom', g: 'Female', dob: '1992-01-01');
    final members = [gp1, gp2, dad, mgp1, mgp2, mom, maunt, me, sis];
    final links = [
      SpouseLink(memberId: 'gp1', spouseId: 'gp2'),
      SpouseLink(memberId: 'dad', spouseId: 'mom'),
      SpouseLink(memberId: 'mgp1', spouseId: 'mgp2'),
    ];
    final fp = FamilyProvider()..debugSetFullTreeForTesting(fullTree: members, spouseLinks: links);
    fp.setCenterMember(me);

    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider.forTesting(currentMember: me)),
      ChangeNotifierProvider<FamilyProvider>.value(value: fp),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider.forTesting()),
    ], child: const MaterialApp(
      localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: [Locale('en'), Locale('gu')], home: FamilyTreeScreen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Long-press mom's box (single tap now opens her profile), then
    // "Explore Rekha's family" in the options sheet.
    await tester.longPress(find.textContaining('Rekha').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining("Rekha's family"));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) { await tester.tap(find.byIcon(Icons.remove)); await tester.pump(); }
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(find.byType(FamilyTreeScreen),
        matchesGoldenFile('goldens/full_tree_pivot.png'));
  });
}
