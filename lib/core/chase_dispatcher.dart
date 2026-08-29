import '../models/dungeon_def.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hub_chase.dart';
import 'keystone.dart';
import 'local_season.dart';
import 'menu_alerts.dart';
import 'menu_router.dart';
import 'nav_intent.dart';

/// Destination-agnostic chase outcome. UI binds this to director / router.
enum ChaseOp {
  none,
  claimVault,
  claimMissions,
  claimMonth,
  syncWeek,
  navMeetHero,
  navEquipBag,
  navMarket,
  navMoreInfo,
  enter,
  enterKey,
  confirmAscend,
  confirmDaily,
  confirmGauntlet,
  confirmRift,
  confirmGreaterRift,
  confirmAshen,
  confirmAshenPractice,
}

class ChasePlan {
  const ChasePlan({
    this.label,
    this.op = ChaseOp.none,
    this.zoneId,
    this.keyLevel,
    this.pickZone = false,
    this.toast,
  });

  final String? label;
  final ChaseOp op;
  final String? zoneId;
  final int? keyLevel;
  final bool pickZone;
  final String? toast;
}

/// One HubChaseKind → plan. Does not import MenuRoute into hub_chase.dart.
abstract final class ChaseDispatcher {
  static ChasePlan plan(
    HubChase chase, {
    required GameState state,
    String? selectedZoneId,
  }) {
    switch (chase.kind) {
      case HubChaseKind.claimDailyVault:
        return const ChasePlan(label: 'CLAIM VAULT', op: ChaseOp.claimVault);
      case HubChaseKind.claimMissions:
        return const ChasePlan(
          label: 'CLAIM QUESTS',
          op: ChaseOp.claimMissions,
        );
      case HubChaseKind.monthGoal:
        return const ChasePlan(label: 'CLAIM MONTH', op: ChaseOp.claimMonth);
      case HubChaseKind.meetHero:
        return const ChasePlan(label: 'OPEN GEAR', op: ChaseOp.navMeetHero);
      case HubChaseKind.equipBag:
        return const ChasePlan(label: 'OPEN GEAR', op: ChaseOp.navEquipBag);
      case HubChaseKind.marketUpgrade:
        return const ChasePlan(label: 'SHOP', op: ChaseOp.navMarket);
      case HubChaseKind.ascend:
        return const ChasePlan(label: 'ASCEND', op: ChaseOp.confirmAscend);
      case HubChaseKind.dailyRun:
        return const ChasePlan(label: 'DAILY', op: ChaseOp.confirmDaily);
      case HubChaseKind.keystone:
        final key = chase.keyLevel ?? 1;
        final id = chase.zoneId ?? selectedZoneId;
        final affixes = Keystone.previewAffixes(state);
        final affixBit = affixes.isEmpty
            ? 'no affixes'
            : affixes.map(Keystone.label).join(' · ');
        final par = Keystone.formatTimer(
          Keystone.parTimeMs(
            bossFloor: GameLogic.bossFloorFor(state),
            key: key,
          ),
        );
        return ChasePlan(
          label: '🔑 ENTER KEY +$key',
          op: ChaseOp.enterKey,
          zoneId: id,
          keyLevel: key,
          pickZone: chase.zoneId != null,
          toast: 'KEY +$key · $affixBit · par $par',
        );
      case HubChaseKind.gauntletMilestone:
        return const ChasePlan(
          label: '⚔ GAUNTLET',
          op: ChaseOp.confirmGauntlet,
        );
      case HubChaseKind.riftMilestone:
        return const ChasePlan(label: '◈ RIFT', op: ChaseOp.confirmRift);
      case HubChaseKind.greaterRiftMilestone:
        return const ChasePlan(
          label: '◆ GREATER RIFT',
          op: ChaseOp.confirmGreaterRift,
        );
      case HubChaseKind.ashenCrown:
        return const ChasePlan(
          label: 'ASHEN CROWN',
          op: ChaseOp.confirmAshen,
        );
      case HubChaseKind.weekGoal:
        final weekKey = state.metaDepth.weeklyKey.isNotEmpty
            ? state.metaDepth.weeklyKey
            : GameLogic.isoWeekKey(DateTime.now().toUtc());
        final week = LocalSeasonCatalog.forWeekKey(weekKey);
        if (chase.urgency == HubChaseUrgency.ready) {
          return const ChasePlan(label: 'CLAIM WEEK', op: ChaseOp.syncWeek);
        }
        if (week.gauntletFloorTarget > 0) {
          return const ChasePlan(
            label: '⚔ GAUNTLET',
            op: ChaseOp.confirmGauntlet,
          );
        }
        return ChasePlan(
          label: 'ENTER',
          op: ChaseOp.enter,
          zoneId: chase.zoneId ?? selectedZoneId,
        );
      case HubChaseKind.dailyVaultProgress:
      case HubChaseKind.clearFloors:
        return ChasePlan(
          label: 'ENTER',
          op: ChaseOp.enter,
          zoneId: chase.zoneId ?? selectedZoneId,
          pickZone: chase.zoneId != null,
        );
      case HubChaseKind.unlockZone:
        final enterId = GameLogic.recommendedDungeonId(state);
        return ChasePlan(
          label: 'PATH',
          op: ChaseOp.enter,
          zoneId: enterId,
          pickZone: true,
        );
      case HubChaseKind.willRank:
        return const ChasePlan(label: 'INFO', op: ChaseOp.navMoreInfo);
    }
  }

  static NavIntent? navIntent(ChasePlan plan, GameState state) {
    switch (plan.op) {
      case ChaseOp.navMeetHero:
        return NavIntent(
          route: MenuRoute.gear,
          gear: MenuTabs.showRoster(state) ? GearPanel.roster : GearPanel.gear,
        );
      case ChaseOp.navEquipBag:
        return const NavIntent(route: MenuRoute.gear, gear: GearPanel.bag);
      case ChaseOp.navMarket:
        return NavIntent.shop;
      case ChaseOp.navMoreInfo:
        return const NavIntent(
          route: MenuRoute.more,
          more: MoreSection.info,
        );
      default:
        return null;
    }
  }

  static bool zoneUnlocked(GameState state, String id) =>
      DungeonCatalog.isUnlocked(
        id,
        GameLogic.partyMeanLevel(state),
        state.highestDungeonCleared,
      );
}
