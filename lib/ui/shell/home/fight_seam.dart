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
import '../shell_layout.dart';
import '../dungeon_party_hud.dart';
import 'fight_seam_rails.dart';

/// FARM / PUSH, the fist, LEAVE, and the party row under the fight.
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
    final plain = GameLogic.plainPlayerChrome(state);
    final world = director.spatial;
    final farmLabel = plain ? 'Repeat' : 'FARM';
    final pushLabel = plain ? 'Next' : 'PUSH';
    return Material(
      color: GameTheme.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: ShellLayout.seamPadding,
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: MenuChrome.segmented(
                      dense: true,
                      labels: [farmLabel, pushLabel],
                      selectedIndex:
                          state.dungeonMode == DungeonMode.farm ? 0 : 1,
                      onSelect: (i) => _setMode(
                        context,
                        i == 0 ? DungeonMode.farm : DungeonMode.push,
                        plain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (world != null)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: FittedBox(
                        child: GodHandRing(
                          cooldown: world.godHandCooldown,
                          maxCooldown: state.godHandCooldownSeconds,
                          dense: true,
                          onTap: director.godHandAtFocus,
                        ),
                      ),
                    ),
                  const Spacer(),
                  _tap(
                    label: 'LEAVE',
                    onTap: onLeave,
                    minHeight: 34,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GameTheme.blood.withValues(alpha: 0.25),
                        borderRadius:
                            BorderRadius.circular(GameTheme.radiusSm),
                        border: Border.all(
                          color: GameTheme.bloodLit.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'LEAVE',
                        style: GameTheme.menuTitle(
                          size: 11,
                          color: GameTheme.bloodLit,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _tap(
                    label: state.homePanelFull
                        ? 'Split forge under fight'
                        : 'Full fight height',
                    onTap: () =>
                        director.setHomePanelFull(!state.homePanelFull),
                    minHeight: 34,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GameTheme.panelInset.withValues(alpha: 0.6),
                        borderRadius:
                            BorderRadius.circular(GameTheme.radiusSm),
                        border: Border.all(
                          color: GameTheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        state.homePanelFull ? 'SPLIT' : 'FULL',
                        style: GameTheme.menuTitle(
                          size: 10,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ShellLayout.divider(),
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
                child: _tap(
                  label: 'HOLD',
                  onTap: director.startExitHold,
                  minHeight: 34,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: GameTheme.torch.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                      border: Border.all(
                        color: GameTheme.torchHot.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'HOLD',
                      style: GameTheme.menuTitle(
                        size: 11,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!hideRails)
            FightSeamRails(director: director, router: router),
        ],
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

  Widget _tap({
    required String label,
    required VoidCallback onTap,
    required Widget child,
    double minHeight = GameTheme.minTouch,
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
            constraints: BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: minHeight,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
