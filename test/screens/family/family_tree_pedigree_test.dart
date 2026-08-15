// Tests for the Pedigree view's pure data-building functions
// (lib/screens/family/family_tree_screen.dart): buildPedigreeAhnentafel,
// pedigreeGeneration, pedigreeSlot.
//
// This replaces the old buildPedigreeChain (a single-line, one-parent-per-
// generation chain with a Paternal/Maternal toggle) after a real reported
// bug: it resolved ancestor ids against a pool that only ever had ONE
// generation of parents in production (get_ego_network's scope), and — even
// once that was fixed with a deeper fetch — only ever showed one line of
// ancestors at a time, and the connector line between generations visually
// landed between a person and their spouse rather than on a specific
// parent/child, since every row was a couple-unit.
//
// buildPedigreeAhnentafel instead builds the standard ahnentafel
// (Sosa-Stradonitz) numbering used by real pedigree charts: index 1 is the
// focus member, index 2n is the father of index n, index 2n+1 is the
// mother of index n — both parents at every generation, each person their
// own entry (no couple merging).

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';

FamilyMember _member({
  required String id,
  String? fatherId,
  String? motherId,
  String gender = 'Male',
}) {
  return FamilyMember(
    id: id,
    createdAt: DateTime(2020, 1, 1),
    fatherId: fatherId,
    motherId: motherId,
    firstNameEn: id,
    lastNameEn: 'Person',
    gender: gender,
  );
}

