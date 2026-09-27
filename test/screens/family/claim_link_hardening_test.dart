// Claim + link hardening (migration 018): the re-parent block helper, the
// onboarding claim waiting view, and the approver inbox showing who asked.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/screens/family/add_family_member_screen.dart';
import 'package:vanshavali/screens/family/requests_screen.dart';
import 'package:vanshavali/screens/profile/profile_form_screen.dart';
import 'package:vanshavali/services/supabase_service.dart';
import 'package:vanshavali/widgets/common_widgets.dart';

FamilyMember m(
  String id, {
  String? gender = 'Male',
  String? auth,
  String? father,
  String? mother,
}) =>
    FamilyMember(
      id: id,
      createdAt: DateTime(2020),
      firstNameEn: id,
      lastNameEn: 'Patel',
      gender: gender,
      authUserId: auth,
      fatherId: father,
      motherId: mother,
    );

Widget app(Widget home) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: home,
    );

void main() {
  group('linkExistingBlockReason', () {
    LinkBlock? r(String rel, FamilyMember anchor, FamilyMember match,
            [String? caller]) =>
        linkExistingBlockReason(
            relation: rel, anchor: anchor, match: match, callerAuthUserId: caller);

    test('father/mother/spouse never blocked (they edit the anchor side)', () {
      final claimed = m('x', auth: 'u1', father: 'f9');
      for (final rel in ['father', 'mother', 'spouse']) {
        expect(r(rel, m('a'), claimed), isNull);
      }
    });

    test('child: registered match blocked, unless it is the caller', () {
      expect(r('child', m('a'), m('x', auth: 'u1')), LinkBlock.registered);
      expect(r('child', m('a'), m('x', auth: 'u1'), 'u1'), isNull);
    });

    test('child: slot already holding a different parent is blocked', () {
      expect(r('child', m('a'), m('x', father: 'other')), LinkBlock.otherParent);
      expect(r('child', m('a'), m('x', father: 'a')), isNull);
      expect(r('child', m('a'), m('x', mother: 'mom')), isNull);
      final mom = m('mom', gender: 'Female');
      expect(r('child', mom, m('x', mother: 'other')), LinkBlock.otherParent);
      expect(r('child', mom, m('x', father: 'dad')), isNull);
    });

    test('sibling: one compatible shared parent is enough', () {
      final a = m('a', father: 'F', mother: 'M');
      expect(r('sibling', a, m('x')), isNull);
      expect(r('sibling', a, m('x', father: 'F', mother: 'M2')), isNull);
      expect(r('sibling', a, m('x', father: 'F2', mother: 'M2')),
          LinkBlock.otherParent);
      expect(r('sibling', m('orphan'), m('x', father: 'F2')), isNull);
      expect(r('sibling', a, m('x', auth: 'u9')), LinkBlock.registered);
    });
  });

  testWidgets('ClaimWaitingView: check again and create-new both reachable',
      (tester) async {
    var checks = 0;
    var createNew = 0;
    await tester.pumpWidget(app(ClaimWaitingView(
      onCheckAgain: () async => checks++,
      onCreateNew: () => createNew++,
      onLogout: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for approval'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a new profile instead'));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(createNew, 1);
  });

  test('ClaimRequest parses requester_email (and tolerates its absence)', () {
    final json = {
      'request_id': 'r1',
      'created_at': '2026-09-01T10:00:00Z',
      'requester': 'u1',
      'target': m('t', gender: null).toJson(),
      'requester_email': 'kaka@example.com',
    };
    expect(ClaimRequest.fromJson(json).requesterEmail, 'kaka@example.com');
    json.remove('requester_email');
    expect(ClaimRequest.fromJson(json).requesterEmail, isNull);
  });

  testWidgets('RequestsScreen shows who asked and when', (tester) async {
    final reqs = [
      ClaimRequest(
        requestId: 'r1',
        createdAt: DateTime(2026, 9, 5, 12),
        requesterAuthUserId: 'u1',
        target: m('Target'),
        requesterEmail: 'kaka@example.com',
      ),
      ClaimRequest(
        requestId: 'r2',
        createdAt: DateTime(2026, 9, 6, 12),
        requesterAuthUserId: 'u2',
        target: m('Other'),
      ),
    ];
    await tester.pumpWidget(app(RequestsScreen(loader: () async => reqs)));
    await tester.pumpAndSettle();
    expect(find.text('Requested by kaka@example.com'), findsOneWidget);
    expect(find.text('Requested on 05/09/2026'), findsOneWidget);
    expect(find.text('Requested by Unknown person'), findsOneWidget);
  });

  testWidgets('parent-already-set server error maps to its own message',
      (tester) async {
    late String msg;
    await tester.pumpWidget(app(Builder(builder: (context) {
      msg = friendlyErrorMessage(
          context,
          'PostgrestException(message: vanshavali_parent_already_set: member x '
          'already has a different father)');
      return const SizedBox();
    })));
    expect(msg, contains('already has a different father or mother'));
  });
}
