import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test APK prerelease workflow ships arm64 and x86_64', () {
    final yaml = File('.github/workflows/test-apk-prerelease.yml')
        .readAsStringSync();
    expect(yaml, contains('name: Test APK prerelease'));
    expect(yaml, contains('android-arm64,android-x64'));
    expect(yaml, contains('--split-per-abi'));
    expect(yaml, contains('idle-party-test-arm64.apk'));
    expect(yaml, contains('idle-party-test-x86_64.apk'));
    expect(yaml, contains('patch_android_test_apk.py'));
  });

  test('release Play workflow stays a default APK plus AAB', () {
    final yaml = File('.github/workflows/build-apk.yml').readAsStringSync();
    expect(yaml, contains("flutter build appbundle --release"));
    expect(yaml, contains("tags:\n      - 'v*'"));
    expect(yaml, isNot(contains('android-x64')));
    expect(yaml, isNot(contains('split-per-abi')));
  });
}
