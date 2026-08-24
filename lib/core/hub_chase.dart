import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/hero_spec.dart';
import '../models/meta_depth.dart';
import 'ascend_roadmap.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hero_identity.dart';
import 'keystone.dart';
import 'local_season.dart';
import 'market_listings_service.dart';
import 'menu_alerts.dart';
import 'meta_systems.dart';
import 'rift.dart';
import 'greater_rift.dart';

/// Kind of hub "today" chase — claimables first, then progress goals.
enum HubChaseKind {
  /// Daily vault ready to claim ([GameLogic.claimDailyVault]).
  claimDailyVault,
  claimMissions,

  /// Month season pass ready to claim.
  monthGoal,

  /// Newly unlocked kit waiting for PARTY meet / acknowledge.
  meetHero,

  /// Better gear already in BAG — equip before farming or buying.
  equipBag,

  /// Affordable UPGRADE on POWER → MARKET when drops miss a slot.
  marketUpgrade,
  ascend,
  dailyVaultProgress,
  willRank,
  gauntletMilestone,
  riftMilestone,
  greaterRiftMilestone,
  unlockZone,
  dailyRun,

  /// Next KEY run after the first hour (habit until KEY dial cap).
  keystone,
  clearFloors,
  weekGoal,
}

/// How close the chase is to a payoff — drives TODAY chrome.
enum HubChaseUrgency {
  /// Keep grinding.
  normal,

  /// One push / few points away — highlight ALMOST.
  almost,

  /// Claim / Ascend ready now.
  ready,
}

/// One plain English chase line for the hub TODAY card.
class HubChase {
  const HubChase({
    required this.kind,
    required this.title,
    required this.detail,
    this.progressLabel,
    this.urgency = HubChaseUrgency.normal,
    this.zoneId,
    this.keyLevel,
  });

  final HubChaseKind kind;
  final String title;
  final String detail;
  final String? progressLabel;
  final HubChaseUrgency urgency;

  /// Target zone id for [HubChaseKind.unlockZone] / clear pushes.
  final String? zoneId;

  /// Preferred KEY to set on ENTER for [HubChaseKind.keystone].
  final int? keyLevel;

