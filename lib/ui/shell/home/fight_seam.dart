import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/menu_router.dart';
import '../../../models/dungeon_mode.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../spatial_dungeon_view.dart';
import '../../web_click_bridge.dart';
import '../dungeon_party_hud.dart';

/// FARM / PUSH, the fist, LEAVE, and the party row under the fight.
class FightSeam extends StatelessWidget {
  const FightSeam({
    super.key,
    required this.director,
    required this.router,
    required this.onLeave,
  });

  final GameDirector director;
  final MenuRouter router;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final plain = GameLogic.plainPlayerChrome(state);
    final world = director.spatial;
    final farmLabel = plain ? 'Repeat' : 'FARM';
    final pushLabel = plain ? 'Next' : 'PUSH';
    return Material(
      color: GameTheme.stone.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: GameTheme.minTouch,
              child: Row(
                children: [
                  _mode(
                    context,
                    label: farmLabel,
                    selected: state.dungeonMode == DungeonMode.farm,
                    onTap: () => _setMode(context, DungeonMode.farm, plain),
                  ),
                  const SizedBox(width: 4),
                  _mode(
                    context,
                    label: pushLabel,
                    selected: state.dungeonMode == DungeonMode.push,
                    onTap: () => _setMode(context, DungeonMode.push, plain),
                  ),
                  const SizedBox(width: 4),
                  if (world != null)
                    GodHandRing(
                      cooldown: world.godHandCooldown,
                      maxCooldown: state.godHandCooldownSeconds,
                      dense: true,
                      onTap: director.godHandAtFocus,
                    ),
                  const Spacer(),
                  _tap(
                    label: 'LEAVE',
                    onTap: onLeave,
                    child: Text(
                      'LEAVE',
                      style: GameTheme.menuTitle(size: 12),
                    ),
                  ),
                  _tap(
                    label: state.homePanelFull ? 'SPLIT' : 'FULL',
                    onTap: () =>
                        director.setHomePanelFull(!state.homePanelFull),
                    child: Text(
                      state.homePanelFull ? 'SPLIT' : 'FULL',
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: PartyCornerHud(
              director: director,
              selectedHeroIndex: router.session.abilityHeroIndex,
              onSelectHero: (i) {
                router.session.abilityHeroIndex = i;
                director.cameraHeroIndex = i;
              },
              onOpenEquip: () => router.toggleGear(GearPanel.gear),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setMode(BuildContext context, DungeonMode mode, bool plain) {
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

  Widget _mode(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _tap(
      label: label,
      onTap: onTap,
      child: Text(
        label,
        style: GameTheme.menuTitle(
          size: 12,
          color: selected ? GameTheme.torchHot : GameTheme.parchment,
        ),
      ),
    );
  }

  Widget _tap({
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
}
