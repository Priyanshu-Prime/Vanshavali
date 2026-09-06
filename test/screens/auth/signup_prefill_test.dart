import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/providers/auth_provider.dart';
import 'package:vanshavali/screens/auth/signup_screen.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('gu')],
      home: child,
    ),
  );
}

void main() {
  testWidgets('prefilled invite code populates the invite-code field',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SignupScreen(prefilledInviteCode: 'ABC123'),
    ));
    await tester.pump();

    // The invite-code field's controller text should show the prefilled code.
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('no prefilled code leaves the invite-code field empty',
      (tester) async {
    await tester.pumpWidget(_wrap(const SignupScreen()));
    await tester.pump();

    expect(find.text('ABC123'), findsNothing);
  });
}
