import 'package:flutter/material.dart';

import '../../core/ashen_crown.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../shell/shell_layout.dart';

/// KEY tab: weekly Ashen Crown ticket + PRACTICE.
class AshenCrownHubPanel extends StatelessWidget {
  const AshenCrownHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return ShellLayout.hint(
        '${AshenCrown.name} unlocks when every active hero is Lv${GameLogic.maxHeroLevel} — '
        'weekly ticket boss (enter from the hub ENDGAME tab too).',
        maxLines: 3,
      );
    }
    final week = AshenCrown.ensureWeek(state);
    final tickets = week.metaDepth.worldBossTickets;
    final cleared = week.metaDepth.worldBossClearedWeek;
    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellLayout.sectionHeader('ASHEN CROWN · WEEKLY'),
        ShellLayout.gap(4),
        ShellLayout.hint(
          cleared
              ? 'Paid clear done this week. PRACTICE is free — no ticket, no essence.\n'
                  '${AshenCrown.kitFor().weekLine}'
              : '${AshenCrown.kitFor().weekLine} First clear pays '
                  '+${AshenCrown.essenceReward}e, title ${AshenCrown.titleReward}, '
                  '+1 STAR. Tickets left: $tickets. '
                  'Wipe or leave returns the ticket.',
          maxLines: 5,
        ),
        ShellLayout.gap(8),
        GameButton(
          label: 'ENTER ASHEN CROWN',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: !cleared && AshenCrown.ticketRunAllowed(week)
              ? () => confirmAshenCrown(context, director, practice: false)
              : null,
        ),
        ShellLayout.gap(4),
        GameButton(
          label: 'PRACTICE',
          style: GameButtonStyle.grey,
          onPressed: AshenCrown.canEnter(state)
              ? () => confirmAshenCrown(context, director, practice: true)
              : null,
        ),
      ],
    ),
    );
  }
}
