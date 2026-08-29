
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
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
          ChallengeToggles(director: d),
          const SizedBox(height: 16),
          GauntletHubPanel(director: d),
          const SizedBox(height: 16),
          RiftHubPanel(director: d),
          const SizedBox(height: 16),
          GreaterRiftHubPanel(director: d),
          const SizedBox(height: 16),
          PlayGamesBoardsSection(director: d),
        ],
      ),
    );
  }
}
