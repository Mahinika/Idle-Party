import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/ashen_crown.dart';
import '../core/meta_systems.dart';
import '../core/rift.dart';
import '../core/greater_rift.dart';
import '../core/story_lore.dart';
import '../models/dungeon_mode.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';
import 'meta/rift_tier_picker.dart';
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
              GameButton(
                label: 'CANCEL',
                style: GameButtonStyle.grey,
                expanded: false,
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(false),
              ),
              GameButton(
                label: 'CONFIRM ASCEND',
                style: GameButtonStyle.red,
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
bool _rebornDialogOpen = false;

Future<void> confirmRebornAtCap(
  BuildContext context,
  GameDirector director,
) async {
  final state = director.state;
  if (!GameLogic.canRebornAtCap(state)) return;
  if (_rebornDialogOpen) return;
  _rebornDialogOpen = true;

  final nav = Navigator.of(context);
  nav.popUntil((route) => route is! ModalBottomSheetRoute);

  final reward = GameLogic.rebornEssenceReward();
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
          if (!GameLogic.canRebornAtCap(director.state)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted &&
                  Navigator.of(ctx, rootNavigator: true).canPop()) {
                Navigator.of(ctx, rootNavigator: true).pop(false);
              }
            });
          }
          return MenuChrome.dialog(
            title: 'Reborn?',
            content: Text(
              StoryLore.rebornConfirmBody(
                rewardEssence: reward,
                godHandLevel: state.godHandLevel,
                blessings: state.metaDepth.ascendBlessings,
              ),
              style: GameTheme.body(size: 15, color: GameTheme.parchment),
            ),
            actions: [
              GameButton(
                label: 'CANCEL',
                style: GameButtonStyle.grey,
                expanded: false,
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(false),
              ),
              GameButton(
                label: 'CONFIRM REBORN',
                style: GameButtonStyle.red,
                expanded: false,
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(true),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true &&
        context.mounted &&
        GameLogic.canRebornAtCap(director.state)) {
      director.rebornAtCap();
    }
  } finally {
    WebClickBridge.popLayer();
    _rebornDialogOpen = false;
  }
}

