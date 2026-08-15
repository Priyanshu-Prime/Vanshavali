// Tests for the pure relation-guard helpers extracted from
// AddFamilyMemberScreen (lib/screens/family/add_family_member_screen.dart)
// into top-level, testable functions:
//   - blockedOneToOneRelation  (father/mother cardinality guard)
//   - isSpouseAlreadyLinked    (spouse duplicate-pair guard, remarriage-safe)
//   - childrenNeedingOtherParent (spouse-add children-linking prompt condition)
//   - wouldCreateAncestryCycle (father/mother "link existing" cycle guard)
//
// These were inline logic inside the async _saveMember() method; extracting
// them lets the cardinality/duplicate/empty-slot rules be verified without a
// live Supabase connection or a widget tree.

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/add_family_member_screen.dart';

FamilyMember _member({
  required String id,
  String? fatherId,
  String? motherId,
  String gender = 'Male',
  String firstName = 'Test',
  String lastName = 'Person',
}) {
  return FamilyMember(
    id: id,
    createdAt: DateTime(2020, 1, 1),
    fatherId: fatherId,
    motherId: motherId,
    firstNameEn: firstName,
    lastNameEn: lastName,
    gender: gender,
  );
}

void main() {
  group('blockedOneToOneRelation (father/mother cardinality guard)', () {
    test('allows adding a father when fatherId is null', () {
      final member = _member(id: 'm1');
      expect(blockedOneToOneRelation('father', member), isNull);
    });

    test('blocks adding a second father when fatherId is already set', () {
      final member = _member(id: 'm1', fatherId: 'existing-father');
      expect(blockedOneToOneRelation('father', member), 'father');
    });

    test('allows adding a mother when motherId is null', () {
      final member = _member(id: 'm1');
      expect(blockedOneToOneRelation('mother', member), isNull);
    });

    test('blocks adding a second mother when motherId is already set', () {
      final member = _member(id: 'm1', motherId: 'existing-mother');
      expect(blockedOneToOneRelation('mother', member), 'mother');
    });

    test('does not block "child" even with father/mother already set '
        '(child is multi-entry, not covered by this guard)', () {
      final member = _member(
        id: 'm1',
        fatherId: 'f1',
        motherId: 'mo1',
      );
      expect(blockedOneToOneRelation('child', member), isNull);
    });

    test('does not block "sibling" even with father/mother already set '
        '(sibling is multi-entry / derived, not covered by this guard)', () {
      final member = _member(
        id: 'm1',
        fatherId: 'f1',
        motherId: 'mo1',
      );
      expect(blockedOneToOneRelation('sibling', member), isNull);
    });

    test('does not block "spouse" — spouse has its own multi-entry guard '
        '(isSpouseAlreadyLinked), never a cardinality guard', () {
      final member = _member(id: 'm1', fatherId: 'f1', motherId: 'mo1');
      expect(blockedOneToOneRelation('spouse', member), isNull);
    });

    test(
      'an unrecognized relation string is never blocked, even when both '
      'father and mother are already set — guards only fire for their own '
      "exact relation name, not as a catch-all for \"anything is set\"",
      () {
        final member = _member(id: 'm1', fatherId: 'f1', motherId: 'mo1');
        expect(blockedOneToOneRelation('', member), isNull);
        expect(blockedOneToOneRelation('grandfather', member), isNull);
      },
    );

    test(
      'when BOTH father and mother are already set, checking "mother" '
      'blocks specifically on \'mother\' (not \'father\', and not null) — '
      'the two branches are independent, not a single "any relation set" '
      'check',
      () {
        final member = _member(id: 'm1', fatherId: 'f1', motherId: 'mo1');
        expect(blockedOneToOneRelation('mother', member), 'mother');
        expect(blockedOneToOneRelation('father', member), 'father');
      },
    );
  });

  group('isSpouseAlreadyLinked (spouse duplicate-pair guard, remarriage)', () {
    test('returns false when the member currently has no spouses', () {
      expect(isSpouseAlreadyLinked([], 'candidate'), isFalse);
    });

    test('blocks re-adding a person who is ALREADY linked as a spouse', () {
      final currentSpouses = [_member(id: 'spouse-1', gender: 'Female')];
      expect(isSpouseAlreadyLinked(currentSpouses, 'spouse-1'), isTrue);
    });

    test(
      'allows adding a genuinely different second spouse (remarriage) even '
      'when a first spouse already exists',
      () {
        final currentSpouses = [_member(id: 'spouse-1', gender: 'Female')];
        expect(isSpouseAlreadyLinked(currentSpouses, 'spouse-2'), isFalse);
      },
    );

    test('handles multiple existing spouses, blocking only an exact repeat',
        () {
      final currentSpouses = [
        _member(id: 'spouse-1', gender: 'Female'),
        _member(id: 'spouse-2', gender: 'Female'),
      ];
      expect(isSpouseAlreadyLinked(currentSpouses, 'spouse-2'), isTrue);
      expect(isSpouseAlreadyLinked(currentSpouses, 'spouse-3'), isFalse);
    });
  });

  group('childrenNeedingOtherParent (spouse-add children-linking prompt)', () {
    test(
      'offers a child whose other-parent slot (fatherId) is empty when the '
      'new spouse is a father figure',
      () {
        final parentId = 'mother-1';
        final child = _member(id: 'child-1', motherId: parentId);
        final result = childrenNeedingOtherParent(
          egoNetwork: [child],
          parentId: parentId,
          isSpouseFather: true,
        );
        expect(result, [child]);
      },
    );

    test(
      'does NOT offer a child whose fatherId is already assigned — must '
      'never overwrite an existing biological-parent link (remarriage case)',
      () {
        final parentId = 'mother-1';
        final child = _member(
          id: 'child-1',
          motherId: parentId,
          fatherId: 'first-husband',
        );
        final result = childrenNeedingOtherParent(
          egoNetwork: [child],
          parentId: parentId,
          isSpouseFather: true,
        );
        expect(result, isEmpty);
      },
    );

    test(
      'offers a child whose other-parent slot (motherId) is empty when the '
      'new spouse is a mother figure',
      () {
        final parentId = 'father-1';
        final child = _member(id: 'child-1', fatherId: parentId);
        final result = childrenNeedingOtherParent(
          egoNetwork: [child],
          parentId: parentId,
          isSpouseFather: false,
        );
        expect(result, [child]);
      },
    );

    test(
      'does NOT offer a child whose motherId is already assigned '
      '(second-marriage case, mother-figure spouse)',
      () {
        final parentId = 'father-1';
        final child = _member(
          id: 'child-1',
          fatherId: parentId,
          motherId: 'first-wife',
        );
        final result = childrenNeedingOtherParent(
          egoNetwork: [child],
          parentId: parentId,
          isSpouseFather: false,
        );
        expect(result, isEmpty);
      },
    );

    test('ignores members who are not children of parentId', () {
      final result = childrenNeedingOtherParent(
        egoNetwork: [
          _member(id: 'unrelated-1'),
          _member(id: 'unrelated-2', fatherId: 'someone-else'),
        ],
        parentId: 'parent-1',
        isSpouseFather: true,
      );
      expect(result, isEmpty);
    });

    test(
      'remarriage regression case: second spouse added to a parent whose '
      'children from the first marriage already have both parents assigned '
      '— none of those children should be offered',
      () {
        final parentId = 'parent-1';
        final childrenFromFirstMarriage = [
          _member(
            id: 'child-a',
            fatherId: parentId,
            motherId: 'first-spouse',
          ),
          _member(
            id: 'child-b',
            fatherId: parentId,
            motherId: 'first-spouse',
          ),
        ];
        final result = childrenNeedingOtherParent(
          egoNetwork: childrenFromFirstMarriage,
          parentId: parentId,
          // A second wife is being added (mother-figure slot).
          isSpouseFather: false,
        );
        expect(result, isEmpty);
      },
    );

    test(
      'mixed case: only children with the empty slot are offered, siblings '
      'with the slot already filled are excluded',
      () {
        final parentId = 'parent-1';
        final needsFather = _member(id: 'child-needs-father', motherId: parentId);
        final alreadyHasFather = _member(
          id: 'child-has-father',
          motherId: parentId,
          fatherId: 'someone',
        );
        final result = childrenNeedingOtherParent(
          egoNetwork: [needsFather, alreadyHasFather],
          parentId: parentId,
          isSpouseFather: true,
        );
        expect(result.map((c) => c.id), [needsFather.id]);
      },
    );

    test('an empty ego network returns an empty list (no crash on a '
        'freshly-loaded/empty network)', () {
      final result = childrenNeedingOtherParent(
        egoNetwork: const [],
        parentId: 'parent-1',
        isSpouseFather: true,
      );
      expect(result, isEmpty);
    });
  });

  group('wouldCreateAncestryCycle (father/mother "link existing" cycle guard)', () {
    Future<FamilyMember?> Function(String) resolverFor(List<FamilyMember> pool) {
      return (id) async => pool.where((m) => m.id == id).firstOrNull;
    }

    test('blocks setting someone as their own father/mother (self-reference)', () async {
      final pool = [_member(id: 'a')];
      final result = await wouldCreateAncestryCycle(
        targetId: 'a',
        candidateId: 'a',
        resolve: resolverFor(pool),
      );
      expect(result, isTrue);
    });

    test('allows linking a completely unrelated existing member', () async {
      final pool = [_member(id: 'a'), _member(id: 'b')];
      final result = await wouldCreateAncestryCycle(
        targetId: 'a',
        candidateId: 'b',
        resolve: resolverFor(pool),
      );
      expect(result, isFalse);
    });

    test('blocks picking your own child as your father (direct cycle)', () async {
      // child.fatherId == target.id — setting target.fatherId = child would
      // create target -> child -> target.
      final pool = [
        _member(id: 'target'),
        _member(id: 'child', fatherId: 'target'),
      ];
      final result = await wouldCreateAncestryCycle(
        targetId: 'target',
        candidateId: 'child',
        resolve: resolverFor(pool),
      );
      expect(result, isTrue);
    });

    test('blocks picking a grandchild as your mother (multi-generation cycle)', () async {
      final pool = [
        _member(id: 'target'),
        _member(id: 'child', fatherId: 'target'),
        _member(id: 'grandchild', fatherId: 'child'),
      ];
      final result = await wouldCreateAncestryCycle(
        targetId: 'target',
        candidateId: 'grandchild',
        resolve: resolverFor(pool),
      );
      expect(result, isTrue);
    });

    test('detects a cycle reachable only through the maternal branch', () async {
      final pool = [
        _member(id: 'target'),
        _member(id: 'child', motherId: 'target'),
      ];
      final result = await wouldCreateAncestryCycle(
        targetId: 'target',
        candidateId: 'child',
        resolve: resolverFor(pool),
      );
      expect(result, isTrue);
    });

    test('allows a sibling of a descendant (shares a parent, but is not '
        'itself in the descendant line)', () async {
      final pool = [
        _member(id: 'target'),
        _member(id: 'child', fatherId: 'target'),
        _member(id: 'child-sibling', fatherId: 'target'), // sibling of child, not a descendant of child
      ];
      final result = await wouldCreateAncestryCycle(
        targetId: 'child',
        candidateId: 'child-sibling',
        resolve: resolverFor(pool),
      );
      expect(result, isFalse);
    });

    test('terminates cleanly when the candidate\'s ancestor chain hits a '
        'dead end (no cycle)', () async {
      final pool = [
        _member(id: 'target'),
        _member(id: 'candidate', fatherId: 'unrelated-ancestor'),
        _member(id: 'unrelated-ancestor'), // no further father/mother
      ];
      final result = await wouldCreateAncestryCycle(
        targetId: 'target',
        candidateId: 'candidate',
        resolve: resolverFor(pool),
      );
      expect(result, isFalse);
    });

    test('does not hang on a pre-existing cycle in unrelated data (maxVisited '
        'bound terminates it, and correctly returns false since target is '
        'never actually reached)', () async {
      // a <-> b is already a bad-data cycle unrelated to target — confirms
      // the visited-set prevents infinite looping on data that predates
      // this guard.
      final pool = [
        _member(id: 'target'),
        _member(id: 'a', fatherId: 'b'),
        _member(id: 'b', fatherId: 'a'),
      ];
      final result = await wouldCreateAncestryCycle(
        targetId: 'target',
        candidateId: 'a',
        resolve: resolverFor(pool),
        maxVisited: 10,
      );
      expect(result, isFalse);
    });

    test('handles a resolver that returns null for a missing id without throwing', () async {
      final pool = [_member(id: 'target')];
      final result = await wouldCreateAncestryCycle(
        targetId: 'target',
        candidateId: 'does-not-exist',
        resolve: resolverFor(pool),
      );
      expect(result, isFalse);
    });
  });
}
