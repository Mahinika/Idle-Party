import 'package:flutter/material.dart';

import '../../../core/farm_intensity.dart';
import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import '../../../models/dungeon_mode.dart';
import '../../chunky_face.dart';
import '../../first_session_tips.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../meta/farm_strength_picker.dart';
import '../../spatial_dungeon_view.dart';
import '../../web_click_bridge.dart';
import '../dungeon_party_hud.dart';
import 'fight_seam_rails.dart';

/// The party row and the SCROLLS / QUESTS / VAULT rail under the
/// fight. FARM / PUSH, the fist, and LEAVE sit on the field itself
/// ([FightFieldControls]) so the buy list keeps its rows.
class FightSeam extends StatelessWidget {
  static const Key leaveFaceKey = ValueKey('fight-seam-leave');

  const FightSeam({
    super.key,
    required this.director,
    required this.router,
    required this.onLeave,
    this.hideRails = false,
  });

  final GameDirector director;
  final MenuRouter router;
  final VoidCallback onLeave;

  /// FULL height: drop the horizontal chip rail — MENU / nav still reach extras.
  final bool hideRails;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameTheme.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PartyCornerHud(
            director: director,
            homeRow: true,
            selectedHeroIndex: router.session.abilityHeroIndex,
            onSelectHero: (i) {
              router.session.abilityHeroIndex = i;
              director.cameraHeroIndex = i;
            },
            onOpenEquip: () => router.toggleGear(GearPanel.gear),
          ),
          if (!hideRails) FightSeamRails(director: director, router: router),
        ],
      ),
    );
  }
}

/// FARM / PUSH, the God Hand fist, LEAVE, and FORGE / TALL along the bottom
/// edge of the fight. The camera frames the party above this strip.
class FightFieldControls extends StatelessWidget {
  const FightFieldControls({
    super.key,
    required this.director,
    required this.router,
    required this.onLeave,
  });

  final GameDirector director;
  final MenuRouter router;
  final VoidCallback onLeave;

  /// Capsule behind the FARM/PUSH hint line.
  static const modeHintKey = ValueKey('fight-seam-mode-hint');
  static const double modeHintCapsuleAlpha = 0.85;

  /// FARM/PUSH line is a first-sessions tip, not forever (audit F065).
  static const int modeHintUntilClears = 20;
  static bool showModeHint(GameState s) =>
      s.metaDepth.lifetimeFloorClears < modeHintUntilClears;

  /// Seam toggle between the big fight (FULL: only the FORGE/CAMP/MARKET
  /// row) and SPLIT (the upgrade list under the fight). Arrow only; it
  /// points where the upgrade panel moves (Robert).
  static const panelToggleFaceKey = ValueKey('fight-seam-panel-toggle');
  static const String expandUpgradesLabel = 'Expand upgrades';
  static const String bigFightLabel = 'Show big fight view';
  static const double arrowEm = GameTheme.chunkyFace;
  static String panelToggleGlyph({required bool full}) => full ? '▲' : '▼';
  static String panelToggleLabel({required bool full}) =>
      full ? expandUpgradesLabel : bigFightLabel;

  /// "FARM n×" chip above the seam while FARM strength applies.
  static const farmChipKey = ValueKey('fight-seam-farm-chip');

