/// sessionStart: inject current STRATEGY month so chats don't wander into /init or chores.
import 'dart:convert';
import 'dart:io';

void main() {
  final now = _nowLine();
  final context =
      'Idle Party default work this session: $now '
      'Do that unless the owner named something else. '
      'Do not start /init, repo cleanup, or Play ops unprompted. '
      'If they paste play notes (hub chase unclear, same-floor wipes, dead menus), '
      'that is the batch. After code: short phone test list, wait; no GitHub/Play before they play. '
      'Prefer git branch main for daily work; release/* only when cutting a tag. '
      'Do not stage windows/flutter/generated_* unless pubspec plugins changed.';
  stdout.write(
    jsonEncode(<String, dynamic>{
      'env': <String, String>{'IDLE_PARTY_FOCUS': now},
      'additional_context': context,
    }),
  );
}

String _nowLine() {
  final file = File('.cursor/rules/owner-preferences.mdc');
  if (!file.existsSync()) return 'monthly cadence (zones + kit polish)';
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return 'monthly cadence (zones + kit polish)';
}
