/// sessionStart: owner Now-line plus the Play-upload lock.
import 'dart:convert';
import 'dart:io';

void main() {
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
  final file = File('.cursor/rules/owner-preferences.mdc');
  if (!file.existsSync()) {
    return 'Owner names the work (no standing program).';
  }
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return 'Owner names the work (no standing program).';
}
