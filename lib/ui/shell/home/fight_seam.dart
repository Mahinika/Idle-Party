import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/menu_router.dart';
import '../../../models/dungeon_mode.dart';
import '../../chunky_face.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../spatial_dungeon_view.dart';
import '../../web_click_bridge.dart';
import '../dungeon_party_hud.dart';
import 'fight_seam_rails.dart';

/// The party row, HOLD, and the SCROLLS / QUESTS / VAULT rail under the
/// fight. FARM / PUSH, the fist, and LEAVE sit on the field itself
/// ([FightFieldControls]) so the buy list keeps its rows.
class FightSeam extends StatelessWidget {
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
    final state = director.state;
    final world = director.spatial;
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
          if (world != null &&
              world.awaitingExit &&
              !state.isPartyDefeated &&
              !director.exitHoldActive)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: _seamTap(
                  label: 'HOLD',
                  onTap: director.startExitHold,
                  child: ChunkyFace(
                    tone: ChunkyTone.gold,
                    minHeight: GameTheme.chunkyFace,
                    child: Text(
                      'HOLD',
                      style: GameTheme.readable(
                        color: ChunkyFace.textOn(ChunkyTone.gold),
                      ),
                    ),
                  ),
                ),
              ),
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

  /// Camera bottom inset: the button row plus its pad.
  static const double cameraReserve = GameTheme.minTouch + 12;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final plain = GameLogic.plainPlayerChrome(state);
    final world = director.spatial;
    final farmLabel = plain ? 'Repeat' : 'FARM';
    final pushLabel = plain ? 'Next' : 'PUSH';
    final modeHint = plain
        ? 'Repeat loots. Next goes deeper.'
        : 'FARM loops. PUSH climbs.';
    final osScale = WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    final seamFitsExtras = osScale <= GameTheme.typeScaleMax;
    final full = state.homePanelFull;
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
            if (seamFitsExtras)
              // Dark capsule: the line sits on lit sand, where the bare
              // text was ~1.1–1.7:1. On the capsule it is above 7:1.
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    key: modeHintKey,
                    decoration: BoxDecoration(
                      color: GameTheme.stoneDeep.withValues(
                        alpha: modeHintCapsuleAlpha,
                      ),
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
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
                        style: GameTheme.hint(color: GameTheme.parchmentDim),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: MenuChrome.segmented(
                    dense: true,
                    labels: [farmLabel, pushLabel],
                    selectedIndex: state.dungeonMode == DungeonMode.farm
                        ? 0
                        : 1,
                    onSelect: (i) => _setFightMode(
                      context,
                      director,
                      i == 0 ? DungeonMode.farm : DungeonMode.push,
                      plain,
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
                  child: ChunkyFace(
                    tone: ChunkyTone.red,
                    minHeight: GameTheme.chunkyFace,
                    child: Text(
                      'LEAVE',
                      style: GameTheme.readable(
                        color: ChunkyFace.textOn(ChunkyTone.red),
                      ),
                    ),
                  ),
                ),
                if (full && seamFitsExtras) ...[
                  const SizedBox(width: 4),
                  _seamTap(
                    label: 'MORE menu',
                    onTap: () => router.open(MenuRoute.more),
                    child: ChunkyFace(
                      tone: ChunkyTone.stone,
                      minHeight: GameTheme.chunkyFace,
                      child: Text(
                        'MORE',
                        style: GameTheme.readable(color: GameTheme.torchHot),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                _seamTap(
                  label: full ? 'TALL' : 'FORGE',
                  onTap: () => director.setHomePanelFull(!full),
                  child: ChunkyFace(
                    tone: ChunkyTone.stone,
                    minHeight: GameTheme.chunkyFace,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      full ? 'TALL' : 'FORGE',
                      style: GameTheme.readable(color: GameTheme.parchment),
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
      title: mode == DungeonMode.farm
          ? (plain ? 'Switch to Repeat?' : 'Switch to FARM?')
          : (plain ? 'Switch to Next?' : 'Switch to PUSH?'),
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
