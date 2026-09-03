
import 'package:flutter/material.dart';

import '../../core/chase_contract.dart';
import '../../core/chase_dispatcher.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/hub_chase.dart';
import '../../core/logic_notices.dart';
import '../chase_bind.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/play_nav.dart';
import '../web_click_bridge.dart';

/// Rich offline progress breakdown — replaces the plain toast with a
/// full-detail dialog the player must dismiss.
Future<void> showOfflineProgressDialog(
  BuildContext context,
  GameDirector director,
) async {
  final summary = director.offlineSummary;
  if (summary == null) return;
  final contract = ChaseContract.fromState(summary.state);
  final chase = contract.chase;
  final rows = summary.highlightRows;
  final notices = List<String>.from(
    LogicNotices.metaPayoffs,
  ).take(2).toList(growable: false);

  final nav = PlayNav.maybeOf(context);
  final plan = ChaseDispatcher.plan(
    chase,
    state: director.state,
    selectedZoneId: GameLogic.recommendedDungeonId(director.state),
  );
  var readyLabel = plan.label ?? contract.readyActionLabel ?? '';
  if (plan.op == ChaseOp.navMeetHero || plan.op == ChaseOp.navEquipBag) {
    readyLabel = 'GEAR';
  }
  if (plan.op == ChaseOp.enterKey) {
    readyLabel = 'ENTER KEY +${plan.keyLevel ?? 1}';
  }

  VoidCallback? readyAction;
  if (plan.op != ChaseOp.none) {
    readyAction = () {
      director.dismissOfflineSummary();
      Navigator.pop(context);
      if (plan.op == ChaseOp.confirmAshen) {
        director.enterAshenCrown();
        return;
      }
      if (nav != null) {
        runChasePlan(
          context: context,
          director: director,
          router: nav.router,
          plan: plan,
          onEnterDungeon: nav.onEnterDungeon,
          openMenus: false,
        );
      } else if (plan.op == ChaseOp.enter || plan.op == ChaseOp.enterKey) {
        if (plan.op == ChaseOp.enterKey) {
          director.setHardmodeLevel(plan.keyLevel ?? 1);
        }
        final id =
            plan.zoneId ?? GameLogic.recommendedDungeonId(director.state);
        if (ChaseDispatcher.zoneUnlocked(director.state, id)) {
          director.enterDungeon(dungeonId: id);
        }
      }
    };
  }

  final showChaseCta = readyAction != null &&
      (chase.urgency == HubChaseUrgency.ready ||
          chase.urgency == HubChaseUrgency.almost ||
          chase.kind == HubChaseKind.keystone ||
          chase.kind == HubChaseKind.unlockZone ||
          chase.kind == HubChaseKind.clearFloors ||
          chase.kind == HubChaseKind.dailyVaultProgress ||
          chase.kind == HubChaseKind.marketUpgrade);

  WebClickBridge.pushLayer();
  await showDialog<void>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'Welcome back!',
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Away for ${OfflineProgressResult.formatOfflineDuration(summary.secondsApplied)}',
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
              const SizedBox(height: 6),
              Text(
                summary.welcomeLead,
                style: GameTheme.body(size: 14, color: GameTheme.torchHot),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final row in rows)
                  MenuChrome.statRow(label: row.$1, value: row.$2),
              ],
              if (notices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notices.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 13, color: GameTheme.mossLit),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                contract.upNextLine,
                style: GameTheme.body(
                  size: 14,
                  color: chase.urgency == HubChaseUrgency.normal
                      ? GameTheme.mossLit
                      : GameTheme.accentWarn,
                ),
              ),
              Text(
                chase.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
              if (contract.ascendTeaser != null &&
                  contract.ascendTeaser!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contract.ascendTeaser!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 13, color: GameTheme.torch),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (showChaseCta) ...[
          KenneyButton(
            label: readyLabel,
            expanded: false,
            style: KenneyButtonStyle.brown,
            onPressed: readyAction,
          ),
        ],
        KenneyButton(
          label: 'NICE',
          expanded: false,
          onPressed: () {
            director.dismissOfflineSummary();
            Navigator.pop(ctx);
          },
        ),
      ],
    ),
  ).whenComplete(WebClickBridge.popLayer);
}
