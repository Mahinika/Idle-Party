import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import 'game_theme.dart';
import 'kenney_button.dart';

/// First-session coaching tips. Persist via [GameState.seenTips].
class FirstSessionTips extends StatelessWidget {
  const FirstSessionTips({super.key, required this.director});

  final GameDirector director;

  static const _tips = <({String id, String title, String body})>[
    (
      id: 'godhand',
      title: 'GOD HAND',
      body: 'Tap the dungeon to smash foes. Cooldown shows as a ring top-right.',
    ),
    (
      id: 'farm_push',
      title: 'FARM / PUSH',
      body: 'FARM loops this floor for loot. PUSH advances when you clear.',
    ),
    (
      id: 'bag',
      title: 'BAG & EQUIP',
      body: 'Open BAG to equip upgrades. Long-press a hero to open their gear.',
    ),
    (
      id: 'ascend',
      title: 'ASCEND',
      body: 'When Ascend unlocks in the hub, prestige for essence and keep pets.',
    ),
  ];

  String? _nextTipId() {
    final seen = director.state.seenTips;
    final inDungeon = director.state.inDungeon;
    for (final tip in _tips) {
      if (seen.contains(tip.id)) continue;
      if (tip.id == 'ascend' && !GameLogic.canAscend(director.state)) {
        continue;
      }
      if ((tip.id == 'godhand' || tip.id == 'farm_push') && !inDungeon) {
        continue;
      }
      if (tip.id == 'bag' &&
          !inDungeon &&
          director.state.gearStash.isEmpty &&
          director.state.gold < 10) {
        continue;
      }
      return tip.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _nextTipId();
    if (id == null) return const SizedBox.shrink();
    final tip = _tips.firstWhere((t) => t.id == id);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
          child: Material(
            color: const Color(0xF214110C),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: GameTheme.torchHot),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tip.title,
                    textAlign: TextAlign.center,
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixelComfort,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.body,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 14,
                      color: GameTheme.parchment,
                    ),
                  ),
                  const SizedBox(height: 10),
                  KenneyButton(
                    label: 'GOT IT',
                    onPressed: () => director.dismissTip(tip.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
