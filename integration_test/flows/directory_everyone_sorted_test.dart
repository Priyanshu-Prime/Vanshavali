// Flow: Directory -> "Everyone" tab lists the whole database A->Z by surname,
// then first name (regression for c0bfb35: postgrest-dart's order() defaults
// to DESCENDING, so the tab showed Z->A).
//
// Seed: supabase/seed.sql's Patel placeholders + the signed-in user "Kiran
// Acharya" (alphabetically first surname in the whole suite). The expected
// order is computed independently in Dart from a raw table read, so the test
// also holds when other flow files have added rows in the same DB reset.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vanshavali/services/supabase_service.dart';

import '../harness.dart';

const _self = '00000000-0000-0000-0000-00000000f301';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Directory Everyone tab is sorted A-Z by surname, first name',
      (tester) async {
    await resetAppState(skipOnboarding: true);
    final c = SupabaseService.client;
    final uid = await apiSignUp(c, uniqueEmail());
    await c.from('family_members').insert({
      'id': _self, 'auth_user_id': uid, 'first_name_en': 'Kiran',
      'last_name_en': 'Acharya', 'gender': 'Male', 'village_origin': 'Anand',
      'deep_details': {'has_password': true},
    });

    await bootApp(tester);
    await pumpUntilFound(tester, find.text('Kiran Acharya'));
    await tapNavTab(tester, 'Directory');
    expect(find.text('Everyone'), findsOneWidget,
        reason: 'the whole-database tab must be labelled "Everyone"');
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    // Rendered rows, top to bottom (only the Everyone page is on screen).
    final tiles = find.byType(ListTile).hitTestable();
    await pumpUntilFound(tester, tiles);
    final shown = tester
        .widgetList<ListTile>(tiles)
        .map((t) => (t.title as Text).data!)
        .toList();
    expect(shown.length, greaterThanOrEqualTo(5), reason: 'rows: $shown');

    // Expected: every row, sorted in Dart by (surname, first name).
    final rows = (await c
            .from('family_members')
            .select('first_name_en,last_name_en') as List)
        .cast<Map<String, dynamic>>()
      ..sort((a, b) {
        final k = (a['last_name_en'] as String)
            .toLowerCase()
            .compareTo((b['last_name_en'] as String).toLowerCase());
        return k != 0
            ? k
            : (a['first_name_en'] as String)
                .toLowerCase()
                .compareTo((b['first_name_en'] as String).toLowerCase());
      });
    final expected = rows
        .map((r) => '${r['first_name_en']} ${r['last_name_en']}')
        .take(shown.length)
        .toList();

    expect(shown.first, 'Kiran Acharya', reason: 'A->Z: Acharya first');
    expect(shown, expected, reason: 'Everyone must be A->Z by surname, first');
    // Seeded Patels appear in first-name order among themselves.
    final patels = shown.where((s) => s.endsWith(' Patel')).toList();
    expect(patels, [...patels]..sort());
    await waitForFamilyIdle(tester);
  });
}
