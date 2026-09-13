import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/meta_depth.dart';
import 'ascend_roadmap.dart';
import 'encounter_factory.dart';
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
import 'ashen_crown.dart';

/// Kind of hub "today" chase - claimables first, then progress goals.
enum HubChaseKind {
  /// Daily vault ready to claim ([GameLogic.claimDailyVault]).
  claimDailyVault,
  claimMissions,

  /// Month season pass ready to claim.
  monthGoal,

  /// Newly unlocked kit waiting for PARTY meet / acknowledge.
  meetHero,

  /// Better gear already in BAG - equip before farming or buying.
  equipBag,

  /// Affordable UPGRADE on GOLD → MARKET when drops miss a slot.
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

  /// Ticket Ashen Crown clear (endgame).
  ashenCrown,

  /// Vault + Daily + KEY dial settled — soft session rest (Spire optional).
  doneForToday,
}

/// Endgame hunts use TODAY + primary ENTER / KEY — not a second hub row.
/// Soft rest (`doneForToday`) mutes idle POWERUPS the same way.
bool hubChaseOwnsEndgameRow(HubChaseKind kind) {
  switch (kind) {
    case HubChaseKind.keystone:
    case HubChaseKind.gauntletMilestone:
    case HubChaseKind.riftMilestone:
    case HubChaseKind.greaterRiftMilestone:
    case HubChaseKind.ashenCrown:
    case HubChaseKind.doneForToday:
      return true;
    default:
      return false;
  }
}

/// How close the chase is to a payoff - drives TODAY chrome.
enum HubChaseUrgency {
  /// Keep grinding.
  normal,

  /// One push / few points away - highlight ALMOST.
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
  /// Priority: claimables → first hour → Meet/BAG/market (pre-endgame) →
  /// Ascend READY (pre-endgame only) → almost-Ascend (pre-endgame) →
  /// prestige re-kit → vault/KEY/zone ALMOST cliffs → party-level ALMOST →
  /// KEY habit → endgame ladder → Daily vault start → party-level → zone →
  /// Will → keep clearing.
  static HubChase forState(GameState state, {DateTime? now}) {
    final md = state.metaDepth;
    final clock = now ?? DateTime.now().toUtc();

    // First hour: keep TODAY on grow-the-party — vault/quests wait until a boss.
    final firstHourQuiet = !GameLogic.showDailyChase(state);

    if (!firstHourQuiet && GameLogic.canClaimDailyVault(state)) {
      final best = md.dailyBestTimedKey;
      final plain = GameLogic.plainPlayerChrome(state);
      final preview = GameLogic.dailyVaultClaimPreviewEssence(state);
      final pay = plain ? '+$preview Permanent' : '+${preview}e';
      // Season bonus still pays on claim — keep TODAY copy to the vault payday.
      final keyTalk = GameLogic.showKeystoneJargon(state);
      return HubChase(
        kind: HubChaseKind.claimDailyVault,
        title: 'Claim Daily Vault',
        detail: best >= 2 && keyTalk
            ? 'Claim $pay (KEY +$best timed today).'
            : 'Claim $pay.',
        // READY chip owns urgency — no "N ready" progress echo.
        progressLabel: null,
        urgency: HubChaseUrgency.ready,
      );
    }

    final completeMissions = state.missions.where((m) => m.canClaim).length;
    if (!firstHourQuiet && completeMissions > 0) {
      return HubChase(
        kind: HubChaseKind.claimMissions,
        title: completeMissions == 1
            ? 'Claim quest reward'
            : 'Claim quest rewards',
        detail: completeMissions == 1
            ? 'Tap CLAIM QUESTS for gold and essence.'
            : 'Tap CLAIM QUESTS for gold and essence ($completeMissions).',
        progressLabel: null,
        urgency: HubChaseUrgency.ready,
      );
    }

    final monthReady = _monthPassChase(state, clock, readyOnly: true);
    if (monthReady != null) return monthReady;

    // First hour: grow the party — EQUIP / MARKET / Meet kit wait until a boss.
    if (firstHourQuiet) {
      final bossesNeed = GameLogic.bossesRequiredForAscension(
        state.ascensionLevel,
      );
      final bossesLeft =
          (bossesNeed - state.bossVictories).clamp(0, bossesNeed);
      return _ascendPushChase(
        state,
        bossesNeed: bossesNeed,
        bossesLeft: bossesLeft,
        urgency: HubChaseUrgency.normal,
      );
    }

    // Endgame (party Lv100): Meet-kit queue stays on PARTY badge, but TODAY
    // must chase Gauntlet / KEY / vault — not a +27 "Meet …" backlog.
    if (!GameLogic.endgameUnlocked(state)) {
      final meet = _pendingMeetChase(state);
      if (meet != null) return meet;
    }

    final bagEquip = _equipBagChase(state);
    if (bagEquip != null) return bagEquip;

    // Shop READY: before KEY nights only. At party max, KEY/Spire habit wins.
    if (!GameLogic.endgameUnlocked(state)) {
      final market = _marketUpgradeChase(state);
      if (market != null) return market;
    }

    if (GameLogic.canAscend(state)) {
      // AL0 first Ascend is optional — keep TODAY on Daily / farming; Ascend
      // stays on the hub urgent row so new saves are not trapped on one button.
      // At party Lv100, KEY / the endgame ladder is the night's job; Ascend
      // stays on the urgent row and KEEP as optional lasting power.
      if (state.ascensionLevel > 0 &&
          !GameLogic.endgameUnlocked(state)) {
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
              '+${reward}e · Ascend Blessing +${GameLogic.ascendBlessingAtk} ATK/'
              '+${GameLogic.ascendBlessingDef} DEF/'
              '+${GameLogic.ascendBlessingVit} STA/'
              '+${GameLogic.ascendBlessingGoldPct}% gold · bag, wallet gold, GOLD tracks, '
              'and floors reset$unlockBit',
          progressLabel: '+${reward}e',
          urgency: HubChaseUrgency.ready,
        );
      }
    }

