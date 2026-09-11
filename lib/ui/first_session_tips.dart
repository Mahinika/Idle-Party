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
          'A number on GEAR means better items are waiting. Open GEAR and tap '
          'EQUIP — the party wears them. No number means nothing to do.',
    ),
    (
      id: 'sanctuary',
      title: 'ESSENCE',
      body:
          'ESSENCE unlocks after your first Ascend or when you earn essence. '
          'Spend essence there for idle gold and party power that persists between '
          'runs. Hub gold/min ticks at the keep overnight (enough to buy Gold). '
          'Gold Find makes that number go up.',
    ),
    (
      id: 'market',
      title: 'GOLD MARKET',
      body:
          'Buy flasks under GOLD → MARKET. When the bag is full, use BAG → CLEAN BAG / '
          'MERGE or SETTINGS auto-sell — there is no Sell junk button.',
    ),
    (
      id: 'forge',
      title: 'GOLD',
      body:
          'GOLD tab: TRACKS buys this-run power (×1 / % spend / EVEN split); '
          'MARKET buys flasks and listings. '
          'God Hand and Ascend Blessing live on ESSENCE → KEEP. Relics live under '
          'ESSENCE → RELICS. Craft is a row inside MORE. Hero '
          'levels come from combat XP (max ${GameLogic.maxHeroLevel}).',
    ),
    (
      id: 'pets',
      title: 'PETS',
      body:
          'Hatch pets with essence. Loot Sprite boosts gold find; others add ATK.',
    ),
    (
      id: 'contracts',
      title: 'QUESTS',
      body:
          'QUESTS (MORE) has five slots: Daily, Bounty, Side, Week, Contract. '
          'Claim completes; every 3 claims grants a +5e chain bonus.',
    ),
    (
      id: 'ascend',
      title: 'ASCEND',
      body:
          'When Ascend unlocks, claim it for essence and Ascend Blessing. '
          'Bag, wallet gold, and GOLD tracks reset — farm early floors in an unlocked zone to re-kit. Apex stays.',
    ),
    (
      id: 'post_ascend',
      title: 'AFTER ASCEND',
      body:
          'New kits land in GEAR → ROSTER — TODAY shows Meet … when something unlocked. '
          'Spend essence under ESSENCE (TRACKS + KEEP for God Hand). '
          'Relics are ESSENCE → RELICS. '
          'Apex stays.',
    ),
    (
      id: 'al20_endgame',
      title: 'AL20 VS ENDGAME',
      body:
          'Ascension cap (AL20) is not endgame. KEY, Gauntlet, Ranked GR, and Farm Rift '
          'unlock when every active hero hits Lv${GameLogic.maxHeroLevel}. '
          'TODAY will say Level the party until then. '
          'When they hit max level, a new ENDGAME act appears on the World Path past Mothveil. '
          'MORE → INFO → AL20 VS ENDGAME explains the split.',
    ),
    (
      id: 'three_dailies',
      title: 'THREE DAILIES',
      body:
          'Three different systems — not one button:\n'
          '• Daily Vault — fill 1/1, then CLAIM VAULT for essence.\n'
          '• Daily Run — one free floor for +25e.\n'
          '• Quests Daily — MORE · QUESTS board; CLAIM QUESTS when ready.\n'
          'TODAY picks one hunt at a time.',
    ),
    (
      id: 'hardmode',
      title: 'KEY',
      body:
          'At party level ${GameLogic.maxHeroLevel}, under KEY pick a key level before you enter. Affixes lock in, '
          'a generous timer runs (AFK counts), and beating the boss under par upgrades your key. '
          'Gauntlet, Ranked GR, Farm Rift, and Ashen Crown sit on the World Path ENDGAME act past Mothveil.',
    ),
    (
      id: 'weekly',
      title: 'DAILY VAULT',
      body:
          'Daily Vault (not Daily Run): clear 1 floor today, then CLAIM VAULT for essence. '
          'First claim of each month also pays a season bonus. '
          'Quests and Daily Run are separate — see THREE DAILIES tip.',
    ),
    (
      id: 'apex',
      title: 'APEX',
      body:
          'Apex slag from Gauntlet/Crystal crafts class Apex gear in MORE → CRAFT. Ranks persist through Ascend.',
    ),
    (
      id: 'endgame_act',
      title: 'ENDGAME ACT',
      body:
          'Party level ${GameLogic.maxHeroLevel} opened a new act on the World Path. '
          'Scroll past Mothveil — tap Gauntlet, Ranked GR, Farm Rift, or Ashen Crown, then ENTER. '
          'KEY still holds the dials.',
    ),
    (
      id: 'gauntlet',
      title: 'INFINITY GAUNTLET',
      body:
          'At party level ${GameLogic.maxHeroLevel}, Infinity Gauntlet is an endless Crystal Spire climb. '
          'Tap it on the World Path ENDGAME act past Mothveil, or under KEY. Best floor survives Ascend.',
    ),
    (
      id: 'rift',
      title: 'FARM RIFT',
      body:
          'At party Lv${GameLogic.maxHeroLevel}, Farm Rift is Stormwake loot farming — '
          'gold + gear mid-run. Tap RIFT on the World Path ENDGAME act, or KEY · FARM RIFT. '
          'TODAY chases it after Ranked GR. Not Spire climb.',
    ),
    (
      id: 'greater_rift',
      title: 'RANKED GR',
      body:
          'At party Lv${GameLogic.maxHeroLevel}, Ranked GR is the Mothveil prestige timer — '
          'harder packs, no mid-run gear, season ranks on KEY · BOARDS. '
          'Tap GR on the World Path ENDGAME act. TODAY chases GR before Farm Rift.',
    ),
    (
      id: 'ashen_crown',
      title: 'ASHEN CROWN',
      body:
          'At party level ${GameLogic.maxHeroLevel}, Ashen Crown is a weekly ticket boss. '
          'Tap ASHEN on the World Path ENDGAME act, or KEY. First ticket clear pays essence; PRACTICE is free after.',
    ),
    (
      id: 'powerups',
      title: 'POWERUPS',
      body:
          'Hub POWERUPS: watch an optional ad for 3 hours of ×2 gold and +25% ATK. Stack time up to 24h. Ads never interrupt combat.',
    ),
    (
      id: 'prestige',
      title: 'ESSENCE KEEP',
      body:
          'Essence lasts between Ascends: ESSENCE → TRACKS for Gold Find and power, '
          'ESSENCE → KEEP for God Hand and permanent buys, '
          'ESSENCE → RELICS for party auras, ESSENCE → PETS for pets. '
          'Bottom-tab SHOP is the real-money store (cheap boosts / ad-free on Play).',
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
              tip.id == 'three_dailies' ||
              tip.id == 'al20_endgame' ||
              tip.id == 'apex' ||
              tip.id == 'gauntlet' ||
              tip.id == 'rift' ||
              tip.id == 'greater_rift' ||
              tip.id == 'ashen_crown' ||
              tip.id == 'endgame_act' ||
              tip.id == 'powerups' ||
              tip.id == 'prestige') &&
          (inDungeon || !porch)) {
        continue;
      }
      if (tip.id == 'three_dailies' && !GameLogic.showDailyChase(s)) {
        continue;
      }
      if (tip.id == 'al20_endgame') {
        if (!GameLogic.isMaxAscension(s) || GameLogic.endgameUnlocked(s)) {
          continue;
        }
        final heroes = s.heroes;
        if (heroes.isEmpty) continue;
        final minLv = heroes.fold<int>(
          heroes.first.level,
          (m, h) => h.level < m ? h.level : m,
        );
        if (minLv < GameLogic.maxHeroLevel - 15) continue;
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
      if (tip.id == 'endgame_act' && !GameLogic.endgameUnlocked(s)) {
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
                        GameButton(
                          label: 'GOT IT',
                          onPressed: () => director.dismissTip(tip.id),
                          primary: true,
                        ),
                        const SizedBox(height: 6),
                        GameButton(
                          label: 'SKIP ALL TIPS',
                          onPressed: () =>
                              director.dismissAllTips(tips.map((t) => t.id)),
                          style: GameButtonStyle.brown,
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
