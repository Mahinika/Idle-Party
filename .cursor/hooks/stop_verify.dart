/// stop: if *this chat* edited code, run flutter analyze (+ changelog sync,
/// ship smoke, or share-fast when those areas moved).
/// On failure, emit followup_message so the agent fixes without owner typing "fix it".
/// When green, nudge once if files edited in this chat are still uncommitted.
/// Other chats' edits stay on their own list.
import 'dart:convert';
import 'dart:io';

import 'verify_dirty.dart';

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

  final chatId = conversationId(payload);
  if (chatId == null) {
    _emit(<String, dynamic>{});
    return;
  }

  final dirtyPaths = dirtyPathsFor(chatId);
  if (dirtyPaths.isEmpty) {
    _emit(<String, dynamic>{});
    return;
  }

  final dirtyText = dirtyPaths.join('\n');
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

  if (_touchesGear(dirtyText)) {
    final visual = await _run(
      'flutter',
      <String>['test', 'test/visual', '--exclude-tags', 'facit'],
    );
    if (visual.exitCode != 0) {
      _emit(<String, dynamic>{
        'followup_message':
            'Stop-hook: visual tests failed after a gear edit. Fix the '
            'resolver or the asset list, then re-run '
            '`flutter test test/visual --exclude-tags facit`.\n\n'
            '${_trim(visual.combined)}',
      });
      return;
    }
    final sw = Stopwatch()..start();
    final facit = await _run(
      'py',
      <String>[
        '-3',
        'tool/check_paper_doll_facit.py',
        '--fast',
        '--no-lock',
      ],
    );
    sw.stop();
    if (sw.elapsed.inSeconds > 120) {
      _emit(<String, dynamic>{
        'followup_message':
            'Stop-hook: facit --fast took ${sw.elapsed.inSeconds}s, '
            'so it is not a stop-hook gate. Run '
            '`py -3 tool/check_paper_doll_facit.py --no-lock` once before '
            'you call the gear done.',
      });
      return;
    }
    if (facit.exitCode != 0) {
      _emit(<String, dynamic>{
        'followup_message':
            'Stop-hook: paper-doll facit failed. Fix the art and re-run '
            '`py -3 tool/check_paper_doll_facit.py --fast --no-lock`.\n\n'
            '${_trim(facit.combined)}',
      });
      return;
    }
  }

  if (_touchesKits(dirtyText)) {
    final share = await _run(
      'flutter',
      <String>['test', 'test/class_balance_share_fast_test.dart'],
    );
    if (share.exitCode != 0) {
      _emit(<String, dynamic>{
        'followup_message':
            'Stop-hook: share-fast failed after a kit or combat edit. A spec '
            'is outside the ±20% DPS share. Trim it (skill grinding-until-pass), '
            'then re-run `flutter test test/class_balance_share_fast_test.dart`.\n\n'
            '${_trim(share.combined)}',
      });
      return;
    }
  }

  clearDirtyChat(chatId);

  final pending = await _uncommitted(dirtyText);
  if (pending.isNotEmpty) {
    _emit(<String, dynamic>{
      'followup_message':
          'Stop-hook: checks are green, but files edited this batch are not '
          'committed:\n${pending.join('\n')}\n\n'
          'Commit them locally (owner-preferences), or tell the owner in one '
          'line why they stay open.',
    });
    return;
  }
  _emit(<String, dynamic>{});
}

/// Edited paths from the dirty list that git still shows as changed.
Future<List<String>> _uncommitted(String dirtyText) async {
  final root = '${Directory.current.path.replaceAll('\\', '/')}/'.toLowerCase();
  final paths = <String>{};
  for (final line in dirtyText.split('\n')) {
    var p = line.trim().replaceAll('\\', '/');
    if (p.isEmpty) continue;
    if (p.toLowerCase().startsWith(root)) p = p.substring(root.length);
    if (p.startsWith('/') || p.contains(':')) continue;
    paths.add(p);
  }
  if (paths.isEmpty) return const <String>[];
  final status = await _run(
    'git',
    <String>['status', '--porcelain', '--', ...paths],
  );
  if (status.exitCode != 0) return const <String>[];
  return status.combined
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty && !l.startsWith('warning:'))
      .toList();
}

bool _touchesChangelog(String dirtyText) {
  final t = dirtyText.toLowerCase().replaceAll('\\', '/');
  return t.contains('meta_systems.dart') ||
      t.contains('pubspec.yaml') ||
      t.contains('dungeon_def.dart') ||
      t.contains('changelog_sync');
}

bool _touchesKits(String dirtyText) {
  final t = dirtyText.toLowerCase().replaceAll('\\', '/');
  const needles = <String>[
    '/lib/models/kits/',
    'class_ability.dart',
    'ability_effects.dart',
    'kit_migrated_casts.dart',
    'spatial_combat.dart',
    'class_balance',
  ];
  for (final n in needles) {
    if (t.contains(n)) return true;
  }
  return false;
}

bool _touchesGear(String dirtyText) {
  final t = dirtyText.toLowerCase().replaceAll('\\', '/');
  const needles = <String>[
    'assets/custom/char/',
    'tool/facit/',
    'tool/gear_style.py',
    'tool/build_owned_gear_layers.py',
    'tool/author_gear_standard.py',
    'tool/check_paper_doll_facit.py',
    'lib/visual/',
  ];
  for (final n in needles) {
    if (t.contains(n)) return true;
  }
  return false;
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

Map<String, String> _processEnv() {
  final env = Map<String, String>.from(Platform.environment);
  if (!Platform.isWindows) return env;
  // flutter.bat / cmd expand %PROGRAMFILES(X86)%. Cursor's hook env
  // sometimes omits it, which fails the process before tests run.
  final x86 = env['PROGRAMFILES(X86)'] ??
      env['ProgramFiles(x86)'] ??
      r'C:\Program Files (x86)';
  env['PROGRAMFILES(X86)'] = x86;
  env['ProgramFiles(x86)'] = x86;
  return env;
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
    environment: _processEnv(),
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