  /// Picks the single best "what should I chase now?" target.
  ///
  /// Priority: claimables → Ascend → almost-Ascend → vault / KEY cliffs →
  /// first hour → KEY habit → daily → vault start → zone → Will → Gauntlet →
  /// keep clearing.
  static HubChase forState(GameState state, {DateTime? now}) {
    final md = state.metaDepth;
    final clock = now ?? DateTime.now().toUtc();

    if (GameLogic.canClaimDailyVault(state)) {
      final best = md.dailyBestTimedKey;
      final month = GameLogic.isoMonthKey(clock);
      final seasonPending = !md.claimedSeasonRewards.contains(month);
      final seasonBit = seasonPending
          ? ' · season +${GameLogic.seasonWeeklyBonusEssence}e'
          : '';
      final keyTalk = GameLogic.showKeystoneJargon(state);
      return HubChase(
        kind: HubChaseKind.claimDailyVault,
        title: seasonPending
            ? 'Claim daily vault · season bonus'
            : 'Claim daily vault',
        detail: best >= 2 && keyTalk
            ? 'Best timed KEY +$best — grab your essence$seasonBit.'
            : 'You filled today’s vault — grab your essence$seasonBit.',
        progressLabel: best >= 2 && keyTalk
            ? 'KEY +$best ready'
            : '${GameLogic.dailyVaultClearTarget}/${GameLogic.dailyVaultClearTarget} ready',
        urgency: HubChaseUrgency.ready,
      );
    }

    final completeMissions = state.missions.where((m) => m.canClaim).length;
    if (completeMissions > 0) {
      return HubChase(
        kind: HubChaseKind.claimMissions,
        title: completeMissions == 1
            ? 'Claim quest reward'
            : 'Claim quest rewards',
        detail: 'Finished quests wait under META → QUESTS.',
        progressLabel: '$completeMissions ready',
        urgency: HubChaseUrgency.ready,
      );
    }

    final monthPass = _monthPassChase(state, clock);
    if (monthPass != null) return monthPass;

    final meet = _pendingMeetChase(state);
    if (meet != null) return meet;

    final bagEquip = _equipBagChase(state);
    if (bagEquip != null) return bagEquip;

    final market = _marketUpgradeChase(state);
    if (market != null) return market;

    if (GameLogic.canAscend(state)) {
      final reward =
          GameLogic.ascendEssenceReward(state.ascensionLevel + 1) +
          MetaSystems.ascendMilestoneReward(
            state.ascensionLevel,
            state.ascensionLevel + 1,
          );
      final nextAl = state.ascensionLevel + 1;
      final unlock = AscendRoadmap.unlockAtAl(nextAl);
      final unlockBit = unlock != null ? ' · AL$nextAl unlocks $unlock' : '';
      return HubChase(
        kind: HubChaseKind.ascend,
        title: 'Ascend for lasting power',
        detail:
            '+${reward}e · Blessing +${GameLogic.ascendBlessingAtk} ATK/'
            '+${GameLogic.ascendBlessingDef} DEF/'
            '+${GameLogic.ascendBlessingVit} STA/'
            '+${GameLogic.ascendBlessingGoldPct}% gold$unlockBit',
        progressLabel: 'Ready',
        urgency: HubChaseUrgency.ready,
      );
    }

    final bossesNeed = GameLogic.bossesRequiredForAscension(
      state.ascensionLevel,
    );
    final bossesLeft = (bossesNeed - state.bossVictories).clamp(0, bossesNeed);
    // Only "almost" once you've banked progress (AL0 needs 1 boss total —
    // 0/1 is the start of the game, not a cliffhanger).
    final almostAscend = bossesLeft == 1 && state.bossVictories > 0;
    if (almostAscend) {
      return _ascendPushChase(
        state,
        bossesNeed: bossesNeed,
        bossesLeft: bossesLeft,
        urgency: HubChaseUrgency.almost,
      );
    }

    // KEY +1 timed but not yet claimable (need KEY +2) — cliffhanger.
    // Only after KEY unlocks (party at max level).
    if (GameLogic.showKeystoneJargon(state) &&
        !md.dailyVaultClaimed &&
        md.dailyVaultClears < GameLogic.dailyVaultClearTarget &&
        md.dailyBestTimedKey == 1) {
      return const HubChase(
        kind: HubChaseKind.dailyVaultProgress,
        title: 'Almost — time KEY +2',
        detail: 'Best timed KEY +1 today — one higher key fills the vault.',
        progressLabel: 'KEY +1',
        urgency: HubChaseUrgency.almost,
      );
    }

    // Other ALMOST cliffs beat Daily / vault-start grind (see CHASE_CONTRACT.md).
    final zoneAlmost = _nextZoneChase(state);
    if (zoneAlmost != null && zoneAlmost.urgency == HubChaseUrgency.almost) {
      return zoneAlmost;
    }
    final willAlmost = _nextWillChase(state);
    if (willAlmost != null && willAlmost.urgency == HubChaseUrgency.almost) {
      return willAlmost;
    }
    final gauntletAlmost = _nextGauntletChase(state);
    if (gauntletAlmost != null &&
        gauntletAlmost.urgency == HubChaseUrgency.almost) {
      return gauntletAlmost;
    }
    final riftAlmost = _nextRiftChase(state);
    if (riftAlmost != null && riftAlmost.urgency == HubChaseUrgency.almost) {
      return riftAlmost;
    }
    final grAlmost = _nextGreaterRiftChase(state);
    if (grAlmost != null && grAlmost.urgency == HubChaseUrgency.almost) {
      return grAlmost;
    }
    final weekAlmostEarly = _weekGoalChase(state, clock, almostOnly: true);
    if (weekAlmostEarly != null) return weekAlmostEarly;

    // First hour: grow the party in the starter zone. Daily / vault / Will
    // / KEY grind wait until a boss (or first Ascend) so TODAY is not a meta list.
    final firstHour = !GameLogic.showDailyChase(state);
    if (firstHour) {
      return _ascendPushChase(
        state,
        bossesNeed: bossesNeed,
        bossesLeft: bossesLeft,
        urgency: HubChaseUrgency.normal,
      );
    }

    // Near endgame: level the party to max before KEY / Gauntlet / Rifts.
    final levelPush = _partyLevelChase(state);
    if (levelPush != null) return levelPush;

    // Habit after the first hour: chase the next KEY until the dial cap.
    final keyPush = _keystonePushChase(state);
    if (keyPush != null) return keyPush;

    if (!MetaSystems.isDailyClaimedToday(state, now: clock)) {
      return const HubChase(
        kind: HubChaseKind.dailyRun,
        title: 'Run today’s Daily',
        detail: 'A short echo dungeon — clear it for bonus essence.',
        progressLabel: 'Available',
      );
    }

    if (!md.dailyVaultClaimed &&
        md.dailyVaultClears == 0 &&
        md.dailyBestTimedKey < 2) {
      final keyTalk = GameLogic.showKeystoneJargon(state);
      return HubChase(
        kind: HubChaseKind.dailyVaultProgress,
        title: 'Start daily vault',
        detail: keyTalk
            ? 'Clear ${GameLogic.dailyVaultClearTarget} floor or time a KEY +2.'
            : 'Clear ${GameLogic.dailyVaultClearTarget} dungeon floor for vault essence.',
        progressLabel: '0/${GameLogic.dailyVaultClearTarget}',
      );
    }

    // Progress grind: zone / Will / Gauntlet / week (normal or leftover almost).
    final zone = _nextZoneChase(state);
    if (zone != null) return zone;

    final will = _nextWillChase(state);
    if (will != null) return will;

    final gauntlet = _nextGauntletChase(state);
    if (gauntlet != null) return gauntlet;

    final rift = _nextRiftChase(state);
    if (rift != null) return rift;

    final greaterRift = _nextGreaterRiftChase(state);
    if (greaterRift != null) return greaterRift;

    final weekAlmost = _weekGoalChase(state, clock, almostOnly: true);
    if (weekAlmost != null) return weekAlmost;

    final weekGoal = _weekGoalChase(state, clock, almostOnly: false);
    if (weekGoal != null) return weekGoal;

    return _ascendPushChase(
      state,
      bossesNeed: bossesNeed,
      bossesLeft: bossesLeft,
      urgency: bossesLeft == 1 && state.bossVictories > 0
          ? HubChaseUrgency.almost
          : HubChaseUrgency.normal,
    );
  }

