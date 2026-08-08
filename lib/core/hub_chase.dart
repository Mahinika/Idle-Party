import '../models/dungeon_def.dart';
import '../models/meta_depth.dart';
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

/// One plain English chase line for the hub TODAY card.
class HubChase {
  const HubChase({
    required this.kind,
    required this.title,
    required this.detail,
    this.progressLabel,
  });

  final HubChaseKind kind;
  final String title;
  final String detail;
  final String? progressLabel;

  /// Picks the single best "what should I chase now?" target.
  ///
  /// Priority: claimables → weekly progress → Will → Gauntlet milestone →
  /// next zone unlock → daily → keep clearing recommended dungeon.
  static HubChase forState(GameState state) {
    final md = state.metaDepth;

    if (md.weeklyProgress >= GameLogic.weeklyClearTarget && !md.weeklyClaimed) {
      return const HubChase(
        kind: HubChaseKind.claimWeekly,
        title: 'Claim weekly reward',
        detail: 'You filled this week’s clears — grab your essence.',
        progressLabel: '3/3 ready',
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
      );
    }

    if (GameLogic.canAscend(state)) {
      final reward = GameLogic.ascendEssenceReward(state.ascensionLevel + 1) +
          MetaSystems.ascendMilestoneReward(
            state.ascensionLevel,
            state.ascensionLevel + 1,
          );
      return HubChase(
        kind: HubChaseKind.ascend,
        title: 'Ascend for lasting power',
        detail: 'Reset the run, keep meta, earn +${reward}e.',
        progressLabel: 'Ready',
      );
    }

    if (!md.weeklyClaimed &&
        md.weeklyProgress > 0 &&
        md.weeklyProgress < GameLogic.weeklyClearTarget) {
      final mod = md.weeklyModifier.isEmpty ? 'weekly' : md.weeklyModifier;
      final left = GameLogic.weeklyClearTarget - md.weeklyProgress;
      return HubChase(
        kind: HubChaseKind.weeklyProgress,
        title: 'Finish weekly ($mod)',
        detail: left == 1
            ? 'One more clear under this week’s mod.'
            : '$left clears left under this week’s mod.',
        progressLabel:
            '${md.weeklyProgress}/${GameLogic.weeklyClearTarget}',
      );
    }

    if (!MetaSystems.isDailyClaimedToday(state)) {
      return const HubChase(
        kind: HubChaseKind.dailyRun,
        title: 'Run today’s Daily',
        detail: 'A short echo dungeon — clear it for bonus essence.',
        progressLabel: 'Available',
      );
    }

    if (!md.weeklyClaimed && md.weeklyProgress == 0) {
      final mod = md.weeklyModifier.isEmpty ? 'weekly' : md.weeklyModifier;
      return HubChase(
        kind: HubChaseKind.weeklyProgress,
        title: 'Start weekly ($mod)',
        detail: 'Clear ${GameLogic.weeklyClearTarget} floors this week for essence.',
        progressLabel: '0/${GameLogic.weeklyClearTarget}',
      );
    }

    final zone = _nextZoneChase(state);
    if (zone != null) return zone;

    final will = _nextWillChase(state);
    if (will != null) return will;

    final gauntlet = _nextGauntletChase(state);
    if (gauntlet != null) return gauntlet;

    final dungeonId = GameLogic.recommendedDungeonId(state);
    final dungeon = DungeonCatalog.byId(dungeonId);
    final bossesNeed =
        GameLogic.bossesRequiredForAscension(state.ascensionLevel);
    final bossesLeft = (bossesNeed - state.bossVictories).clamp(0, bossesNeed);
    return HubChase(
      kind: HubChaseKind.clearFloors,
      title: 'Push ${dungeon.name}',
      detail: bossesLeft > 0
          ? 'Clear bosses toward Ascend ($bossesLeft left).'
          : 'Farm gear or push deeper for power.',
      progressLabel:
          'Ascend ${state.bossVictories}/$bossesNeed',
    );
  }

  static HubChase? _nextWillChase(GameState state) {
    final score = state.collectionScore;
    for (final entry in WillRanks.thresholds) {
      final threshold = entry.$1;
      if (threshold <= 0 || score >= threshold) continue;
      final need = threshold - score;
      return HubChase(
        kind: HubChaseKind.willRank,
        title: 'Chase ${entry.$2}',
        detail: need == 1
            ? '1 collection point to the next Will rank (+essence).'
            : '$need collection points to the next Will rank (+essence).',
        progressLabel: '$score/$threshold',
      );
    }
    return null;
  }

  static HubChase? _nextGauntletChase(GameState state) {
    if (state.ascensionLevel < GameLogic.gauntletMinAscension) return null;
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
      return HubChase(
        kind: HubChaseKind.gauntletMilestone,
        title: 'Gauntlet floor $floor',
        detail: best <= 0
            ? 'Enter Infinity Gauntlet and climb for a milestone reward.'
            : 'Best F$best — $need floors to the next milestone.',
        progressLabel: 'F$best → F$floor',
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
        );
      }
      return HubChase(
        kind: HubChaseKind.unlockZone,
        title: 'Unlock ${d.name}',
        detail: 'Need $goldNeed more lifetime gold — or clear $prevName.',
        progressLabel: '$lifetime / ${d.unlockPrice}g',
      );
    }
    return null;
  }
}
