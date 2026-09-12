/// sessionStart: inject growth mandate so chats don't wander into AL20 default.
import 'dart:convert';
import 'dart:io';

void main() {
  final now = _nowLine();
  final context =
      'Idle Party default work this session: $now '
      'Do that unless the owner named something else. '
      'Program: docs/GROWTH_MANDATE.md — first 15 min + Play listing/funnel. '
      'AL20 is a quality gate, not the batch. '
      'Forks: silent expert council (.cursor/rules/expert-council.mdc) — Growth GM + new-player outweigh AL20. '
      'Do not start /init or repo cleanup unprompted. '
      'Play listing/docs ARE in mandate (play-store-prep); do not treat Play as background chores. '
      'If they paste play notes, prefer a new save / first 15 min; AL20 notes block ship if endgame is broken. '
      'After code: short phone test list (new save first), wait; no GitHub/Play upload before they play. '
      'When every GROWTH_MANDATE done-bar box is checked, start the user message with exactly: '
      'ROBBAN DET BEHÖVS GÖRAS EN NY PLAN FÖR FRAMTIDEN '
      'Prefer git branch main for daily work; release/* only when cutting a tag. '
      'Do not stage windows/flutter/generated_* unless pubspec plugins changed. '
      'Live app look is the Samsung_A56 emulator (a56-playtest), not localhost web tabs.';
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
    return 'growth mandate (first 15 min + Play funnel)';
  }
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return 'growth mandate (first 15 min + Play funnel)';
}
