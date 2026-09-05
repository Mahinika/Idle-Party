import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/menu_alerts.dart';
import '../core/menu_router.dart';
import '../core/nav_intent.dart';
import 'confirm_dialogs.dart';
import 'cave_atmosphere.dart';
import '../assets/custom_assets.dart';
import 'game_theme.dart';
import 'spatial_dungeon_view.dart';
import 'shell/dungeon_party_hud.dart';
import 'shell/dungeon_target_hud.dart';
import 'shell/dungeon_top_hud.dart';

/// Idle Party dungeon scene: full-bleed stage + corner HUD.
/// Shared menu sheets + bottom bar are owned by [PlayShell], not this scene.
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
      router.toggleGear(GearPanel.bag);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH && widget.onLeaveDungeon != null) {
      confirmLeaveDungeon(
        context,
        widget.onLeaveDungeon!,
        state: state,
      );
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
    final partyBottom = GameTheme.combatHudBottom(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CaveAtmosphere.fullBleedScene(
            CustomAssets.dungeonBackdropFor(state.dungeonId),
          ),
        ),
        const RepaintBoundary(child: _DungeonScrimBloom()),
        // Map fills the whole scene under the floating chrome so more floor
        // stays visible under FARM / PUSH (camera gets the extra height).
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: d.combatFrame,
              builder: (context, _) => SpatialDungeonView(director: d),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              DungeonTopHud(
                state: state,
                director: d,
                onOpenSettings: () => router.open(
                  MenuRoute.more,
                  more: MoreSection.settings,
                ),
                onOpenMore: () => router.open(MenuRoute.more),
                onOpenKey: MenuTabs.showKey(state)
                    ? () => router.open(MenuRoute.key)
                    : null,
                onOpenContracts: () => router.apply(NavIntent.quests),
                onOpenForge: () => router.open(MenuRoute.gold),
                onOpenParty: () => router.toggleGear(GearPanel.gear),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!d.awaitingWipeChoice) ...[
                      if (_dpsMeterOpen)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: GameTheme.hudDimSoft,
                            ),
                          ),
                        ),
                      Positioned(
                        left: hudSide,
                        top: 2,
                        child: GameLogic.plainPlayerChrome(state)
                            ? const SizedBox.shrink()
                            : DpsMeter(
                                director: d,
                                onOpenChanged: (open) {
                                  if (_dpsMeterOpen == open) return;
                                  setState(() => _dpsMeterOpen = open);
                                },
                              ),
                      ),
                      Positioned(
                        right: hudSide,
                        top: 2,
                        child: TargetCornerHud(director: d),
                      ),
                      Positioned(
                        left: hudSide,
                        bottom: partyBottom,
                        child: PartyCornerHud(
                          director: d,
                          selectedHeroIndex: router.session.abilityHeroIndex,
                          onSelectHero: (i) =>
                              router.session.abilityHeroIndex = i,
                          onOpenEquip: () => router.toggleGear(GearPanel.gear),
                        ),
                      ),
                      Positioned(
                        right: hudSide,
                        bottom: partyBottom,
                        child: DungeonFlaskButton(
                          director: d,
                          onTap: d.useConsumable,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (router.isOpen)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: GameTheme.hudDim),
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
