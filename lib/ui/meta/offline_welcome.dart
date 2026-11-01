import 'package:flutter/material.dart';

import 'dart:async' show unawaited;

import '../../core/ad_rewarded.dart';
import '../../core/analytics_events.dart';
import '../../core/chase_contract.dart';
import '../../core/chase_dispatcher.dart';
import '../../core/comeback_chest.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/hub_chase.dart';
import '../../core/pet_service.dart';
import '../chase_bind.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/play_nav.dart';
import '../web_click_bridge.dart';

/// Short Welcome Back: wow lead, ≤3 highlights, one Up next, dismiss.
Future<void> showOfflineProgressDialog(
  BuildContext context,
  GameDirector director,
) async {
  final summary = director.offlineSummary;
  final rewardState = summary?.state ?? director.state;
  final now = DateTime.now();
  if (summary == null && !GameLogic.returnCardWaiting(rewardState, now)) {
    return;
  }
  final contract = ChaseContract.fromState(rewardState);
  final checkInLine = GameLogic.checkInWelcomeLine(rewardState);
  final showCheckIn =
      checkInLine.isNotEmpty && !contract.detail.contains('Check-in');
  final chase = contract.chase;
  final rows = summary?.highlightRows ?? const <(String, String)>[];
  final lead = summary?.lootLead;
  final chestLine = ComebackChest.waitingLine(
    rewardState,
    sanctuaryCost: GameLogic.cheapestSanctuaryNextCost(rewardState),
  );
  final petLine = PetService.errandReady(rewardState, now)
      ? '${PetService.errandPet(rewardState)?.name ?? 'Your pet'} is home.'
      : '';

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
          if (lead != null) ...[
            Text(
              lead,
              style: GameTheme.body(size: 16, color: GameTheme.torchHot),
            ),
            const SizedBox(height: 6),
          ],
          if (summary != null) ...[
            Text(
              'Away for ${OfflineProgressResult.formatOfflineDuration(summary.awayForSeconds)} · ${summary.welcomeLead}',
              style: GameTheme.body(size: 14, color: GameTheme.parchment),
            ),
            const SizedBox(height: 6),
            Text(
              summary.afkWhereLine,
              style: GameTheme.body(size: 13, color: GameTheme.mossLit),
            ),
            if (summary.awayReport.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary.awayReport,
                style: GameTheme.body(size: 13, color: GameTheme.parchment),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              GoldIncome.awayPromise(
                summary.state,
                wasInDungeon: summary.wasInDungeon,
              ),
              style: GameTheme.body(size: 13, color: GameTheme.mossLit),
            ),
          ],
          if (chestLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              chestLine,
              style: GameTheme.body(size: 14, color: GameTheme.torchHot),
            ),
          ],
          if (petLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              petLine,
              style: GameTheme.body(size: 14, color: GameTheme.torchHot),
            ),
          ],
          if (showCheckIn) ...[
            const SizedBox(height: 6),
            Text(
              checkInLine,
              style: GameTheme.body(size: 14, color: GameTheme.torchHot),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final row in rows)
              if (lead == null || !_lootAlreadySaid(row.$1))
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
                      style: GameTheme.body(
                        size: 14,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  );
                }
                if (!showWatch) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Optional. Watch an ad and this trip\'s gold and essence are doubled.',
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchment,
                        ),
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
                                final ok = await director.watchWelcomeBackGoldAd(
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
          if (contract.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contract.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
          ],
        ],
      ),
      actions: [
        if (showChaseCta)
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
          onPressed: () {
            director.claimReturnRewards();
            director.dismissOfflineSummary();
            Navigator.pop(ctx);
            if (director.state.inDungeon) {
              director.continueClearableFloor();
              return;
            }
            final id = GameLogic.recommendedDungeonId(director.state);
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

bool _lootAlreadySaid(String label) =>
    label == 'Gold' ||
    label == 'Combat gold' ||
    label == 'Floors cleared' ||
    label == 'New gear';
