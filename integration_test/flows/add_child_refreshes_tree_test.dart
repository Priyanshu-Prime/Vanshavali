// Flow: add a child from Home and see it in the Family Tree tab without an app
// restart (regression for d8e3e12: the full-tree load was guarded once per
// root, so a member added from Home never appeared until restart).
//
// Seeded through the app's own session BEFORE boot (so the app starts on Home):
//   self "Vikram Desai" (Male, Anand) + spouse "Nisha Desai" + child "Mira".
// Then, all in-app: open the tree once (full tree loads, Mira visible) -> Home
// -> Add Family Member -> Children -> "Tara" (Female, village via picker) ->
// confirm -> other parent Nisha -> back on the Tree tab "Tara" is present.
// Also asserts the duplicate sheet did NOT fire: Tara shares surname, parents
// and village with her sister Mira, but a different first name is not a match
// (migration 018's first-name rule).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _self = '00000000-0000-0000-0000-00000000f201';
const _spouse = '00000000-0000-0000-0000-00000000f202';
const _mira = '00000000-0000-0000-0000-00000000f203';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('child added from Home appears in the tree without restart',
      (tester) async {
    await resetAppState(skipOnboarding: true);

    // --- Seed a signed-in user with a spouse and one child ---
    final c = SupabaseService.client;
    final uid = await apiSignUp(c, uniqueEmail());
    await c.from('family_members').insert({
      'id': _self, 'auth_user_id': uid, 'first_name_en': 'Vikram',
      'last_name_en': 'Desai', 'gender': 'Male', 'village_origin': 'Anand',
      'deep_details': {'has_password': true},
    });
    await c.from('family_members').insert({
      'id': _spouse, 'first_name_en': 'Nisha', 'last_name_en': 'Desai',
      'gender': 'Female', 'village_origin': 'Anand',
    });
    await SupabaseService.linkFamilyMembers(
        memberId: _self, relatedMemberId: _spouse,
        relationType: RelationType.spouse);
    await c.from('family_members').insert({
      'id': _mira, 'first_name_en': 'Mira', 'last_name_en': 'Desai',
      'gender': 'Female', 'village_origin': 'Anand',
      'father_id': _self, 'mother_id': _spouse,
    });

    await bootApp(tester);
    await pumpUntilFound(tester, find.text('Vikram Desai'));
    expect(find.text('Vikram Desai'), findsWidgets, reason: 'boots to Home');

    // --- Open the tree once: the full tree loads with Mira in it ---
    await tapNavTab(tester, 'Family Tree');
    await pumpUntilFound(tester, find.textContaining('Mira'));
    expect(find.textContaining('Mira'), findsWidgets);
    expect(find.textContaining('Tara'), findsNothing);

    // --- Home -> Add Family Member -> Children -> Tara ---
    await tapNavTab(tester, 'Home');
    await tapText(tester, 'Add Family Member');
    await pumpUntilFound(tester, find.text('Children'));
    await tester.tap(find.text('Children').last);
    await tester.pumpAndSettle();
    await enterInField(tester, 'first name *', 'Tara');
    await enterInField(tester, 'last name *', 'Desai');
    await pickGender(tester, 'Female');
    await pickVillage(tester, 'Anand');
    await tapFormSave(tester);

    // Next step is the confirm dialog — never the duplicate sheet.
    await pumpUntilFound(tester, find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Is this the same person?'), findsNothing,
        reason: 'a sibling with a different first name must not be offered');
    expect(find.textContaining('as your child'), findsOneWidget);
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    // Other parent: pick the spouse.
    await pumpUntilFound(tester, find.text('Who is the Mother?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nisha Desai').last);
    await tester.pump(const Duration(seconds: 1));

    // Back on Home once the add completes.
    await pumpUntilFound(tester, find.text('My Family'));

    // --- Tree tab again, no restart: Tara is there ---
    await tapNavTab(tester, 'Family Tree');
    await pumpUntilFound(tester, find.textContaining('Tara'));
    expect(find.textContaining('Tara'), findsWidgets,
        reason: 'the new child must appear in the tree without a restart');

    final kids = await SupabaseService.getChildren(_self);
    final tara = kids.where((m) => m.firstNameEn == 'Tara').single;
    expect(tara.motherId, _spouse, reason: 'other parent must be linked');
    expect(tara.villageOrigin, 'Anand');
    await waitForFamilyIdle(tester);
  });
}
