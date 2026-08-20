import '../models/dungeon_def.dart';
import '../models/hero_spec.dart';
import '../models/meta_depth.dart';
import 'ascend_roadmap.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hero_identity.dart';
import 'keystone.dart';
import 'local_season.dart';
import 'meta_systems.dart';

/// Kind of hub "today" chase — claimables first, then progress goals.
enum HubChaseKind {
  /// Daily vault ready to claim ([GameLogic.claimDailyVault]).
  claimDailyVault,
  claimMissions,

  /// Newly unlocked kit waiting for PARTY meet / acknowledge.
  meetHero,
  ascend,
  dailyVaultProgress,
  willRank,
  gauntletMilestone,
  unlockZone,
  dailyRun,

  /// Next KEY run after the first hour (habit until AL cap).
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

    final completeMissions = state.missions.where((m) => m.isComplete).length;
    if (completeMissions > 0) {
      return HubChase(
        kind: HubChaseKind.claimMissions,
        title: completeMissions == 1
            ? 'Claim contract reward'
            : 'Claim contract rewards',
        detail: 'Finished jobs are waiting on the hub.',
        progressLabel: '$completeMissions ready',
        urgency: HubChaseUrgency.ready,
      );
    }

    final meet = _pendingMeetChase(state);
    if (meet != null) return meet;

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
    // Early players get soft copy; KEY jargon waits for mid layer.
    if (!md.dailyVaultClaimed &&
        md.dailyVaultClears < GameLogic.dailyVaultClearTarget &&
        md.dailyBestTimedKey == 1) {
      final keyTalk = GameLogic.showKeystoneJargon(state);
      return HubChase(
        kind: HubChaseKind.dailyVaultProgress,
        title: keyTalk ? 'Almost — time KEY +2' : 'Almost — fill the vault',
        detail: keyTalk
            ? 'Best timed KEY +1 today — one higher key fills the vault.'
            : 'One more strong timed clear fills today’s vault.',
        progressLabel: keyTalk ? 'KEY +1' : 'Almost',
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

    // Habit after the first hour: chase the next KEY until the AL cap.
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

  /// Next KEY after the first hour, until preferred key hits the AL cap.
  ///
  /// Uses KEY words even before [GameLogic.showKeystoneJargon] — this is the
  /// habit loop, not mid-layer vault copy.
  static HubChase? _keystonePushChase(GameState state) {
    final cap = Keystone.maxForAl(state.ascensionLevel);
    final pref = state.hardmodeLevel.clamp(0, cap);
    if (pref >= cap) return null;
    final target = pref <= 0 ? 1 : pref;
    final firstKey = pref <= 0;
    return HubChase(
      kind: HubChaseKind.keystone,
      title: firstKey ? 'Run KEY +1' : 'Time KEY +$target',
      detail: firstKey
          ? 'Higher keys drop higher iLvl loot — start with KEY +1.'
          : 'Time KEY +$target for better iLvl loot and the next key unlock.',
      progressLabel: 'KEY +$target',
      keyLevel: target,
      zoneId: GameLogic.recommendedDungeonId(state),
    );
  }

  static HubChase _ascendPushChase(
    GameState state, {
    required int bossesNeed,
    required int bossesLeft,
    required HubChaseUrgency urgency,
  }) {
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
    if (state.ascensionLevel < GameLogic.gauntletMinAscension) {
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

  static HubChase? _nextZoneChase(GameState state) {
    final lifetime = state.lifetimeGoldEarned;
    final cleared = state.highestDungeonCleared;
    for (final d in DungeonCatalog.all) {
      if (DungeonCatalog.isUnlocked(d.id, lifetime, cleared)) continue;
      final goldNeed = (d.unlockPrice - lifetime).clamp(0, d.unlockPrice);
      final prevName = d.number <= 0
          ? 'the start'
          : DungeonCatalog.all[d.number - 1].name;
      if (goldNeed <= 0) {
        return HubChase(
          kind: HubChaseKind.unlockZone,
          title: 'Unlock ${d.name}',
          detail: 'Clear $prevName (or earn lifetime gold) to open the path.',
          urgency: HubChaseUrgency.almost,
          zoneId: d.id,
        );
      }
      final almost =
          d.unlockPrice > 0 &&
          goldNeed <= (d.unlockPrice * 0.12).ceil().clamp(1, d.unlockPrice);
      // Playing the current zone unlocks the next. TODAY only names a zone
      // unlock when gold is a cliffhanger — not as the default grind.
      if (!almost) return null;
      return HubChase(
        kind: HubChaseKind.unlockZone,
        title: 'Almost ${d.name}',
        detail: 'Need $goldNeed more lifetime gold — or clear $prevName.',
        progressLabel: '$lifetime / ${d.unlockPrice}g',
        urgency: HubChaseUrgency.almost,
        zoneId: d.id,
      );
    }
    return null;
  }
}
