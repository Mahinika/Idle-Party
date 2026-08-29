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

  static final tips = <({String id, String title, String body})>[
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
      title: 'Repeat / Next',
      body:
          'Repeat stays on this floor for extra loot. Next goes deeper toward the boss.',
    ),
    (
      id: 'godhand',
      title: 'Tap the fight',
      body:
          'Tap the fist button (top bar) to smash and steer your party. Wait for '
          'the ring to refill, then tap again. You can also long-press the battlefield.',
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
          'POWER → CAMP unlocks after your first Ascend or when you earn essence. '
          'Spend essence there for idle gold and party power that persists between '
          'runs. Hub gold/min ticks at the keep overnight (enough to buy forge). '
          'Gold Find makes that number go up.',
    ),
    (
      id: 'market',
      title: 'MARKET',
      body:
          'Buy flasks in POWER → MARKET. When the bag is full, use BAG → CLEAN BAG / '
          'MERGE or SETTINGS auto-sell — there is no Sell junk button.',
    ),
    (
      id: 'forge',
      title: 'FORGE',
      body:
          'POWER → FORGE: GOLD for this-run power (×1 / % spend / EVEN split), '
          'KEEP for relics / God Hand / Blessing, '
          'APEX for forever gear. Hero levels come from combat XP (max ${GameLogic.maxHeroLevel}).',
    ),
    (
      id: 'pets',
      title: 'BEAST PEN',
      body:
          'Hatch pets with essence. Loot Sprite boosts gold find; others add ATK.',
    ),
    (
      id: 'contracts',
      title: 'QUESTS',
      body:
          'META → QUESTS pays gold and essence. '
          'Claim completes; every 3 claims grants a +5e chain bonus.',
    ),
    (
      id: 'ascend',
      title: 'ASCEND',
      body:
          'When Ascend unlocks, prestige for essence. Gear, gold, and forge '
          'reset — farm early floors in an unlocked zone to re-kit. Apex stays.',
    ),
    (
      id: 'post_ascend',
      title: 'AFTER ASCEND',
      body:
          'New kits land in PARTY — TODAY shows Meet … when something unlocked. '
          'Spend essence under Forge → KEEP (relics / God Hand) and POWER → CAMP. '
          'Apex stays.',
    ),
    (
      id: 'hardmode',
      title: 'KEYSTONE',
      body:
          'At party level ${GameLogic.maxHeroLevel}, under META → KEY pick a key level before you enter. Affixes lock in, '
          'a generous timer runs (AFK counts), and beating the boss under par upgrades your key.',
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
      title: 'INFINITY GAUNTLET',
      body:
          'At party level ${GameLogic.maxHeroLevel}, Infinity Gauntlet is an endless Crystal Spire climb from the hub. Best floor survives Ascend.',
    ),
    (
      id: 'rift',
      title: 'RIFTS',
      body:
          'At party level ${GameLogic.maxHeroLevel}, farm Rifts are timed kill challenges from the hub. Gold and gear drop during the run. Clear the quota before the timer for essence and the next tier.',
    ),
    (
      id: 'greater_rift',
      title: 'GREATER RIFTS',
      body:
          'At party level ${GameLogic.maxHeroLevel}, Greater Rifts are the prestige ladder — harder packs, no mid-run gear, and season ranks on META → KEY · BOARDS.',
    ),
    (
      id: 'ashen_crown',
      title: 'ASHEN CROWN',
      body:
          'At party level ${GameLogic.maxHeroLevel}, Ashen Crown is a weekly ticket boss under META → KEY. First ticket clear pays essence; PRACTICE is free after.',
    ),
    (
      id: 'powerups',
      title: 'POWERUPS',
      body:
          'Hub POWERUPS: watch an optional ad for 3 hours of ×2 gold and +25% ATK. Stack time up to 24h. Ads never interrupt combat.',
    ),
    (
      id: 'prestige',
      title: 'ESSENCE SHOP',
      body:
          'Essence lasts between Ascends: POWER → CAMP for sanctuary tracks, '
          'POWER → SHOP for prestige buys, Forge → KEEP for relics and God Hand.',
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
      if (tip.id == 'post_ascend' &&
          (s.ascensionLevel < 1 ||
              inDungeon ||
              // Rebuild chase owns the re-kit copy — avoid doubling AFTER ASCEND.
              GameLogic.isFreshPrestigeGear(s))) {
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
              tip.id == 'ashen_crown' ||
              tip.id == 'powerups' ||
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
      // KEYSTONE tip waits for party-max-level endgame unlock.
      if (tip.id == 'hardmode' &&
          (!GameLogic.showKeystoneJargon(s) ||
              s.effectiveMaxHardmode <= 0)) {
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
          !GameLogic.endgameUnlocked(s) &&
          !GameLogic.canEnterGauntlet(s)) {
        continue;
      }
      if (tip.id == 'rift' &&
          !GameLogic.endgameUnlocked(s) &&
          !GameLogic.canEnterRift(s)) {
        continue;
      }
      if (tip.id == 'greater_rift' &&
          !GameLogic.endgameUnlocked(s) &&
          !GameLogic.canEnterGreaterRift(s)) {
        continue;
      }
      if (tip.id == 'ashen_crown' && !GameLogic.endgameUnlocked(s)) {
        continue;
      }
      if (tip.id == 'powerups' && !porch) {
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
    final title = switch (tip.id) {
      'farm_push' when !GameLogic.plainPlayerChrome(director.state) =>
        'FARM / PUSH',
      'godhand' when !GameLogic.plainPlayerChrome(director.state) =>
        'GOD HAND',
      _ => tip.title,
    };
    final body = switch (tip.id) {
      'weekly' when GameLogic.showKeystoneJargon(director.state) =>
        'Clear 1 floor or time a KEY +2 today, then claim the vault for essence '
            '(scales with your best timed key). First claim of each month also pays a season bonus.',
      'farm_push' when GameLogic.plainPlayerChrome(director.state) => tip.body,
      'farm_push' =>
        'FARM stays on this floor for extra loot. PUSH goes deeper toward the boss.',
      'godhand' when GameLogic.plainPlayerChrome(director.state) => tip.body,
      'godhand' =>
        'God Hand: fist button (top bar). Tap it to smash and steer. Wait '
            'for the ring to refill, then tap again.',
      _ => tip.body,
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = MediaQuery.sizeOf(context).height * 0.55;
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
                          title,
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
                          style: KenneyButtonStyle.brown,
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