  static HubChase? _equipBagChase(GameState state) {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    if (upgrades <= 0) return null;
    return HubChase(
      kind: HubChaseKind.equipBag,
      title: upgrades == 1 ? 'Equip upgrade in PARTY' : 'Equip upgrades in PARTY',
      detail: upgrades == 1
          ? '1 better item in BAG — tap EQUIP before you farm deeper.'
          : '$upgrades better items in BAG — tap EQUIP before you farm deeper.',
      progressLabel: upgrades == 1 ? 'EQUIP 1' : 'EQUIP $upgrades',
      urgency: HubChaseUrgency.ready,
    );
  }

  static HubChase? _marketUpgradeChase(GameState state) {
    final listing = MarketListingsService.bestAffordableUpgradeListing(state);
    if (listing == null) return null;
    final slot = listing.slot.name.toUpperCase().replaceAll('_', '-');
    return HubChase(
      kind: HubChaseKind.marketUpgrade,
      title: 'Buy MARKET upgrade',
      detail:
          '${listing.item.name} · $slot · ${listing.priceGold}g — listings beat bad drops.',
      progressLabel: 'MARKET',
      urgency: HubChaseUrgency.almost,
    );
  }

  static HubChase? _pendingMeetChase(GameState state) {
    final pending = state.metaDepth.pendingHeroReveals;
    if (pending.isEmpty) return null;
    final specs = <HeroSpecId>[
      for (final name in pending) ?HeroIdentity.tryParseSpec(name),
    ];
    if (specs.isEmpty) return null;
    final first = specs.first;
    final def = HeroSpecs.def(first);
    final extra = specs.length - 1;
    return HubChase(
      kind: HubChaseKind.meetHero,
      title: extra > 0 ? 'Meet ${def.name} · +$extra' : 'Meet ${def.name}',
      detail: '${HeroIdentity.meetDetail(first)} Open PARTY to field them.',
      progressLabel: 'New',
      urgency: HubChaseUrgency.ready,
    );
  }

  static HubChase? _monthPassChase(GameState state, DateTime clock) {
    final monthKey = state.metaDepth.monthPassKey.isNotEmpty
        ? state.metaDepth.monthPassKey
        : GameLogic.isoMonthKey(clock);
    final month = LocalSeasonCatalog.forMonthKey(monthKey);
    if (!LocalSeasonCatalog.monthPassReady(state, month)) {
      if (LocalSeasonCatalog.monthPassAlmost(state, month)) {
        return HubChase(
          kind: HubChaseKind.monthGoal,
          title: 'Almost · ${month.name}',
          detail: 'Finish the month pass for +${month.essenceReward}e.',
          progressLabel: LocalSeasonCatalog.monthProgressLabel(state, month),
          urgency: HubChaseUrgency.almost,
        );
      }
      return null;
    }
    return HubChase(
      kind: HubChaseKind.monthGoal,
      title: 'Claim ${month.name}',
      detail: 'Month pass ready · +${month.essenceReward}e.',
      progressLabel: LocalSeasonCatalog.monthProgressLabel(state, month),
      urgency: HubChaseUrgency.ready,
    );
  }

