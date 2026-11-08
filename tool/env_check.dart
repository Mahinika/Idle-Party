import 'dart:convert';
import 'dart:io';

/// What the repo requires, read from the manifest and the lock.
class RepoConstraints {
  const RepoConstraints({
    required this.packageName,
    required this.dartPubspec,
    required this.dartLock,
    required this.flutterLock,
  });

  final String packageName;
  final VersionBound dartPubspec;
  final VersionBound dartLock;
  final VersionBound flutterLock;
}

class VersionBound {
  const VersionBound({this.min, this.maxExclusive});

  final List<int>? min;
  final List<int>? maxExclusive;

  bool allows(List<int> version) {
    if (min != null && _cmp(version, min!) < 0) return false;
    if (maxExclusive != null && _cmp(version, maxExclusive!) >= 0) {
      return false;
    }
    return true;
  }

  @override
  String toString() {
    final parts = <String>[];
    if (min != null) parts.add('>=${_text(min!)}');
    if (maxExclusive != null) parts.add('<${_text(maxExclusive!)}');
    return parts.isEmpty ? 'any' : parts.join(' ');
  }
}

class EnvReport {
  const EnvReport({
    required this.sourceReady,
    required this.needsPubGet,
    required this.lines,
  });

  final bool sourceReady;
  final bool needsPubGet;
  final List<String> lines;
}

/// Numbers only. Pre-release words after the third component are ignored.
List<int>? parseVersion(String raw) {
  final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(raw.trim());
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}

VersionBound parseBound(String raw) {
  final text = raw.trim().replaceAll('"', '').replaceAll("'", '');
  final caret = RegExp(r'^\^(\d+)\.(\d+)\.(\d+)$').firstMatch(text);
  if (caret != null) {
    final major = int.parse(caret.group(1)!);
    final minor = int.parse(caret.group(2)!);
    final patch = int.parse(caret.group(3)!);
    if (major > 0) {
      return VersionBound(
        min: [major, minor, patch],
        maxExclusive: [major + 1, 0, 0],
      );
    }
    if (minor > 0) {
      return VersionBound(
        min: [major, minor, patch],
        maxExclusive: [major, minor + 1, 0],
      );
    }
    return VersionBound(
      min: [major, minor, patch],
      maxExclusive: [major, minor, patch + 1],
    );
  }
  List<int>? min;
  List<int>? maxExclusive;
  for (final part in text.split(RegExp(r'\s+'))) {
    final minMatch = RegExp(r'^>=(\d+\.\d+\.\d+)$').firstMatch(part);
    final maxMatch = RegExp(r'^<(\d+\.\d+\.\d+)$').firstMatch(part);
    if (minMatch != null) min = parseVersion(minMatch.group(1)!);
    if (maxMatch != null) maxExclusive = parseVersion(maxMatch.group(1)!);
  }
  if (min == null && maxExclusive == null) {
    final plain = parseVersion(text);
    if (plain != null) min = plain;
  }
  return VersionBound(min: min, maxExclusive: maxExclusive);
}

RepoConstraints constraintsFrom({
  required String pubspec,
  required String lock,
}) {
  final name = RegExp(
    r'^name:\s*([A-Za-z0-9_]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  final environment = RegExp(
    r'^environment:\s*\n((?:[ \t].*\n)*)',
    multiLine: true,
  ).firstMatch(pubspec);
  final sdk = environment == null
      ? null
      : RegExp(r'sdk:\s*(\S+)').firstMatch(environment.group(1)!);
  final sdks = RegExp(
    r'^sdks:\s*\n(?:[ \t].*\n)*',
    multiLine: true,
  ).firstMatch(lock);
  final block = sdks?.group(0) ?? '';
  final dartLock = RegExp(
    r'dart:\s*"?([^"\n]+)"?',
  ).firstMatch(block);
  final flutterLock = RegExp(
    r'flutter:\s*"?([^"\n]+)"?',
  ).firstMatch(block);
  if (name == null || sdk == null || dartLock == null || flutterLock == null) {
    throw FormatException('manifest or lock is missing sdk bounds');
  }
  return RepoConstraints(
    packageName: name.group(1)!,
    dartPubspec: parseBound(sdk.group(1)!),
    dartLock: parseBound(dartLock.group(1)!),
    flutterLock: parseBound(flutterLock.group(1)!),
  );
}

