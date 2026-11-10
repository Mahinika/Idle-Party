/// sessionStart: owner Now-line plus the Play and test-APK lock. Also prunes
/// old emulator shots in playshots/.
library;

import 'dart:convert';
import 'dart:io';

const _shotDir = 'playshots';
const _shotMaxAge = Duration(days: 3);
const _shotExtensions = <String>['.png', '.jpg', '.jpeg', '.xml'];

void main() {
  _pruneOldShots();
  final now = _nowLine();
  final context =
      'Idle Party this session: $now '
      'Never upload a Google Play AAB, and never push a test-* or v* tag '
      'or start an APK workflow, unless the owner asks in that turn.';
  stdout.write(
    jsonEncode(<String, dynamic>{
      'env': <String, String>{'IDLE_PARTY_FOCUS': now},
      'additional_context': context,
    }),
  );
}

String _nowLine() {
  final file = File('.cursor/rules/20-how-we-work.mdc');
  if (!file.existsSync()) {
    return _fallback;
  }
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return _fallback;
}

const _fallback =
    'Do the job named this turn. Do not start an unrelated feature. '
    'Commit locally when the checks are green. Hand off on a branch and a PR. '
    'Do not merge, do not push a test-* or v* tag, and do not upload an AAB '
    'unless the owner asks in that turn.';

void _pruneOldShots() {
  final dir = Directory(_shotDir);
  if (!dir.existsSync()) return;
  final cutoff = DateTime.now().subtract(_shotMaxAge);
  try {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.path.toLowerCase();
      if (!_shotExtensions.any(name.endsWith)) continue;
      if (entity.lastModifiedSync().isBefore(cutoff)) entity.deleteSync();
    }
    for (final sub in dir.listSync(recursive: true).whereType<Directory>()
        .toList()
        .reversed) {
      if (sub.listSync().isEmpty) sub.deleteSync();
    }
  } catch (_) {}
}
