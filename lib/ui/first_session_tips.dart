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
      id: 'first_run',
      title: 'WORLD PATH',
      body:
          'Pick a zone on the World Path, then enter. Clear floors to push deeper — FARM loops a floor for loot.',
    ),
    (
      id: 'lore_descent',
      title: StoryLore.loreTipTitle,
      body: StoryLore.loreTipBody,
    ),
    (
      id: 'godhand',
      title: 'GOD HAND',
      body:
          'Your distant will. Tap the dungeon to smash foes. Cooldown is the ring top-right. '
          'Forge → KEEP: BAL / FOCUS / WIDE styles trade damage vs radius.',
    ),
    (
      id: 'farm_push',
      title: 'FARM / PUSH',
      body: 'FARM loops this floor for loot. PUSH advances when you clear.',
    ),
    (
      id: 'bag',
      title: 'BAG & GEAR',
      body:
          'Open GEAR for the paper-doll, BAG for stash. Tap an empty slot to filter the bag.',
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
      id: 'contracts',
      title: 'CONTRACTS',
      body:
          'Hub CONTRACTS pay gold and essence. Claim completes; every 3 claims grants a +5e chain bonus.',
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
          'New kits land in PARTY — TODAY shows Meet … when something unlocked. '
          'Gold & forge tracks wiped: farm Sandy → Forge GOLD → Market flasks. '
          'Spend essence under Forge → KEEP (relics / God Hand). Apex mats survive.',
    ),
    (
      id: 'hardmode',
      title: 'KEYSTONE',
      body:
          'Under KEYSTONE, pick a key level before you enter. Affixes lock in, a generous timer runs '
          '(AFK counts), and beating the boss under par upgrades your key.',
    ),
    (
      id: 'weekly',
      title: 'DAILY VAULT',
      body:
          'Clear 1 floor or time a KEY +2 today, then claim the vault for essence '
          '(scales with your best timed key). First claim of each month also pays a season bonus.',
    ),
    (
      id: 'apex',
      title: 'APEX FORGE',
      body:
          'Apex slag from Gauntlet/Crystal crafts soulbound apex gear in Forge. Ranks persist through Ascend.',
    ),
    (
      id: 'gauntlet',
      title: 'CRYSTAL SPIRE',
      body:
          'At AL10+, Infinity Gauntlet is an endless climb from the hub. Best floor survives Ascend.',
    ),
    (
      id: 'prestige',
      title: 'ESSENCE SHOP',
      body:
          'Spend essence in the Essence Shop and Forge → KEEP for relics, God Hand, and prestige power that lasts.',
    ),
  ];

  String? _nextTipId() {
    final seen = director.state.seenTips;
    final inDungeon = director.state.inDungeon;
    final s = director.state;
    for (final tip in _tips) {
      if (seen.contains(tip.id)) continue;
      // Live combat: only God Hand + FARM/PUSH tips — avoid tip spam mid-fight.
      if (inDungeon && tip.id != 'godhand' && tip.id != 'farm_push') {
        continue;
      }
      if (tip.id == 'first_run' && inDungeon) {
        continue;
      }
      if (tip.id == 'ascend' && !GameLogic.canAscend(s)) {
        continue;
      }
      if (tip.id == 'post_ascend' && (s.ascensionLevel < 1 || inDungeon)) {
        continue;
      }
      if ((tip.id == 'godhand' || tip.id == 'farm_push') && !inDungeon) {
        continue;
      }
      if (tip.id == 'bag' &&
          !inDungeon &&
          s.gearStash.isEmpty &&
          s.gold < 10) {
        continue;
      }
      if ((tip.id == 'sanctuary' ||
              tip.id == 'market' ||
              tip.id == 'forge' ||
              tip.id == 'pets' ||
              tip.id == 'contracts' ||
              tip.id == 'hardmode' ||
              tip.id == 'weekly' ||
              tip.id == 'apex' ||
              tip.id == 'gauntlet' ||
              tip.id == 'prestige') &&
          inDungeon) {
        continue;
      }
      if (tip.id == 'pets' && s.ownedPets.isEmpty && s.essence < 3) {
        continue;
      }
      if (tip.id == 'contracts' &&
          s.missions.isEmpty &&
          s.highestFloorCleared < 1 &&
          s.metaDepth.lifetimeFloorClears < 1) {
        continue;
      }
      if (tip.id == 'hardmode' &&
          (s.effectiveMaxHardmode <= 0 ||
              (s.highestDungeonCleared < 0 && s.ascensionLevel < 1))) {
        continue;
      }
      if (tip.id == 'weekly' &&
          s.highestFloorCleared < 1 &&
          s.metaDepth.lifetimeFloorClears < 1 &&
          s.ascensionLevel < 1) {
        continue;
      }
      if (tip.id == 'apex' &&
          s.ascensionLevel < 1 &&
          s.craftMaterials.isEmpty &&
          s.apexVault.isEmpty) {
        continue;
      }
      if (tip.id == 'gauntlet' &&
          s.ascensionLevel < GameLogic.gauntletMinAscension &&
          !GameLogic.canEnterGauntlet(s)) {
        continue;
      }
      if (tip.id == 'prestige' &&
          s.ascensionLevel < 1 &&
          s.essence < 1 &&
          s.unlockedRelics.isEmpty) {
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
                          style: GameTheme.menuTitle(size: 16),
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
