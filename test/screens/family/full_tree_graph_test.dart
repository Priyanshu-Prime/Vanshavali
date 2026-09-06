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
  // Family: paternal gp1 -> dad (m. mom) -> me (m. spouse) -> kid.
  // Maternal: mgp1 -> mom (+ maternalAunt). Spouse married in.
  final gp1 = _m('gp1');
  final dad = _m('dad', father: 'gp1');
  final mgp1 = _m('mgp1');
  final mom = _m('mom', father: 'mgp1', dob: '1961-01-01');
  final maternalAunt = _m('maternalAunt', father: 'mgp1', dob: '1963-01-01');
  final me = _m('me', father: 'dad', mother: 'mom');
  final spouse = _m('spouse');
  final kid = _m('kid', father: 'me', mother: 'spouse');
  final members = [gp1, dad, mgp1, mom, maternalAunt, me, spouse, kid];

  test('default view shows the paternal clan; mom is a married-in leaf', () {
    final data =
        buildFullTreeData(members: members, spouseLinks: const [], focusId: 'me');
    // Paternal lineage: gp1, dad(+mom), me(+spouse), kid.
    expect(data.contents.containsKey('u:gp1'), isTrue);
    expect(data.contents.containsKey('u:dad'), isTrue);
    expect(data.contents.containsKey('u:me'), isTrue);
    expect(data.contents.containsKey('u:kid'), isTrue);
    // Mom is absorbed into dad's unit — no unit of her own, and her parents /
    // sister are NOT in this lineage.
    expect(data.contents.containsKey('u:mom'), isFalse);
    expect(data.contents.containsKey('u:mgp1'), isFalse);
    expect(data.contents.containsKey('u:maternalAunt'), isFalse);
    // Centered on me.
    expect(data.initialNodeId, 'u:me');
  });

  test('pivoting to the mother re-roots on her lineage', () {
    final data = buildFullTreeData(
        members: members,
        spouseLinks: const [],
        focusId: 'me',
        rootPersonId: 'mom');
    // Maternal lineage now shown: mgp1 -> mom(+dad) -> me -> ...; sister too.
    expect(data.contents.containsKey('u:mgp1'), isTrue);
    expect(data.contents.containsKey('u:maternalAunt'), isTrue);
    // Dad is now the married-in leaf (absorbed into mom's unit), paternal gp gone.
    expect(data.contents.containsKey('u:gp1'), isFalse);
    // You're still highlighted / centered.
    expect(data.initialNodeId, 'u:me');
  });
}
