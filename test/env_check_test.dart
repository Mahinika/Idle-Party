import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/env_check.dart';

void main() {
  test('caret and lock bounds honor the upper exclusive', () {
    final caret = parseBound('^3.11.0');
    expect(caret.allows(parseVersion('3.11.0')!), isTrue);
    expect(caret.allows(parseVersion('3.99.0')!), isTrue);
    expect(caret.allows(parseVersion('4.0.0')!), isFalse);
    expect(caret.allows(parseVersion('3.10.9')!), isFalse);

    final lock = parseBound('>=3.12.0 <4.0.0');
    expect(lock.allows(parseVersion('3.12.0')!), isTrue);
    expect(lock.allows(parseVersion('3.11.9')!), isFalse);
    expect(lock.allows(parseVersion('4.0.0')!), isFalse);
  });

  test('the repo manifest and lock parse without a hardcoded floor', () {
    final constraints = constraintsFrom(
      pubspec: File('pubspec.yaml').readAsStringSync(),
      lock: File('pubspec.lock').readAsStringSync(),
    );
    expect(constraints.packageName, 'idle_party');
    expect(constraints.dartLock.min, isNotNull);
    expect(constraints.flutterLock.min, isNotNull);
    expect(
      constraints.dartPubspec.allows(constraints.dartLock.min!),
      isTrue,
    );
    expect(
      constraints.dartPubspec.allows(constraints.dartPubspec.maxExclusive!),
      isFalse,
    );
    expect(
      constraints.flutterLock.allows(constraints.flutterLock.min!),
      isTrue,
    );
  });

  test('ready requires fresh dependencies, not only the three tools', () {
    final constraints = constraintsFrom(
      pubspec: 'name: idle_party\nenvironment:\n  sdk: ^3.11.0\n',
      lock: 'sdks:\n  dart: ">=3.12.0 <4.0.0"\n  flutter: ">=3.44.0"\n',
    );
    final stale = diagnose(
      constraints: constraints,
      flutterVersion: parseVersion('3.44.0'),
      dartVersion: parseVersion('3.12.0'),
      javaMajor: 17,
      dependenciesReady: false,
      dependencyNote: 'run flutter pub get',
    );
    expect(stale.sourceReady, isFalse);
    expect(stale.needsPubGet, isTrue);
    expect(stale.lines.join('\n'), contains('source: not ready'));

    final ready = diagnose(
      constraints: constraints,
      flutterVersion: parseVersion('3.44.0'),
      dartVersion: parseVersion('3.12.0'),
      javaMajor: null,
      dependenciesReady: true,
      dependencyNote: 'match the lock',
    );
    expect(ready.sourceReady, isTrue);
    expect(ready.lines.join('\n'), contains('java: missing'));
  });

  test('a version outside either dart bound is not ready', () {
    final constraints = constraintsFrom(
      pubspec: 'name: idle_party\nenvironment:\n  sdk: ^3.11.0\n',
      lock: 'sdks:\n  dart: ">=3.12.0 <4.0.0"\n  flutter: ">=3.44.0"\n',
    );
    final low = diagnose(
      constraints: constraints,
      flutterVersion: parseVersion('3.44.0'),
      dartVersion: parseVersion('3.11.4'),
      javaMajor: 17,
      dependenciesReady: true,
      dependencyNote: 'match the lock',
    );
    expect(low.sourceReady, isFalse);
  });

  test('package config is stale when the lock is newer', () {
    final older = DateTime.utc(2026, 11, 8, 10);
    final newer = older.add(const Duration(seconds: 1));
    expect(
      dependenciesFresh(
        packageName: 'idle_party',
        packageConfig: '{"name": "idle_party"}',
        pubspecModified: older,
        lockModified: newer,
        configModified: older,
      ),
      isFalse,
    );
    expect(
      dependenciesFresh(
        packageName: 'idle_party',
        packageConfig: '{"name": "idle_party"}',
        pubspecModified: older,
        lockModified: older,
        configModified: newer,
      ),
      isTrue,
    );
    expect(
      dependenciesFresh(
        packageName: 'idle_party',
        packageConfig: '{"name": "other"}',
        pubspecModified: older,
        lockModified: older,
        configModified: newer,
      ),
      isFalse,
    );
  });

  test('writing flutter.sdk keeps unrelated lines and the report hides them', () {
    final dir = Directory.systemTemp.createTempSync('env-check');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/local.properties')
      ..writeAsStringSync('sdk.dir=SECRET_VALUE\n');
    ensureFlutterSdkLine(file, '${dir.path}/sdk');
    final written = file.readAsStringSync();
    expect(written, contains('sdk.dir=SECRET_VALUE'));
    expect(written, contains('flutter.sdk='));
    final constraints = constraintsFrom(
      pubspec: 'name: idle_party\nenvironment:\n  sdk: ^3.11.0\n',
      lock: 'sdks:\n  dart: ">=3.12.0 <4.0.0"\n  flutter: ">=3.44.0"\n',
    );
    final report = diagnose(
      constraints: constraints,
      flutterVersion: parseVersion('3.44.0'),
      dartVersion: parseVersion('3.12.0'),
      javaMajor: 21,
      dependenciesReady: true,
      dependencyNote: 'match the lock',
    );
    expect(report.lines.join('\n'), isNot(contains('SECRET_VALUE')));
    expect(report.lines.join('\n'), isNot(contains(dir.path)));
  });

  test('flutter machine json is read and a broken blob is not guessed', () {
    const machine =
        '{"frameworkVersion":"3.44.1","dartSdkVersion":"3.12.2 (stable)"}';
    expect(versionFromFlutterMachine(machine), [3, 44, 1]);
    expect(dartFromFlutterMachine(machine), [3, 12, 2]);
    expect(javaMajorFrom('openjdk version "17.0.2" 2022-01-18'), 17);
  });
}
