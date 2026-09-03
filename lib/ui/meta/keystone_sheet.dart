
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../menu_chrome.dart';
import 'challenge_toggles.dart';
import 'gauntlet_hub_panel.dart';
import 'greater_rift_hub_panel.dart';
import 'play_games_section.dart';
import 'rift_hub_panel.dart';

/// KEYSTONE sheet (hub tab + dungeon HUD Meta entry).
class KeystoneSheet extends StatelessWidget {
  const KeystoneSheet({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final d = director;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabelScoped('KEYSTONE', scope: MenuScope.run),
          ChallengeToggles(director: d),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped('GAUNTLET', scope: MenuScope.run),
          GauntletHubPanel(director: d),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped('RIFT · farm', scope: MenuScope.run),
          RiftHubPanel(director: d),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped(
            'GREATER RIFT · prestige',
            scope: MenuScope.run,
          ),
          GreaterRiftHubPanel(director: d),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped('BOARDS', scope: MenuScope.account),
          PlayGamesBoardsSection(director: d),
        ],
      ),
    );
  }
}
