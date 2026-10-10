import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/config/app_config.dart';

void main() {
  test('AppConfig.appVersion matches pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(AppConfig.appVersion, version);
  });
}
