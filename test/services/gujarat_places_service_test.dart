import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/services/gujarat_places_service.dart';

const _fixture = '''
{"source":"t","districts":[
  {"name":"Anand","code":"440","talukas":[
    {"name":"Anand","code":"03801","villages":[
      {"name":"Napad","code":"111"},
      {"name":"Vasad","code":"112"}
    ]},
    {"name":"Borsad","code":"03802","villages":[
      {"name":"Napa","code":"113"}
    ]}
  ]},
  {"name":"Kachchh","code":"468","talukas":[
    {"name":"Lakhpat","code":"03722","villages":[{"name":"Dayapar","code":"200"}]}
  ]}
]}
''';

void main() {
  setUp(() => GujaratPlacesService.loadFromJson(_fixture));

  test('districts are indexed', () {
    expect(GujaratPlacesService.districts().map((d) => d.name),
        ['Anand', 'Kachchh']);
  });

  test('talukas resolve by district code', () {
    final t = GujaratPlacesService.talukas('440').map((x) => x.name).toList();
    expect(t, ['Anand', 'Borsad']);
  });

  test('villages resolve by district+taluka code', () {
    final v =
        GujaratPlacesService.villages('440', '03801').map((x) => x.name).toList();
    expect(v, ['Napad', 'Vasad']);
  });

  test('village search ranks exact, then prefix, then contains', () {
    final r =
        GujaratPlacesService.searchVillages('napa').map((x) => x.name).toList();
    // "Napa" exact first, then "Napad" prefix.
    expect(r.first, 'Napa');
    expect(r, containsAll(['Napa', 'Napad']));
  });

  test('search is spelling/space insensitive', () {
    expect(GujaratPlacesService.searchVillages('DAY A par').first.name,
        'Dayapar');
  });

  test('searchPlaces matches districts, talukas and villages', () {
    // "Anand" is both a district and a taluka in the fixture.
    final r = GujaratPlacesService.searchPlaces('Anand');
    final levels = r.map((h) => h.level).toSet();
    expect(levels, containsAll([GjLevel.district, GjLevel.taluka]));
    // District hit comes before the taluka hit (depth-first within exact rank).
    final district = r.firstWhere((h) => h.level == GjLevel.district);
    final taluka = r.firstWhere((h) => h.level == GjLevel.taluka);
    expect(r.indexOf(district), lessThan(r.indexOf(taluka)));
    // Context disambiguates: taluka carries its district, village its parents.
    expect(taluka.context, 'Anand');
    final village =
        GujaratPlacesService.searchPlaces('Napad').single;
    expect(village.level, GjLevel.village);
    expect(village.context, 'Anand, Anand');
  });
}
