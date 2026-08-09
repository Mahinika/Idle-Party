import '../models/dungeon_def.dart';
import '../models/meta_depth.dart';
import 'ascend_roadmap.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';

/// Kind of hub "today" chase — claimables first, then progress goals.
enum HubChaseKind {
  claimWeekly,
  claimMissions,
  ascend,
  weeklyProgress,
  willRank,
  gauntletMilestone,
  unlockZone,
  dailyRun,
  clearFloors,
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
  });

  final HubChaseKind kind;
  final String title;
  final String detail;
  final String? progressLabel;
  final HubChaseUrgency urgency;

  /// Picks the single best "what should I chase now?" target.
  ///
  /// Priority: claimables → Ascend → almost-Ascend → vault progress →
  /// daily → zone → Will → Gauntlet → keep clearing.
  static HubChase forState(GameState state, {DateTime? now}) {
    final md = state.metaDepth;
    final clock = now ?? DateTime.now().toUtc();

    if (GameLogic.canClaimDailyVault(state)) {
      final best = md.dailyBestTimedKey;
      return HubChase(
        kind: HubChaseKind.claimWeekly,
        title: 'Claim daily vault',
        detail: best >= 2
            ? 'Best timed KEY +$best — grab your essence.'
            : 'You filled today’s vault — grab your essence.',
        progressLabel: best >= 2
            ? 'KEY +$best ready'
            : '${GameLogic.dailyVaultClearTarget}/${GameLogic.dailyVaultClearTarget} ready',
        urgency: HubChaseUrgency.ready,
      );
    }

    final completeMissions =
        state.missions.where((m) => m.isComplete).length;
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

    if (GameLogic.canAscend(state)) {
      final reward = GameLogic.ascendEssenceReward(state.ascensionLevel + 1) +
          MetaSystems.ascendMilestoneReward(
            state.ascensionLevel,
            state.ascensionLevel + 1,
          );
      final nextAl = state.ascensionLevel + 1;
      final unlock = AscendRoadmap.unlockAtAl(nextAl);
      final unlockBit =
          unlock != null ? ' · AL$nextAl unlocks $unlock' : '';
      return HubChase(
        kind: HubChaseKind.ascend,
        title: 'Ascend for lasting power',
        detail:
            '+${reward}e · Blessing +${GameLogic.ascendBlessingAtk} ATK/'
            '+${GameLogic.ascendBlessingDef} DEF/'
            '+${GameLogic.ascendBlessingVit} VIT/'
            '+${GameLogic.ascendBlessingGoldPct}% gold$unlockBit',
        progressLabel: 'Ready',
        urgency: HubChaseUrgency.ready,
      );
    }

    final bossesNeed =
        GameLogic.bossesRequiredForAscension(state.ascensionLevel);
    final bossesLeft =
        (bossesNeed - state.bossVictories).clamp(0, bossesNeed);
    // Only "almost" once you've banked progress (AL0 needs 1 boss total —
    // 0/1 is the start of the game, not a cliffhanger).
    final almostAscend =
        bossesLeft == 1 && state.bossVictories > 0;
    if (almostAscend) {
      return _ascendPushChase(
        state,
        bossesNeed: bossesNeed,
        bossesLeft: bossesLeft,
        urgency: HubChaseUrgency.almost,
      );
    }

    if (!md.dailyVaultClaimed &&
        md.dailyVaultClears > 0 &&
        md.dailyVaultClears < GameLogic.dailyVaultClearTarget &&
        md.dailyBestTimedKey < 2) {
      final left =
          GameLogic.dailyVaultClearTarget - md.dailyVaultClears;
      return HubChase(
        kind: HubChaseKind.weeklyProgress,
        title: left == 1 ? 'Almost — finish daily vault' : 'Finish daily vault',
        detail: left == 1
            ? 'One more clear — or time a KEY +2 — then claim.'
            : 'One more clear — or time a KEY +2.',
        progressLabel:
            '${md.dailyVaultClears}/${GameLogic.dailyVaultClearTarget}',
        urgency: left == 1 ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }

    // KEY +1 timed but not yet claimable (need KEY +2) — cliffhanger.
    if (!md.dailyVaultClaimed &&
        md.dailyVaultClears < GameLogic.dailyVaultClearTarget &&
        md.dailyBestTimedKey == 1) {
      return const HubChase(
        kind: HubChaseKind.weeklyProgress,
        title: 'Almost — time KEY +2',
        detail: 'Best timed KEY +1 today — one higher key fills the vault.',
        progressLabel: 'KEY +1',
        urgency: HubChaseUrgency.almost,
      );
    }

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
      return HubChase(
        kind: HubChaseKind.weeklyProgress,
        title: 'Start daily vault',
        detail:
            'Clear ${GameLogic.dailyVaultClearTarget} floor or time a KEY +2.',
        progressLabel: '0/${GameLogic.dailyVaultClearTarget}',
      );
    }

    final zone = _nextZoneChase(state);
    if (zone != null) return zone;

    final will = _nextWillChase(state);
    if (will != null) return will;

    final gauntlet = _nextGauntletChase(state);
    if (gauntlet != null) return gauntlet;

    return _ascendPushChase(
      state,
      bossesNeed: bossesNeed,
      bossesLeft: bossesLeft,
      urgency: bossesLeft == 1 && state.bossVictories > 0
          ? HubChaseUrgency.almost
          : HubChaseUrgency.normal,
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
    final teaser = AscendRoadmap.chaseTeaser(state.ascensionLevel);
    final almost = urgency == HubChaseUrgency.almost;
    return HubChase(
      kind: HubChaseKind.clearFloors,
      title: almost
          ? 'Almost Ascend — push ${dungeon.name}'
          : 'Push ${dungeon.name}',
      detail: bossesLeft > 0
          ? (almost
              ? '1 boss left · then Ascend. $teaser'
              : 'Clear bosses toward Ascend ($bossesLeft left). $teaser')
          : 'Farm gear or push deeper for power. $teaser',
      progressLabel: 'Ascend ${state.bossVictories}/$bossesNeed',
      urgency: urgency,
    );
  }

  static HubChase? _nextWillChase(GameState state) {
    final score = state.collectionScore;
    for (final entry in WillRanks.thresholds) {
      final threshold = entry.$1;
      if (threshold <= 0 || score >= threshold) continue;
      final need = threshold - score;
      final almost = need <= 3;
      return HubChase(
        kind: HubChaseKind.willRank,
        title: almost ? 'Almost ${entry.$2}' : 'Chase ${entry.$2}',
        detail: need == 1
            ? '1 collection point to the next Will rank (+essence).'
            : '$need collection points to the next Will rank (+essence).',
        progressLabel: '$score/$threshold',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    return null;
  }

  static HubChase? _nextGauntletChase(GameState state) {
    if (state.ascensionLevel < GameLogic.gauntletMinAscension) {
      // Soft teaser before unlock — still not the primary chase usually.
      return null;
    }
    final best = state.metaDepth.gauntletBestFloor;
    final claimed = state.metaDepth.claimedGauntletMilestones;
    for (final floor in GauntletMilestones.floors) {
      final id = GauntletMilestones.claimId(floor);
      if (claimed.contains(id)) continue;
      if (best >= floor) {
        // Payoff sync should claim; still nudge climb if somehow pending.
        continue;
      }
      final need = floor - best;
      final almost = need <= 5 && best > 0;
      return HubChase(
        kind: HubChaseKind.gauntletMilestone,
        title: almost
            ? 'Almost Gauntlet floor $floor'
            : 'Gauntlet floor $floor',
        detail: best <= 0
            ? 'Enter Infinity Gauntlet and climb for a milestone reward.'
            : 'Best F$best — $need floors to the next milestone.',
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
        );
      }
      final almost = d.unlockPrice > 0 &&
          goldNeed <= (d.unlockPrice * 0.12).ceil().clamp(1, d.unlockPrice);
      return HubChase(
        kind: HubChaseKind.unlockZone,
        title: almost ? 'Almost ${d.name}' : 'Unlock ${d.name}',
        detail: 'Need $goldNeed more lifetime gold — or clear $prevName.',
        progressLabel: '$lifetime / ${d.unlockPrice}g',
        urgency: almost ? HubChaseUrgency.almost : HubChaseUrgency.normal,
      );
    }
    return null;
  }
}
