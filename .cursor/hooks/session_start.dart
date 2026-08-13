/// sessionStart: inject current STRATEGY month so chats don't wander into /init or chores.
import 'dart:convert';
import 'dart:io';

void main() {
  final now = _nowLine();
  final context =
      'Idle Party default work this session: $now '
      'Do that unless the owner named something else. '
      'Do not start /init, repo cleanup, Play ops, new zones, or new specs unprompted. '
      'If they paste play notes (TODAY felt wrong, did not know what to chase), '
      'that is the batch — fix ChaseContract / hub / tips. '
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
  if (!file.existsSync()) return 'Month 1 (chase / first hour)';
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return 'Month 1 (chase / first hour)';
}