    final bossesNeed = GameLogic.bossesRequiredForAscension(
      state.ascensionLevel,
    );
    final bossesLeft = (bossesNeed - state.bossVictories).clamp(0, bossesNeed);
    // Only "almost" once you've banked progress (AL0 needs 1 boss total -
    // 0/1 is the start of the game, not a cliffhanger).
    final almostAscend = bossesLeft == 1 && state.bossVictories > 0;
    if (almostAscend &&
        !GameLogic.endgameUnlocked(state) &&
        !GameLogic.isMaxAscension(state)) {
      return _ascendPushChase(
        state,
        bossesNeed: bossesNeed,
        bossesLeft: bossesLeft,
        urgency: HubChaseUrgency.almost,
      );
    }

    if (GameLogic.isFreshPrestigeGear(state)) {
      final zoneId = GameLogic.recommendedDungeonId(state);
      final zoneName = DungeonCatalog.byId(zoneId).name;
      final pressure = EncounterFactory.partyGearPressure(state);
      final exitAt = EncounterFactory.freshPrestigeGearMax;
      final span = (exitAt - 1.0).clamp(0.01, 2.0);
      final pct = (((pressure - 1.0) / span) * 100).clamp(0, 99).round();
      return HubChase(
        kind: HubChaseKind.clearFloors,
        title: 'Rebuild your bag',
        detail:
            'Farm early floors in $zoneName and re-equip the party. '
            'Zones stay open — bag and GOLD tracks reset on Ascend.',
        progressLabel: '$pct% geared',
        zoneId: zoneId,
      );
    }

