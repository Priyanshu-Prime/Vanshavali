import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/config/app_config.dart';

void main() {
  test('client photo cap matches the avatars bucket limit (migration 019)', () {
    final sql =
        File('supabase/migrations/019_avatar_size_1mb.sql').readAsStringSync();
    final limit = RegExp(r'file_size_limit = (\d+)').firstMatch(sql)!.group(1);
    expect(kAvatarMaxBytes, int.parse(limit!));
  });
}