bool dependenciesFresh({
  required String packageName,
  required String? packageConfig,
  required DateTime? pubspecModified,
  required DateTime? lockModified,
  required DateTime? configModified,
}) {
  if (packageConfig == null || configModified == null) return false;
  if (!packageConfig.contains('"name": "$packageName"') &&
      !packageConfig.contains('"name":"$packageName"')) {
    return false;
  }
  for (final input in [pubspecModified, lockModified]) {
    if (input != null && configModified.isBefore(input)) return false;
  }
  return lockModified != null && pubspecModified != null;
}

EnvReport diagnose({
  required RepoConstraints constraints,
  required List<int>? flutterVersion,
  required List<int>? dartVersion,
  required int? javaMajor,
  required bool dependenciesReady,
  required String dependencyNote,
}) {
  final lines = <String>[];
  var sourceReady = true;

  if (flutterVersion == null) {
    lines.add('flutter: missing');
    sourceReady = false;
  } else if (!constraints.flutterLock.allows(flutterVersion)) {
    lines.add(
      'flutter: ${_text(flutterVersion)} does not satisfy ${constraints.flutterLock}',
    );
    sourceReady = false;
  } else {
    lines.add('flutter: ${_text(flutterVersion)} satisfies ${constraints.flutterLock}');
  }

  final dartOk = dartVersion != null &&
      constraints.dartPubspec.allows(dartVersion) &&
      constraints.dartLock.allows(dartVersion);
  if (dartVersion == null) {
    lines.add('dart: missing');
    sourceReady = false;
  } else if (!dartOk) {
    lines.add(
      'dart: ${_text(dartVersion)} does not satisfy '
      'pubspec ${constraints.dartPubspec} and lock ${constraints.dartLock}',
    );
    sourceReady = false;
  } else {
    lines.add(
      'dart: ${_text(dartVersion)} satisfies '
      'pubspec ${constraints.dartPubspec} and lock ${constraints.dartLock}',
    );
  }

  if (!dependenciesReady) {
    lines.add('dependencies: $dependencyNote');
    sourceReady = false;
  } else {
    lines.add('dependencies: match the lock');
  }

  if (javaMajor == null) {
    lines.add('java: missing (Android compile wants 17; flutter test does not)');
  } else if (javaMajor < 17) {
    lines.add('java: $javaMajor is below 17');
  } else {
    lines.add('java: $javaMajor ok for source 17');
  }

  lines.add(sourceReady ? 'source: ready' : 'source: not ready');
  return EnvReport(
    sourceReady: sourceReady,
    needsPubGet: !dependenciesReady,
    lines: lines,
  );
}

/// Writes `flutter.sdk` only. Other lines, including secrets, stay put and
/// are never returned.
bool ensureFlutterSdkLine(File file, String sdkRoot) {
  final prior = file.existsSync() ? file.readAsStringSync() : '';
  final lines = prior.split('\n').where((line) {
    return !line.startsWith('flutter.sdk=');
  }).toList();
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  lines.add('flutter.sdk=$sdkRoot');
  file.writeAsStringSync('${lines.join('\n')}\n');
  return true;
}

int? javaMajorFrom(String text) {
  final match = RegExp(r'version "(\d+)').firstMatch(text);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

List<int>? versionFromFlutterMachine(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) return null;
  final framework = decoded['frameworkVersion'];
  if (framework is! String) return null;
  return parseVersion(framework);
}

List<int>? dartFromFlutterMachine(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) return null;
  final dart = decoded['dartSdkVersion'];
  if (dart is! String) return null;
  return parseVersion(dart);
}

