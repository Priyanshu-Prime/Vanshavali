// Flow: create your own profile (scenarios 3.1 / Phase 2-3). Sign up WITHOUT
// an invite code, fill the required name fields on "Complete Your Profile",
// save, and land on Home showing that name — verifying the created row is
// linked to the auth user (createProfile stamps auth_user_id) and persisted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signing up without a code lets you create your own profile',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);

    await signUp(tester); // no invite code -> manual profile creation
    expect(SupabaseService.currentUser, isNotNull,
        reason: 'signup must establish a session');

    // Land on the creation form.
    await pumpUntilFound(tester, find.text('Complete Your Profile'));
    expect(find.text('Complete Your Profile'), findsWidgets);

    // Fill the two required fields (the ' *' suffix disambiguates the English
    // fields from their Gujarati counterparts).
    await enterInField(tester, 'first name *', 'Kiran');
    await enterInField(tester, 'last name *', 'Solanki');

    // The form is a lazy ListView, so the bottom save button isn't built until
    // scrolled to — drag the list (building children) until it appears.
    final save = find.byType(ElevatedButton);
    await tester.scrollUntilVisible(
      save,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // Land on Home showing the newly created person.
    await pumpUntilFound(tester, find.textContaining('Kiran'));
    expect(find.textContaining('Kiran'), findsWidgets,
        reason: 'after creating a profile, Home should show that person');
    expect(find.text('Complete Your Profile'), findsNothing,
        reason: 'the creation form should be gone once the profile is saved');

    // The created row is linked to the auth user server-side.
    final me = await SupabaseService.getCurrentUserProfile();
    expect(me, isNotNull,
        reason: 'the created profile must be linked to the auth user');
    expect(me!.firstNameEn, 'Kiran');
  });
}
