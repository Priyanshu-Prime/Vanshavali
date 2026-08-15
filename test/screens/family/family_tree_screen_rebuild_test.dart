// Regression tests for THREE separate real crashes observed on-device, all
// variants of the same underlying class of bug: something about
// FamilyTreeScreen's default (graphview) view being unmounted-and-remounted
// left a stale, already-disposed TransformationController in play.
//
// 1. '_lifecycleState == _ElementLifecycle.inactive' — an incidental
//    rebuild (app resuming from background) rebuilt the graphview Graph
//    with brand-new Node object instances every time, even though
//    GraphView.builder's own Element persisted. Fixed by caching the built
//    Graph/Node objects, keyed on reference-equality of FamilyProvider's
//    egoNetwork/spouseLinks.
// 2. 'A TransformationController was used after being disposed' (first
//    report) — FamilyTreeScreen's own dispose() double-disposed a
//    TransformationController that graphview's _GraphViewState.dispose()
//    already disposes itself. Fixed by removing that redundant dispose call.
// 3. The SAME error, again, on-device, AFTER fix #2 — because #2 only
//    covered the "leaving this screen entirely" case. graphview's
//    _GraphViewState (confirmed by reading its full source) disposes
//    whatever TransformationController it was given every time ITS Element
//    unmounts, for ANY reason — including this screen's isLoading branch
//    swapping the whole subtree out and back (which happens on every
//    re-center/refresh), view-mode switching away from and back to the
//    default view, and the single-node bypass in _buildDefaultView kicking
//    in and later reverting. A single controller reused across any of
//    those unmount cycles gets handed, already-dead, to the next GraphView
//    instance. Fixed by moving controller ownership into a dedicated
//    _GraphViewHost widget whose own initState/dispose — which Flutter
//    guarantees run fresh on every mount, regardless of cause — create and
//    release the controller, instead of the parent State trying to track
//    when a reused one might be stale.
//
// 4. Found by independent review of fix #3 (not on-device — a silent
//    correctness bug, not a crash): _GraphViewHost's original single
//    nullable onControllerChanged callback had a same-frame race. Toggling
//    the siblings badge flips _showSiblings, which changes
//    _GraphViewHost's key WITHIN one setState — Flutter mounts the NEW
//    instance (calling the callback with the new controller) before the
//    OLD instance's dispose() runs (calling the same callback with null).
//    The null write landed second, clobbering the new instance's
//    still-valid controller — so _graphController silently went null with
//    a perfectly healthy GraphView still on screen, breaking the explicit
//    zoom/reset buttons with no exception to signal it. Fixed by splitting
//    into onControllerCreated/onControllerDisposed, where the disposal
//    side only clears _graphController if it's still (identical to) the
//    controller being disposed.
//
// These tests drive all four trigger mechanisms directly rather than just
// re-testing earlier fixes' specific triggers, since #3 and #4 are both
// proof that "the previous fix's own tests passed" did not mean the bug
// class (or even the same file's other bugs) was fully closed.

import 'package:flutter/material.dart';
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

FamilyMember _member({
  required String id,
  String? fatherId,
  String? motherId,
  String gender = 'Male',
  String firstName = 'Test',
}) {
  return FamilyMember(
    id: id,
    createdAt: DateTime(2020, 1, 1),
    fatherId: fatherId,
    motherId: motherId,
    firstNameEn: firstName,
    lastNameEn: 'Person',
    gender: gender,
  );
}

