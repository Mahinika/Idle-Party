import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/ashen_crown.dart';
import '../core/meta_systems.dart';
import '../core/rift.dart';
import '../core/greater_rift.dart';
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
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Text(
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
              ),
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
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Text(
                  StoryLore.rebornConfirmBody(
                    rewardEssence: reward,
                    godHandLevel: state.godHandLevel,
                    blessings: state.metaDepth.ascendBlessings,
                  ),
                  style: GameTheme.body(size: 15, color: GameTheme.parchment),
                ),
              ),
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
                label: 'CONFIRM REBORN',
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
          'Leave to hub now? This floor’s fight progress is lost '
          '(FARM loop restarts from the hub). Gear and gold already banked stay.',
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
          'Party level ${GameLogic.maxHeroLevel} endgame climb in the Crystal Spire.\n\n'
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
          'Party level ${GameLogic.maxHeroLevel} timed kill challenge.\n\n'
          'Kill $kills enemies before $par. Gold and gear drop during the run. '
          'Success pays +${essence}e · +${gold}g and unlocks higher tiers '
          '(faster clears unlock +2).\n\n'
          'Farm mode — not ranked on Play Games. Wipe or timeout ends the run. '
          'Best clear: R$best',
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

Future<void> confirmGreaterRiftRun(
  BuildContext context,
  GameDirector director,
) async {
  final state = director.state;
  if (!GameLogic.canEnterGreaterRift(state)) return;
  final tier = GreaterRift.clampTier(
    state.metaDepth.grPreferredTier.clamp(
      GreaterRift.minTier,
      GreaterRift.maxSelectableTier(state.metaDepth.grBestTier),
    ),
  );
  final kills = GreaterRift.killTarget(tier);
  final par = GreaterRift.formatTimer(GreaterRift.parTimeMs(tier));
  final essence = GreaterRift.successEssence(tier);
  final gold = GreaterRift.successGold(tier);
  final best = state.metaDepth.grBestTier;
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Greater Rift GR$tier?',
        content: Text(
          'Party level ${GameLogic.maxHeroLevel} prestige ladder — harder than farm Rifts.\n\n'
          'Kill $kills enemies before $par. Gold OK mid-run; no gear drops. '
          'Clear pays +${essence}e · +${gold}g and ranks on META → KEY · BOARDS.\n\n'
          'Fast clears unlock +2. Best clear: GR$best',
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
            label: 'ENTER GR$tier',
            style: KenneyButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      director.enterGreaterRift(tier: tier);
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
  WebClickBridge.pushLayer();
  try {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: practice ? 'Practice Ashen Crown?' : 'Ashen Crown?',
        content: Text(
          practice
              ? 'Free practice — no ticket spent, no essence reward.\n\n'
                  'Wipe or leave returns to hub. Learn the fight safely.'
              : 'Weekly ticket boss. First clear this week pays '
                  '+${AshenCrown.essenceReward}e.\n\n'
                  'Tickets left: $tickets. Wipe or leave before the clear '
                  'returns the ticket. After the paid clear, use PRACTICE '
                  '(free) instead of spending more tickets.\n\n'
                  'Returns to hub on wipe or leave.',
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
            label: practice ? 'PRACTICE' : 'ENTER',
            style: practice
                ? KenneyButtonStyle.brown
                : KenneyButtonStyle.red,
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
