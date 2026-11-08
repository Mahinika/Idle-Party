import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../core/chase_dispatcher.dart';
import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../core/town_access.dart';
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

/// Out-of-dungeon town: party on the square, distinct buildings, one ENTER.
///
/// Not wired into [HomeShell] on this branch (PR58 owns that file). Pump
/// [TownPreview] or swap `CampViewport` → this widget on merge.
class TownViewport extends StatefulWidget {
  const TownViewport({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  State<TownViewport> createState() => _TownViewportState();
}

class _TownViewportState extends State<TownViewport> {
  String? _lockedTitle;
  String? _lockedBody;

  GameDirector get director => widget.director;
  MenuRouter get router => widget.router;

  void _clearLocked() {
    if (_lockedTitle == null) return;
    setState(() {
      _lockedTitle = null;
      _lockedBody = null;
    });
  }

  void _showLocked(String title, String body) {
    router.close();
    setState(() {
      _lockedTitle = title;
      _lockedBody = body;
    });
  }

  void _openBuilding(TownBuilding building) {
    final state = director.state;
    switch (building.id) {
      case TownBuildingId.forge:
        if (!TownAccess.forgeOpen(state)) {
          _showLocked(building.label, TownAccess.lockedCopy(building.id, state));
          return;
        }
        _clearLocked();
        router.open(MenuRoute.more, more: MoreSection.craft);
      case TownBuildingId.market:
        if (!TownAccess.marketOpen(state)) {
          _showLocked(building.label, TownAccess.lockedCopy(building.id, state));
          return;
        }
        _clearLocked();
        router.open(MenuRoute.gold, gold: GoldPanel.market);
      case TownBuildingId.inn:
        if (!TownAccess.innOpen(state)) {
          _showLocked(building.label, TownAccess.lockedCopy(building.id, state));
          return;
        }
        _clearLocked();
        router.open(MenuRoute.gear, gear: GearPanel.roster);
      case TownBuildingId.guild:
        if (!TownAccess.guildOpen(state)) {
          _showLocked(building.label, TownAccess.lockedCopy(building.id, state));
          return;
        }
        _clearLocked();
        router.open(MenuRoute.more, more: MoreSection.quests);
      case TownBuildingId.vault:
        if (TownAccess.vaultClaimable(state)) {
          _clearLocked();
          director.claimDailyVault();
          return;
        }
        _showLocked(building.label, TownAccess.lockedCopy(building.id, state));
    }
  }

  bool _badge(TownBuildingId id, GameState state) {
    return switch (id) {
      TownBuildingId.forge => false,
      TownBuildingId.market => !MenuAlerts.marketAlert(state).isQuiet,
      TownBuildingId.inn => state.metaDepth.pendingHeroReveals.isNotEmpty,
      TownBuildingId.guild => state.missions.any((m) => m.canClaim),
      TownBuildingId.vault => TownAccess.vaultClaimable(state),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) => _scene(context),
    );
  }

  Widget _scene(BuildContext context) {
    final state = director.state;
    final chase = HubChase.forState(state);
    final plan = ChaseDispatcher.plan(chase, state: state);
    final label = plan.label ?? 'ENTER';
    final cave = DungeonCatalog.byId(state.dungeonId).name;
    final short = GameTheme.isShortHeight(context);
    final al = state.ascensionLevel;
    final tier = TownTier.paintedIndex(al);

    return Material(
      color: GameTheme.stoneDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: _TownBackdrop()),
                if (TownTier.showPennants(al))
                  const Positioned(
                    left: 24,
                    right: 24,
                    top: 18,
                    height: 36,
                    child: IgnorePointer(child: _TownPennants()),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return _TownSquare(
                      short: short,
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      state: state,
                      tier: tier,
                      onTap: _openBuilding,
                      badgeOf: (id) => _badge(id, state),
                    );
                  },
                ),
                if (_lockedTitle != null && _lockedBody != null)
                  Positioned.fill(
                    child: _TownLockedNote(
                      title: _lockedTitle!,
                      body: _lockedBody!,
                      onClose: _clearLocked,
                    ),
                  ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: MenuChrome.panel(opaque: true),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    TownTier.progressLine(al),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(),
                  ),
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

class _TownSquare extends StatelessWidget {
  const _TownSquare({
    required this.short,
    required this.size,
    required this.state,
    required this.tier,
    required this.onTap,
    required this.badgeOf,
  });

  final bool short;
  final Size size;
  final GameState state;
  final int tier;
  final ValueChanged<TownBuilding> onTap;
  final bool Function(TownBuildingId id) badgeOf;

  @override
  Widget build(BuildContext context) {
    final h = size.height;
    final w = size.width;
    final guild = TownBuilding.byId(TownBuildingId.guild);
    final vault = TownBuilding.byId(TownBuildingId.vault);
    final partyH = short ? 48.0 : 60.0;
    final cobbleH = short ? 40.0 : 52.0;
    final frontW = short ? 100.0 : 118.0;
    final frontH = short ? 138.0 : 168.0;
    final guildW = short ? 124.0 : 152.0;
    final guildH = short ? 164.0 : 204.0;
    final vaultW = short ? 72.0 : 88.0;
    final vaultH = short ? 92.0 : 112.0;
    final well = short ? 40.0 : 52.0;
    final vaultPath = TownAccess.vaultClaimedToday(state)
        ? CustomAssets.townVaultOpen
        : CustomAssets.townVaultShut;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: cobbleH,
          child: Image.asset(
            CustomAssets.townGround,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        if (TownTier.showArcade(state.ascensionLevel))
          Positioned(
            left: 20,
            right: 20,
            bottom: cobbleH - 8,
            height: 18,
            child: const IgnorePointer(child: _TownArcade()),
          ),
        Positioned(
          left: w * 0.08,
          top: h * (short ? 0.04 : 0.06),
          width: guildW,
          height: guildH,
          child: _TownBuildingButton(
            building: guild,
            assetPath: guild.assetPath(tier),
            width: guildW,
            height: guildH,
            badge: badgeOf(guild.id),
            onTap: () => onTap(guild),
          ),
        ),
        Positioned(
          right: w * 0.08,
          top: h * (short ? 0.12 : 0.16),
          width: vaultW,
          height: vaultH,
          child: _TownBuildingButton(
            building: vault,
            assetPath: vaultPath,
            width: vaultW,
            height: vaultH,
            badge: badgeOf(vault.id),
            onTap: () => onTap(vault),
          ),
        ),
        Positioned(
          left: (w - well) / 2,
          top: h * (short ? 0.28 : 0.32),
          width: well,
          height: well + 8,
          child: IgnorePointer(
            child: Image.asset(
              CustomAssets.townWell,
              filterQuality: FilterQuality.none,
              excludeFromSemantics: true,
            ),
          ),
        ),
        for (var i = 0; i < TownBuilding.frontRow.length; i++)
          Positioned(
            left: _frontLeft(w, frontW, i),
            bottom: partyH + (short ? 2 : 6),
            width: frontW,
            height: frontH,
            child: _TownBuildingButton(
              building: TownBuilding.frontRow[i],
              assetPath: TownBuilding.frontRow[i].assetPath(tier),
              width: frontW,
              height: frontH,
              badge: badgeOf(TownBuilding.frontRow[i].id),
              onTap: () => onTap(TownBuilding.frontRow[i]),
            ),
          ),
        Positioned(
          left: GameTheme.edgeGap,
          right: GameTheme.edgeGap,
          bottom: short ? 2 : 4,
          height: partyH,
          child: _PartyRow(heroes: state.heroes, short: short),
        ),
      ],
    );
  }

  double _frontLeft(double w, double frontW, int i) {
    const gap = 4.0;
    final total = frontW * 3 + gap * 2;
    final start = (w - total) / 2;
    return start + i * (frontW + gap);
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

class _TownPennants extends StatelessWidget {
  const _TownPennants();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PennantPainter());
  }
}

class _PennantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF3A2A18)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, 6), Offset(size.width, 6), line);
    const colors = [
      Color(0xFFB43C2C),
      Color(0xFFC9A24A),
      Color(0xFF2F4A3C),
      Color(0xFF7A342C),
    ];
    final n = 7;
    for (var i = 0; i < n; i++) {
      final x = size.width * (i + 0.5) / n;
      final path = Path()
        ..moveTo(x - 7, 6)
        ..lineTo(x + 7, 6)
        ..lineTo(x, 28)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i % colors.length]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TownArcade extends StatelessWidget {
  const _TownArcade();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: GameTheme.torch,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.heroes, required this.short});

  final List<PartyHero> heroes;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final size = short
        ? 40.0
        : (heroes.length > 4 ? 44.0 : 52.0);
    return Semantics(
      label: 'Party resting in town',
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
    );
  }
}

