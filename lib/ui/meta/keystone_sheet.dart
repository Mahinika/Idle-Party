import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/hub_chase.dart';
import '../../core/hub_endgame_act.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import 'ashen_crown_hub_panel.dart';
import 'challenge_toggles.dart';
import 'gauntlet_hub_panel.dart';
import 'greater_rift_hub_panel.dart';
import 'play_games_section.dart';
import 'rift_hub_panel.dart';

/// KEY sheet (hub tab + dungeon HUD Meta entry).
///
/// One scroll of named hunts — no inner FARM/RANKED tabs hiding Rifts.
/// Hub ENDGAME tab is the other door to the same hunts.
class KeystoneSheet extends StatelessWidget {
  const KeystoneSheet({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final d = director;
    final chase = HubChase.forState(d.state);
    final huntHint = switch (chase.kind) {
      HubChaseKind.keystone =>
        'Hub hunt · KEY +${chase.keyLevel ?? d.state.hardmodeLevel}',
      HubChaseKind.gauntletMilestone => 'Hub hunt · Gauntlet',
      HubChaseKind.riftMilestone => 'Hub hunt · Farm Rift',
      HubChaseKind.greaterRiftMilestone => 'Hub hunt · Ranked GR',
      HubChaseKind.doneForToday => 'Hub hunt · soft rest · BOARDS',
      HubChaseKind.ashenCrown => 'Hub hunt · Ashen Crown',
      _ => '',
    };
    final hunt = HubEndgameAct.huntForChase(chase.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (huntHint.isNotEmpty) ...[
          Text(
            huntHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'PATH is the 15 caves. KEY is a timed run on those caves — this '
          'week’s pack jobs and boss tell rotate. Farm Rift is Stormwake '
          'progress + Guardian (loot), not the same hunt.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuChrome.fold(
                  title: 'KEY',
                  subtitle: 'Timed keys on PATH caves — dial then ENTER',
                  initiallyExpanded: hunt == null,
                  children: [
                    MenuChrome.sectionLabelScoped(
                      'KEY',
                      scope: MenuScope.run,
                    ),
                    ChallengeToggles(director: d, lockExpanded: true),
                  ],
                ),
                MenuChrome.fold(
                  title: 'GAUNTLET',
                  subtitle: 'Endless Spire — not a 16th cave · wipe → hub',
                  initiallyExpanded: hunt == HubEndgameHunt.gauntlet,
                  children: [
                    GauntletHubPanel(director: d),
                  ],
                ),
                MenuChrome.fold(
                  title: 'RANKED GR',
                  subtitle:
                      'Mothveil · pick GR on ENTER · clock · ranked',
                  initiallyExpanded: hunt == HubEndgameHunt.rankedGr,
                  children: [
                    GreaterRiftHubPanel(director: d),
                  ],
                ),
                MenuChrome.fold(
                  title: 'FARM RIFT',
                  subtitle:
                      'Stormwake · pick R on ENTER · gold + gear · not ranked',
                  initiallyExpanded: hunt == HubEndgameHunt.farmRift,
                  children: [
                    RiftHubPanel(director: d),
                  ],
                ),
                MenuChrome.fold(
                  title: 'ASHEN CROWN',
                  subtitle: 'Weekly ticket boss · one clear',
                  initiallyExpanded: hunt == HubEndgameHunt.ashen,
                  children: [
                    AshenCrownHubPanel(director: d),
                  ],
                ),
                MenuChrome.fold(
                  title: 'BOARDS',
                  subtitle: 'Play Games ranks',
                  initiallyExpanded: chase.kind == HubChaseKind.doneForToday,
                  children: [
                    PlayGamesBoardsSection(director: d),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