  static HubChase? _weekGoalChase(
    GameState state,
    DateTime clock, {
    required bool almostOnly,
  }) {
    final weekKey = state.metaDepth.weeklyKey.isNotEmpty
        ? state.metaDepth.weeklyKey
        : GameLogic.isoWeekKey(clock);
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    if (!week.hasGoal) return null;
    // KEY-only weeks stay quiet until party-max-level endgame unlock.
    if (week.timedKeyTarget > 0 &&
        week.gauntletFloorTarget <= 0 &&
        !GameLogic.endgameUnlocked(state)) {
      return null;
    }
    if (LocalSeasonCatalog.weekGoalClaimed(state, week)) return null;
    if (LocalSeasonCatalog.weekGoalReady(state, week)) return null;

    if (LocalSeasonCatalog.weekGoalAlmost(state, week)) {
      return HubChase(
        kind: HubChaseKind.weekGoal,
        title: 'Almost · ${week.name}',
        detail: '${week.blurb} · +${week.essenceReward}e',
        progressLabel: LocalSeasonCatalog.weekProgressLabel(state, week),
        urgency: HubChaseUrgency.almost,
      );
    }

    if (almostOnly) return null;

    return HubChase(
      kind: HubChaseKind.weekGoal,
      title: week.name,
      detail: '${week.blurb} · +${week.essenceReward}e',
      progressLabel: LocalSeasonCatalog.weekProgressLabel(state, week),
    );
  }

  /// Next KEY after endgame unlock, until preferred key hits the dial cap.
  static HubChase? _keystonePushChase(GameState state) {
    if (!GameLogic.endgameUnlocked(state)) return null;
    final cap = Keystone.maxForState(state);
    if (cap <= 0) return null;
    final pref = state.hardmodeLevel.clamp(0, cap);
    if (pref >= cap) return null;
    final target = pref <= 0 ? 1 : pref;
    final firstKey = pref <= 0;
    return HubChase(
      kind: HubChaseKind.keystone,
      title: firstKey ? 'Run KEY +1' : 'Time KEY +$target',
      detail: firstKey
          ? 'Higher keys drop higher iLvl loot and pay more gold — start with KEY +1.'
          : 'Time KEY +$target for better iLvl, more gold, and the next key unlock.',
      progressLabel: 'KEY +$target',
      keyLevel: target,
      zoneId: GameLogic.recommendedDungeonId(state),
    );
  }

  /// Level the party toward [GameLogic.maxHeroLevel] near Ascension cap.
  static HubChase? _partyLevelChase(GameState state) {
    if (GameLogic.endgameUnlocked(state)) return null;
    final heroes = state.heroes;
    if (heroes.isEmpty) return null;
    final minLv = heroes.fold<int>(heroes.first.level, (m, h) => min(m, h.level));
    final maxLv = heroes.fold<int>(heroes.first.level, (m, h) => max(m, h.level));
    final near =
        GameLogic.isMaxAscension(state) || minLv >= (GameLogic.maxHeroLevel - 15);
    if (!near) return null;
    final need = GameLogic.maxHeroLevel - minLv;
    final almost = need <= 5 && minLv > 0;
    return HubChase(
      kind: HubChaseKind.clearFloors,
      title: almost
          ? 'Almost party Lv${GameLogic.maxHeroLevel}'
          : 'Level the party to ${GameLogic.maxHeroLevel}',
      detail: almost
          ? 'Lowest hero Lv$minLv — a few more levels unlock KEY, Gauntlet, and Rifts.'
          : 'Heroes Lv$minLv–$maxLv. Combat XP to ${GameLogic.maxHeroLevel} unlocks '
              'KEY, Gauntlet, and Rifts.',
      progressLabel: 'Lv$minLv/${GameLogic.maxHeroLevel}',
      urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      zoneId: GameLogic.recommendedDungeonId(state),
    );
  }

