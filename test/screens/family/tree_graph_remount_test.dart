// Regression test for "lines going haywire" (0.1.0-alpha.2+17): when the tree
// data changed but _GraphViewHost's key did not (same focus / same member
// count), a NEW Graph was handed to the still-mounted GraphView. graphview's
// Node equality is by key, so its render object kept the OLD Node objects
// (stale positions) for the boxes while edges were drawn from the NEW nodes'
// positions. The host is now keyed by graph identity, so any new graph
// remounts it and every box sits exactly where the layout put it.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';
import 'package:provider/provider.dart';

import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/auth_provider.dart';
import 'package:vanshavali/providers/family_provider.dart';
import 'package:vanshavali/providers/settings_provider.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';

FamilyMember _m(String id, {String? father, String? mother, String g = 'Male'}) =>
    FamilyMember(
      id: id,
      createdAt: DateTime(2020),
      firstNameEn: id,
      lastNameEn: 'T',
      gender: g,
      fatherId: father,
      motherId: mother,
    );

Future<void> _pump(WidgetTester tester, FamilyProvider fp, FamilyMember me) =>
    tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider.forTesting(currentMember: me)),
        ChangeNotifierProvider<FamilyProvider>.value(value: fp),
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
    ));

/// Every rendered box offset must equal the position the layout algorithm
/// assigned to the nodes of the graph currently handed to GraphView — the
/// same nodes the edges are drawn from. Returns those positions.
Set<Offset> _expectBoxesMatchLayout(WidgetTester tester) {
  final graph = tester.widget<GraphView>(find.byType(GraphView)).graph;
  final box = tester.allRenderObjects.whereType<RenderCustomLayoutBox>().toSet().single;
  final rendered = <Offset>{};
  box.visitChildren(
      (c) => rendered.add(((c as RenderBox).parentData as BoxParentData).offset));
  final layout = {for (final n in graph.nodes) n.position};
  expect(rendered, layout,
      reason: 'boxes must sit where the current layout (and its edges) put them');
  return layout;
}

void main() {
  testWidgets('ego view remounts the graph host when the shape changes '
      'with the same focus and member count', (tester) async {
    final fp = FamilyProvider();
    final focus = _m('focus', father: 'father', mother: 'mother');
    fp.debugSetNetworkForTesting(
      egoNetwork: [
        focus,
        _m('father'),
        _m('mother', g: 'Female'),
        _m('c1', father: 'focus'),
        _m('c2', father: 'focus'),
      ],
      centerMember: focus,
    );
    await _pump(tester, fp, focus);
    await tester.pump();
    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();

    final before = _expectBoxesMatchLayout(tester);
    final stateBefore = tester.state(find.byType(GraphView));

    // Same focus, same 5 members — c2 is re-parented from child to sibling.
    final focus2 = _m('focus', father: 'father', mother: 'mother');
    fp.debugSetNetworkForTesting(
      egoNetwork: [
        focus2,
        _m('father'),
        _m('mother', g: 'Female'),
        _m('c1', father: 'focus'),
        _m('c2', father: 'father', mother: 'mother'),
      ],
      centerMember: focus2,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final after = _expectBoxesMatchLayout(tester);
    expect(after, isNot(before), reason: 'fixture must actually shift layout');
    expect(identical(tester.state(find.byType(GraphView)), stateBefore), isFalse);

    // Zoom still wired to the new host's controller.
    final ctrl = tester
        .widget<GraphView>(find.byType(GraphView))
        .controller!
        .transformationController!;
    final scale = ctrl.value.getMaxScaleOnAxis();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(ctrl.value.getMaxScaleOnAxis(), greaterThan(scale));
  });

  testWidgets('full view remounts on a same-count re-parent, but keeps the '
      'host on an incidental rebuild', (tester) async {
    final fp = FamilyProvider();
    final me = _m('me', father: 'f');
    List<FamilyMember> fam({required String cousinFather}) => [
          _m('g'),
          _m('f', father: 'g'),
          _m('u', father: 'g'),
          _m('me', father: 'f'),
          _m('s', father: 'f'),
          _m('c', father: cousinFather),
        ];
    fp.debugSetNetworkForTesting(egoNetwork: [me], centerMember: me);
    fp.debugSetFullTreeForTesting(fullTree: fam(cousinFather: 'u'));
    await _pump(tester, fp, me);
    await tester.pumpAndSettle();

    final before = _expectBoxesMatchLayout(tester);
    final stateBefore = tester.state(find.byType(GraphView));

    // Incidental rebuild with the SAME lists: no remount.
    fp.debugSetNetworkForTesting(egoNetwork: [me], centerMember: me);
    await tester.pumpAndSettle();
    expect(identical(tester.state(find.byType(GraphView)), stateBefore), isTrue);

    // Refetch with identical content (new list objects): graph reused, no
    // remount (no viewport jump on returning from a profile).
    fp.debugSetFullTreeForTesting(fullTree: fam(cousinFather: 'u'));
    await tester.pumpAndSettle();
    expect(identical(tester.state(find.byType(GraphView)), stateBefore), isTrue);
    _expectBoxesMatchLayout(tester);

    // Same member count, cousin moved under f: layout shifts -> remount.
    fp.debugSetFullTreeForTesting(fullTree: fam(cousinFather: 'f'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final after = _expectBoxesMatchLayout(tester);
    expect(after, isNot(before), reason: 'fixture must actually shift layout');
    expect(identical(tester.state(find.byType(GraphView)), stateBefore), isFalse);
  });
}
