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
        if (chase.urgency == HubChaseUrgency.ready) {
          return const ChasePlan(label: 'CLAIM MONTH', op: ChaseOp.claimMonth);
        }
        return _monthAlmostPlan(state, chase, selectedZoneId);
      case HubChaseKind.meetHero:
        return const ChasePlan(label: 'OPEN GEAR', op: ChaseOp.navMeetHero);
      case HubChaseKind.equipBag:
        return const ChasePlan(label: 'OPEN BAG', op: ChaseOp.navEquipBag);
      case HubChaseKind.marketUpgrade:
        return const ChasePlan(label: 'SHOP', op: ChaseOp.navMarket);
      case HubChaseKind.ascend:
        return const ChasePlan(label: 'ASCEND', op: ChaseOp.confirmAscend);
      case HubChaseKind.dailyRun:
        return const ChasePlan(label: 'DAILY', op: ChaseOp.confirmDaily);
      case HubChaseKind.keystone:
        return _enterKeyPlan(
          state,
          key: chase.keyLevel ?? 1,
          zoneId: chase.zoneId ?? selectedZoneId,
          pickZone: chase.zoneId != null,
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
        if (week.timedKeyTarget > 0) {
          return _enterKeyPlan(
            state,
            key: week.timedKeyTarget,
            zoneId: chase.zoneId ?? selectedZoneId,
            pickZone: chase.zoneId != null,
          );
        }
        return ChasePlan(
          label: 'ENTER',
          op: ChaseOp.enter,
          zoneId: chase.zoneId ?? selectedZoneId,
        );
      case HubChaseKind.dailyVaultProgress:
        final vaultKey = chase.keyLevel ??
            (state.metaDepth.dailyBestTimedKey == 1 ? 2 : null);
        if (vaultKey != null && GameLogic.showKeystoneJargon(state)) {
          return _enterKeyPlan(
            state,
            key: vaultKey,
            zoneId: chase.zoneId ?? selectedZoneId,
            pickZone: chase.zoneId != null,
          );
        }
        return ChasePlan(
          label: 'ENTER',
          op: ChaseOp.enter,
          zoneId: chase.zoneId ?? selectedZoneId,
          pickZone: chase.zoneId != null,
        );
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
        return const ChasePlan(label: 'GUIDE', op: ChaseOp.navMoreInfo);
    }
  }

  static ChasePlan _enterKeyPlan(
    GameState state, {
    required int key,
    required String? zoneId,
    required bool pickZone,
  }) {
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
      zoneId: zoneId,
      keyLevel: key,
      pickZone: pickZone,
      toast: 'KEY +$key · $affixBit · par $par',
    );
  }

  static ChasePlan _monthAlmostPlan(
    GameState state,
    HubChase chase,
    String? selectedZoneId,
  ) {
    final monthKey = state.metaDepth.monthPassKey.isNotEmpty
        ? state.metaDepth.monthPassKey
        : GameLogic.isoMonthKey(DateTime.now().toUtc());
    final month = LocalSeasonCatalog.forMonthKey(monthKey);
    if (month.grTierTarget > 0) {
      return const ChasePlan(
        label: '◆ GREATER RIFT',
        op: ChaseOp.confirmGreaterRift,
      );
    }
    if (month.timedKeyTarget > 0) {
      return _enterKeyPlan(
        state,
        key: month.timedKeyTarget,
        zoneId: chase.zoneId ?? selectedZoneId,
        pickZone: chase.zoneId != null,
      );
    }
    return ChasePlan(
      label: 'ENTER',
      op: ChaseOp.enter,
      zoneId: chase.zoneId ?? selectedZoneId,
    );
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
