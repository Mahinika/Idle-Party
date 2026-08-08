/// afterFileEdit: mark repo dirty when game/docs/agent files change.
import 'dart:convert';
import 'dart:io';

void main() async {
  final raw = await stdin.transform(utf8.decoder).join();
  Map<String, dynamic> payload = <String, dynamic>{};
  try {
    payload = jsonDecode(raw.isEmpty ? '{}' : raw) as Map<String, dynamic>;
  } catch (_) {}

  final path = _pathFrom(payload);
  if (path == null || !_shouldMark(path)) {
    stdout.write('{}');
    return;
  }

  final dirty = File('.cursor/hooks/.verify-dirty');
  dirty.parent.createSync(recursive: true);
  dirty.writeAsStringSync('${DateTime.now().toIso8601String()}\n$path\n');
  stdout.write('{}');
}

String? _pathFrom(Map<String, dynamic> payload) {
  for (final key in <String>['file_path', 'path', 'filePath', 'uri']) {
    final v = payload[key];
    if (v is String && v.isNotEmpty) return v.replaceAll('\\', '/');
  }
  final file = payload['file'];
  if (file is Map && file['path'] is String) {
    return (file['path'] as String).replaceAll('\\', '/');
  }
  return null;
}

bool _shouldMark(String path) {
  final p = path.toLowerCase();
  const needles = <String>[
    '/lib/',
    '/test/',
    'pubspec.yaml',
    'agents.md',
    '/docs/play_store.md',
    '/docs/privacy.md',
    '/.cursor/rules/',
    '/.cursor/skills/',
  ];
  for (final n in needles) {
    if (p.contains(n)) return true;
  }
  // Windows-ish relative paths without leading slash
  return p.startsWith('lib/') ||
      p.startsWith('test/') ||
      p.endsWith('pubspec.yaml') ||
      p.endsWith('agents.md');
}