class _TownBuildingButton extends StatelessWidget {
  const _TownBuildingButton({
    required this.building,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.badge,
    required this.onTap,
  });

  final TownBuilding building;
  final String assetPath;
  final double width;
  final double height;
  final bool badge;
  final VoidCallback onTap;

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
          key: ValueKey('town-${building.id.name}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: GameTheme.minTouch,
              maxWidth: width,
              maxHeight: height,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                      if (badge)
                        Positioned(
                          right: 4,
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
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: GameTheme.panel.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(GameTheme.radiusHud),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
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

class _TownLockedNote extends StatelessWidget {
  const _TownLockedNote({
    required this.title,
    required this.body,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MenuChrome.scrim,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DecoratedBox(
                  decoration: MenuChrome.panel(opaque: true),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GameTheme.section(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: GameTheme.readable(),
                        ),
                        const SizedBox(height: GameTheme.clusterGap),
                        WebClickScope(
                          label: 'CLOSE',
                          onPressed: onClose,
                          child: GameButton(
                            label: 'CLOSE',
                            onPressed: onClose,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
    this.size = phoneSize,
  });

  final GameDirector director;
  final MenuRouter router;
  final double textScale;
  final Size size;

  static const Size phoneSize = Size(360, 780);
  static const Size shortSize = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: ListenableBuilder(
          listenable: Listenable.merge([router, director]),
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                TownViewport(director: director, router: router),
                if (router.isOpen)
                  MenuSurface(
                    director: director,
                    router: router,
                    home: false,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