    // KEY +1 timed but not yet claimable (need KEY +2) - cliffhanger.
    // Only after KEY unlocks (party at max level).
    if (GameLogic.showKeystoneJargon(state) &&
        !md.dailyVaultClaimed &&
        md.dailyVaultClears < GameLogic.dailyVaultClearTarget &&
        md.dailyBestTimedKey == 1) {
      return const HubChase(
        kind: HubChaseKind.dailyVaultProgress,
        title: 'Daily Vault halfway — KEY +2',
        detail:
            'Timed KEY +1 already counts. Time KEY +2 to fill and claim '
            'Daily Vault (not Daily Run).',
        progressLabel: 'KEY +1',
        urgency: HubChaseUrgency.almost,
        keyLevel: 2,
      );
    }

    // Month ALMOST before KEY only pre-endgame; at Lv100 KEY/Spire nights win.
    if (!GameLogic.endgameUnlocked(state)) {
      final monthAlmost = _monthPassChase(state, clock, almostOnly: true);
      if (monthAlmost != null) return monthAlmost;
    }

    // Other ALMOST cliffs beat Daily / vault-start grind (see CHASE_CONTRACT.md).
    // At endgame, skip Will / early week ALMOST so Spire / KEY night stays clear.
    final zoneAlmost = _nextZoneChase(state);
    if (zoneAlmost != null && zoneAlmost.urgency == HubChaseUrgency.almost) {
      return zoneAlmost;
    }
    if (GameLogic.showDailyRunOnHub(state) &&
        !GameLogic.endgameUnlocked(state)) {
      final willAlmost = _nextWillChase(state);
      if (willAlmost != null && willAlmost.urgency == HubChaseUrgency.almost) {
        return willAlmost;
      }
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
    if (!GameLogic.endgameUnlocked(state)) {
      final weekAlmostEarly = _weekGoalChase(state, clock, almostOnly: true);
      if (weekAlmostEarly != null) return weekAlmostEarly;
    }

    // First-hour grow-party already returned above.

    // Near Lv100: ALMOST party-level beats Daily vault start.
    final levelPush = _partyLevelChase(state);
    if (levelPush != null && levelPush.urgency == HubChaseUrgency.almost) {
      return levelPush;
    }

    // KEY habit at party max — do not wait on unpaid Daily.
    final keyPush = _keystonePushChase(state);
    if (keyPush != null) return keyPush;

    // Week ALMOST can own the night at endgame (season habit before Spire).
    if (GameLogic.endgameUnlocked(state)) {
      final weekAlmostEarly = _weekGoalChase(state, clock, almostOnly: true);
      if (weekAlmostEarly != null) return weekAlmostEarly;
    }

    // At party max level: ladder Gauntlet → GR → Rift → Ashen Crown before
    // Daily/Will so TODAY is one hunt, not a meta shuffle.
    if (GameLogic.endgameUnlocked(state)) {
      final endgameLadder = _endgameLadderChase(state, clock);
      if (endgameLadder != null) return endgameLadder;
      final monthAlmost = _monthPassChase(state, clock, almostOnly: true);
      if (monthAlmost != null) return monthAlmost;
    }

    // Day-2–7 job (pre-endgame): one cave clear fills Daily Vault.
    // Daily Run waits until first Ascend so TODAY is not three dailies.
    final wantVaultStart = !md.dailyVaultClaimed &&
        md.dailyVaultClears == 0 &&
        md.dailyBestTimedKey < 2;
    if (!GameLogic.endgameUnlocked(state)) {
      if (wantVaultStart) return _dailyVaultStartChase(state);
      if (GameLogic.showDailyRunOnHub(state) &&
          !MetaSystems.isDailyClaimedToday(state, now: clock)) {
        return const HubChase(
          kind: HubChaseKind.dailyRun,
          title: 'Clear Daily Run',
          detail:
              'One free seeded floor for +25e — separate from Daily Vault '
              'and Quests.',
          progressLabel: 'Available',
        );
      }
    } else {
      if (!MetaSystems.isDailyClaimedToday(state, now: clock)) {
        return const HubChase(
          kind: HubChaseKind.dailyRun,
          title: 'Clear Daily Run',
          detail:
              'One free seeded floor for +25e — separate from Daily Vault '
              'and Quests.',
          progressLabel: 'Available',
        );
      }
      if (wantVaultStart) return _dailyVaultStartChase(state);
    }

    // Midgame: levels unlock KEY (under Daily when the vault is still empty).
    if (levelPush != null) return levelPush;

    // Progress grind: zone / Shop (endgame) / Will / leftover endgame / week.
    final zone = _nextZoneChase(state);
    if (zone != null) return zone;

    final marketLate = _marketUpgradeChase(state);
    if (marketLate != null) return marketLate;

    final will = GameLogic.showDailyRunOnHub(state) ? _nextWillChase(state) : null;
    if (will != null) return will;

    if (!GameLogic.endgameUnlocked(state)) {
      final gauntlet = _nextGauntletChase(state);
      if (gauntlet != null) return gauntlet;
      final rift = _nextRiftChase(state);
      if (rift != null) return rift;
      final greaterRift = _nextGreaterRiftChase(state);
      if (greaterRift != null) return greaterRift;
    }

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

  /// One clear endgame hunt (not a stats dump). KEY habit already handled.
  static HubChase? _endgameLadderChase(GameState state, DateTime clock) {
    // Spire fans: Gauntlet before Greater Rift (FEEL 060 / 240).
    final gauntlet = _nextGauntletChase(state);
    if (gauntlet != null) return gauntlet;
    final greaterRift = _nextGreaterRiftChase(state);
    if (greaterRift != null) return greaterRift;
    final rift = _nextRiftChase(state);
    if (rift != null) return rift;
    final crown = _ashenCrownChase(state);
    if (crown != null) return crown;
    // F100 milestones done — PB push, or soft "Done for today" when loop settled.
    return _sessionRestOrPbChase(state, clock);
  }

  static HubChase? _sessionRestOrPbChase(GameState state, DateTime clock) {
    final pb = _gauntletPbChase(state);
    if (pb == null) return null;
    final cap = Keystone.maxForState(state);
    final keySettled = cap <= 0 || state.hardmodeLevel >= cap;
    final vaultOk = state.metaDepth.dailyVaultClaimed;
    final dailyOk = MetaSystems.isDailyClaimedToday(state, now: clock);
    if (vaultOk && dailyOk && keySettled) {
      // Week ALMOST / READY beat soft rest — hardcore still has a season chase.
      // Normal (non-cliff) week goals stay below doneForToday.
      final weekAlmost = _weekGoalChase(state, clock, almostOnly: true);
      if (weekAlmost != null) return weekAlmost;
      final weekAny = _weekGoalChase(state, clock, almostOnly: false);
      if (weekAny != null && weekAny.urgency == HubChaseUrgency.ready) {
        return weekAny;
      }
      return HubChase(
        kind: HubChaseKind.doneForToday,
        title: 'Done for today',
        detail:
            'Vault, Daily, and KEY dial settled — soft rest. '
            'Optional: KEY · BOARDS (Spire PB ${pb.progressLabel ?? 'open'}).',
        progressLabel: 'BOARDS',
      );
    }
    return pb;
  }

  static HubChase? _ashenCrownChase(GameState state) {
    if (!AshenCrown.canEnter(state)) return null;
    final tickets = AshenCrown.ensureWeek(state).metaDepth.worldBossTickets;
    if (tickets <= 0) return null;
    if (state.metaDepth.worldBossClearedWeek) return null;
    return HubChase(
      kind: HubChaseKind.ashenCrown,
      title: 'Clear ${AshenCrown.name}',
      detail: tickets == 1
          ? "This week's boss night — 1 ticket. First clear pays "
              '+${AshenCrown.essenceReward}e. PRACTICE free after.'
          : "This week's boss night — $tickets tickets. One paid clear/week "
              '(+${AshenCrown.essenceReward}e); PRACTICE free after.',
      progressLabel: tickets == 1 ? '1 ticket' : '$tickets tickets',
      urgency: tickets <= 1 ? HubChaseUrgency.almost : HubChaseUrgency.normal,
    );
  }

  static HubChase? _equipBagChase(GameState state) {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    if (upgrades <= 0) return null;
    final plan = GameLogic.planBiSAssignments(state);
    String? itemName;
    String? heroBit;
    String? slotBit;
    if (plan.isNotEmpty) {
      final step = plan.first;
      for (final item in state.gearStash) {
        if (item.id == step.itemId) {
          itemName = item.name;
          break;
        }
      }
      if (step.heroIndex >= 0 && step.heroIndex < state.heroes.length) {
        heroBit = state.heroes[step.heroIndex].name;
      }
      slotBit = _equipSlotLabel(step.slot);
    }
    final named = itemName == null
        ? null
        : (heroBit == null
            ? (slotBit == null ? itemName : '$itemName ($slotBit)')
            : (slotBit == null
                ? '$itemName → $heroBit'
                : '$itemName → $heroBit ($slotBit)'));
    return HubChase(
      kind: HubChaseKind.equipBag,
      title: upgrades == 1
          ? 'Better gear waiting'
          : '$upgrades better items waiting',
      detail: upgrades == 1
          ? (named != null
              ? '$named is in BAG — tap EQUIP 1.'
              : 'Tap EQUIP 1 before you go deeper.')
          : (named != null
              ? 'Tap EQUIP $upgrades (first: $named).'
              : 'Tap EQUIP $upgrades — upgrades waiting.'),
      progressLabel: upgrades == 1 ? 'EQUIP 1' : 'EQUIP $upgrades',
      urgency: HubChaseUrgency.ready,
    );
  }

  static String _equipSlotLabel(EquipmentSlot slot) => switch (slot) {
        EquipmentSlot.weapon => 'weapon',
        EquipmentSlot.offHand => 'off-hand',
        EquipmentSlot.ranged => 'ranged',
        EquipmentSlot.head => 'helm',
        EquipmentSlot.chest => 'chest',
        EquipmentSlot.boots => 'boots',
        EquipmentSlot.ring || EquipmentSlot.ring2 => 'ring',
        EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'trinket',
        _ => slot.name,
      };

  static HubChase? _marketUpgradeChase(GameState state) {
    final listing = MarketListingsService.bestAffordableUpgradeListing(state);
    if (listing == null) return null;
    final slot = listing.slot.name.toUpperCase().replaceAll('_', '-');
    return HubChase(
      kind: HubChaseKind.marketUpgrade,
      title: 'Buy market upgrade',
      detail:
          '${listing.item.name} · $slot · ${listing.priceGold}g — listings beat bad drops.',
      progressLabel: 'BUY',
      urgency: HubChaseUrgency.ready,
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
      detail: '${HeroIdentity.meetDetail(first)} Open GEAR → ROSTER to field them.',
      progressLabel: 'New',
      urgency: HubChaseUrgency.ready,
    );
  }

  static HubChase? _monthPassChase(GameState state, DateTime clock, {bool readyOnly = false, bool almostOnly = false}) {
    final monthKey = state.metaDepth.monthPassKey.isNotEmpty
        ? state.metaDepth.monthPassKey
        : GameLogic.isoMonthKey(clock);
    final month = LocalSeasonCatalog.forMonthKey(monthKey);
    if (!LocalSeasonCatalog.monthPassReady(state, month)) {
      if (LocalSeasonCatalog.monthPassAlmost(state, month)) {
        if (readyOnly) return null;
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
    if (almostOnly) return null;
    return HubChase(
      kind: HubChaseKind.monthGoal,
      title: 'Claim ${month.name}',
      detail:
          'Month pass ready · +${month.essenceReward}e · '
          '${LocalSeasonCatalog.monthProgressLabel(state, month)}.',
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
    if ((week.grTierTarget > 0 || week.ashenClearTarget) &&
        !GameLogic.endgameUnlocked(state)) {
      return null;
    }
    if (week.timedKeyTarget > 0 &&
        week.gauntletFloorTarget <= 0 &&
        week.grTierTarget <= 0 &&
        !week.ashenClearTarget &&
        !GameLogic.endgameUnlocked(state)) {
      return null;
    }
    if (LocalSeasonCatalog.weekGoalClaimed(state, week)) return null;
    if (LocalSeasonCatalog.weekGoalReady(state, week)) {
      if (almostOnly) return null;
      return HubChase(
        kind: HubChaseKind.weekGoal,
        title: 'Claim ${week.name}',
        detail:
            'Week goal done — reward auto-claims on hub sync '
            '(+${week.essenceReward}e).',
        progressLabel: LocalSeasonCatalog.weekProgressLabel(state, week),
        urgency: HubChaseUrgency.ready,
      );
    }

    if (LocalSeasonCatalog.weekGoalAlmost(state, week)) {
      return HubChase(
        kind: HubChaseKind.weekGoal,
        title: 'Almost · ${week.name}',
        detail:
            '${_weekRhythmPrefix(state, clock)}${week.blurb} · +${week.essenceReward}e',
        progressLabel: LocalSeasonCatalog.weekProgressLabel(state, week),
        urgency: HubChaseUrgency.almost,
      );
    }

    if (almostOnly) return null;

    return HubChase(
      kind: HubChaseKind.weekGoal,
      title: week.name,
      detail:
          '${_weekRhythmPrefix(state, clock)}${week.blurb} · +${week.essenceReward}e',
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
      detail: _keyPhoneDetail(state, target, firstKey: firstKey),
      progressLabel: 'KEY +$target',
      keyLevel: target,
      zoneId: GameLogic.recommendedDungeonId(state),
    );
  }

  /// Compact phone line: KEY +N · +iLvl · affixes · par.
  static String _keyPhoneDetail(
    GameState state,
    int key, {
    bool firstKey = false,
  }) {
    final ilvl = Keystone.lootItemLevelBonus(key);
    final affixes = Keystone.previewAffixesForKey(state, key);
    final affixBit = affixes.isEmpty
        ? 'no affixes'
        : affixes.map(Keystone.label).join(' · ');
    final par = Keystone.formatTimer(
      Keystone.parTimeMs(
        bossFloor: GameLogic.bossFloorFor(state),
        key: key,
      ),
    );
    final lead = firstKey
        ? 'ENTER sets KEY +1 · +$ilvl iLvl'
        : '+$ilvl iLvl';
    final hint = Keystone.rosterHintForAffixes(affixes);
    final base = '$lead · $affixBit · par $par';
    if (hint == null) return base;
    return '$base · $hint';
  }

  static String _weekRhythmPrefix(GameState state, DateTime clock) {
    final weekKey = state.metaDepth.weeklyKey.isNotEmpty
        ? state.metaDepth.weeklyKey
        : GameLogic.isoWeekKey(clock);
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    if (!week.hasGoal) return '';
    return "This week's beat · ${week.name} — ";
  }

  /// Level the party toward [GameLogic.maxHeroLevel] after the first boss.
  /// First hour stays "Grow the party"; Daily vault start still owns day 2–7
  /// unless this chase is ALMOST (within 5 levels of the cap).
  static HubChase? _partyLevelChase(GameState state) {
    if (GameLogic.endgameUnlocked(state)) return null;
    if (!GameLogic.showDailyChase(state)) return null;
    final heroes = state.heroes;
    if (heroes.isEmpty) return null;
    final minLv = heroes.fold<int>(heroes.first.level, (m, h) => min(m, h.level));
    final maxLv = heroes.fold<int>(heroes.first.level, (m, h) => max(m, h.level));
    final need = GameLogic.maxHeroLevel - minLv;
    if (need <= 0) return null;
    final almost = need <= 5;
    return HubChase(
      kind: HubChaseKind.clearFloors,
      title: almost
          ? 'Almost party Lv${GameLogic.maxHeroLevel}'
          : 'Level the party to ${GameLogic.maxHeroLevel}',
      detail: almost
          ? 'Lowest hero Lv$minLv — a few more combat levels unlock KEY, '
              'Gauntlet, and Ranked GR.'
          : 'Heroes Lv$minLv–$maxLv. Combat XP to '
              '${GameLogic.maxHeroLevel} unlocks KEY, Gauntlet, and Ranked GR.',
      progressLabel: minLv == maxLv
          ? 'Lv$minLv/${GameLogic.maxHeroLevel}'
          : 'Lv$minLv–$maxLv/${GameLogic.maxHeroLevel}',
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
          : state.ascensionLevel == 0 && GameLogic.canAscend(state)
          ? 'Ascend is ready when you want it — farm more floors or gear first. $teaser'
          : 'Farm gear or push deeper for power. $teaser',
      progressLabel: firstHour
          ? 'Boss ${state.bossVictories}/$bossesNeed'
          : 'Ascend ${state.bossVictories}/$bossesNeed',
      urgency: urgency,
      zoneId: dungeonId,
    );
  }

  /// One player-facing daily habit: clear a cave, then claim on the hub.
  static HubChase _dailyVaultStartChase(GameState state) {
    final keyTalk = GameLogic.showKeystoneJargon(state);
    return HubChase(
      kind: HubChaseKind.dailyVaultProgress,
      title: keyTalk ? 'Start Daily Vault' : 'Clear one cave today',
      detail: keyTalk
          ? 'Clear ${GameLogic.dailyVaultClearTarget} dungeon floor for '
              'Daily Vault essence, or time KEY +2 under par for a bigger claim.'
          : 'One dungeon clear fills today\'s reward. Then claim on the hub.',
      progressLabel: '0/${GameLogic.dailyVaultClearTarget}',
    );
  }

  /// Ladder exhausted — one actionable KEY/GR habit (never a stats dump).
  static HubChase _endgamePushChase(GameState state) {
    final cap = state.effectiveMaxHardmode;
    final pref = state.hardmodeLevel.clamp(0, cap);
    if (cap > 0 && pref > 0) {
      return HubChase(
        kind: HubChaseKind.keystone,
        title: 'Time KEY +$pref',
        detail:
            'Ladder quiet — ${_keyPhoneDetail(state, pref)}. Vault score / PB.',
        progressLabel: 'KEY +$pref',
        keyLevel: pref,
        zoneId: GameLogic.recommendedDungeonId(state),
      );
    }
    final gr = state.metaDepth.grBestTier;
    final nextGr = gr <= 0 ? 1 : (gr >= GreaterRift.maxTier ? gr : gr + 1);
    return HubChase(
      kind: HubChaseKind.greaterRiftMilestone,
      title: 'Push Ranked GR$nextGr',
      detail:
          'Mothveil prestige timer — no Ascend left. No mid-run gear; boards score. '
          'Not Crystal Spire climb.',
      progressLabel: 'RANK GR$nextGr',
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
            ? '1 point to ${entry.$2} (+${pay}e). Points from codex, pets, relics, achievements, trophies.'
            : '$need points to ${entry.$2} (+${pay}e). Points from codex, pets, relics, achievements, trophies.',
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
        title: best <= 0
            ? 'First Gauntlet Spire'
            : (almost
                ? 'Almost Gauntlet floor $floor'
                : 'Gauntlet floor $floor'),
        detail: best <= 0
            ? 'Infinity Gauntlet — boss every 5 floors; wipe or leave '
                'returns to hub. Climb for +${pay}e.'
            : 'Best F$best — $need floors to F$floor (+${pay}e). '
                'Boss every 5; wipe → hub.',
        progressLabel: 'F$best → F$floor',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    return null;
  }

  /// After F100 milestones and the rest of the endgame ladder go quiet.
  static HubChase? _gauntletPbChase(GameState state) {
    if (!GameLogic.endgameUnlocked(state)) return null;
    final best = state.metaDepth.gauntletBestFloor;
    final last = GauntletMilestones.floors.last;
    if (best < last) return null;
    final nextBoss = ((best ~/ 5) + 1) * 5;
    final nextMilestone = GauntletMilestones.floors
        .where((f) => f > best)
        .cast<int?>()
        .firstOrNull;
    final milestoneBit = nextMilestone == null
        ? ''
        : ' · next title F$nextMilestone';
    return HubChase(
      kind: HubChaseKind.gauntletMilestone,
      title: nextMilestone == null
          ? 'Fallback · Push Gauntlet PB'
          : 'Push toward F$nextMilestone',
      detail:
          'Endgame ladder quiet — PB F$best · next boss F$nextBoss'
          '$milestoneBit. Boss every 5; wipe or leave → hub.',
      progressLabel: 'PB F$best → F$nextBoss',
      urgency: HubChaseUrgency.normal,
    );
  }

  /// Farm Rift waits until Ranked GR has a clear or GR milestones are done.
  static bool _farmRiftChaseReady(GameState state) {
    if (state.metaDepth.grBestTier >= 1) return true;
    for (final tier in GreaterRiftMilestones.tiers) {
      final id = GreaterRiftMilestones.claimId(tier);
      if (!state.metaDepth.claimedGrMilestones.contains(id)) return false;
    }
    return true;
  }

  static HubChase? _nextRiftChase(GameState state) {
    if (!GameLogic.endgameUnlocked(state)) return null;
    if (!_farmRiftChaseReady(state)) return null;
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
        title: almost ? 'Almost Farm Rift R$tier' : 'Farm Rift R$tier',
        detail: best <= 0
            ? 'Farm Rift in Stormwake (KEY dial) — timed kills + loot mid-run; +${pay}e at R$tier.'
            : 'Best R$best — $need farm tiers to R$tier (+${pay}e). Not Spire climb.',
        progressLabel: 'R$best → R$tier',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    // No milestone left — nudge next selectable tier if below max.
    final next = Rift.maxSelectableTier(best);
    if (best < Rift.maxTier && next > best) {
      return HubChase(
        kind: HubChaseKind.riftMilestone,
        title: 'Clear Farm Rift R$next',
        detail:
            'Stormwake farm · ${Rift.killTarget(next)} kills before '
            '${Rift.formatTimer(Rift.parTimeMs(next))} — gold + gear mid-run '
            '(not Gauntlet floors).',
        progressLabel: 'FARM R$next',
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
        title: almost ? 'Almost Ranked GR$tier' : 'Ranked GR$tier',
        detail: best <= 0
            ? 'Mothveil Ranked GR — no mid-run gear (+${pay}e at GR$tier). Not Spire climb.'
            : 'Best GR$best — $need ranks to GR$tier (+${pay}e). No mid-run gear.',
        progressLabel: 'GR$best → GR$tier',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    final next = GreaterRift.maxSelectableTier(best);
    if (best < GreaterRift.maxTier && next > best) {
      return HubChase(
        kind: HubChaseKind.greaterRiftMilestone,
        title: 'Clear Ranked GR$next',
        detail:
            'Mothveil ranked · ${GreaterRift.killTarget(next)} kills before '
            '${GreaterRift.formatTimer(GreaterRift.parTimeMs(next))} — '
            'no mid-run gear (not farm Rift / not Spire climb).',
        progressLabel: 'RANK GR$next',
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
          detail:
              'Clear $prevName (or reach party Lv$need) to open the path. '
              'PATH farms the open prior zone.',
          urgency: HubChaseUrgency.almost,
          zoneId: d.id,
        );
      }
      final almost = levelsShort <= 3;
      // TODAY only names a zone unlock when level is a cliffhanger -
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
