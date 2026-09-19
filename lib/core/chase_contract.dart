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

  /// One-line “why this job” — same contract, not a second chase.
  String get whyLine => switch (kind) {
    HubChaseKind.claimDailyVault =>
      'Why: the UTC vault is ready — claim before the next job.',
    HubChaseKind.claimMissions =>
      'Why: MORE · QUESTS has rewards (board, not an ENDGAME hunt).',
    HubChaseKind.monthGoal => 'Why: the month pass is ready to claim.',
    HubChaseKind.weekGoal => 'Why: this week’s local goal is ready to claim.',
    HubChaseKind.meetHero => 'Why: a new kit is waiting on GEAR → PARTY.',
    HubChaseKind.equipBag => 'Why: BAG already holds a stronger piece.',
    HubChaseKind.marketUpgrade => 'Why: GOLD → MARKET has an affordable upgrade.',
    HubChaseKind.ascend =>
      'Why: Ascend is ready — AL and Blessing, not party-Lv100 endgame.',
    HubChaseKind.dailyVaultProgress =>
      'Why: one clear (or timed KEY +2) fills today’s vault.',
    HubChaseKind.dailyRun => 'Why: the free Daily Run floor is still open.',
    HubChaseKind.keystone =>
      'Why: party is max level — KEY is the next precision climb.',
    HubChaseKind.gauntletMilestone =>
      'Why: KEY habit settled — Gauntlet is the next endless climb.',
    HubChaseKind.greaterRiftMilestone =>
      'Why: Ranked GR is the timed ladder (no mid-run gear).',
    HubChaseKind.riftMilestone =>
      'Why: Farm Rift is the gear farm (elapsed clock, no fail timer).',
    HubChaseKind.ashenCrown =>
      'Why: a weekly Ashen ticket is waiting (PRACTICE is free after).',
    HubChaseKind.unlockZone => 'Why: the next PATH cave is in reach.',
    HubChaseKind.clearFloors => 'Why: grow the party — extra hunts wait.',
    HubChaseKind.willRank => 'Why: a Will rank payday is close.',
    HubChaseKind.doneForToday => 'Why: vault and KEY habit are settled.',
  };

  /// Short CTA when [isReady] (hub / offline action buttons).
  String? get readyActionLabel => switch (kind) {
    HubChaseKind.claimDailyVault => 'CLAIM VAULT',
    HubChaseKind.claimMissions => 'CLAIM QUESTS',
    HubChaseKind.monthGoal => 'CLAIM MONTH',
    HubChaseKind.weekGoal => 'CLAIM WEEK',
    HubChaseKind.meetHero => 'OPEN GEAR',
    HubChaseKind.equipBag =>
      progressLabel != null && progressLabel!.startsWith('EQUIP')
          ? progressLabel
          : 'EQUIP',
    HubChaseKind.marketUpgrade => 'OPEN GOLD',
    HubChaseKind.ascend => 'ASCEND',
    HubChaseKind.dailyRun => 'DAILY RUN',
    HubChaseKind.keystone => chase.keyLevel != null
        ? 'ENTER KEY +${chase.keyLevel}'
        : 'ENTER KEY',
    HubChaseKind.gauntletMilestone => 'GAUNTLET',
    HubChaseKind.riftMilestone => 'FARM RIFT',
    HubChaseKind.greaterRiftMilestone => chase.progressLabel != null &&
            chase.progressLabel!.startsWith('RANK GR')
        ? chase.progressLabel!.replaceFirst('RANK GR', 'RANKED GR')
        : 'RANKED GR',
    HubChaseKind.ashenCrown => 'ASHEN CROWN',
    HubChaseKind.doneForToday => 'KEY · BOARDS',
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
