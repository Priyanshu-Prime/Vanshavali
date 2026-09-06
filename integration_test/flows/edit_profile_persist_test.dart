// Flow: editing your OWN profile persists (scenario 3.2), against a real local
// Supabase backend. Exercises the real UPDATE path (updateFamilyMember) and the
// migration-010 UPDATE policy that must still allow a user to edit their own
// row — complementing edit_authorization_test.dart, which checks the
// permission gate but never performs an actual persisted write.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _self = '00000000-0000-0000-0000-0000000000b3'; // Child, claimed via TEST04

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editing your own profile persists across a re-fetch',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    await bootApp(tester);
    await signUp(tester, code: 'TEST04');
    expect(SupabaseService.currentUser, isNotNull,
        reason: 'signup+claim must establish an authenticated session');

    // Load own profile, change a field, and save through the real path.
    final me = await SupabaseService.getFamilyMemberById(_self);
    expect(me, isNotNull, reason: 'claimed self profile must be readable');
    const newCity = 'Rajkot';
    expect(me!.currentCity, isNot(newCity),
        reason: 'precondition: seed does not already set this city');

    await SupabaseService.updateFamilyMember(me.copyWith(currentCity: newCity));

    // Re-fetch fresh from the DB — the change must have persisted.
    final reloaded = await SupabaseService.getFamilyMemberById(_self);
    expect(reloaded!.currentCity, newCity,
        reason: 'own-profile edit must persist (UPDATE + migration-010 policy)');
  });
}
