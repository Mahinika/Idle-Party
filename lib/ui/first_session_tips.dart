import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/story_lore.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';

/// First-session coaching tips. Persist via [GameState.seenTips].
class FirstSessionTips extends StatelessWidget {
  const FirstSessionTips({super.key, required this.director});

  final GameDirector director;

  static const tips = <({String id, String title, String body})>[
    (
      id: 'first_run',
      title: 'TODAY',
      body:
          'This line is your next job. Tap ENTER DUNGEON. Your party fights on '
          'its own — watch them, pick up loot, get stronger, beat the first boss.',
    ),
    (
      id: 'lore_descent',
      title: StoryLore.loreTipTitle,
      body: StoryLore.loreTipBody,
    ),
    (
      id: 'farm_push',
      title: 'FARM / PUSH',
      body:
          'FARM stays on this floor for extra loot. PUSH goes deeper toward the boss.',
    ),
    (
      id: 'godhand',
      title: 'GOD HAND',
      body:
          'Tap the map once to help: smash enemies and steer the party. Wait '
          'for the ring (top-right) to refill, then tap again.',
    ),
    (
      id: 'bag',
      title: 'BAG & GEAR',
      body:
          'A number on PARTY means better items are waiting. Open PARTY and tap '
          'EQUIP — the party wears them. No number means nothing to do.',
    ),
    (
      id: 'sanctuary',
      title: 'SANCTUARY',
      body:
          'Spend essence here for idle gold and party power that persists between runs. '
          'Hub gold/min ticks at the keep overnight (enough to buy forge). '
          'Gold Find makes that number go up.',
    ),
    (
      id: 'market',
      title: 'MARKET',
      body: 'Buy flasks and sell stash junk for gold when the bag gets full.',
    ),
    (
      id: 'forge',
      title: 'FORGE',
      body:
          'POWER → FORGE: GOLD for this-run power, KEEP for relics / God Hand / Blessing, '
          'APEX for forever gear. Train levels keep on Ascend.',
    ),
    (
      id: 'pets',
      title: 'BEAST PEN',
      body:
          'Hatch pets with essence. Loot Sprite boosts gold find; others add ATK.',
    ),
    (
      id: 'contracts',
      title: 'CONTRACTS',
      body:
          'META → JOBS (or the CONTRACTS sheet) pays gold and essence. '
          'Claim completes; every 3 claims grants a +5e chain bonus.',
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
          'Clear 1 dungeon floor today, then claim the vault for essence. '
          'First claim of each month also pays a season bonus.',
    ),
    (
      id: 'apex',
      title: 'APEX FORGE',
      body:
          'Apex slag from Gauntlet/Crystal crafts class Apex gear in Forge. Ranks persist through Ascend.',
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

  /// True after the player has actually run a floor (or already Ascended).
  static bool leftPorch(GameState s) =>
      s.highestFloorCleared >= 1 ||
      s.metaDepth.lifetimeFloorClears >= 1 ||
      s.ascensionLevel >= 1;

  static String? nextTipId(GameState s, {required bool inDungeon}) {
    final seen = s.seenTips;
    final porch = leftPorch(s);
    for (final tip in tips) {
      if (seen.contains(tip.id)) continue;
      // Live combat: only God Hand + FARM/PUSH tips — avoid tip spam mid-fight.
      if (inDungeon && tip.id != 'godhand' && tip.id != 'farm_push') {
        continue;
      }
      if (tip.id == 'first_run' && inDungeon) {
        continue;
      }
      if (tip.id == 'lore_descent' && !porch) {
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
      if (tip.id == 'bag' && !inDungeon && s.gearStash.isEmpty && s.gold < 10) {
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
          (inDungeon || !porch)) {
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
      // KEYSTONE tip waits for mid-layer jargon (AL≥2 or zone 3+ cleared).
      if (tip.id == 'hardmode' &&
          (!GameLogic.showKeystoneJargon(s) ||
              s.effectiveMaxHardmode <= 0 ||
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
    final id = nextTipId(director.state, inDungeon: director.state.inDungeon);
    if (id == null) return const SizedBox.shrink();
    final tip = tips.firstWhere((t) => t.id == id);
    final body =
        tip.id == 'weekly' && GameLogic.showKeystoneJargon(director.state)
        ? 'Clear 1 floor or time a KEY +2 today, then claim the vault for essence '
              '(scales with your best timed key). First claim of each month also pays a season bonus.'
        : tip.body;

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
                          body,
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
                          onPressed: () =>
                              director.dismissAllTips(tips.map((t) => t.id)),
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