/// Sets up a multi-node family (parents + focus + 2 children — deliberately
/// more than the single-node bypass covers) and pumps FamilyTreeScreen.
/// Returns the providers so a test can drive further state changes.
Future<
    ({
      FamilyProvider familyProvider,
      SettingsProvider settingsProvider,
      FamilyMember focus,
    })> _pumpTreeScreen(WidgetTester tester) async {
  final focus = _member(id: 'focus', gender: 'Male');
  final father = _member(id: 'father', gender: 'Male');
  final mother = _member(id: 'mother', gender: 'Female');
  final child1 = _member(id: 'child1', fatherId: 'focus', gender: 'Female');
  final child2 = _member(id: 'child2', fatherId: 'focus', gender: 'Male');
  focus.fatherId = 'father';
  focus.motherId = 'mother';

  final familyProvider = FamilyProvider();
  familyProvider.debugSetNetworkForTesting(
    egoNetwork: [focus, father, mother, child1, child2],
    spouseLinks: const [],
    centerMember: focus,
  );

  final authProvider = AuthProvider.forTesting(currentMember: focus);
  final settingsProvider = SettingsProvider.forTesting();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<FamilyProvider>.value(value: familyProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider),
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
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  return (
    familyProvider: familyProvider,
    settingsProvider: settingsProvider,
    focus: focus,
  );
}

