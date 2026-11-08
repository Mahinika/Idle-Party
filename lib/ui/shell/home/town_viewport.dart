import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../core/chase_dispatcher.dart';
import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../models/dungeon_def.dart';
import '../../../models/hero.dart';
import '../../../models/town_building.dart';
import '../../chase_bind.dart';
import '../../game_theme.dart';
import '../../hero_doll_sprite.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../menu_surface.dart';
import 'home_gold_dock.dart';
import 'upgrade_panel.dart';

/// Out-of-dungeon town: party on the square, distinct buildings, one ENTER.
///
/// Not wired into [HomeShell] on this branch (PR58 owns that file). Pump
/// [TownPreview] or swap `CampViewport` → this widget on merge.
class TownViewport extends StatelessWidget {
  const TownViewport({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  void _openBuilding(BuildContext context, TownBuilding building) {
    switch (building.id) {
      case TownBuildingId.forge:
        showHomeGoldSheet(
          context,
          director: director,
          router: router,
          initialPanel: HomeGoldPanel.forge,
        );
      case TownBuildingId.market:
        showHomeGoldSheet(
          context,
          director: director,
          router: router,
          initialPanel: HomeGoldPanel.market,
        );
      case TownBuildingId.inn:
        router.open(
          MenuRoute.gear,
          gear: MenuTabs.showRoster(director.state)
              ? GearPanel.roster
              : GearPanel.gear,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final chase = HubChase.forState(state);
    final plan = ChaseDispatcher.plan(chase, state: state);
    final label = plan.label ?? 'ENTER';
    final cave = DungeonCatalog.byId(state.dungeonId).name;
    final short = GameTheme.isShortHeight(context);

    return Material(
      color: GameTheme.stoneDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: _TownBackdrop(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: short ? 36 : 48,
                  child: Image.asset(
                    CustomAssets.townGround,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    excludeFromSemantics: true,
                  ),
                ),
                Positioned(
                  left: GameTheme.edgeGap,
                  right: GameTheme.edgeGap,
                  bottom: short ? 48 : 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final building in TownBuilding.all)
                        Expanded(
                          child: _TownBuildingButton(
                            building: building,
                            state: state,
                            onTap: () => _openBuilding(context, building),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: GameTheme.edgeGap,
                  right: GameTheme.edgeGap,
                  bottom: short ? 4 : 8,
                  child: _PartyRow(heroes: state.heroes),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: MenuChrome.panel(opaque: true),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    cave,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.section(),
                  ),
                  const SizedBox(height: GameTheme.clusterGap),
                  WebClickScope(
                    label: label,
                    onPressed: () => runChasePlan(
                      context: context,
                      director: director,
                      router: router,
                      plan: plan,
                      onEnterDungeon: (id) {
                        router.close();
                        director.enterDungeon(dungeonId: id);
                      },
                    ),
                    child: GameButton(
                      label: label,
                      onPressed: () => runChasePlan(
                        context: context,
                        director: director,
                        router: router,
                        plan: plan,
                        onEnterDungeon: (id) {
                          router.close();
                          director.enterDungeon(dungeonId: id);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TownBackdrop extends StatelessWidget {
  const _TownBackdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CustomAssets.townBackdrop,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.heroes});

  final List<PartyHero> heroes;

  @override
  Widget build(BuildContext context) {
    final size = heroes.length > 4 ? 36.0 : 44.0;
    return Semantics(
      label: 'Party resting in town',
      child: SizedBox(
        height: size + 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < heroes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: size + 8,
                  height: size + 8,
                  alignment: Alignment.center,
                  decoration: MenuChrome.dollWellDecoration(),
                  child: HeroDollSprite(
                    hero: heroes[i],
                    partyIndex: i,
                    size: size,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TownBuildingButton extends StatelessWidget {
  const _TownBuildingButton({
    required this.building,
    required this.state,
    required this.onTap,
  });

  final TownBuilding building;
  final GameState state;
  final VoidCallback onTap;

  bool get _hasBadge {
    return switch (building.id) {
      TownBuildingId.forge => !MenuAlerts.forgeAlert(state).isQuiet,
      TownBuildingId.market => !MenuAlerts.marketAlert(state).isQuiet,
      TownBuildingId.inn => state.metaDepth.pendingHeroReveals.isNotEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    final semantics = '${building.label}. ${building.description}';
    return WebClickScope(
      label: building.label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: semantics,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: GameTheme.minTouch,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Image.asset(
                      building.assetPath,
                      width: 96,
                      height: 128,
                      filterQuality: FilterQuality.none,
                    ),
                    if (_hasBadge)
                      Positioned(
                        right: 8,
                        top: 4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: GameTheme.torchHot,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: GameTheme.stone,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: GameTheme.panel.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(GameTheme.radiusHud),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      building.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.hint(color: GameTheme.parchment),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 360×780 harness so tests and previews pump the town without HomeShell.
class TownPreview extends StatelessWidget {
  const TownPreview({
    super.key,
    required this.director,
    required this.router,
    this.textScale = 1.0,
  });

  final GameDirector director;
  final MenuRouter router;
  final double textScale;

  static const Size phoneSize = Size(360, 780);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: phoneSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox.fromSize(
        size: phoneSize,
        child: ListenableBuilder(
          listenable: router,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                TownViewport(director: director, router: router),
                if (router.route == MenuRoute.gear)
                  MenuSurface(
                    director: director,
                    router: router,
                    home: true,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
