import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/screens/family/add_family_member_screen.dart';

void main() {
  test('relation-driven default gender on the add form', () {
    expect(defaultGenderForRelation('father', 'Female'), 'Male');
    expect(defaultGenderForRelation('mother', 'Male'), 'Female');
    expect(defaultGenderForRelation('spouse', 'Male'), 'Female');
    expect(defaultGenderForRelation('spouse', 'Female'), 'Male');
    expect(defaultGenderForRelation('spouse', null), isNull);
    expect(defaultGenderForRelation('child', 'Male'), isNull);
    expect(defaultGenderForRelation('sibling', 'Female'), isNull);
  });
}
