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
  bool _dpsMeterOpen = false;

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

  void _openMenuFeel(VoidCallback open) {
    final wasOpen = router.isOpen;
    open();
    if (!wasOpen &&
        router.isOpen &&
        state.inDungeon &&
        !state.isPartyDefeated) {
      widget.director.showToast(
        'Fight paused in menu — close to resume',
        life: 1.6,
      );
    }
  }

  Widget _buildBody(GameDirector d) {
    final hudSide = GameTheme.edgeGap;
    final hudBottom = GameTheme.hudAboveNav;
    final awaitingExit = d.spatial?.awaitingExit == true;
    // Raise party strip while walking to stairs so GO / exit stays visible.
    final partyBottom = awaitingExit ? hudBottom + 52 : hudBottom;

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
                onOpenForge: () =>
                    router.open(MenuRoute.power, power: PowerTab.forge),
                onOpenParty: () => router.toggleParty(PartyTab.gear),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The map redraws every combat frame (~60 Hz)…
                    ListenableBuilder(
                      listenable: d.combatFrame,
                      builder: (context, _) => SpatialDungeonView(director: d),
                    ),
                    // …the HUD numbers follow the director's ~10 Hz beat.
                    // Reading every hero and every enemy 60 times a second only
                    // bought digits nobody can read that fast.
                    if (!d.awaitingWipeChoice) ...[
                      // Light map dim while the DPS meter panel is open.
                      if (_dpsMeterOpen)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: const Color(0x4414100C),
                            ),
                          ),
                        ),
                      // Calm map-first HUD: meter (tap), target chip, party strip.
                      Positioned(
                        left: hudSide,
                        top: GameTheme.clusterGap / 2,
                        child: DpsMeter(
                          director: d,
                          onOpenChanged: (open) {
                            if (_dpsMeterOpen == open) return;
                            setState(() => _dpsMeterOpen = open);
                          },
                        ),
                      ),
                      Positioned(
                        right: hudSide,
                        top: GameTheme.clusterGap / 2,
                        child: TargetCornerHud(director: d),
                      ),
                      Positioned(
                        left: hudSide,
                        bottom: partyBottom,
                        child: PartyCornerHud(
                          director: d,
                          selectedHeroIndex: router.abilityHeroIndex,
                          onSelectHero: (i) => router.abilityHeroIndex = i,
                          onOpenEquip: () => router.toggleParty(PartyTab.gear),
                          onUseConsumable: d.useConsumable,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppBottomBar(
                alerts: MenuAlerts.forState(state),
                route: router.route,
                showReason: true,
                onParty: () => _openMenuFeel(
                  () => router.toggleParty(router.partyTab),
                ),
                onPower: () => _openMenuFeel(
                  () => router.toggle(MenuRoute.power),
                ),
                onMeta: () => _openMenuFeel(
                  () => router.toggle(MenuRoute.meta, state: state),
                ),
                onHubClose: widget.onLeaveDungeon == null
                    ? null
                    : () =>
                          confirmLeaveDungeon(context, widget.onLeaveDungeon!),
              ),
            ],
          ),
        ),
        if (router.isOpen)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x6614100C)),
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
        CaveAtmosphere.readabilityScrim(top: 0.18, bottom: 0.28),
        CaveAtmosphere.torchBloom(
          intensity: 0.45,
          alignment: const Alignment(0, 0.15),
          sizeFactor: 0.7,
        ),
      ],
    );
  }
}