void main() {
  group('pedigreeGeneration / pedigreeSlot — pure ahnentafel index math', () {
    test('known index -> (generation, slot) table', () {
      final table = <int, (int, int)>{
        1: (0, 0), // focus
        2: (1, 0), // father
        3: (1, 1), // mother
        4: (2, 0), // paternal grandfather
        5: (2, 1), // paternal grandmother
        6: (2, 2), // maternal grandfather
        7: (2, 3), // maternal grandmother
        8: (3, 0),
        15: (3, 7),
        16: (4, 0),
      };
      for (final entry in table.entries) {
        expect(pedigreeGeneration(entry.key), entry.value.$1,
            reason: 'generation of index ${entry.key}');
        expect(pedigreeSlot(entry.key), entry.value.$2,
            reason: 'slot of index ${entry.key}');
      }
    });
  });

  group('buildPedigreeAhnentafel — normal cases', () {
    test('a focus member with no recorded parents yields just {1: focus}',
        () {
      final focus = _member(id: 'focus');
      final result =
          buildPedigreeAhnentafel(focus: focus, pool: [focus]);
      expect(result.keys.toSet(), {1});
      expect(result[1], focus);
    });

    test('father only -> index 2, no index 3', () {
      final father = _member(id: 'father');
      final focus = _member(id: 'focus', fatherId: 'father');
      final result = buildPedigreeAhnentafel(
        focus: focus,
        pool: [focus, father],
      );
      expect(result.keys.toSet(), {1, 2});
      expect(result[2], father);
    });

    test('mother only -> index 3, no index 2', () {
      final mother = _member(id: 'mother');
      final focus = _member(id: 'focus', motherId: 'mother');
      final result = buildPedigreeAhnentafel(
        focus: focus,
        pool: [focus, mother],
      );
      expect(result.keys.toSet(), {1, 3});
      expect(result[3], mother);
    });

    test('both parents -> indices 2 and 3, both correctly resolved', () {
      final father = _member(id: 'father');
      final mother = _member(id: 'mother');
      final focus =
          _member(id: 'focus', fatherId: 'father', motherId: 'mother');
      final result = buildPedigreeAhnentafel(
        focus: focus,
        pool: [focus, father, mother],
      );
      expect(result.keys.toSet(), {1, 2, 3});
      expect(result[2], father);
      expect(result[3], mother);
    });

    test(
      'full 3-generation tree (focus, 2 parents, 4 grandparents) resolves '
      'every index correctly — this is the exact real bug: both sides must '
      'be present, not just the paternal line',
      () {
        final pgf = _member(id: 'pgf'); // paternal grandfather
        final pgm = _member(id: 'pgm'); // paternal grandmother
        final mgf = _member(id: 'mgf'); // maternal grandfather
        final mgm = _member(id: 'mgm'); // maternal grandmother
        final father =
            _member(id: 'father', fatherId: 'pgf', motherId: 'pgm');
        final mother =
            _member(id: 'mother', fatherId: 'mgf', motherId: 'mgm');
        final focus =
            _member(id: 'focus', fatherId: 'father', motherId: 'mother');
        final pool = [focus, father, mother, pgf, pgm, mgf, mgm];

        final result = buildPedigreeAhnentafel(focus: focus, pool: pool);

        expect(result.keys.toSet(), {1, 2, 3, 4, 5, 6, 7});
        expect(result[1], focus);
        expect(result[2], father);
        expect(result[3], mother);
        expect(result[4], pgf);
        expect(result[5], pgm);
        expect(result[6], mgf);
        expect(result[7], mgm);
      },
    );

    test(
      'a branch with missing data terminates cleanly without affecting '
      'other branches (grandfather has no recorded father, but the '
      'grandmother side is untouched)',
      () {
        final father = _member(id: 'father', fatherId: 'gf', motherId: 'gm');
        final gf = _member(id: 'gf'); // no fatherId/motherId recorded
        final gm = _member(id: 'gm', fatherId: 'ggf');
        final ggf = _member(id: 'ggf');
        final focus = _member(id: 'focus', fatherId: 'father');
        final pool = [focus, father, gf, gm, ggf];

        final result = buildPedigreeAhnentafel(focus: focus, pool: pool);

        expect(result.keys.toSet(), {1, 2, 4, 5, 10});
        expect(result[10], ggf); // gm (index 5) -> father is index 10
      },
    );

    test(
      'chain terminates cleanly when the next id is not present in the '
      'pool at all (e.g. not yet loaded)',
      () {
        final father = _member(id: 'father', fatherId: 'not-loaded');
        final focus = _member(id: 'focus', fatherId: 'father');
        final result = buildPedigreeAhnentafel(
          focus: focus,
          pool: [focus, father], // 'not-loaded' intentionally absent
        );
        expect(result.keys.toSet(), {1, 2});
      },
    );

    test('maxGenerations bounds how far the chain is walked even when the '
        'data continues further', () {
      final ggf = _member(id: 'ggf'); // would be index 8, generation 3
      final gf = _member(id: 'gf', fatherId: 'ggf');
      final father = _member(id: 'father', fatherId: 'gf');
      final focus = _member(id: 'focus', fatherId: 'father');
      final pool = [focus, father, gf, ggf];

      final result = buildPedigreeAhnentafel(
        focus: focus,
        pool: pool,
        maxGenerations: 2, // focus, parents, grandparents — no further
      );

      expect(result.keys.toSet(), {1, 2, 4});
      expect(result.containsKey(8), isFalse);
    });
  });

  group('buildPedigreeAhnentafel — cycle safety', () {
    test(
      'a father_id cycle does not hang — the walk is bounded by a fixed '
      'generation count (a for loop), not an unbounded chain walk, so this '
      'is safe by construction, unlike the old linear-chain approach it '
      'replaced',
      () {
        // self-ref: a member whose own father_id points at themselves.
        final selfRef = _member(id: 'self-ref', fatherId: 'self-ref');
        final focus = _member(id: 'focus', fatherId: 'self-ref');
        final pool = [focus, selfRef];

        Map<int, FamilyMember>? result;
        expect(
          () {
            result = buildPedigreeAhnentafel(focus: focus, pool: pool);
          },
          returnsNormally,
        );

        // The cycle just means 'self-ref' appears at more than one
        // ahnentafel index (real "pedigree collapse"), not a crash/hang.
        expect(result![2], selfRef);
        expect(result![4], selfRef);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'a 2-node cycle (father <-> grandfather pointing at each other) '
      'terminates at maxGenerations, not earlier or later than expected',
      () {
        final a = _member(id: 'a', fatherId: 'b');
        final b = _member(id: 'b', fatherId: 'a');
        final focus = _member(id: 'focus', fatherId: 'a');
        final pool = [focus, a, b];

        final result = buildPedigreeAhnentafel(
          focus: focus,
          pool: pool,
          maxGenerations: 4,
        );

        // focus(1) -> a(2) -> b(4) -> a(8) -> b(16, beyond maxGenerations=4
        // from focus, i.e. generation 4 is the last one walked) — index 16
        // is generation 4, which IS included (maxGenerations counts rounds
        // walked, producing generations 1..maxGenerations).
        expect(result[2], a);
        expect(result[4], b);
        expect(result[8], a);
        expect(result[16], b);
        expect(result.containsKey(32), isFalse);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });
}
