import 'ascend_roadmap.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hub_chase.dart';

/// Shared “what am I chasing?” for hub TODAY, offline Up next, and Ascend copy.
///
/// Selection lives in [HubChase.forState]; this facade keeps every surface on
/// the same title / urgency / teaser (see docs/CHASE_CONTRACT.md).
class ChaseContract {
  const ChaseContract({required this.chase, this.ascendTeaser});

  final HubChase chase;

  /// Next kit / Gauntlet unlock blurb when the chase is Ascend-related.
  final String? ascendTeaser;

  HubChaseKind get kind => chase.kind;
  String get title => chase.title;
  String get detail => chase.detail;
  String? get progressLabel => chase.progressLabel;
  HubChaseUrgency get urgency => chase.urgency;
  String? get zoneId => chase.zoneId;

  bool get isReady => urgency == HubChaseUrgency.ready;
  bool get isAlmost => urgency == HubChaseUrgency.almost;
  bool get isClaimable =>
      kind == HubChaseKind.claimDailyVault ||
      kind == HubChaseKind.claimMissions ||
      (kind == HubChaseKind.monthGoal && isReady) ||
      (kind == HubChaseKind.weekGoal && isReady) ||
      kind == HubChaseKind.meetHero ||
      kind == HubChaseKind.equipBag ||
      kind == HubChaseKind.marketUpgrade ||
      kind == HubChaseKind.ascend;

  /// Offline welcome + any “Up next” chrome — same words as hub TODAY.
  /// Urgency stays on the hub chip; this line is title-only (no READY echo).
  String get upNextLine => 'Up next: $title';

  /// Short CTA when [isReady] (hub / offline action buttons).
  String? get readyActionLabel => switch (kind) {
    HubChaseKind.claimDailyVault => 'CLAIM VAULT',
    HubChaseKind.claimMissions => 'CLAIM QUESTS',
    HubChaseKind.monthGoal => 'CLAIM MONTH',
    HubChaseKind.weekGoal => 'CLAIM WEEK',
    HubChaseKind.meetHero => 'GEAR',
    HubChaseKind.equipBag => 'GEAR',
    HubChaseKind.marketUpgrade => 'MARKET',
    HubChaseKind.ascend => 'ASCEND',
    HubChaseKind.dailyRun => 'DAILY',
    HubChaseKind.keystone => 'ENTER',
    HubChaseKind.gauntletMilestone => 'GAUNTLET',
    HubChaseKind.riftMilestone => 'RIFT',
    HubChaseKind.greaterRiftMilestone => 'GREATER RIFT',
    HubChaseKind.ashenCrown => 'ASHEN CROWN',
    HubChaseKind.unlockZone => zoneId != null ? 'PATH' : null,
    _ => null,
  };

  static ChaseContract fromState(GameState state, {DateTime? now}) {
    final chase = HubChase.forState(state, now: now);
    String? teaser;
    final firstHour = !GameLogic.showDailyChase(state);
    if (chase.kind == HubChaseKind.ascend ||
        (chase.kind == HubChaseKind.clearFloors && !firstHour)) {
      teaser =
          AscendRoadmap.nextMissingKitTeaser(state) ??
          AscendRoadmap.chaseTeaser(state.ascensionLevel);
    } else if (chase.kind == HubChaseKind.meetHero) {
      teaser = chase.detail;
    }
    return ChaseContract(chase: chase, ascendTeaser: teaser);
  }
}
