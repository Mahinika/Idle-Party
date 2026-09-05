/// stop: if code was edited, run flutter analyze (+ changelog sync when relevant).
/// On failure, emit followup_message so the agent fixes without owner typing "fix it".
import 'dart:convert';
import 'dart:io';

const _dirtyPath = '.cursor/hooks/.verify-dirty';
const _maxOut = 3500;

Future<void> main() async {
  final raw = await stdin.transform(utf8.decoder).join();
  Map<String, dynamic> payload = <String, dynamic>{};
  try {
    payload = jsonDecode(raw.isEmpty ? '{}' : raw) as Map<String, dynamic>;
  } catch (_) {}

  final status = payload['status']?.toString() ?? '';
  if (status != 'completed') {
    _emit(<String, dynamic>{});
    return;
  }

  final dirty = File(_dirtyPath);
  if (!dirty.existsSync()) {
    _emit(<String, dynamic>{});
    return;
  }

  final dirtyText = dirty.readAsStringSync();
  final needChangelog = _touchesChangelog(dirtyText);
  final needShipSmoke = _touchesChase(dirtyText);

  final analyze = await _run(
    'flutter',
    <String>['analyze', 'lib', 'test', '--no-fatal-infos'],
  );
  if (analyze.exitCode != 0) {
    _emit(<String, dynamic>{
      'followup_message':
          'Stop-hook: flutter analyze failed. Fix the issues below, '
          're-run `flutter analyze lib test --no-fatal-infos`, then finish.\n\n'
          '${_trim(analyze.combined)}',
    });
    return;
  }

  if (needChangelog) {
    final changelog = await _run(
      'flutter',
      <String>['test', 'test/changelog_sync_test.dart'],
    );
    if (changelog.exitCode != 0) {
      _emit(<String, dynamic>{
        'followup_message':
            'Stop-hook: changelog sync test failed. Align pubspec, '
            'MetaSystems.currentVersion / What’s New, and zone mentions, '
            'then re-run `flutter test test/changelog_sync_test.dart`.\n\n'
            '${_trim(changelog.combined)}',
      });
      return;
    }
  }

  if (needShipSmoke) {
    final smoke = await _run(
      'flutter',
      <String>['test', 'test/ship_smoke_test.dart'],
    );
    if (smoke.exitCode != 0) {
      _emit(<String, dynamic>{
        'followup_message':
            'Stop-hook: ship_smoke failed. Hub TODAY / unlock / guides '
            'copy is lying. Fix ChaseContract honesty, then re-run '
            '`flutter test test/ship_smoke_test.dart`.\n\n'
            '${_trim(smoke.combined)}',
      });
      return;
    }
  }

  try {
    dirty.deleteSync();
  } catch (_) {}
  _emit(<String, dynamic>{});
}

bool _touchesChangelog(String dirtyText) {
  final t = dirtyText.toLowerCase().replaceAll('\\', '/');
  return t.contains('meta_systems.dart') ||
      t.contains('pubspec.yaml') ||
      t.contains('dungeon_def.dart') ||
      t.contains('changelog_sync');
}

bool _touchesChase(String dirtyText) {
  final t = dirtyText.toLowerCase().replaceAll('\\', '/');
  const needles = <String>[
    'hub_chase.dart',
    'chase_contract.dart',
    'hub_screen.dart',
    'game_guides.dart',
    'ascend_roadmap.dart',
    'first_session_tips.dart',
    'story_lore.dart',
    'ship_smoke_test.dart',
  ];
  for (final n in needles) {
    if (t.contains(n)) return true;
  }
  return false;
}

Future<({int exitCode, String combined})> _run(
  String exe,
  List<String> args,
) async {
  final result = await Process.run(
    exe,
    args,
    runInShell: true,
    workingDirectory: Directory.current.path,
  );
  final out = StringBuffer()
    ..write(result.stdout)
    ..write(result.stderr);
  return (exitCode: result.exitCode, combined: out.toString());
}

String _trim(String s) {
  final t = s.trim();
  if (t.length <= _maxOut) return t;
  return '${t.substring(0, _maxOut)}\n…(truncated)…';
}

void _emit(Map<String, dynamic> map) {
  stdout.write(jsonEncode(map));
}