  static HubChase _ascendPushChase(
    GameState state, {
    required int bossesNeed,
    required int bossesLeft,
    required HubChaseUrgency urgency,
  }) {
    if (GameLogic.isMaxAscension(state)) {
      final levelChase = _partyLevelChase(state);
      if (levelChase != null) return levelChase;
      return _endgamePushChase(state);
    }
    final dungeonId = GameLogic.recommendedDungeonId(state);
    final dungeon = DungeonCatalog.byId(dungeonId);
    final kitTeaser = AscendRoadmap.nextMissingKitTeaser(state);
    final teaser = kitTeaser ?? AscendRoadmap.chaseTeaser(state.ascensionLevel);
    final almost = urgency == HubChaseUrgency.almost;
    final firstHour =
        state.ascensionLevel == 0 && state.bossVictories == 0 && !almost;
    return HubChase(
      kind: HubChaseKind.clearFloors,
      title: almost
          ? 'Almost Ascend — push ${dungeon.name}'
          : firstHour
          ? 'Grow the party — ${dungeon.name}'
          : 'Push ${dungeon.name}',
      detail: firstHour
          ? 'Enter the cave. Your party fights on its own. Get stronger and beat the boss.'
          : bossesLeft > 0
          ? (almost
                ? '1 boss left · then Ascend. $teaser'
                : 'Clear bosses toward Ascend ($bossesLeft left). $teaser')
          : 'Farm gear or push deeper for power. $teaser',
      progressLabel: 'Ascend ${state.bossVictories}/$bossesNeed',
      urgency: urgency,
      zoneId: dungeonId,
    );
  }

  /// Party at max level — no more Ascend; chase KEY / Gauntlet / Rift / Greater / vault.
  static HubChase _endgamePushChase(GameState state) {
    final md = state.metaDepth;
    final cap = state.effectiveMaxHardmode;
    final pref = state.hardmodeLevel.clamp(0, cap);
    final gauntlet = md.gauntletBestFloor;
    final rift = md.riftBestTier;
    final gr = md.grBestTier;
    final timed = md.seasonBestTimedKey;
    final timedBit = timed > 0 ? 'Best timed KEY +$timed · ' : '';
    return HubChase(
      kind: HubChaseKind.clearFloors,
      title: 'Party Lv${GameLogic.maxHeroLevel} endgame',
      detail:
          '${timedBit}Gauntlet F$gauntlet · Rift R$rift · GR$gr · vault · boards · '
          'Blessing ×${md.ascendBlessings}',
      progressLabel: 'KEY +$pref · G F$gauntlet · R$rift · GR$gr',
      zoneId: GameLogic.recommendedDungeonId(state),
    );
  }