Future<void> main(List<String> args) async {
  final setup = args.contains('--setup');
  final root = Directory.current;
  final pubspecFile = File('${root.path}/pubspec.yaml');
  final lockFile = File('${root.path}/pubspec.lock');
  final configFile = File('${root.path}/.dart_tool/package_config.json');
  final constraints = constraintsFrom(
    pubspec: pubspecFile.readAsStringSync(),
    lock: lockFile.readAsStringSync(),
  );
  final flutter = await _flutterVersions();
  final java = await _javaMajor();
  final fresh = dependenciesFresh(
    packageName: constraints.packageName,
    packageConfig: configFile.existsSync() ? configFile.readAsStringSync() : null,
    pubspecModified: pubspecFile.existsSync() ? pubspecFile.lastModifiedSync() : null,
    lockModified: lockFile.existsSync() ? lockFile.lastModifiedSync() : null,
    configModified: configFile.existsSync() ? configFile.lastModifiedSync() : null,
  );
  var report = diagnose(
    constraints: constraints,
    flutterVersion: flutter.flutter,
    dartVersion: flutter.dart,
    javaMajor: java,
    dependenciesReady: fresh,
    dependencyNote: fresh ? 'match the lock' : 'run flutter pub get',
  );
  if (setup && report.needsPubGet) {
    final pub = await Process.run('flutter', ['pub', 'get']);
    if (pub.exitCode != 0) {
      stdout.writeln('dependencies: flutter pub get failed');
      exitCode = 1;
      return;
    }
    final again = dependenciesFresh(
      packageName: constraints.packageName,
      packageConfig: configFile.existsSync() ? configFile.readAsStringSync() : null,
      pubspecModified: pubspecFile.lastModifiedSync(),
      lockModified: lockFile.lastModifiedSync(),
      configModified: configFile.existsSync() ? configFile.lastModifiedSync() : null,
    );
    report = diagnose(
      constraints: constraints,
      flutterVersion: flutter.flutter,
      dartVersion: flutter.dart,
      javaMajor: java,
      dependenciesReady: again,
      dependencyNote: again ? 'match the lock' : 'flutter pub get did not refresh',
    );
  }
  if (setup) {
    final wrote = _ensureSdkIfNeeded(root);
    if (wrote) stdout.writeln('flutter.sdk: wrote');
  }
  for (final line in report.lines) {
    stdout.writeln(line);
  }
  if (!report.sourceReady) exitCode = 1;
}

class _FlutterVersions {
  const _FlutterVersions({this.flutter, this.dart});
  final List<int>? flutter;
  final List<int>? dart;
}

Future<_FlutterVersions> _flutterVersions() async {
  final machine = await Process.run('flutter', ['--version', '--machine']);
  if (machine.exitCode == 0) {
    try {
      final text = machine.stdout.toString();
      final flutter = versionFromFlutterMachine(text);
      final dart = dartFromFlutterMachine(text);
      if (flutter != null && dart != null) {
        return _FlutterVersions(flutter: flutter, dart: dart);
      }
    } catch (_) {}
  }
  final plain = await Process.run('flutter', ['--version']);
  final text = '${plain.stdout}\n${plain.stderr}';
  final flutter = RegExp(r'Flutter (\d+\.\d+\.\d+)').firstMatch(text);
  final dart = RegExp(r'Dart (\d+\.\d+\.\d+)').firstMatch(text);
  return _FlutterVersions(
    flutter: flutter == null ? null : parseVersion(flutter.group(1)!),
    dart: dart == null ? null : parseVersion(dart.group(1)!),
  );
}

Future<int?> _javaMajor() async {
  final result = await Process.run('java', ['-version']);
  return javaMajorFrom('${result.stdout}\n${result.stderr}');
}

bool _ensureSdkIfNeeded(Directory root) {
  final flutter = Process.runSync('which', ['flutter']);
  if (flutter.exitCode != 0) return false;
  final bin = File(flutter.stdout.toString().trim()).absolute;
  final sdk = bin.parent.parent.path;
  if (!Directory(sdk).existsSync()) return false;
  final file = File('${root.path}/android/local.properties');
  var current = '';
  if (file.existsSync()) current = file.readAsStringSync();
  final line = RegExp(r'^flutter\.sdk=(.*)$', multiLine: true).firstMatch(current);
  if (line != null && Directory(line.group(1)!.trim()).existsSync()) {
    return false;
  }
  ensureFlutterSdkLine(file, sdk);
  return true;
}

String _text(List<int> version) => version.join('.');

int _cmp(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    final diff = a[i] - b[i];
    if (diff != 0) return diff;
  }
  return 0;
}
