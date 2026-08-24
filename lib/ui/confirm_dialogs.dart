import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/meta_systems.dart';
import '../core/rift.dart';
import '../core/story_lore.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';
import 'web_click_bridge.dart';

Future<void> confirmAscend(BuildContext context, GameDirector director) async {
  final state = director.state;
  if (!GameLogic.canAscend(state)) return;
  if (_ascendDialogOpen) return;
  _ascendDialogOpen = true;

  // Drop any MORE/HUB bottom sheet so Ascend is the only modal (avoids
  // stacked routes where pop hits the sheet and Ascend stays underneath).
  final nav = Navigator.of(context);
  nav.popUntil((route) => route is! ModalBottomSheetRoute);

  final nextAl = state.ascensionLevel + 1;
  final baseReward = GameLogic.ascendEssenceReward(nextAl);
  final milestone = MetaSystems.ascendMilestoneReward(
    state.ascensionLevel,
    nextAl,
  );
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => ListenableBuilder(
        listenable: director,
        builder: (ctx, _) {
          // Autopilot / double-open can ascend underneath — dismiss stale dialog.
          if (!GameLogic.canAscend(director.state)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted &&
                  Navigator.of(ctx, rootNavigator: true).canPop()) {
                Navigator.of(ctx, rootNavigator: true).pop(false);
              }
            });
          }
          return MenuChrome.dialog(
            title: 'Ascend?',
            content: Text(
              StoryLore.ascendConfirmBody(
                rewardEssence: baseReward + milestone,
                nextAl: nextAl,
                milestoneBonus: milestone,
                godHandLevel: state.godHandLevel,
                blessingsAfter: state.metaDepth.ascendBlessings + 1,
                unlockCombatRogue: state.ascensionLevel == 0,
              ),
              style: GameTheme.body(size: 15, color: GameTheme.parchment),
            ),
            actions: [
              KenneyButton(
                label: 'CANCEL',
                style: KenneyButtonStyle.grey,
                expanded: false,
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(false),
              ),
              KenneyButton(
                label: 'CONFIRM ASCEND',
                style: KenneyButtonStyle.red,
                expanded: false,
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(true),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && context.mounted && GameLogic.canAscend(director.state)) {
      director.ascend();
    }
  } finally {
    WebClickBridge.popLayer();
    _ascendDialogOpen = false;
  }
}

bool _ascendDialogOpen = false;

Future<void> confirmLeaveDungeon(
  BuildContext context,
  VoidCallback onLeave,
) async {
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Return to hub?',
        content: Text(
          'Leave the dungeon and return to the hub. '
          'Mid-floor combat progress on this room is lost.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          KenneyButton(
            label: 'STAY',
            style: KenneyButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'RETURN',
            style: KenneyButtonStyle.brown,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      onLeave();
    }
  } finally {
    WebClickBridge.popLayer();
  }
}

Future<void> confirmGauntletRun(
  BuildContext context,
  GameDirector director,
) async {
  final state = director.state;
  if (!GameLogic.canEnterGauntlet(state)) return;
  final best = state.metaDepth.gauntletBestFloor;
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Infinity Gauntlet?',
        content: Text(
          'AL${GameLogic.gauntletMinAscension}+ endgame climb in the Crystal Spire.\n\n'
          'Floors escalate forever — harder packs, bigger gold & essence. '
          'Boss every 5 floors. Wipe or leave returns to hub.\n\n'
          'Best clear: F$best',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          KenneyButton(
            label: 'CANCEL',
            style: KenneyButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'ENTER',
            style: KenneyButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      director.enterGauntlet();
    }
  } finally {
    WebClickBridge.popLayer();
  }
}

Future<void> confirmRiftRun(
  BuildContext context,
  GameDirector director,
) async {
  final state = director.state;
  if (!GameLogic.canEnterRift(state)) return;
  final tier = Rift.clampTier(
    state.metaDepth.riftPreferredTier.clamp(
      Rift.minTier,
      Rift.maxSelectableTier(state.metaDepth.riftBestTier),
    ),
  );
  final kills = Rift.killTarget(tier);
  final par = Rift.formatTimer(Rift.parTimeMs(tier));
  final essence = Rift.successEssence(tier);
  final gold = Rift.successGold(tier);
  final best = state.metaDepth.riftBestTier;
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Rift R$tier?',
        content: Text(
          'AL${Rift.minAscension} timed kill challenge.\n\n'
          'Kill $kills enemies before $par. Success pays +${essence}e · +${gold}g '
          'and unlocks higher tiers (faster clears unlock +2).\n\n'
          'Wipe or timeout ends the run. Best clear: R$best',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          KenneyButton(
            label: 'CANCEL',
            style: KenneyButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'ENTER R$tier',
            style: KenneyButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      director.enterRift(tier: tier);
    }
  } finally {
    WebClickBridge.popLayer();
  }
}

Future<void> confirmDailyRun(
  BuildContext context,
  GameDirector director,
) async {
  if (director.isDailyClaimedToday) return;
  final dungeonId = director.dailyDungeonId;
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Daily Run?',
        content: Text(
          '${StoryLore.dailyRun(dungeonId)}\n\n'
          'Starts a free seeded floor. Clear it for essence, then return to hub. '
          'Wipe: retry the floor or leave from MORE.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          KenneyButton(
            label: 'CANCEL',
            style: KenneyButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'START',
            style: KenneyButtonStyle.brown,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      director.enterDaily();
    }
  } finally {
    WebClickBridge.popLayer();
  }
}
