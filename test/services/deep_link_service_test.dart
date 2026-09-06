import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseInviteCodeFromUri', () {
    test('custom scheme with ?code= extracts the code', () {
      final uri = Uri.parse('vanshavali://invite?code=ABC123');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), 'ABC123');
    });

    test('custom scheme with ?c= extracts the code', () {
      final uri = Uri.parse('vanshavali://invite?c=ABC123');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), 'ABC123');
    });

    test('normalises lowercase code to uppercase', () {
      final uri = Uri.parse('vanshavali://invite?code=abc123');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), 'ABC123');
    });

    test('https Pages URL with ?c= extracts the code', () {
      final uri = Uri.parse(
        'https://priyanshu-prime.github.io/Vanshavali/?c=XYZ789',
      );
      expect(DeepLinkService.parseInviteCodeFromUri(uri), 'XYZ789');
    });

    test('https Pages URL with ?c= and ?n= still extracts the code', () {
      final uri = Uri.parse(
        'https://priyanshu-prime.github.io/Vanshavali/?c=XYZ789&n=Ravi%20Patel',
      );
      expect(DeepLinkService.parseInviteCodeFromUri(uri), 'XYZ789');
    });

    test('returns null for a malformed (too-short) code', () {
      final uri = Uri.parse('vanshavali://invite?code=ABC12');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), isNull);
    });

    test('returns null for a code with invalid characters', () {
      final uri = Uri.parse('vanshavali://invite?code=ABC-12');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), isNull);
    });

    test('returns null when no code query param present', () {
      final uri = Uri.parse('vanshavali://invite');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), isNull);
    });

    test('returns null for an unrelated https host', () {
      final uri = Uri.parse('https://example.com/?c=ABC123');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), isNull);
    });

    test('returns null for the auth deep link', () {
      final uri = Uri.parse('vanshavali://auth/callback');
      expect(DeepLinkService.parseInviteCodeFromUri(uri), isNull);
    });
  });

  group('DeepLinkService.buildInviteUrl / generateInviteText', () {
    test('buildInviteUrl matches the shared contract format', () {
      expect(
        DeepLinkService.buildInviteUrl('Ravi Patel', 'ABC123'),
        'https://priyanshu-prime.github.io/Vanshavali/?c=ABC123&n=Ravi%20Patel',
      );
    });

    test('round-trips: a generated URL parses back to the same code', () {
      final url = DeepLinkService.buildInviteUrl('Meera', 'QWE456');
      expect(
        DeepLinkService.parseInviteCodeFromUri(Uri.parse(url)),
        'QWE456',
      );
    });

    test('EN invite text carries the real link and the code fallback', () {
      final text = DeepLinkService.generateInviteText('Ravi', 'ABC123', 'en');
      expect(text, contains('https://priyanshu-prime.github.io/Vanshavali/?c=ABC123'));
      expect(text, contains('ABC123'));
      expect(text, isNot(contains('coming soon')));
    });

    test('GU invite text carries the real link and the code fallback', () {
      final text = DeepLinkService.generateInviteText('Ravi', 'ABC123', 'gu');
      expect(text, contains('https://priyanshu-prime.github.io/Vanshavali/?c=ABC123'));
      expect(text, contains('ABC123'));
      expect(text, isNot(contains('ટૂંક સમયમાં')));
    });
  });
}
