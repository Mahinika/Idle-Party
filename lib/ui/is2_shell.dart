import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_state.dart';
import '../core/menu_alerts.dart';
import '../core/menu_router.dart';
import 'confirm_dialogs.dart';
import 'cave_atmosphere.dart';
import 'custom_assets.dart';
import 'feedback_toast.dart';
import 'game_theme.dart';
import 'spatial_dungeon_view.dart';
import 'first_session_tips.dart';
import 'shell/app_bottom_bar.dart';
import 'shell/dungeon_party_hud.dart';
import 'shell/dungeon_target_hud.dart';
import 'shell/dungeon_top_hud.dart';
import 'shell/menu_surface.dart';

/// Idle Party dungeon shell: full-bleed stage + corner HUD; menus are the
/// shared [MenuSurface], so PARTY/POWER/META look the same as in the hub.
class Is2Shell extends StatefulWidget {
  const Is2Shell({
    super.key,
    required this.director,
    required this.router,
    required this.pulse,
    this.onLeaveDungeon,
  });

  final GameDirector director;
  final MenuRouter router;
  final double pulse;
  final VoidCallback? onLeaveDungeon;

  @override
  State<Is2Shell> createState() => _Is2ShellState();
}

class _Is2ShellState extends State<Is2Shell> {
  GameState get state => widget.director.state;
  MenuRouter get router => widget.router;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (!router.isOpen) return KeyEventResult.ignored;
      router.close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyB) {
      router.toggleParty(PartyTab.bag);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH && widget.onLeaveDungeon != null) {
      confirmLeaveDungeon(context, widget.onLeaveDungeon!);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (state.inDungeon && !state.isPartyDefeated && !router.isOpen) {
        widget.director.godHandAtFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: ListenableBuilder(
        listenable: router,
        builder: (context, _) => _buildBody(d),
      ),
    );
  }

  Widget _buildBody(GameDirector d) {
    final hudSide = GameTheme.edgeGap;
    final hudBottom = GameTheme.hudAboveNav;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CaveAtmosphere.fullBleedScene(
            CustomAssets.dungeonBackdropFor(state.dungeonId),
          ),
        ),
        const RepaintBoundary(child: _DungeonScrimBloom()),
        SafeArea(
          child: Column(
            children: [
              DungeonTopHud(
                state: state,
                director: d,
                onOpenSettings: () => router.open(MenuRoute.settings),
                onOpenContracts: () => router.open(MenuRoute.jobs),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: d.combatFrame,
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        SpatialDungeonView(director: d),
                        if (!d.awaitingWipeChoice) ...[
                          // Calm map-first HUD: meter (tap), target chip, party strip.
                          Positioned(
                            left: hudSide,
                            top: GameTheme.clusterGap / 2,
                            child: DpsMeter(director: d),
                          ),
                          Positioned(
                            right: hudSide,
                            top: GameTheme.clusterGap / 2,
                            child: TargetCornerHud(director: d),
                          ),
                          Positioned(
                            left: hudSide,
                            bottom: hudBottom,
                            child: PartyCornerHud(
                              director: d,
                              selectedHeroIndex: router.abilityHeroIndex,
                              onSelectHero: (i) => router.abilityHeroIndex = i,
                              onOpenEquip: () =>
                                  router.toggleParty(PartyTab.gear),
                              onUseConsumable: d.useConsumable,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              AppBottomBar(
                alerts: MenuAlerts.forState(state),
                route: router.route,
                onParty: () => router.toggleParty(router.partyTab),
                onPower: () => router.toggle(MenuRoute.power),
                onMeta: () => router.toggle(MenuRoute.meta),
                onHubClose: widget.onLeaveDungeon == null
                    ? null
                    : () =>
                          confirmLeaveDungeon(context, widget.onLeaveDungeon!),
              ),
            ],
          ),
        ),
        MenuSurface(director: d, router: router),
        FirstSessionTips(director: d),
        if (d.toast != null)
          Positioned.fill(
            child: FeedbackToast(
              message: d.toast!,
              alignment: router.isOpen
                  ? const Alignment(0, -0.82)
                  : const Alignment(0, -0.42),
            ),
          ),
      ],
    );
  }
}

class _DungeonScrimBloom extends StatelessWidget {
  const _DungeonScrimBloom();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CaveAtmosphere.readabilityScrim(top: 0.25, bottom: 0.35),
        CaveAtmosphere.torchBloom(
          intensity: 0.65,
          alignment: const Alignment(0, 0.15),
          sizeFactor: 0.7,
        ),
      ],
    );
  }
}
