import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/services/transliteration_service.dart';

void main() {
  group('parseInputToolsResponse', () {
    test('extracts ranked candidates from a SUCCESS response', () {
      const body =
          '["SUCCESS",[["ramesh",["રમેશ","રામેશ","રમીશ"],[],{"candidate_type":[0,0,0]}]]]';
      expect(
        TransliterationService.parseInputToolsResponse(body),
        ['રમેશ', 'રામેશ', 'રમીશ'],
      );
    });

    test('returns empty on a FAILED response', () {
      expect(
        TransliterationService.parseInputToolsResponse('["FAILED"]'),
        isEmpty,
      );
    });

    test('returns empty on malformed JSON', () {
      expect(
        TransliterationService.parseInputToolsResponse('not json'),
        isEmpty,
      );
    });

    test('returns empty when there are no candidates', () {
      expect(
        TransliterationService.parseInputToolsResponse(
            '["SUCCESS",[["x",[],[],{}]]]'),
        isEmpty,
      );
    });

    test('drops non-string / empty entries defensively', () {
      const body = '["SUCCESS",[["x",["રમેશ","",null,"રમીશ"],[],{}]]]';
      expect(
        TransliterationService.parseInputToolsResponse(body),
        ['રમેશ', 'રમીશ'],
      );
    });
  });
}
