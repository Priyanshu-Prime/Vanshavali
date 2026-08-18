import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/utils/invite_code_parser.dart';

void main() {
  group('parseInviteCode', () {
    test('accepts a bare 6-char uppercase code', () {
      expect(parseInviteCode('ABC123'), 'ABC123');
    });

    test('trims surrounding whitespace/newlines', () {
      expect(parseInviteCode('  ABC123 \n'), 'ABC123');
    });

    test('uppercases lowercase input', () {
      expect(parseInviteCode('abc123'), 'ABC123');
    });

    test('accepts all-digit and all-letter codes', () {
      expect(parseInviteCode('123456'), '123456');
      expect(parseInviteCode('ABCDEF'), 'ABCDEF');
    });

    test('pulls code query param from a deep-link URL', () {
      expect(parseInviteCode('vanshavali://auth?code=ABC123'), 'ABC123');
    });

    test('pulls and normalizes code param from an https URL', () {
      expect(
        parseInviteCode('https://example.com/invite?foo=1&code=xyz789'),
        'XYZ789',
      );
    });

    test('returns null when URL code param is not a valid code', () {
      expect(parseInviteCode('vanshavali://auth?code=TOOLONG12'), isNull);
    });

    test('returns null for null / empty / whitespace', () {
      expect(parseInviteCode(null), isNull);
      expect(parseInviteCode(''), isNull);
      expect(parseInviteCode('   '), isNull);
    });

    test('returns null for wrong length', () {
      expect(parseInviteCode('ABC12'), isNull);
      expect(parseInviteCode('ABC1234'), isNull);
    });

    test('returns null for codes with invalid characters', () {
      expect(parseInviteCode('ABC-12'), isNull);
      expect(parseInviteCode('ABC 12'), isNull);
      expect(parseInviteCode('ABC_12'), isNull);
    });

    test('returns null for a URL without a code param', () {
      expect(parseInviteCode('https://example.com/invite?foo=ABC123'), isNull);
    });
  });
}
