// Tests for AuthProvider.hasPasswordSet — the pure part of the mandatory
// set-password flow (see SetPasswordScreen / AppNavigator in main.dart).
//
// setPassword/signUpWithEmail/signInWithEmail themselves are NOT covered
// here: they call SupabaseService's static methods directly, which require
// a live Supabase connection unavailable in a plain `flutter test` run —
// the same known, already-documented coupling as other Supabase-backed
// provider methods in this codebase (see family_provider_spouses_test.dart's
// note on getSpousesOf's fallback branch). hasPasswordSet itself is pure
// (reads deep_details off the already-loaded currentMember), so it's
// tested directly via the forTesting() seam.

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/auth_provider.dart';

FamilyMember _member({Map<String, dynamic> deepDetails = const {}}) {
  return FamilyMember(
    id: 'a',
    createdAt: DateTime(2020, 1, 1),
    firstNameEn: 'Test',
    lastNameEn: 'Person',
    deepDetails: deepDetails,
  );
}

void main() {
  group('AuthProvider.hasPasswordSet', () {
    test('false when there is no current member', () {
      final provider = AuthProvider.forTesting();
      expect(provider.hasPasswordSet, isFalse);
    });

    test('false when deep_details has no has_password key '
        '(a magic-link-only account)', () {
      final provider = AuthProvider.forTesting(
        currentMember: _member(deepDetails: const {}),
      );
      expect(provider.hasPasswordSet, isFalse);
    });

    test('false when has_password is explicitly false', () {
      final provider = AuthProvider.forTesting(
        currentMember: _member(deepDetails: const {'has_password': false}),
      );
      expect(provider.hasPasswordSet, isFalse);
    });

    test('true when has_password is true', () {
      final provider = AuthProvider.forTesting(
        currentMember: _member(deepDetails: const {'has_password': true}),
      );
      expect(provider.hasPasswordSet, isTrue);
    });

    test('unaffected by other unrelated deep_details fields', () {
      final provider = AuthProvider.forTesting(
        currentMember: _member(deepDetails: const {
          'education': 'B.Sc',
          'occupation': 'Farmer',
          'has_password': true,
        }),
      );
      expect(provider.hasPasswordSet, isTrue);
    });
  });

  group('AuthProvider.authenticatedWithPassword', () {
    test('defaults to false via forTesting (no password auth happened)', () {
      final provider = AuthProvider.forTesting();
      expect(provider.authenticatedWithPassword, isFalse);
    });
  });
}
