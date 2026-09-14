/// sessionStart: inject growth mandate so chats don't wander into AL20 default.
import 'dart:convert';
import 'dart:io';

void main() {
  final now = _nowLine();
  final context =
      'Idle Party default work this session: $now '
      'Do that unless the owner named something else. '
      'No standing program. Owner names the work (or clear batch). '
      'Do not restore AL20 as the batch. Do not invent numbered programs. '
      'Hard locks only (product-locks). Ask-first for zone/class/God Hand/UA/push/Play/wipe-save removed. '
      'UX flat-nav / hide-until-unlock / ≤90s are guidance, not hard stops. '
      'Forks: six studio seats (.cursor/rules/studio-seats.mdc). '
      'Do not start /init or repo cleanup unprompted. '
      'Play listing/docs stay honest (play-store-prep). '
      'If they paste play notes, prefer a new save; AL20 notes block ship if endgame is broken. '
      'After code: short phone test list (new save first), wait. '
      'Commit locally when green; push/PR/tag/Play when the batch needs it (no ask-first). '
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
    return 'Owner names the work (no standing program)';
  }
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    final marker = '**Now:**';
    if (t.contains(marker)) {
      final i = t.indexOf(marker);
      return t.substring(i + marker.length).trim();
    }
  }
  return 'Owner names the work (no standing program)';
}
