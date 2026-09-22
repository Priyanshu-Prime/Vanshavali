// Duplicate-match sheet: tapping "No — create new" must resolve to the
// createNew branch (proceed to insert a fresh row), never a match. This is the
// safety-critical default — a mis-wired sheet that returned a match here would
// silently claim/link someone else's profile.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/services/supabase_service.dart';
import 'package:vanshavali/widgets/duplicate_match_sheet.dart';

DuplicateCandidate _candidate() => DuplicateCandidate(
      member: FamilyMember(
        id: 'abc',
        createdAt: DateTime(2020),
        firstNameEn: 'Ramesh',
        lastNameEn: 'Patel',
        gender: 'Male',
        villageOrigin: 'Anand',
        dob: DateTime(1980, 1, 1),
      ),
      score: 0.9,
      subScores: const {'name': 0.9},
    );

void main() {
  testWidgets('"No — create new" resolves to createNew, not a match',
      (tester) async {
    DuplicateMatchResult? result;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showDuplicateMatchSheet(
                  context: context,
                  candidates: [_candidate()],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Sheet is up and shows the candidate.
    expect(find.text('Ramesh Patel'), findsOneWidget);

    await tester.tap(find.text('No — create new'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.createNew, isTrue);
    expect(result!.selected, isNull);
  });

  testWidgets('tapping a candidate resolves to that match', (tester) async {
    DuplicateMatchResult? result;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showDuplicateMatchSheet(
                  context: context,
                  candidates: [_candidate()],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ramesh Patel'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.createNew, isFalse);
    expect(result!.selected?.member.id, 'abc');
  });
}
