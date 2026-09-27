import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/services/gujarat_places_service.dart';

// District "Patan" and a same-named taluka with a different (machine) spelling:
// the district's hand-checked spelling must win.
const _fixture = '''
{"source":"t","districts":[
  {"name":"Patan","gu":"પાટણ","code":"1","talukas":[
    {"name":"Patan","gu":"પાટન","code":"11","villages":[
      {"name":"Anavada","gu":"અનાવાડા","code":"111"}
    ]},
    {"name":"Sidhpur","gu":"સિદ્ધપુર","code":"12","villages":[
      {"name":"Nogu","code":"121"}
    ]}
  ]}
]}
''';

void main() {
  // Must run before loadFromJson: order within a file is declaration order.
  test('before load: returns the stored value, never blank', () {
    expect(GujaratPlacesService.isLoaded, isFalse);
    expect(GujaratPlacesService.displayName('Anavada', 'gu'), 'Anavada');
  });

  group('after load', () {
    setUpAll(() => GujaratPlacesService.loadFromJson(_fixture));

    test('en returns the stored English name', () {
      expect(GujaratPlacesService.displayName('Anavada', 'en'), 'Anavada');
    });

    test('gu returns Gujarati for district, taluka and village names', () {
      expect(GujaratPlacesService.displayName('Patan', 'gu'), 'પાટણ');
      expect(GujaratPlacesService.displayName('Sidhpur', 'gu'), 'સિદ્ધપુર');
      expect(GujaratPlacesService.displayName('Anavada', 'gu'), 'અનાવાડા');
    });

    test('unknown or gu-less names fall back to the stored value', () {
      expect(GujaratPlacesService.displayName('Mumbai', 'gu'), 'Mumbai');
      expect(GujaratPlacesService.displayName('Nogu', 'gu'), 'Nogu');
    });

    test('searchPlaces matches Gujarati script too', () {
      final hit = GujaratPlacesService.searchPlaces('અનાવા').single;
      expect(hit.name, 'Anavada');
      expect(hit.level, GjLevel.village);
    });
  });
}
