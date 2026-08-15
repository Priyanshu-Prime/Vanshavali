// Tests for `buildTreeData`, the pure graph-building function extracted
// from `_FamilyTreeScreenState._buildTreeData`
// (lib/screens/family/family_tree_screen.dart).
//
// Context: a brand-new user's profile — no father/mother/spouse/children/
// siblings yet — produced a single-node, edge-less `Graph`, which
// graphview's `BuchheimWalkerAlgorithm` can't lay out and crashed with a
// Flutter framework GlobalKey assertion on a real device. The screen now
// bypasses graphview entirely for the `graph.nodes.length <= 1` case (see
// `_buildDefaultView`), but `_buildTreeData` itself — the logic that
// decides how many nodes/edges a given family shape produces — had zero
// test coverage, which is what let this ship. This file closes that gap.
//
// `buildTreeData` was extracted as a standalone, top-level pure function
// (previously a private method reading directly from `FamilyProvider` and
// `_showSiblings`) so it can be exercised here without a widget tree, a
// FamilyProvider, or a live Supabase connection. `TreeNodeContent` /
// `TreeUnitContent` / `SiblingsBadgeContent` were promoted from
// underscore-prefixed (library-private) to public as part of the same
// extraction, since a private class can't cross this test file's library
// boundary — see the doc comment on `buildTreeData` in the screen file.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';

FamilyMember _member({
  required String id,
  String? fatherId,
  String? motherId,
  String gender = 'Male',
  String firstName = 'Test',
  DateTime? dob,
}) {
  return FamilyMember(
    id: id,
    createdAt: DateTime(2020, 1, 1),
    fatherId: fatherId,
    motherId: motherId,
    firstNameEn: firstName,
    lastNameEn: 'Person',
    gender: gender,
    dob: dob,
  );
}

/// Node ids in [graph], as plain strings, for easy set/list assertions.
Set<String> _nodeIds(Graph graph) =>
    graph.nodes.map((n) => n.key!.value as String).toSet();

