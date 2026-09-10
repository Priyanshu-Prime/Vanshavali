// Regression tests for friendlyErrorMessage — a returning user who tapped
// "Create Account" hit GoTrue's "User already registered" (422), which fell
// through to the generic "something went wrong on our end" instead of the
// helpful "already exists, please log in" message.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/widgets/common_widgets.dart';

Future<String> _map(WidgetTester tester, Object error) async {
  late String result;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Builder(builder: (context) {
      result = friendlyErrorMessage(context, error);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  testWidgets('GoTrue "User already registered" maps to the log-in hint, '
      'not the generic error', (tester) async {
    final msg = await _map(
      tester,
      'AuthApiException(message: User already registered, statusCode: 422, '
      'code: user_already_exists)',
    );
    expect(msg.toLowerCase(), contains('already exists'));
    expect(msg.toLowerCase(), isNot(contains('went wrong')));
  });

  testWidgets('user_already_exists code alone also maps correctly',
      (tester) async {
    final msg = await _map(tester, 'AuthApiException: user_already_exists');
    expect(msg.toLowerCase(), contains('already exists'));
  });

  testWidgets('an unrecognized service error still falls back to generic',
      (tester) async {
    final msg = await _map(tester, 'PostgrestException(message: weird db thing)');
    expect(msg.toLowerCase(), contains('went wrong'));
  });

  testWidgets('offline errors map to the no-internet message', (tester) async {
    final msg = await _map(tester, 'SocketException: Failed host lookup');
    expect(msg.toLowerCase(), contains('internet'));
  });
}
