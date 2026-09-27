// Regression: first-time profile photo upload always failed because it ran
// before the family_members row existed (storage RLS, migration 016, checks
// can_edit_family_member on the path's member id). The row must be created
// first, then the photo uploaded and attached.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/auth_provider.dart';
import 'package:vanshavali/screens/profile/profile_form_screen.dart';

class _FakeAuth extends AuthProvider {
  _FakeAuth({this.createOk = true}) : super.forTesting();
  final bool createOk;
  final log = <String>[];
  FamilyMember? updated;

  @override
  Future<bool> createProfile(FamilyMember member) async {
    log.add('create:${member.id}');
    return createOk;
  }

  @override
  Future<bool> updateProfile(FamilyMember member) async {
    log.add('update');
    updated = member;
    return true;
  }
}

final _member = FamilyMember(
  id: 'm1',
  createdAt: DateTime(2020, 1, 1),
  firstNameEn: 'New',
  lastNameEn: 'Person',
);
final _bytes = Uint8List.fromList([1, 2, 3]);

void main() {
  test('creates the row BEFORE uploading, then attaches the avatar url',
      () async {
    final auth = _FakeAuth();
    final r = await createProfileThenUploadAvatar(auth, _member, _bytes,
        upload: (id, _) async {
      auth.log.add('upload:$id');
      return 'https://x/$id/avatar.jpg';
    });

    expect(auth.log, ['create:m1', 'upload:m1', 'update']);
    expect(auth.updated!.avatarUrl, 'https://x/m1/avatar.jpg');
    expect(r.saved, isTrue);
    expect(r.photoFailed, isFalse);
  });

  test('no upload when creation fails', () async {
    final auth = _FakeAuth(createOk: false);
    final r = await createProfileThenUploadAvatar(auth, _member, _bytes,
        upload: (id, _) async {
      auth.log.add('upload');
      return '';
    });

    expect(auth.log, ['create:m1']);
    expect(r.saved, isFalse);
  });

  test('upload failure keeps the saved profile and reports photoFailed',
      () async {
    final auth = _FakeAuth();
    final r = await createProfileThenUploadAvatar(auth, _member, _bytes,
        upload: (_, _) async => throw Exception('rls'));

    expect(auth.log, ['create:m1']);
    expect(r.saved, isTrue);
    expect(r.photoFailed, isTrue);
  });

  test('no photo picked: just creates', () async {
    final auth = _FakeAuth();
    final r = await createProfileThenUploadAvatar(auth, _member, null);
    expect(auth.log, ['create:m1']);
    expect(r, (saved: true, photoFailed: false));
  });
}
