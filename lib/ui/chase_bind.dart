import 'package:flutter/material.dart';

import '../core/chase_dispatcher.dart';
import '../core/game_director.dart';
import '../core/hub_chase.dart';
import '../core/menu_router.dart';
import '../core/nav_intent.dart';
import 'confirm_dialogs.dart';

/// Executes a [ChasePlan] on director / router / confirm dialogs.
void runChasePlan({
  required BuildContext context,
  required GameDirector director,
  required MenuRouter router,
  required ChasePlan plan,
  required void Function(String dungeonId) onEnterDungeon,
  void Function(String id)? onPickZone,
  bool openMenus = true,
}) {
  // Hub TODAY / enter must not fight an open MORE/CRAFT sheet.
  switch (plan.op) {
    case ChaseOp.claimVault:
    case ChaseOp.claimMissions:
    case ChaseOp.claimMonth:
    case ChaseOp.enter:
    case ChaseOp.enterKey:
    case ChaseOp.confirmAscend:
    case ChaseOp.confirmDaily:
    case ChaseOp.confirmGauntlet:
    case ChaseOp.confirmRift:
    case ChaseOp.confirmGreaterRift:
    case ChaseOp.confirmAshen:
    case ChaseOp.confirmAshenPractice:
      if (router.isOpen) router.close();
    default:
      break;
  }
  switch (plan.op) {
    case ChaseOp.none:
      return;
    case ChaseOp.claimVault:
      director.claimDailyVault();
    case ChaseOp.claimMissions:
      // One-tap TODAY claim — do not bounce into MORE · QUESTS.
      director.claimAllReadyMissions();
    case ChaseOp.claimMonth:
      director.claimMonthPass();
    case ChaseOp.syncWeek:
      director.syncMetaPayoffs();
    case ChaseOp.navMeetHero:
      router.openForHubChase(director.state, HubChaseKind.meetHero);
    case ChaseOp.navEquipBag:
      router.openForHubChase(director.state, HubChaseKind.equipBag);
    case ChaseOp.navMarket:
      router.apply(NavIntent.market);
    case ChaseOp.navMoreInfo:
      router.open(MenuRoute.more, more: MoreSection.info);
    case ChaseOp.navKey:
      router.open(MenuRoute.key);
    case ChaseOp.enter:
    case ChaseOp.enterKey:
      final id = plan.zoneId;
      if (id == null) return;
      if (plan.pickZone) onPickZone?.call(id);
      if (plan.op == ChaseOp.enterKey) {
        director.setHardmodeLevel(plan.keyLevel ?? 1);
        if (plan.toast != null) {
          director.showToast(plan.toast!, life: 2.8);
        }
      }
      if (ChaseDispatcher.zoneUnlocked(director.state, id)) {
        onEnterDungeon(id);
      }
    case ChaseOp.confirmAscend:
      confirmAscend(context, director);
    case ChaseOp.confirmDaily:
      confirmDailyRun(context, director);
    case ChaseOp.confirmGauntlet:
      confirmGauntletRun(context, director);
    case ChaseOp.confirmRift:
      confirmRiftRun(context, director);
    case ChaseOp.confirmGreaterRift:
      confirmGreaterRiftRun(context, director);
    case ChaseOp.confirmAshen:
      confirmAshenCrown(context, director, practice: false);
    case ChaseOp.confirmAshenPractice:
      confirmAshenCrown(context, director, practice: true);
  }
}
