// Children with no DOB must keep one order regardless of the order the server
// returns them in — otherwise the tree reshuffles between loads (seen on-device
// in +17: Kavya/Aarav/Dhruv swapped places after returning from a profile).

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';

FamilyMember _m(String id, DateTime created, {String? fatherId}) => FamilyMember(
      id: id,
      createdAt: created,
      fatherId: fatherId,
      firstNameEn: id,
      lastNameEn: 'Patel',
      gender: 'Male',
    );

List<String> _childOrder(List<FamilyMember> children, FamilyMember focus) {
  final data = buildTreeData(
    focus: focus,
    focusSpouses: const [],
    children: children,
    siblings: const [],
    spousesOf: (_) => const [],
    showSiblings: false,
  );
  return data.graph.nodes
      .map((n) => n.key!.value as String)
      .where((id) => children.any((c) => id.contains(c.id)))
      .toList();
}

void main() {
  test('undated children keep the same order whatever the input order', () {
    final focus = _m('focus', DateTime(2020));
    final a = _m('kavya', DateTime(2021, 1, 1), fatherId: 'focus');
    final b = _m('aarav', DateTime(2021, 1, 2), fatherId: 'focus');
    final c = _m('dhruv', DateTime(2021, 1, 3), fatherId: 'focus');
    final first = _childOrder([a, b, c], focus);
    expect(first, hasLength(3));
    expect(_childOrder([c, a, b], focus), first);
    expect(_childOrder([b, c, a], focus), first);
  });
}
