import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';

FamilyMember _m(String id, {String? father, String? mother, String? dob}) =>
    FamilyMember(
      id: id,
      createdAt: DateTime(2020),
      firstNameEn: id,
      lastNameEn: 'T',
      fatherId: father,
      motherId: mother,
      dob: dob == null ? null : DateTime.parse(dob),
    );

void main() {
  test('builds a descendant tree of couple-units, spouses absorbed', () {
    // gp -> p (married to ps) -> c1, c2
    final gp = _m('gp');
    final p = _m('p', father: 'gp');
    final ps = _m('ps'); // married-in, inferred as p's spouse via shared children
    final c1 = _m('c1', father: 'p', mother: 'ps', dob: '2000-01-01');
    final c2 = _m('c2', father: 'p', mother: 'ps', dob: '1998-01-01');

    final data = buildFullTreeData(
      members: [gp, p, ps, c1, c2],
      spouseLinks: const [],
      focusId: 'c1',
    );

    // Units: gp, p(+ps), c1, c2 — ps is absorbed into p's unit, not its own.
    expect(data.graph.nodes.length, 4);
    expect(data.contents.containsKey('u:ps'), isFalse);

    final pUnit = data.contents['u:p'];
    expect(pUnit, isA<TreeUnitContent>());
    pUnit as TreeUnitContent;
    expect(pUnit.primary.id, 'p');
    expect(pUnit.spouses.map((s) => s.id), contains('ps'));

    // gp->p, p->c1, p->c2
    expect(data.graph.edges.length, 3);

    // Roots at the top ancestor; single root means no super-root.
    expect(data.initialNodeId, 'u:gp');
    expect(data.contents.containsKey(kFullTreeSuperRoot), isFalse);
  });

  test('joins multiple family roots under an invisible super-root', () {
    // Two unconnected mini-families in one member set.
    final a = _m('a');
    final ac = _m('ac', father: 'a');
    final b = _m('b');
    final bc = _m('bc', father: 'b');

    final data = buildFullTreeData(
      members: [a, ac, b, bc],
      spouseLinks: const [],
      focusId: 'ac',
    );

    expect(data.contents[kFullTreeSuperRoot], isA<SuperRootContent>());
    expect(data.initialNodeId, kFullTreeSuperRoot);
    // 4 person-units + 1 super-root.
    expect(data.graph.nodes.length, 5);
  });
}
