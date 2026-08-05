import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/story_lore.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';

/// First-session coaching tips. Persist via [GameState.seenTips].
class FirstSessionTips extends StatelessWidget {
  const FirstSessionTips({super.key, required this.director});

  final GameDirector director;

  static const _tips = <({String id, String title, String body})>[
    (
      id: 'lore_descent',
      title: StoryLore.loreTipTitle,
      body: StoryLore.loreTipBody,
    ),
    (
      id: 'godhand',
      title: 'GOD HAND',
      body:
          'Your distant will. Tap the dungeon to smash foes. Cooldown is the ring top-right.',
    ),
    (
      id: 'farm_push',
      title: 'FARM / PUSH',
      body: 'FARM loops this floor for loot. PUSH advances when you clear.',
    ),
    (
      id: 'bag',
      title: 'BAG & GEAR',
      body: 'Open BAG or GEAR to equip upgrades. Long-press a hero for gear.',
    ),
    (
      id: 'sanctuary',
      title: 'SANCTUARY',
      body:
          'Spend essence here for idle gold and party power that persists between runs.',
    ),
    (
      id: 'market',
      title: 'MARKET',
      body: 'Buy flasks and sell stash junk for gold when the bag gets full.',
    ),
    (
      id: 'forge',
      title: 'FORGE',
      body: 'Train the party and buy relics. Power here stacks with gear.',
    ),
    (
      id: 'pets',
      title: 'BEAST PEN',
      body: 'Hatch pets with essence. Loot Sprite boosts gold find; others add ATK.',
    ),
    (
      id: 'ascend',
      title: 'ASCEND',
      body:
          'When Ascend unlocks, prestige for essence. Gear resets — Farm early floors to re-kit before Pushing deep zones.',
    ),
    (
      id: 'post_ascend',
      title: 'AFTER ASCEND',
      body:
          'Gold & forge tracks wiped. Farm Sandy for gold → Forge GOLD upgrades → Market flasks. '
          'Spend essence under Forge → META (relics / God Hand). Apex mats survive.',
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
      if (tip.id == 'post_ascend' &&
          (director.state.ascensionLevel < 1 || inDungeon)) {
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
      if ((tip.id == 'sanctuary' ||
              tip.id == 'market' ||
              tip.id == 'forge' ||
              tip.id == 'pets') &&
          inDungeon) {
        continue;
      }
      if (tip.id == 'pets' &&
          director.state.ownedPets.isEmpty &&
          director.state.essence < 3) {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = MediaQuery.sizeOf(context).height * 0.42;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: DecoratedBox(
                  decoration: MenuChrome.panel(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                          primary: true,
                        ),
                        const SizedBox(height: 6),
                        KenneyButton(
                          label: 'SKIP ALL TIPS',
                          onPressed: () => director.dismissAllTips(
                            _tips.map((t) => t.id),
                          ),
                          style: KenneyButtonStyle.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