  /// Camera bottom inset: the button row plus its pad.
  static const double cameraReserve = GameTheme.minTouch + 12;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final plain = GameLogic.plainPlayerChrome(state);
    final world = director.spatial;
    // One word pair from the first floor on (polish7 P005).
    const farmLabel = 'FARM';
    const pushLabel = 'PUSH';
    final modeHint = plain
        ? FirstSessionTips.farmPushPlain
        : 'FARM loops. PUSH climbs.';
    final osScale = WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    final seamFitsExtras = osScale <= GameTheme.typeScaleMax;
    final full = state.homePanelFull;
    final showFarmChip = FarmIntensity.applies(state);
    final wiped = director.awaitingWipeChoice;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.stoneDeep.withValues(alpha: 0),
            GameTheme.stoneDeep.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((seamFitsExtras && FightFieldControls.showModeHint(state)) ||
                showFarmChip)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    if (seamFitsExtras &&
                        FightFieldControls.showModeHint(state))
                      // Dark capsule: the line sits on lit sand, where the
                      // bare text was ~1.1–1.7:1. On the capsule it is
                      // above 7:1.
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            key: modeHintKey,
                            decoration: BoxDecoration(
                              color: GameTheme.stoneDeep.withValues(
                                alpha: modeHintCapsuleAlpha,
                              ),
                              borderRadius: BorderRadius.circular(
                                GameTheme.radiusSm,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              child: Text(
                                modeHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GameTheme.hint(
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    // FARM strength in effect; tap to change it mid-run.
                    if (showFarmChip)
                      _seamTap(
                        label:
                            '${FarmStrengthPicker.seamLabel(state)} — change FARM strength',
                        onTap: () =>
                            FarmStrengthPicker.openSheet(context, director),
                        child: ChunkyFace(
                          key: farmChipKey,
                          tone: FarmIntensity.effectiveMult(state) > 1
                              ? ChunkyTone.orange
                              : ChunkyTone.stone,
                          minHeight: GameTheme.chunkyFaceDense - 4,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ExcludeSemantics(
                            child: Text(
                              FarmStrengthPicker.seamLabel(state),
                              style: GameTheme.hint(color: GameTheme.torchHot),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Opacity(
                    opacity: wiped ? 0.38 : 1,
                    child: IgnorePointer(
                      key: const ValueKey('fight-mode-wipe-lock'),
                      ignoring: wiped,
                      child: MenuChrome.segmented(
                        dense: true,
                        labels: [farmLabel, pushLabel],
                        selectedIndex: state.dungeonMode == DungeonMode.farm
                            ? 0
                            : 1,
                        onSelect: (i) {
                          if (wiped) return;
                          _setFightMode(
                            context,
                            director,
                            i == 0 ? DungeonMode.farm : DungeonMode.push,
                            plain,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (world != null)
                  Semantics(
                    button: true,
                    label: plain
                        ? 'Long-press the fight, or tap the fist'
                        : 'God Hand — long-press the fight or tap the fist',
                    child: SizedBox(
                      width: GameTheme.minTouch,
                      height: GameTheme.minTouch,
                      child: GodHandRing(
                        cooldown: world.godHandCooldown,
                        maxCooldown: state.godHandCooldownSeconds,
                        dense: true,
                        readyLabel: plain
                            ? 'Long-press the fight, or tap the fist'
                            : null,
                        onTap: director.godHandAtFocus,
                      ),
                    ),
                  ),
                // At large text FARM/PUSH (or Repeat/Next) takes the gap
                // instead, so "Repeat" is not cut to "Repe…".
                if (osScale <= 1.2)
                  const Spacer()
                else
                  const SizedBox(width: 6),
                _seamTap(
                  label: 'LEAVE',
                  onTap: onLeave,
                  // Outline, not a solid red slab: leaving is a quiet
                  // exit beside the mode toggle, not the loudest button.
                  child: ChunkyFace(
                    key: FightSeam.leaveFaceKey,
                    tone: ChunkyTone.stone,
                    edgeColor: GameTheme.blood,
                    minHeight: GameTheme.chunkyFace,
                    child: Text(
                      'LEAVE',
                      style: GameTheme.readable(color: GameTheme.bloodLit),
                    ),
                  ),
                ),
                // No second MENU here: the top bar's MENU is one tap away
                // (polish7 P028).
                const SizedBox(width: 4),
                // Arrow only: where the upgrade panel goes on tap. FULL is
                // the big fight with just the FORGE/CAMP/MARKET row, so ▲
                // grows the panel; SPLIT shows the list, so ▼ shrinks it.
                Tooltip(
                  message: FightFieldControls.panelToggleLabel(full: full),
                  excludeFromSemantics: true,
                  child: _seamTap(
                    label: FightFieldControls.panelToggleLabel(full: full),
                    onTap: () => director.setHomePanelFull(!full),
                    child: ChunkyFace(
                      key: FightFieldControls.panelToggleFaceKey,
                      tone: ChunkyTone.stone,
                      minHeight: GameTheme.chunkyFace,
                      padding: EdgeInsets.zero,
                      child: SizedBox.square(
                        dimension: GameTheme.chunkyFace,
                        child: Center(
                          child: ExcludeSemantics(
                            child: Text(
                              FightFieldControls.panelToggleGlyph(full: full),
                              textScaler: TextScaler.noScaling,
                              // IdleArrows draws ▲/▼ at about a third of
                              // the em, so the em fills the face.
                              style:
                                  GameTheme.readable(
                                    color: GameTheme.torchHot,
                                  ).copyWith(
                                    fontSize: FightFieldControls.arrowEm,
                                    height: 1,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _setFightMode(
  BuildContext context,
  GameDirector director,
  DungeonMode mode,
  bool plain,
) {
  final state = director.state;
  final world = director.spatial;
  final fighting = world?.enemies.any((e) => e.isAlive) ?? false;
  if (!fighting || state.dungeonMode == mode) {
    director.setDungeonMode(mode);
    return;
  }
  showDialog<bool>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: mode == DungeonMode.farm ? 'Switch to FARM?' : 'Switch to PUSH?',
      content: Text(
        'You are mid-fight. Switch anyway?',
        style: GameTheme.readable(color: GameTheme.parchment),
      ),
      actions: [
        GameButton(
          label: 'CANCEL',
          style: GameButtonStyle.grey,
          expanded: false,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        GameButton(
          label: 'SWITCH',
          expanded: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  ).then((ok) {
    if (ok == true) director.setDungeonMode(mode);
  });
}

Widget _seamTap({
  required String label,
  required VoidCallback onTap,
  required Widget child,
}) {
  return WebClickScope(
    label: label,
    onPressed: onTap,
    child: Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: GameTheme.minTouch,
            minHeight: GameTheme.minTouch,
          ),
          child: Center(child: child),
        ),
      ),
    ),
  );
}