Future<void> confirmLeaveDungeon(
  BuildContext context,
  VoidCallback onLeave, {
  GameState? state,
  bool floorCleared = false,
  bool keystoneActive = false,
  String? keyTimer,
}) async {
  final plain = state != null && GameLogic.plainPlayerChrome(state);
  final String body;
  if (plain) {
    body = floorCleared
        ? 'Leave to hub now? This floor is already clear — banked gear and gold stay.'
        : 'Leave to hub now? This floor’s fight restarts when you come back. '
            'Gear and gold you already got stay.';
  } else if (floorCleared) {
    body =
        'Leave to hub now? Floor is clear (stairs ready) — you keep banked gear and gold. '
        'Coming back starts a fresh floor from hub.';
  } else if (keystoneActive) {
    final timerBit = (keyTimer != null && keyTimer.isNotEmpty)
        ? ' Timer $keyTimer.'
        : '';
    body =
        'Leave to hub now? KEY run ends — timer stops.$timerBit '
        'Gear and gold already banked stay.';
  } else if (state != null && state.dungeonMode == DungeonMode.farm) {
    body =
        'Leave to hub now? FARM loop on this floor stops — you restart '
        'from hub (not the same floor mid-loop). Gear and gold already banked stay.';
  } else {
    body =
        'Leave to hub now? This floor’s fight progress is lost '
        '(PUSH climb resets from hub). Gear and gold already banked stay.';
  }
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => PopScope(
        canPop: true,
        child: MenuChrome.dialog(
          title: 'Return to hub?',
          content: Text(
            body,
            style: GameTheme.body(size: 15, color: GameTheme.parchment),
          ),
          actions: [
            GameButton(
              label: 'STAY',
              style: GameButtonStyle.grey,
              expanded: false,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            GameButton(
              label: 'RETURN',
              style: GameButtonStyle.brown,
              expanded: false,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
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
          'Endless Spire climb — not a 16th PATH cave, not a timed Rift.\n\n'
          'Floors escalate forever. Boss every 5 floors, each with a different tell. '
          'Wipe or leave returns to hub.\n\n'
          'Best clear: F$best',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          GameButton(
            label: 'CANCEL',
            style: GameButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GameButton(
            label: 'ENTER',
            style: GameButtonStyle.red,
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
  final best = state.metaDepth.riftBestTier;
  final maxSel = Rift.maxTier;
  final initial = Rift.pickerStart(
    preferred: state.metaDepth.riftPreferredTier,
    bestCleared: best,
  );
  WebClickBridge.pushLayer();
  try {
    final chosen = await showDialog<int>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => RiftTierPickerDialog(
        title: 'Farm Rift',
        prefix: 'R',
        minusLabel: 'RIFT -',
        plusLabel: 'RIFT +',
        enterLabel: (t) => 'ENTER FARM R$t',
        initial: initial,
        minTier: Rift.minTier,
        maxTier: maxSel,
        blurb:
            'Stormwake · gold + gear mid-run. Best R$best · pick any R.',
        onStep: director.setRiftPreferredTier,
      ),
    );
    if (chosen != null && context.mounted) {
      director.enterRift(tier: chosen);
    }
  } finally {
    WebClickBridge.popLayer();
  }
}

Future<void> confirmGreaterRiftRun(
  BuildContext context,
  GameDirector director,
) async {
  final state = director.state;
  if (!GameLogic.canEnterGreaterRift(state)) return;
  final best = state.metaDepth.grBestTier;
  final maxSel = GreaterRift.maxTier;
  final initial = GreaterRift.pickerStart(
    preferred: state.metaDepth.grPreferredTier,
    bestCleared: best,
  );
  WebClickBridge.pushLayer();
  try {
    final chosen = await showDialog<int>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => RiftTierPickerDialog(
        title: 'Ranked GR',
        prefix: 'GR',
        minusLabel: 'GR -',
        plusLabel: 'GR +',
        enterLabel: (t) => 'ENTER RANK GR$t',
        initial: initial,
        minTier: GreaterRift.minTier,
        maxTier: maxSel,
        blurb:
            'Mothveil · clock · no gear. Best GR$best · pick any GR.',
        onStep: director.setGrPreferredTier,
      ),
    );
    if (chosen != null && context.mounted) {
      director.enterGreaterRift(tier: chosen);
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
          'One free seeded floor for +25e — separate from Daily Vault and Quests. '
          'Clear it, then return to hub. Wipe: retry the floor or leave from MORE.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          GameButton(
            label: 'CANCEL',
            style: GameButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GameButton(
            label: 'START',
            style: GameButtonStyle.brown,
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

Future<void> confirmAshenCrown(
  BuildContext context,
  GameDirector director, {
  bool practice = false,
}) async {
  if (!AshenCrown.canEnter(director.state)) return;
  final week = AshenCrown.ensureWeek(director.state);
  final tickets = week.metaDepth.worldBossTickets;
  final cleared = week.metaDepth.worldBossClearedWeek;
  if (!practice && (cleared || tickets <= 0)) {
    director.enterAshenCrown(practice: false); // toast via director
    return;
  }
  final kit = AshenCrown.kitFor();
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: practice ? 'Practice ${kit.title}?' : '${kit.title}?',
        content: Text(
          practice
              ? 'Free practice — no ticket spent, no essence reward.\n\n'
                  '${kit.weekLine}\n\n'
                  'Wipe or leave returns to hub. Learn the fight safely.'
              : 'Weekly ticket boss in ${kit.venueName}. First clear this week pays '
                  '+${AshenCrown.essenceReward}e.\n\n'
                  '${kit.weekLine}\n\n'
                  'Tickets left: $tickets. Wipe or leave before the clear '
                  'returns the ticket. After the paid clear, use PRACTICE '
                  '(free) instead of spending more tickets.\n\n'
                  'Returns to hub on wipe or leave.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          GameButton(
            label: 'CANCEL',
            style: GameButtonStyle.grey,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GameButton(
            label: practice ? 'PRACTICE' : 'ENTER',
            style: practice
                ? GameButtonStyle.brown
                : GameButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      director.enterAshenCrown(practice: practice);
    }
  } finally {
    WebClickBridge.popLayer();
  }
}
