/// afterFileEdit: mark repo dirty when game/docs/agent files change.
import 'dart:convert';
import 'dart:io';

const _dirtyPath = '.cursor/hooks/.verify-dirty';

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

  final dirty = File(_dirtyPath);
  dirty.parent.createSync(recursive: true);
  final normalized = path.replaceAll('\\', '/');
  final existing = dirty.existsSync() ? dirty.readAsStringSync() : '';
  if (existing.contains(normalized)) {
    stdout.write('{}');
    return;
  }
  dirty.writeAsStringSync(
    '${existing.isEmpty ? '${DateTime.now().toIso8601String()}\n' : existing}'
    '$normalized\n',
  );
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
  final p = path.toLowerCase().replaceAll('\\', '/');
  if (p.contains('/windows/flutter/generated_')) return false;
  const needles = <String>[
    '/lib/',
    '/test/',
    'pubspec.yaml',
    'agents.md',
    '/docs/play_store.md',
    '/docs/privacy.md',
    '/docs/strategy_90d.md',
    '/.cursor/rules/',
    '/.cursor/skills/',
    '/.cursor/hooks/',
  ];
  for (final n in needles) {
    if (p.contains(n)) return true;
  }
  return p.startsWith('lib/') ||
      p.startsWith('test/') ||
      p.endsWith('pubspec.yaml') ||
      p.endsWith('agents.md');
}