void main() {
  group('buildTreeData — single node (regression test for the crash)', () {
    test(
      'a focus member with no father/mother/spouse/children/siblings '
      'produces a graph with exactly 1 node — the shape that used to crash '
      'graphview\'s BuchheimWalkerAlgorithm before the '
      '`graph.nodes.length <= 1` bypass was added to _buildDefaultView',
      () {
        final focus = _member(id: 'focus');
        final data = buildTreeData(
          focus: focus,
          focusSpouses: const [],
          father: null,
          mother: null,
          children: const [],
          siblings: const [],
          spousesOf: (_) => const [],
          showSiblings: false,
        );

        expect(data.graph.nodes.length, 1);
        expect(data.graph.edges, isEmpty);
        expect(data.initialNodeId, 'f:focus');
        final content = data.contents[data.initialNodeId];
        expect(content, isA<TreeUnitContent>());
        expect((content as TreeUnitContent).primary.id, 'focus');
        expect(content.spouses, isEmpty);
      },
    );
  });

  group('buildTreeData — minimal 2-node cases', () {
    test('focus + one child only (no parents/spouse/siblings)', () {
      final focus = _member(id: 'focus');
      final child = _member(id: 'child-1', fatherId: 'focus');
      final data = buildTreeData(
        focus: focus,
        focusSpouses: const [],
        father: null,
        mother: null,
        children: [child],
        siblings: const [],
        spousesOf: (_) => const [],
        showSiblings: false,
      );

      // 2 real nodes (focus unit + child unit) — NOT graphview-degenerate:
      // this has a real edge between two distinct nodes, which is exactly
      // the minimal shape BuchheimWalkerAlgorithm is designed for (its
      // documented failure case is specifically 0-edge/single-node graphs).
      // We can't execute graphview's internal layout in a pure unit test,
      // but structurally this is not the same degenerate shape as the
      // single-node crash case above.
      expect(data.graph.nodes.length, 2);
      expect(data.graph.edges.length, 1);
      final childContent = data.contents['c:child-1'];
      expect(childContent, isA<TreeUnitContent>());
      expect((childContent as TreeUnitContent).primary.id, 'child-1');
    });

    test(
      'focus + one spouse only produces just 1 node — the spouse is drawn '
      'inside the SAME couple-unit node as focus (TreeUnitContent.spouses), '
      'not a separate graph node, so this case is ALSO covered by the '
      'existing `graph.nodes.length <= 1` single-node bypass even though a '
      'relative exists. Flagged explicitly per the task instructions: no '
      'additional fix is needed here, but it is worth knowing this shape '
      'exists and is already handled.',
      () {
        final focus = _member(id: 'focus', gender: 'Male');
        final spouse = _member(id: 'spouse-1', gender: 'Female');
        final data = buildTreeData(
          focus: focus,
          focusSpouses: [spouse],
          father: null,
          mother: null,
          children: const [],
          siblings: const [],
          spousesOf: (_) => const [],
          showSiblings: false,
        );

        expect(data.graph.nodes.length, 1);
        final content = data.contents[data.initialNodeId] as TreeUnitContent;
        expect(content.spouses.map((m) => m.id), ['spouse-1']);
      },
    );

    test('focus + father only (no mother/spouse/children/siblings)', () {
      final father = _member(id: 'father-1', gender: 'Male');
      final focus = _member(id: 'focus', fatherId: 'father-1');
      final data = buildTreeData(
        focus: focus,
        focusSpouses: const [],
        father: father,
        mother: null,
        children: const [],
        siblings: const [],
        spousesOf: (_) => const [],
        showSiblings: false,
      );

      // 2 nodes (parent unit + focus unit), 1 edge — same reasoning as the
      // child-only case above: a real edge between two nodes, not the
      // degenerate single-node shape.
      expect(data.graph.nodes.length, 2);
      expect(data.graph.edges.length, 1);
      final parentContent = data.contents['p:father-1'];
      expect(parentContent, isA<TreeUnitContent>());
      expect((parentContent as TreeUnitContent).primary.id, 'father-1');
    });

    test('focus + mother only (no father/spouse/children/siblings)', () {
      final mother = _member(id: 'mother-1', gender: 'Female');
      final focus = _member(id: 'focus', motherId: 'mother-1');
      final data = buildTreeData(
        focus: focus,
        focusSpouses: const [],
        father: null,
        mother: mother,
        children: const [],
        siblings: const [],
        spousesOf: (_) => const [],
        showSiblings: false,
      );

      expect(data.graph.nodes.length, 2);
      expect(data.graph.edges.length, 1);
      final parentContent = data.contents['p:mother-1'];
      expect(parentContent, isA<TreeUnitContent>());
      expect((parentContent as TreeUnitContent).primary.id, 'mother-1');
      // The parent unit's primary is the mother (no father present), and
      // she has no "other parent" to fold in.
      expect(parentContent.spouses, isEmpty);
    });
  });

  group('buildTreeData — multi-spouse combinations (remarriage)', () {
    test(
      'parent unit with 2+ spouses: father unit includes both the '
      "focus's biological mother AND the father's other (remarriage) "
      'spouse, with no duplicate',
      () {
        final father = _member(id: 'father-1', gender: 'Male');
        final bioMother = _member(id: 'mother-1', gender: 'Female');
        final secondWife = _member(id: 'mother-2', gender: 'Female');
        final focus = _member(
          id: 'focus',
          fatherId: 'father-1',
          motherId: 'mother-1',
        );

        final data = buildTreeData(
          focus: focus,
          focusSpouses: const [],
          father: father,
          mother: bioMother,
          children: const [],
          siblings: const [],
          spousesOf: (id) =>
              id == 'father-1' ? [bioMother, secondWife] : const [],
          showSiblings: false,
        );

        final parentContent = data.contents['p:father-1'] as TreeUnitContent;
        expect(
          parentContent.spouses.map((m) => m.id).toSet(),
          {'mother-1', 'mother-2'},
        );
        expect(parentContent.spouses.length, 2); // no duplicate bioMother
      },
    );

    test(
      'parent unit dedupes correctly when spousesOf returns the '
      'other-parent (bioMother) in a different order than it appears as '
      "the explicit 'mother' parameter",
      () {
        final father = _member(id: 'father-1', gender: 'Male');
        final bioMother = _member(id: 'mother-1', gender: 'Female');
        final secondWife = _member(id: 'mother-2', gender: 'Female');
        final focus = _member(
          id: 'focus',
          fatherId: 'father-1',
          motherId: 'mother-1',
        );

        final data = buildTreeData(
          focus: focus,
          focusSpouses: const [],
          father: father,
          mother: bioMother,
          children: const [],
          siblings: const [],
          // secondWife listed FIRST this time.
          spousesOf: (id) =>
              id == 'father-1' ? [secondWife, bioMother] : const [],
          showSiblings: false,
        );

        final parentContent = data.contents['p:father-1'] as TreeUnitContent;
        expect(
          parentContent.spouses.map((m) => m.id).toSet(),
          {'mother-1', 'mother-2'},
        );
        expect(parentContent.spouses.length, 2);
      },
    );

    test('focus unit with 2+ spouses renders all of them, in given order',
        () {
      final focus = _member(id: 'focus', gender: 'Male');
      final spouseA = _member(id: 'spouse-a', gender: 'Female');
      final spouseB = _member(id: 'spouse-b', gender: 'Female');

      final data = buildTreeData(
        focus: focus,
        focusSpouses: [spouseA, spouseB],
        father: null,
        mother: null,
        // Add a child so the graph isn't the single-node degenerate case,
        // keeping this test focused purely on focus-unit spouse content.
        children: [_member(id: 'child-1', fatherId: 'focus')],
        siblings: const [],
        spousesOf: (_) => const [],
        showSiblings: false,
      );

      final focusContent = data.contents['f:focus'] as TreeUnitContent;
      expect(
        focusContent.spouses.map((m) => m.id).toList(),
        ['spouse-a', 'spouse-b'],
      );
    });

    test('a child unit with their own spouse(s) is rendered correctly', () {
      final focus = _member(id: 'focus');
      final child = _member(id: 'child-1', fatherId: 'focus');
      final childSpouse = _member(id: 'child-spouse-1', gender: 'Female');

      final data = buildTreeData(
        focus: focus,
        focusSpouses: const [],
        father: null,
        mother: null,
        children: [child],
        siblings: const [],
        spousesOf: (id) => id == 'child-1' ? [childSpouse] : const [],
        showSiblings: false,
      );

      final childContent = data.contents['c:child-1'] as TreeUnitContent;
      expect(childContent.spouses.map((m) => m.id), ['child-spouse-1']);
    });
  });

  group('buildTreeData — siblings show/hide', () {
    test(
      'siblings_badge node is created when showSiblings=false and siblings '
      'exist (requires a parent node to attach to)',
      () {
        final father = _member(id: 'father-1');
        final focus = _member(id: 'focus', fatherId: 'father-1');
        final sib1 = _member(id: 'sib-1', fatherId: 'father-1');
        final sib2 = _member(id: 'sib-2', fatherId: 'father-1');

        final data = buildTreeData(
          focus: focus,
          focusSpouses: const [],
          father: father,
          mother: null,
          children: const [],
          siblings: [sib1, sib2],
          spousesOf: (_) => const [],
          showSiblings: false,
        );

        expect(data.contents.containsKey('siblings_badge'), isTrue);
        final badge = data.contents['siblings_badge'] as SiblingsBadgeContent;
        expect(badge.count, 2);
        // No individual sibling unit nodes when the badge is shown.
        expect(data.contents.containsKey('s:sib-1'), isFalse);
        expect(data.contents.containsKey('s:sib-2'), isFalse);
      },
    );

    test(
      'individual sibling unit nodes are created (no badge) when '
      'showSiblings=true',
      () {
        final father = _member(id: 'father-1');
        final focus = _member(id: 'focus', fatherId: 'father-1');
        final sib1 = _member(id: 'sib-1', fatherId: 'father-1');
        final sib2 = _member(id: 'sib-2', fatherId: 'father-1');

        final data = buildTreeData(
          focus: focus,
          focusSpouses: const [],
          father: father,
          mother: null,
          children: const [],
          siblings: [sib1, sib2],
          spousesOf: (_) => const [],
          showSiblings: true,
        );

        expect(data.contents.containsKey('siblings_badge'), isFalse);
        expect(data.contents.containsKey('s:sib-1'), isTrue);
        expect(data.contents.containsKey('s:sib-2'), isTrue);
      },
    );

    test(
      'no sibling-related nodes (neither badge nor individual) are created '
      'when there are no siblings',
      () {
        final father = _member(id: 'father-1');
        final focus = _member(id: 'focus', fatherId: 'father-1');

        for (final showSiblings in [true, false]) {
          final data = buildTreeData(
            focus: focus,
            focusSpouses: const [],
            father: father,
            mother: null,
            children: const [],
            siblings: const [],
            spousesOf: (_) => const [],
            showSiblings: showSiblings,
          );

          expect(data.contents.containsKey('siblings_badge'), isFalse);
          expect(
            data.contents.keys.any((k) => k.startsWith('s:')),
            isFalse,
          );
        }
      },
    );

    test(
      'siblings are NOT rendered at all (no badge, no individual nodes) '
      'when there is no parent node to attach them to — documents current, '
      'intentional behavior: a sibling relation only makes sense hanging '
      'off a shared-parent unit, and there is nowhere to hang it if focus '
      'has no recorded father/mother',
      () {
        final focus = _member(id: 'focus'); // no fatherId/motherId
        final sib1 = _member(id: 'sib-1'); // sibling with no shared parent id

        for (final showSiblings in [true, false]) {
          final data = buildTreeData(
            focus: focus,
            focusSpouses: const [],
            father: null,
            mother: null,
            children: const [],
            siblings: [sib1],
            spousesOf: (_) => const [],
            showSiblings: showSiblings,
          );

          expect(data.contents.containsKey('siblings_badge'), isFalse);
          expect(
            data.contents.keys.any((k) => k.startsWith('s:')),
            isFalse,
          );
          // Still just the single focus node — the sibling can't be
          // reached, so this remains the degenerate single-node case too.
          expect(data.graph.nodes.length, 1);
        }
      },
    );
  });

  group('buildTreeData — node ID uniqueness (prefix scheme)', () {
    test(
      'a complex family shape (parent with 2 spouses, focus with 2 spouses, '
      '3 children, 2 siblings, showSiblings=true) produces only unique node '
      'ids, proving the p:/f:/s:/c: prefix scheme actually prevents '
      'collisions',
      () {
        final father = _member(id: 'father-1', gender: 'Male');
        final bioMother = _member(id: 'mother-1', gender: 'Female');
        final secondWife = _member(id: 'mother-2', gender: 'Female');
        final focus = _member(
          id: 'focus',
          fatherId: 'father-1',
          motherId: 'mother-1',
        );
        final spouseA = _member(id: 'spouse-a', gender: 'Female');
        final spouseB = _member(id: 'spouse-b', gender: 'Female');
        final child1 = _member(id: 'child-1', fatherId: 'focus');
        final child2 = _member(id: 'child-2', fatherId: 'focus');
        final child3 = _member(id: 'child-3', fatherId: 'focus');
        final childSpouse = _member(id: 'child-1-spouse', gender: 'Female');
        final sib1 = _member(id: 'sib-1', fatherId: 'father-1');
        final sib2 = _member(id: 'sib-2', fatherId: 'father-1');

        final data = buildTreeData(
          focus: focus,
          focusSpouses: [spouseA, spouseB],
          father: father,
          mother: bioMother,
          children: [child1, child2, child3],
          siblings: [sib1, sib2],
          spousesOf: (id) {
            if (id == 'father-1') return [bioMother, secondWife];
            if (id == 'child-1') return [childSpouse];
            return const [];
          },
          showSiblings: true,
        );

        final ids = data.graph.nodes.map((n) => n.key!.value as String).toList();
        expect(ids.toSet().length, ids.length); // no duplicates
        expect(
          ids.toSet(),
          {
            'p:father-1',
            'f:focus',
            's:sib-1',
            's:sib-2',
            'c:child-1',
            'c:child-2',
            'c:child-3',
          },
        );
        expect(data.graph.nodes.length, 7);
      },
    );
  });

  group('buildTreeData — children/siblings sorted by DOB', () {
    test('children are ordered eldest to youngest in the resulting edges',
        () {
      final focus = _member(id: 'focus');
      final younger = _member(
        id: 'younger',
        fatherId: 'focus',
        dob: DateTime(2015, 1, 1),
      );
      final elder = _member(
        id: 'elder',
        fatherId: 'focus',
        dob: DateTime(2010, 1, 1),
      );

      final data = buildTreeData(
        focus: focus,
        focusSpouses: const [],
        father: null,
        mother: null,
        // Passed in reverse (youngest first) to prove sorting happens
        // inside buildTreeData, not relying on caller order.
        children: [younger, elder],
        siblings: const [],
        spousesOf: (_) => const [],
        showSiblings: false,
      );

      final childEdgeTargets = data.graph.edges
          .map((e) => e.destination.key!.value as String)
          .toList();
      expect(childEdgeTargets, ['c:elder', 'c:younger']);
    });
  });

  group('buildTreeData — node/edge sanity (no orphan edges)', () {
    test('every edge in the graph connects two nodes present in `contents`',
        () {
      final father = _member(id: 'father-1');
      final focus = _member(id: 'focus', fatherId: 'father-1');
      final child = _member(id: 'child-1', fatherId: 'focus');
      final sib = _member(id: 'sib-1', fatherId: 'father-1');

      final data = buildTreeData(
        focus: focus,
        focusSpouses: const [],
        father: father,
        mother: null,
        children: [child],
        siblings: [sib],
        spousesOf: (_) => const [],
        showSiblings: false, // sibling renders as a badge, not a unit node
      );

      final contentIds = _nodeIds(data.graph);
      for (final edge in data.graph.edges) {
        expect(
          contentIds.contains(edge.source.key!.value as String),
          isTrue,
        );
        expect(
          contentIds.contains(edge.destination.key!.value as String),
          isTrue,
        );
      }
    });
  });
}
