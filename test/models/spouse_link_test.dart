import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';

void main() {
  group('SpouseLink', () {
    test('otherId returns spouseId when given memberId', () {
      const link = SpouseLink(memberId: 'a', spouseId: 'b');
      expect(link.otherId('a'), 'b');
    });

    test('otherId returns memberId when given spouseId', () {
      const link = SpouseLink(memberId: 'a', spouseId: 'b');
      expect(link.otherId('b'), 'a');
    });

    test(
      'otherId falls back to memberId when given an id unrelated to the link '
      '(matches the "==" branch semantics: only spouseId is returned when '
      'knownId == memberId, everything else returns memberId)',
      () {
        const link = SpouseLink(memberId: 'a', spouseId: 'b');
        expect(link.otherId('unrelated'), 'a');
      },
    );

    test('direction is arbitrary — a link works the same regardless of '
        'which id is stored as memberId vs spouseId', () {
      const link1 = SpouseLink(memberId: 'a', spouseId: 'b');
      const link2 = SpouseLink(memberId: 'b', spouseId: 'a');
      expect(link1.otherId('a'), link2.otherId('a'));
      expect(link1.otherId('b'), link2.otherId('b'));
    });

    test('fromJson parses member_id and spouse_id', () {
      final link = SpouseLink.fromJson({
        'member_id': 'm1',
        'spouse_id': 's1',
      });
      expect(link.memberId, 'm1');
      expect(link.spouseId, 's1');
    });

    test('fromJson throws when a required field is missing', () {
      expect(
        () => SpouseLink.fromJson({'member_id': 'm1'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
