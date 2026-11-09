import 'package:flutter/material.dart';

import 'dart:async' show unawaited;

import '../../core/ad_rewarded.dart';
import '../../core/analytics_events.dart';
import '../../core/chase_contract.dart';
import '../../core/chase_dispatcher.dart';
import '../../core/comeback_chest.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/menu_router.dart';
import '../../core/home_layout.dart';
import '../../core/hub_chase.dart';
import '../../core/menu_alerts.dart';
import '../../core/pet_service.dart';
import '../chase_bind.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/home/home_gold_dock.dart';
import '../shell/home/upgrade_panel.dart';
import '../shell/shell_layout.dart';
import '../shell/play_nav.dart';
import '../web_click_bridge.dart';

/// Short Welcome Back: wow lead, ≤3 highlights, one Up next, dismiss.
Future<void> showOfflineProgressDialog(
  BuildContext context,
  GameDirector director, {
  MenuRouter? router,
}) async {
  final summary = director.offlineSummary;
  final rewardState = summary?.state ?? director.state;
  final now = DateTime.now();
  if (summary == null && !GameLogic.returnCardWaiting(rewardState, now)) {
    return;
  }
  final contract = ChaseContract.fromState(rewardState);
  final checkInLine = GameLogic.checkInWelcomeLine(rewardState);
  final chase = contract.chase;
  final rows = summary?.highlightRows ?? const <(String, String)>[];
  // lootLead merged into welcomeLead in the dialog body.
  final chestLine = ComebackChest.waitingLine(
    rewardState,
    sanctuaryCost: GameLogic.cheapestSanctuaryNextCost(rewardState),
  );
  final petLine = PetService.errandReady(rewardState, now)
      ? '${PetService.errandPet(rewardState)?.name ?? 'Your pet'} is home.'
      : '';

  final nav = PlayNav.maybeOf(context);
  final menu = router ?? nav?.router;
  final home = director.state.homeLayout == HomeLayout.home;
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

  final showChaseCta =
      readyAction != null &&
      plan.op != ChaseOp.enter &&
      (chase.urgency == HubChaseUrgency.ready ||
          chase.urgency == HubChaseUrgency.almost ||
          hubChaseOwnsEndgameRow(chase.kind) ||
          chase.kind == HubChaseKind.unlockZone ||
          chase.kind == HubChaseKind.clearFloors ||
          chase.kind == HubChaseKind.dailyVaultProgress ||
          chase.kind == HubChaseKind.marketUpgrade);
  // The brown button is the cave. A claim stays on the grey button so the
  // prize is still one tap, and the next press is the fight.
  final inCave = director.state.inDungeon;
  final returnLabel = inCave ? 'CONTINUE' : 'ENTER DUNGEON';
  final canSpend = menu != null && (home || nav != null);
  final gainLine = GameLogic.returnGainLine(
    rewardState,
    goldGained: summary?.goldGained ?? 0,
    essenceGained: summary?.essenceGained ?? 0,
    canOpenGold: canSpend && MenuTabs.showGold(rewardState),
    canOpenEssence: canSpend && MenuTabs.showCamp(rewardState),
  );
  final showCheckIn = checkInLine.isNotEmpty &&
      !gainLine.contains('wallet covers') &&
      !gainLine.contains('Open ESSENCE');
  final openGold = canSpend && gainLine.contains('Open GOLD');
  final openEssence = canSpend && gainLine.contains('Open ESSENCE');
  var showWatch = summary?.welcomeBackAdOffer == true;
  var watchBusy = false;
  var adNote = '';
  var offerPrepared = false;

  WebClickBridge.pushLayer();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'WELCOME BACK',
      // The dialog scrolls. A fixed 55% cap clipped Check-in on a
      // 1080×1920 phone (360×640 logical).
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary != null) ...[
            Text(
              'Away for '
              '${OfflineProgressResult.formatOfflineDuration(summary.awayForSeconds)}'
              ' · ${summary.welcomeLead}',
              style: GameTheme.readable(color: GameTheme.torchHot),
            ),
          ],
          if (gainLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              gainLine,
              style: GameTheme.readable(color: GameTheme.parchment),
            ),
          ],
          if (summary != null) ...[
            if (summary.materialsLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary.materialsLine,
                style: GameTheme.section(color: GameTheme.torchHot),
              ),
            ],
            if (summary.bestDrop.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Best find: ${summary.bestDrop}',
                style: GameTheme.section(color: GameTheme.parchment),
              ),
            ],
          ],
          if (chestLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              chestLine,
              style: GameTheme.readable(color: GameTheme.torchHot),
            ),
          ],
          if (petLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(petLine, style: GameTheme.readable(color: GameTheme.torchHot)),
          ],
          if (showCheckIn) ...[
            const SizedBox(height: 6),
            Text(
              checkInLine,
              style: GameTheme.readable(color: GameTheme.torchHot),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final row in rows.take(OfflineProgressResult.maxHighlightRows))
              if (!_lootAlreadySaid(row.$1))
                MenuChrome.statRow(label: row.$1, value: row.$2),
          ],
          if (director.state.missions.any((m) => m.canClaim)) ...[
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: director,
              builder: (context, _) {
                final ready = director.state.missions
                    .where((m) => m.canClaim)
                    .length;
                if (ready == 0) return const SizedBox.shrink();
                return GameButton(
                  label: 'COLLECT ALL',
                  style: GameButtonStyle.grey,
                  onPressed: director.claimAllReadyMissions,
                );
              },
            ),
          ],
          if (summary != null)
            StatefulBuilder(
              builder: (context, setLocal) {
                if (showWatch && !offerPrepared) {
                  offerPrepared = true;
                  unawaited(
                    AdRewarded.prepareOffer(
                      placement: AnalyticsEvents.placementWelcomeBack,
                    ),
                  );
                }
                if (adNote.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      adNote,
                      style: GameTheme.readable(color: GameTheme.torchHot),
                    ),
                  );
                }
                if (!showWatch) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShellLayout.hint(
                        'Optional. Watch an ad and this trip\'s gold and essence are doubled.',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      GameButton(
                        label: watchBusy
                            ? 'LOADING AD…'
                            : summary.welcomeBackAdLabel,
                        style: GameButtonStyle.grey,
                        onPressed: watchBusy
                            ? null
                            : () async {
                                setLocal(() => watchBusy = true);
                                final beforeGold = director.state.gold;
                                final beforeEssence = director.state.essence;
                                final ok = await director
                                    .watchWelcomeBackGoldAd(
                                      summary.goldGained,
                                      baseEssence: summary.essenceGained,
                                    );
                                if (!context.mounted) return;
                                setLocal(() {
                                  watchBusy = false;
                                  if (ok) {
                                    showWatch = false;
                                    final gold =
                                        director.state.gold - beforeGold;
                                    final essence =
                                        director.state.essence - beforeEssence;
                                    final parts = <String>[
                                      if (gold > 0) '$gold gold',
                                      if (essence > 0) '$essence essence',
                                    ];
                                    adNote = parts.isEmpty
                                        ? 'Offline loot doubled.'
                                        : 'Ad doubled ${parts.join(' and ')}.';
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      actions: [
        if (openGold)
          GameButton(
            label: 'OPEN GOLD',
            expanded: false,
            style: GameButtonStyle.grey,
            onPressed: () => _openReturnSpend(
              context,
              ctx,
              director,
              menu,
              home: home,
              panel: HomeGoldPanel.forge,
              route: MenuRoute.gold,
            ),
          )
        else if (openEssence)
          GameButton(
            label: 'OPEN ESSENCE',
            expanded: false,
            style: GameButtonStyle.grey,
            onPressed: () => _openReturnSpend(
              context,
              ctx,
              director,
              menu,
              home: home,
              panel: HomeGoldPanel.camp,
              route: MenuRoute.essence,
            ),
          )
        else if (showChaseCta)
          GameButton(
            label: readyLabel,
            expanded: false,
            style: GameButtonStyle.grey,
            onPressed: () {
              director.claimReturnRewards();
              director.dismissOfflineSummary();
              Navigator.pop(ctx);
              readyAction?.call();
            },
          ),
        GameButton(
          label: returnLabel,
          expanded: false,
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: () {
            director.claimReturnRewards();
            director.dismissOfflineSummary();
            Navigator.pop(ctx);
            if (director.state.inDungeon) {
              director.continueClearableFloor();
              return;
            }
            final id = GameLogic.recommendedDungeonId(director.state);
            // Home already enters from the shell. PlayNav on that tree must
            // not skip the unlock check the camp button uses.
            if (home) {
              if (ChaseDispatcher.zoneUnlocked(director.state, id)) {
                director.enterDungeon(dungeonId: id);
              }
              return;
            }
            if (nav != null) {
              nav.onEnterDungeon(id);
            } else if (ChaseDispatcher.zoneUnlocked(director.state, id)) {
              director.enterDungeon(dungeonId: id);
            }
          },
        ),
      ],
    ),
  ).whenComplete(WebClickBridge.popLayer);
}

void _openReturnSpend(
  BuildContext context,
  BuildContext dialogContext,
  GameDirector director,
  MenuRouter menu, {
  required bool home,
  required HomeGoldPanel panel,
  required MenuRoute route,
}) {
  director.claimReturnRewards();
  director.dismissOfflineSummary();
  Navigator.pop(dialogContext);
  if (home) {
    showHomeGoldSheet(
      context,
      director: director,
      router: menu,
      initialPanel: panel,
    );
    return;
  }
  menu.open(route);
}

bool _lootAlreadySaid(String label) =>
    label == 'Gold' ||
    label == 'Combat gold' ||
    label == 'Floors cleared' ||
    label == 'New gear';
