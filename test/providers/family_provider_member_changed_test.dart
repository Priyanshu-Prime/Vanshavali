import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/providers/family_provider.dart';

void main() {
  // The tree screen reloads only when dataVersion moves; an own-profile save
  // (e.g. photo attached after first create) must move it or the tree stays stale.
  test('memberChangedElsewhere bumps dataVersion and notifies', () {
    final fp = FamilyProvider();
    var notified = 0;
    fp.addListener(() => notified++);
    final before = fp.dataVersion;

    fp.memberChangedElsewhere();

    expect(fp.dataVersion, before + 1);
    expect(notified, greaterThan(0));
  });
}
