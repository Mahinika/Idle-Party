/// sessionStart: inject growth mandate so chats don't wander into AL20 default.
import 'dart:convert';
import 'dart:io';

void main() {
  final now = _nowLine();
  final context =
      'Idle Party default work this session: $now '
      'Do that unless the owner named something else. '
      'Program 3 closed 2026-09-14 (D1 paste: Play has no D1; too small to read). '
      'Wait for the next plan. Do not restore AL20 as the batch. '
      'Do not repeat the Program 3 Robban line. '
      'Forks: six studio seats (.cursor/rules/studio-seats.mdc) — EP + UX + Marketing outweigh AL20. '
      'Do not start /init or repo cleanup unprompted. '
      'Play listing/docs stay honest (play-store-prep); do not treat Play as background chores. '
      'If they paste play notes, prefer a new save / first 90s to combat; AL20 notes block ship if endgame is broken. '
      'Named leftover if they say mer endgame: KEY week affix only against play notes. '
      'After code: short phone test list (new save first), wait; no GitHub/Play upload before they play. '
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
    return 'Wait for the next plan (Program 3 closed)';
  }
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return 'Wait for the next plan (Program 3 closed)';
}
