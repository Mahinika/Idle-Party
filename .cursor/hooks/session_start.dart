/// sessionStart: owner Now-line plus the Play-upload lock. Also prunes old
/// emulator shots in playshots/.
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
      'Never upload Google Play AAB unless the owner asks that turn.';
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
    'The agent picks and builds the next batch from checked facts '
    '(10-what-to-build.mdc).';

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
