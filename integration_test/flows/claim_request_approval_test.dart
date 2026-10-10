// Flow: onboarding duplicate match -> claim REQUEST -> relative approves ->
// requester lands on the dashboard as the placeholder (migrations 017/018).
//
// Seeded in-test through isolated Supabase clients (own sessions, the app's
// session is never touched):
//   A  "Arjun Joshi"  claimed, child of Harilal + Meena (placeholders)
//   P  "Kavita Joshi" UNCLAIMED placeholder sibling of A (same parents, Anand)
//   C  "Chirag Mehta" claimed, unrelated stranger
// B signs up in-app with no code and types P's name/gender/village on the
// profile form. Asserts: the duplicate sheet offers P; picking P sends a claim
// request and shows the waiting view IN PLACE (the form is the app root, so a
// pop would leave a black screen); only A (a ring-1 relative) sees the request,
// with B's email; C sees nothing and can't approve; after A approves, "Check
// again" takes B to the dashboard as P.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/screens/auth/set_password_screen.dart';
import 'package:vanshavali/screens/home/home_screen.dart';
import 'package:vanshavali/screens/profile/profile_form_screen.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _a = '00000000-0000-0000-0000-00000000f101';
const _father = '00000000-0000-0000-0000-00000000f102';
const _mother = '00000000-0000-0000-0000-00000000f103';
const _p = '00000000-0000-0000-0000-00000000f104';
const _c = '00000000-0000-0000-0000-00000000f105';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('claim request: waiting view, approver-only inbox, approve -> dashboard',
      (tester) async {
    await resetAppState(skipOnboarding: true);

    // --- Seed A's family + stranger C through their own sessions ---
    final a = isolatedClient();
    final c = isolatedClient();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final aUid = await apiSignUp(a, 'e2e_a_$stamp@example.com');
    await a.from('family_members').insert({
      'id': _a, 'auth_user_id': aUid, 'first_name_en': 'Arjun',
      'last_name_en': 'Joshi', 'gender': 'Male', 'village_origin': 'Anand',
      'deep_details': {'has_password': true},
    });
    await a.from('family_members').insert([
      {'id': _father, 'first_name_en': 'Harilal', 'last_name_en': 'Joshi',
        'gender': 'Male'},
      {'id': _mother, 'first_name_en': 'Meena', 'last_name_en': 'Joshi',
        'gender': 'Female'},
    ]);
    await a.from('family_members')
        .update({'father_id': _father, 'mother_id': _mother}).eq('id', _a);
    await a.from('family_members').insert({
      'id': _p, 'first_name_en': 'Kavita', 'last_name_en': 'Joshi',
      'gender': 'Female', 'village_origin': 'Anand',
      'father_id': _father, 'mother_id': _mother,
    });
    final cUid = await apiSignUp(c, 'e2e_c_$stamp@example.com');
    await c.from('family_members').insert({
      'id': _c, 'auth_user_id': cUid, 'first_name_en': 'Chirag',
      'last_name_en': 'Mehta', 'gender': 'Male', 'village_origin': 'Surat',
      'deep_details': {'has_password': true},
    });

    // --- B signs up in-app and fills the onboarding form as P ---
    await bootApp(tester);
    final bEmail = 'e2e_b_$stamp@example.com';
    await signUp(tester, email: bEmail);
    await pumpUntilFound(tester, find.text('Complete Your Profile'));
    await enterInField(tester, 'first name *', 'Kavita');
    await enterInField(tester, 'last name *', 'Joshi');
    await pickGender(tester, 'Female');
    await pickVillage(tester, 'Anand');
    await tapFormSave(tester);

    // Duplicate sheet offers P; pick it.
    await pumpUntilFound(tester, find.text('Is this the same person?'));
    // Let the sheet finish sliding in (no pumpAndSettle: the Save button
    // behind it shows a spinner, which never settles).
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Is this the same person?'), findsOneWidget,
        reason: 'typing an unclaimed placeholder\'s details must offer it');
    expect(find.text('Arjun Joshi'), findsNothing,
        reason: 'a sibling with a different first name is not a match');
    await tester.tap(find.text('Kavita Joshi').last);
    await tester.pump(const Duration(seconds: 1));

    // Waiting view replaces the form in place — no pop to a blank root.
    await pumpUntilFound(tester, find.text('Waiting for approval'));
    await tester.pump(const Duration(seconds: 2)); // let any post-frame pop run
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.byType(ClaimWaitingView), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(find.byType(ProfileFormScreen), findsOneWidget,
        reason: 'the onboarding root must still be mounted (no black screen)');

    // --- Stranger C: sees no request, cannot approve ---
    final cInbox = await c.rpc('pending_claim_requests') as List;
    expect(cInbox, isEmpty, reason: 'an unrelated member must not see the claim');

    // --- A (P's registered sibling) sees it, with B's email, and approves ---
    final aInbox = (await a.rpc('pending_claim_requests') as List)
        .cast<Map<String, dynamic>>();
    expect(aInbox, hasLength(1));
    expect((aInbox.single['target'] as Map)['id'], _p);
    expect(aInbox.single['requester_email'], bEmail,
        reason: 'the approver must see who is asking');
    final requestId = aInbox.single['request_id'] as String;

    await expectLater(
      c.rpc('approve_claim_request', params: {'request_id': requestId}),
      throwsA(anything),
      reason: 'a stranger must not be able to approve',
    );
    await a.rpc('approve_claim_request', params: {'request_id': requestId});

    // --- Back as B: "Check again" -> dashboard as P ---
    await tester.tap(find.text('Check again'));
    await pumpUntilFound(tester, find.byType(HomeScreen));
    final onScreen = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .join(' | ');
    expect(find.byType(SetPasswordScreen), findsNothing,
        reason: 'B chose a password at signup; an approved claim must not '
            'force the set-password screen. On screen: $onScreen');
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'an approved claim must land B on the dashboard. '
            'On screen: $onScreen');
    expect(find.textContaining('Kavita'), findsWidgets);
    final me = await SupabaseService.getCurrentUserProfile();
    expect(me?.id, _p, reason: 'B must now own the placeholder P');

    await waitForFamilyIdle(tester);
    a.dispose();
    c.dispose();
  });
}