void main() {
  testWidgets(
    'FamilyTreeScreen survives an incidental rebuild triggered by an '
    'unrelated provider (regression test for crash #1)',
    (WidgetTester tester) async {
      final ctx = await _pumpTreeScreen(tester);

      // Trigger several rebuilds that have nothing to do with family data —
      // this is what the app-resume scenario looked like: FamilyTreeScreen
      // rebuilds (because it context.watch()es SettingsProvider too) while
      // egoNetwork/spouseLinks are completely untouched.
      for (var i = 0; i < 5; i++) {
        ctx.settingsProvider.debugNotifyForTesting();
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Incidental rebuild #$i threw an exception',
        );
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FamilyTreeScreen survives being unmounted entirely '
    '(regression test for crash #2 — dispose-order double-dispose)',
    (WidgetTester tester) async {
      await _pumpTreeScreen(tester);

      // Unmount FamilyTreeScreen entirely — this is exactly what crash #2's
      // fix (widget test) covered. Kept here so the whole bug class has one
      // file of regression coverage. (Not "leaving and returning": this
      // only tears down, it never remounts — a fresh remount just gets a
      // brand-new State, nothing to reuse, so there's nothing extra to
      // prove there.)
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FamilyTreeScreen survives repeated loading-state swaps while mounted '
    '(regression test for crash #3 — the actual on-device trigger)',
    (WidgetTester tester) async {
      final ctx = await _pumpTreeScreen(tester);

      // This is what a re-center or the refresh button actually does:
      // isLoading flips true (swapping the whole Column/Stack/GraphView out
      // for AppWidgets.loading — unmounting the default view's GraphView
      // entirely) then false again (remounting it), while centerMember and
      // the tree shape stay exactly the same. Crash #2's fix did not cover
      // this — the GraphView.builder key doesn't change here, so the old
      // (pre-_GraphViewHost) code kept reusing the same, by-then-disposed
      // TransformationController on remount.
      for (var i = 0; i < 4; i++) {
        ctx.familyProvider.debugSetNetworkForTesting(
          egoNetwork: ctx.familyProvider.egoNetwork,
          spouseLinks: ctx.familyProvider.spouseLinks,
          centerMember: ctx.focus,
          isLoading: true,
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Loading-state swap #$i (loading=true) threw');

        ctx.familyProvider.debugSetNetworkForTesting(
          egoNetwork: ctx.familyProvider.egoNetwork,
          spouseLinks: ctx.familyProvider.spouseLinks,
          centerMember: ctx.focus,
          isLoading: false,
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Loading-state swap #$i (loading=false) threw');
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FamilyTreeScreen survives switching between Family and Pedigree view '
    'repeatedly (regression test for crash #3 — another unmount path)',
    (WidgetTester tester) async {
      await _pumpTreeScreen(tester);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Pedigree'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Switch to Pedigree view #$i threw');

        await tester.tap(find.text('Family'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Switch back to Family view #$i threw');
      }
    },
  );

  testWidgets(
    'FamilyTreeScreen zoom buttons work after a loading-state swap '
    '(the new controller must actually be wired up, not just non-null)',
    (WidgetTester tester) async {
      final ctx = await _pumpTreeScreen(tester);

      // Force an unmount+remount of the default view's GraphView.
      ctx.familyProvider.debugSetNetworkForTesting(
        egoNetwork: ctx.familyProvider.egoNetwork,
        spouseLinks: ctx.familyProvider.spouseLinks,
        centerMember: ctx.focus,
        isLoading: true,
      );
      await tester.pump();
      ctx.familyProvider.debugSetNetworkForTesting(
        egoNetwork: ctx.familyProvider.egoNetwork,
        spouseLinks: ctx.familyProvider.spouseLinks,
        centerMember: ctx.focus,
        isLoading: false,
      );
      await tester.pumpAndSettle();

      // Zoom in — must actually change the transform, not just avoid
      // throwing. A silently-nulled controller (see finding #4 above)
      // makes _zoomBy's `if (controller == null) return;` guard a no-op
      // that would pass a takeException()-only check while doing nothing.
      final scaleBefore = _currentScale(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_currentScale(tester), greaterThan(scaleBefore),
          reason: 'Zoom-in should increase scale; a silently-null '
              '_graphController would leave it unchanged with no exception');
    },
  );

  testWidgets(
    'FamilyTreeScreen zoom buttons still work after tapping the siblings '
    'badge (regression test for finding #4 — the onControllerCreated/'
    'onControllerDisposed same-frame race)',
    (WidgetTester tester) async {
      // Needs a sibling (and a parents unit) so the siblings badge — the
      // '+N' node that flips _showSiblings on tap — actually renders.
      final focus =
          _member(id: 'focus', fatherId: 'father', motherId: 'mother');
      final father = _member(id: 'father', gender: 'Male');
      final mother = _member(id: 'mother', gender: 'Female');
      final sibling = _member(
        id: 'sibling',
        fatherId: 'father',
        motherId: 'mother',
        gender: 'Female',
      );

      final familyProvider = FamilyProvider();
      familyProvider.debugSetNetworkForTesting(
        egoNetwork: [focus, father, mother, sibling],
        spouseLinks: const [],
        centerMember: focus,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(
                value: AuthProvider.forTesting(currentMember: focus)),
            ChangeNotifierProvider<FamilyProvider>.value(
                value: familyProvider),
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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tap the siblings badge ('+1') — flips _showSiblings, changing
      // _GraphViewHost's key within the same setState. This is the exact
      // same-frame mount-new-then-dispose-old sequence the race depended
      // on.
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final scaleBefore = _currentScale(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_currentScale(tester), greaterThan(scaleBefore),
          reason: 'Zoom-in after toggling the siblings badge should still '
              'work — a stale-null _graphController (finding #4) would '
              'leave the scale unchanged with no exception thrown');
    },
  );

  testWidgets(
    'FamilyTreeScreen builds its GraphView with animation disabled '
    '(regression test for the re-center "tree rebuilds and nodes fly '
    'around" jank reported live on-device)',
    (WidgetTester tester) async {
      await _pumpTreeScreen(tester);

      // _GraphViewHost fully remounts on every re-center tap (a new key —
      // see its class doc comment), and graphview's default (animated:
      // true) replays a per-node "fly in from parent position" animation
      // every time its RenderObject is freshly created — i.e. every single
      // tap, not just the first load. graphview's own hitTestChildren also
      // ignores taps while that animation is running, compounding the
      // sluggish feel. Must stay explicitly disabled.
      final graphView = tester.widget<GraphView>(find.byType(GraphView));
      expect(
        graphView.animated,
        isFalse,
        reason: 'GraphView.animated defaults to true — without explicitly '
            'setting it false in _GraphViewHost, every re-center tap would '
            'replay a fly-in animation for every node and briefly swallow '
            'taps, instead of re-centering instantly.',
      );
    },
  );

  testWidgets(
    'Pedigree view shows grandparents/great-grandparents once the ancestor '
    'chain has loaded, not just the one generation of parents in '
    'egoNetwork (regression test for a real reported bug: the pedigree '
    'view silently dead-ended after "father" because egoNetwork never '
    'contains grandparents — see get_ego_network, migration 003)',
    (WidgetTester tester) async {
      final ctx = await _pumpTreeScreen(tester);

      // _pumpTreeScreen's egoNetwork is exactly what get_ego_network
      // actually returns in production: focus + its direct father/mother +
      // children — no grandparents at all. Simulate the deeper fetch
      // (loadAncestorChain / get_ancestor_chain, migration 005) resolving
      // with further generations, via the same fixture id ('father') the
      // focus member's fatherId already points at.
      final father =
          _member(id: 'father', firstName: 'Dad', fatherId: 'grandfather');
      final grandfather = _member(
        id: 'grandfather',
        firstName: 'Grandpa',
        fatherId: 'great-grandfather',
      );
      final greatGrandfather =
          _member(id: 'great-grandfather', firstName: 'Ancestor');

      ctx.familyProvider.debugSetAncestorChainForTesting(
        ancestorChain: [ctx.focus, father, grandfather, greatGrandfather],
        forId: ctx.focus.id,
      );

      await tester.tap(find.text('Pedigree'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.text('Grandpa Person'),
        findsOneWidget,
        reason: 'The pedigree pool should come from ancestorChain (already '
            "loaded for this focus, per the test's debug seam), which "
            'includes the grandfather — egoNetwork alone never would.',
      );
      expect(find.text('Ancestor Person'), findsOneWidget);
    },
  );

  testWidgets(
    'FamilyTreeScreen renders a long-named, unclaimed, focused member '
    'without a RenderFlex overflow (regression test for a real overflow '
    'reported live on-device: a visual refresh added a 44px avatar circle '
    "to _PersonBox, pushing a 2-line name + the 'unclaimed' chip past the "
    "box's fixed height — worst case on a focused node, whose thicker "
    'border leaves even less content room)',
    (WidgetTester tester) async {
      // Single node, no father/mother/children/spouse — takes the
      // single-node bypass in _buildDefaultView straight to _UnitWidget /
      // _PersonBox, without needing graphview at all. Long enough name to
      // wrap to 2 lines in _PersonBox's ~108-116px content width; authUserId
      // left unset so isClaimed is false, showing the 'unclaimed' chip that
      // adds further vertical content.
      final focus = FamilyMember(
        id: 'focus',
        createdAt: DateTime(2020, 1, 1),
        firstNameEn: 'Priyankabahen Chandulal',
        lastNameEn: 'Makwana',
        gender: 'Female',
      );

      final familyProvider = FamilyProvider();
      familyProvider.debugSetNetworkForTesting(
        egoNetwork: [focus],
        centerMember: focus,
      );
      final authProvider = AuthProvider.forTesting(currentMember: focus);
      final settingsProvider = SettingsProvider.forTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<FamilyProvider>.value(
                value: familyProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('gu')],
            // Force a larger text scale rather than relying on exact font
            // metrics matching a real device — GoogleFonts commonly falls
            // back to a different font in the widget-test environment (no
            // network fetch), which renders this same long name at a
            // different width/line-height than on-device and can mask this
            // overflow entirely. A larger scale reproduces the same "text
            // takes more vertical room than the fixed-height box budgeted
            // for" condition deterministically, regardless of which font
            // actually rendered — and is also a real, legitimate case on
            // its own (a user with a larger system font-size setting).
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const FamilyTreeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

double _currentScale(WidgetTester tester) {
  final viewer =
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);
  return viewer.transformationController!.value.getMaxScaleOnAxis();
}
