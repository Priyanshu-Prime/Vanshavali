// Tests for SupabaseService's auth methods, using SupabaseService.
// debugClientOverride (see supabase_service.dart) to inject a mocktail
// MockSupabaseClient/MockGoTrueClient instead of needing a live
// Supabase.initialize() call.
//
// Scoped to methods that call client.auth.* directly (GoTrueClient methods
// are plain `Future<T>`-returning async methods) — NOT client.rpc(...) or
// client.from(...) (both return PostgrestFilterBuilder<T>, which itself
// `implements Future<T>` rather than returning one; mocking that safely
// needs stubbing the object's own Future machinery, not just its declared
// method, and was judged too fragile/SDK-internals-coupled for the value
// versus this file's plain-Future auth calls). See the architecture review
// memory / hardening plan for that scope note.
//
// signUpWithEmail's identities-emptiness check is the highest-value target
// here: it's the exact logic that failed once already, producing a real
// duplicate family_members row for an existing account re-signing up (see
// docs/claude_handoff and the has_password/set-password work this project
// did to recover from it) — this is its first automated coverage.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vanshavali/services/supabase_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakeUserAttributes extends Fake implements UserAttributes {}

User _user({List<UserIdentity>? identities}) {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2020, 1, 1).toIso8601String(),
    email: 'test@example.com',
    identities: identities,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUserAttributes());
  });

  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    SupabaseService.debugClientOverride = mockClient;
  });

  tearDown(() {
    SupabaseService.debugClientOverride = null;
  });

  group('signUpWithEmail — the duplicate-profile-incident logic', () {
    test('a genuinely new signup (non-empty identities) does not throw', () async {
      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async => AuthResponse(
            user: _user(identities: [
              UserIdentity(
                id: 'id-1',
                userId: 'user-1',
                identityData: const {},
                identityId: 'identity-1',
                provider: 'email',
                createdAt: DateTime(2020, 1, 1).toIso8601String(),
                lastSignInAt: DateTime(2020, 1, 1).toIso8601String(),
                updatedAt: DateTime(2020, 1, 1).toIso8601String(),
              ),
            ]),
          ));

      final response =
          await SupabaseService.signUpWithEmail('new@example.com', 'password123');

      expect(response.user, isNotNull);
      verify(() => mockAuth.signUp(
            email: 'new@example.com',
            password: 'password123',
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).called(1);
    });

    test(
      'an email that already has an account (empty identities — Supabase\'s '
      'documented anti-enumeration signal) throws instead of silently '
      'succeeding — this is the exact bug that produced a real duplicate '
      'family_members row',
      () async {
        when(() => mockAuth.signUp(
              email: any(named: 'email'),
              password: any(named: 'password'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenAnswer((_) async => AuthResponse(user: _user(identities: [])));

        expect(
          () => SupabaseService.signUpWithEmail('existing@example.com', 'password123'),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            'vanshavali_email_already_registered',
          )),
        );
      },
    );

    test('null identities is also treated as already-registered (the ?? true fallback)',
        () async {
      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async => AuthResponse(user: _user(identities: null)));

      expect(
        () => SupabaseService.signUpWithEmail('existing@example.com', 'password123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('a null user (no exception from Supabase, but nothing created either) '
        'does not throw — the check only applies when a user was returned', () async {
      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async => AuthResponse(user: null));

      final response =
          await SupabaseService.signUpWithEmail('new@example.com', 'password123');
      expect(response.user, isNull);
    });
  });

  group('other auth calls — forwarded correctly to GoTrueClient', () {
    test('signInWithMagicLink calls signInWithOtp with the given email', () async {
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async {});

      await SupabaseService.signInWithMagicLink('someone@example.com');

      verify(() => mockAuth.signInWithOtp(
            email: 'someone@example.com',
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).called(1);
    });

    test('signInWithEmail forwards email and password', () async {
      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => AuthResponse(user: _user()));

      await SupabaseService.signInWithEmail('someone@example.com', 'hunter2');

      verify(() => mockAuth.signInWithPassword(
            email: 'someone@example.com',
            password: 'hunter2',
          )).called(1);
    });

    test('updatePassword calls updateUser with the new password', () async {
      when(() => mockAuth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson({'id': 'user-1'}));

      await SupabaseService.updatePassword('newPassword123');

      final captured = verify(() => mockAuth.updateUser(captureAny())).captured;
      expect(captured.single, isA<UserAttributes>());
      expect((captured.single as UserAttributes).password, 'newPassword123');
    });

    test('resetPassword forwards the email', () async {
      when(() => mockAuth.resetPasswordForEmail(
            any(),
            redirectTo: any(named: 'redirectTo'),
          )).thenAnswer((_) async {});

      await SupabaseService.resetPassword('someone@example.com');

      verify(() => mockAuth.resetPasswordForEmail(
            'someone@example.com',
            redirectTo: any(named: 'redirectTo'),
          )).called(1);
    });

    test('a thrown AuthApiException from GoTrueClient propagates, not swallowed',
        () async {
      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthApiException('Invalid login credentials'));

      expect(
        () => SupabaseService.signInWithEmail('someone@example.com', 'wrong'),
        throwsA(isA<AuthApiException>()),
      );
    });
  });
}
