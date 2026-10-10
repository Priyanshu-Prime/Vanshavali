// Regression: the village picker sheet sized its result list at 50% of the
// SCREEN height regardless of the keyboard, so with the keyboard up (typing a
// search) the sheet's Column overflowed. Caught on-device by the e2e rig
// (integration_test/flows/claim_request_approval_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/l10n/app_localizations.dart';
import 'package:vanshavali/services/gujarat_places_service.dart';
import 'package:vanshavali/widgets/village_picker_field.dart';

// Many "Anand..." villages so the search result list is taller than the space
// left above the keyboard.
final _places = '{"source":"t","districts":[{"name":"Anand","code":"1",'
    '"talukas":[{"name":"Borsad","code":"2","villages":['
    '${List.generate(40, (i) => '{"name":"Anand$i","code":"v$i"}').join(',')}'
    ']}]}]}';

void main() {
  testWidgets('picker sheet does not overflow with the keyboard open',
      (tester) async {
    GujaratPlacesService.loadFromJson(_places);
    // Phone-sized screen (411x890 dp) with a ~340 dp keyboard (Gboard + suggestion strip).
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2337);
    tester.view.viewInsets = const FakeViewPadding(bottom: 340 * 2.625);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VillagePickerField(value: null, onChanged: (_) {}),
      ),
    ));
    await tester.tap(find.text('Select village'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'anand');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Anand'), findsWidgets, reason: 'results still listed');
  });
}
