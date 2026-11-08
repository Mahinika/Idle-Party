import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI still compiles Kotlin and does not build an APK', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('compile-kotlin'));
    expect(ci, contains('gradle :app:compileDebugKotlin'));
    expect(ci, isNot(contains('flutter build apk')));
    expect(ci, isNot(contains('flutter build appbundle')));
  });

  test('APK workflows stay on their existing triggers', () {
    final testApk = File(
      '.github/workflows/test-apk-prerelease.yml',
    ).readAsStringSync();
    expect(testApk, contains("tags:\n      - 'test-*'"));
    expect(testApk, isNot(contains("branches: [main")));

    final release = File('.github/workflows/build-apk.yml').readAsStringSync();
    expect(release, contains("tags:\n      - 'v*'"));
    expect(release, contains('workflow_dispatch'));

    final play = File('.github/workflows/play-upload.yml').readAsStringSync();
    expect(play, contains('workflow_dispatch'));
    expect(play, isNot(contains('push:')));
  });

  test('the always-on page keeps Now and drops the main-and-tag clash', () {
    final page = File('.cursor/rules/20-how-we-work.mdc').readAsStringSync();
    expect(page, contains('**Now:**'));
    expect(page, contains('test-*'));
    expect(page, contains('do not upload an AAB'));
    expect(page, isNot(contains('Daily work stays on `main`')));
    expect(page, isNot(contains('or tag when the batch needs it')));
    final now = page
        .split('\n')
        .firstWhere((line) => line.contains('**Now:**'));
    expect(now, contains('branch and a PR'));
  });

  test('the session hook still locks AAB and test APK tags', () {
    final hook = File('.cursor/hooks/session_start.dart').readAsStringSync();
    expect(hook, contains('**Now:**'));
    expect(hook, contains('test-*'));
    expect(hook, contains('v*'));
    expect(hook, contains('Google Play AAB'));
  });

  test('playtest skills do not uninstall a save to fix a signature', () {
    final a56 = File('.cursor/skills/a56-playtest/SKILL.md').readAsStringSync();
    final play = File('.cursor/skills/playtest/SKILL.md').readAsStringSync();
    expect(a56, contains('Signature mismatch'));
    expect(a56, contains('Do not `adb uninstall`'));
    expect(a56, isNot(contains('OK when the batch needs a')));
    expect(play, contains('signature mismatch'));
    expect(play, contains('Do not `adb uninstall`'));
  });

  test('the four workflow skills exist and point at live files', () {
    for (final name in [
      'env-check',
      'open-pr-overlap',
      'camera-follow',
      'handoff-proof',
    ]) {
      expect(File('.cursor/skills/$name/SKILL.md').existsSync(), isTrue);
    }
    final camera = File(
      '.cursor/skills/camera-follow/SKILL.md',
    ).readAsStringSync();
    expect(camera, isNot(contains('5c709e84')));
    expect(camera, isNot(contains('ed5b9024')));
    final overlap = File(
      '.cursor/skills/open-pr-overlap/SKILL.md',
    ).readAsStringSync();
    expect(overlap, contains('gh pr list'));
    expect(overlap, isNot(contains('fa0fa46e')));
  });
}
