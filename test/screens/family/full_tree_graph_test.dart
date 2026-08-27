import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/family_tree_screen.dart';

FamilyMember _m(String id, {String? father, String? mother}) => FamilyMember(
      id: id,
      createdAt: DateTime(2020),
      firstNameEn: id,
      lastNameEn: 'T',
      fatherId: father,
      motherId: mother,
    );

void main() {
  test('buildFullTreeGraph makes one node per member', () {
    final g = buildFullTreeGraph([_m('a'), _m('b'), _m('c')]);
    expect(g.nodes.length, 3);
  });

  test('adds a parent->child edge for each present parent link', () {
    final members = [
      _m('a'),
      _m('d'),
      _m('b', father: 'a'), // a -> b
      _m('c', father: 'a', mother: 'd'), // a -> c, d -> c
    ];
    final g = buildFullTreeGraph(members);
    expect(g.nodes.length, 4);
    expect(g.edges.length, 3);
  });

  test('skips edges to a parent id that is not in the member set', () {
    // x references a father who is not part of this connected component.
    final g = buildFullTreeGraph([_m('a'), _m('x', father: 'missing')]);
    expect(g.nodes.length, 2);
    expect(g.edges.length, 0);
  });
}