  static HubChase? _nextWillChase(GameState state) {
    final score = state.collectionScore;
    for (final entry in WillRanks.thresholds) {
      final threshold = entry.$1;
      if (threshold <= 0 || score >= threshold) continue;
      final need = threshold - score;
      final almost = need <= 3;
      final pay = WillRanks.essenceForThreshold(threshold);
      return HubChase(
        kind: HubChaseKind.willRank,
        title: almost ? 'Almost ${entry.$2}' : 'Chase ${entry.$2}',
        detail: need == 1
            ? '1 collection point to ${entry.$2} (+${pay}e).'
            : '$need collection points to ${entry.$2} (+${pay}e).',
        progressLabel: '$score/$threshold',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    return null;
  }

  static HubChase? _nextGauntletChase(GameState state) {
    if (!GameLogic.endgameUnlocked(state)) {
      return null;
    }
    final best = state.metaDepth.gauntletBestFloor;
    final claimed = state.metaDepth.claimedGauntletMilestones;
    for (final floor in GauntletMilestones.floors) {
      final id = GauntletMilestones.claimId(floor);
      if (claimed.contains(id)) continue;
      if (best >= floor) {
        continue;
      }
      final need = floor - best;
      final almost = need <= 5 && best > 0;
      final pay = GauntletMilestones.essenceForFloor(floor);
      return HubChase(
        kind: HubChaseKind.gauntletMilestone,
        title: almost
            ? 'Almost Gauntlet floor $floor'
            : 'Gauntlet floor $floor',
        detail: best <= 0
            ? 'Enter Infinity Gauntlet and climb for +${pay}e.'
            : 'Best F$best — $need floors to F$floor (+${pay}e).',
        progressLabel: 'F$best → F$floor',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    return null;
  }

  static HubChase? _nextRiftChase(GameState state) {
    if (!GameLogic.endgameUnlocked(state)) return null;
    final best = state.metaDepth.riftBestTier;
    final claimed = state.metaDepth.claimedRiftMilestones;
    for (final tier in RiftMilestones.tiers) {
      final id = RiftMilestones.claimId(tier);
      if (claimed.contains(id)) continue;
      if (best >= tier) continue;
      final need = tier - best;
      final almost = need <= 2 && best > 0;
      final pay = RiftMilestones.essenceForTier(tier);
      return HubChase(
        kind: HubChaseKind.riftMilestone,
        title: almost ? 'Almost Rift R$tier' : 'Rift R$tier',
        detail: best <= 0
            ? 'Enter a Rift and clear tiers for +${pay}e at R$tier.'
            : 'Best R$best — $need tiers to R$tier (+${pay}e).',
        progressLabel: 'R$best → R$tier',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    // No milestone left — nudge next selectable tier if below max.
    final next = Rift.maxSelectableTier(best);
    if (best < Rift.maxTier && next > best) {
      return HubChase(
        kind: HubChaseKind.riftMilestone,
        title: 'Clear Rift R$next',
        detail:
            'Timed kill challenge — ${Rift.killTarget(next)} kills before '
            '${Rift.formatTimer(Rift.parTimeMs(next))}.',
        progressLabel: 'R$next',
        urgency: HubChaseUrgency.normal,
      );
    }
    return null;
  }

  static HubChase? _nextGreaterRiftChase(GameState state) {
    if (!GameLogic.endgameUnlocked(state)) return null;
    final best = state.metaDepth.grBestTier;
    final claimed = state.metaDepth.claimedGrMilestones;
    for (final tier in GreaterRiftMilestones.tiers) {
      final id = GreaterRiftMilestones.claimId(tier);
      if (claimed.contains(id)) continue;
      if (best >= tier) continue;
      final need = tier - best;
      final almost = need <= 2 && best > 0;
      final pay = GreaterRiftMilestones.essenceForTier(tier);
      return HubChase(
        kind: HubChaseKind.greaterRiftMilestone,
        title: almost ? 'Almost Greater Rift GR$tier' : 'Greater Rift GR$tier',
        detail: best <= 0
            ? 'Enter Greater Rift for prestige ranks (+${pay}e at GR$tier).'
            : 'Best GR$best — $need tiers to GR$tier (+${pay}e).',
        progressLabel: 'GR$best → GR$tier',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    final next = GreaterRift.maxSelectableTier(best);
    if (best < GreaterRift.maxTier && next > best) {
      return HubChase(
        kind: HubChaseKind.greaterRiftMilestone,
        title: 'Clear Greater Rift GR$next',
        detail:
            'Harder packs, no mid-run gear — ${GreaterRift.killTarget(next)} kills '
            'before ${GreaterRift.formatTimer(GreaterRift.parTimeMs(next))}.',
        progressLabel: 'GR$next',
        urgency: HubChaseUrgency.normal,
      );
    }
    return null;
  }

  static HubChase? _nextZoneChase(GameState state) {
    final partyLv = GameLogic.partyMeanLevel(state);
    final cleared = state.highestDungeonCleared;
    for (final d in DungeonCatalog.all) {
      if (DungeonCatalog.isUnlocked(d.id, partyLv, cleared)) continue;
      final need = DungeonCatalog.unlockHeroLevel(d);
      final prevName = d.number <= 0
          ? 'the start'
          : DungeonCatalog.all[d.number - 1].name;
      final levelsShort = (need - partyLv).clamp(0, need);
      if (levelsShort <= 0) {
        return HubChase(
          kind: HubChaseKind.unlockZone,
          title: 'Unlock ${d.name}',
          detail: 'Clear $prevName (or reach party Lv$need) to open the path.',
          urgency: HubChaseUrgency.almost,
          zoneId: d.id,
        );
      }
      final almost = levelsShort <= 3;
      // TODAY only names a zone unlock when level is a cliffhanger —
      // clearing the prior zone still opens the path anytime.
      if (!almost) return null;
      return HubChase(
        kind: HubChaseKind.unlockZone,
        title: 'Almost ${d.name}',
        detail: levelsShort == 1
            ? '1 more party level (Lv$need) — or clear $prevName.'
            : '$levelsShort more party levels (Lv$need) — or clear $prevName.',
        progressLabel: 'Lv$partyLv / Lv$need',
        urgency: HubChaseUrgency.almost,
        zoneId: d.id,
      );
    }
    return null;
  }
}
