import 'package:flutter/material.dart';

import '../../core/ashen_crown.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// KEY tab: weekly Ashen Crown ticket + PRACTICE.
class AshenCrownHubPanel extends StatelessWidget {
  const AshenCrownHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        '${AshenCrown.name} unlocks at party level ${GameLogic.maxHeroLevel} — '
        'weekly ticket boss (enter from the hub ENDGAME tab too).',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final week = AshenCrown.ensureWeek(state);
    final tickets = week.metaDepth.worldBossTickets;
    final cleared = week.metaDepth.worldBossClearedWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ASHEN CROWN · WEEKLY',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          cleared
              ? 'Paid clear done this week. PRACTICE is free — no ticket, no essence.\n'
                  '${AshenCrown.kitFor().weekLine}'
              : '${AshenCrown.kitFor().weekLine} First clear pays '
                  '+${AshenCrown.essenceReward}e. Tickets left: $tickets. '
                  'Wipe or leave returns the ticket.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER ASHEN CROWN',
          style: GameButtonStyle.red,
          onPressed: !cleared && AshenCrown.ticketRunAllowed(week)
              ? () => confirmAshenCrown(context, director, practice: false)
              : null,
        ),
        const SizedBox(height: 4),
        GameButton(
          label: 'PRACTICE',
          style: GameButtonStyle.grey,
          onPressed: AshenCrown.canEnter(state)
              ? () => confirmAshenCrown(context, director, practice: true)
              : null,
        ),
      ],
    );
  }
}
