import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../core/chase_dispatcher.dart';
import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../core/town_access.dart';
import '../../../models/dungeon_def.dart';
import '../../../models/hero.dart';
import '../../../models/town_building.dart';
import '../../chase_bind.dart';
import '../../confirm_dialogs.dart';
import '../../game_theme.dart';
import '../../hero_doll_sprite.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../menu_surface.dart';
import 'fight_seam_rails.dart';

/// Out-of-dungeon town on [HomeShell]: party on the square, distinct
/// buildings, one ENTER. [TownPreview] is the isolated harness.
class TownViewport extends StatefulWidget {
  const TownViewport({super.key, required this.director, required this.router});

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
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        router.open(MenuRoute.more, more: MoreSection.craft);
        router.pushSub();
      case TownBuildingId.market:
        if (!TownAccess.marketOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        router.open(MenuRoute.gold, gold: GoldPanel.market);
      case TownBuildingId.inn:
        if (!TownAccess.innOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        router.open(MenuRoute.gear, gear: GearPanel.roster);
        router.pushSub();
      case TownBuildingId.guild:
        if (!TownAccess.guildOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
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
          FightSeamRails(director: director, router: router),
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
                  if (GameLogic.canAscend(state) &&
                      plan.op != ChaseOp.confirmAscend &&
                      plan.op != ChaseOp.enter &&
                      plan.op != ChaseOp.enterKey) ...[
                    const SizedBox(height: 6),
                    GameButton(
                      label: 'ASCEND',
                      style: GameButtonStyle.brown,
                      dense: true,
                      onPressed: () => confirmAscend(context, director),
                    ),
                  ],
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
    required this.size,
    required this.state,
    required this.tier,
    required this.onTap,
    required this.badgeOf,
  });

  final Size size;
  final GameState state;
  final int tier;
  final ValueChanged<TownBuilding> onTap;
  final bool Function(TownBuildingId id) badgeOf;

  @override
  Widget build(BuildContext context) {
    final h = size.height;
    final w = size.width;
    final compact = h < 420;
    final guild = TownBuilding.byId(TownBuildingId.guild);
    final vault = TownBuilding.byId(TownBuildingId.vault);
    final partyH = compact ? 46.0 : 54.0;
    double fit(double value, double lo, double hi) {
      if (hi < lo) return hi;
      return value.clamp(lo, hi);
    }

    final frontW = fit(w / 3.15, compact ? 96.0 : 108.0, 128.0);
    // Hit boxes do not overlap, so the forge chimney cannot cover GUILD
    // or steal its tap. The cave stays visible above the plaza.
    final frontRoom = h - partyH - 64;
    final frontH = fit(
      h * 0.40,
      compact ? 88.0 : 112.0,
      fit(168, 72, frontRoom),
    );
    final frontTop = h - partyH - frontH;
    final backTop = compact ? 0.0 : 2.0;
    final guildW = fit(w * 0.46, compact ? 112.0 : 128.0, 176.0);
    final guildH = fit(frontTop - backTop - 2, 0, h);
    final vaultW = fit(w * 0.26, 72.0, 104.0);
    final vaultH = fit(guildH * 0.62, 64.0, guildH);
    final well = compact ? 36.0 : 44.0;
    final cobbleH = fit(frontTop + frontH * 0.55, partyH + 48, h * 0.78);
    final vaultPath = TownAccess.vaultClaimedToday(state)
        ? CustomAssets.townVaultOpen
        : CustomAssets.townVaultShut;
    final guildLeft = w * 0.02;
    final vaultLeft = w - vaultW - w * 0.03;

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
            repeat: ImageRepeat.repeat,
            alignment: Alignment.bottomCenter,
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
          left: guildLeft,
          top: backTop,
          width: guildW,
          height: guildH,
          child: _TownBuildingButton(
            building: guild,
            assetPath: guild.assetPath(tier),
            badge: badgeOf(guild.id),
            onTap: () => onTap(guild),
          ),
        ),
        Positioned(
          left: vaultLeft,
          top: backTop + 8,
          width: vaultW,
          height: vaultH,
          child: _TownBuildingButton(
            building: vault,
            assetPath: vaultPath,
            badge: badgeOf(vault.id),
            onTap: () => onTap(vault),
          ),
        ),
        Positioned(
          left: (w - well) / 2,
          top: frontTop - well - 2,
          width: well,
          height: well,
          child: IgnorePointer(
            child: Image.asset(
              CustomAssets.townWell,
              filterQuality: FilterQuality.none,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        for (var i = 0; i < TownBuilding.frontRow.length; i++)
          Positioned(
            left: _frontLeft(w, frontW, i),
            top: frontTop,
            width: frontW,
            height: frontH,
            child: _TownBuildingButton(
              building: TownBuilding.frontRow[i],
              assetPath: TownBuilding.frontRow[i].assetPath(tier),
              badge: badgeOf(TownBuilding.frontRow[i].id),
              onTap: () => onTap(TownBuilding.frontRow[i]),
            ),
          ),
        Positioned(
          left: GameTheme.edgeGap,
          right: GameTheme.edgeGap,
          bottom: 0,
          height: partyH,
          child: _PartyRow(heroes: state.heroes, compact: compact),
        ),
        // Chips sit on the sprites. Bottom-aligned art leaves sky above
        // the towers, so the names are not pinned to the top of the box.
        _nameChip(
          guild.label,
          left: guildLeft + 8,
          top: backTop + guildH * 0.22,
        ),
        _nameChip(
          vault.label,
          left: vaultLeft + 4,
          top: backTop + vaultH * 0.22,
        ),
        for (var i = 0; i < TownBuilding.frontRow.length; i++)
          _nameChip(
            TownBuilding.frontRow[i].label,
            left: _frontLeft(w, frontW, i) + 10,
            bottom: partyH + 2,
          ),
      ],
    );
  }

  double _frontLeft(double w, double frontW, int i) {
    const gap = 6.0;
    final total = frontW * 3 + gap * 2;
    final start = (w - total) / 2;
    return start + i * (frontW + gap);
  }

  Widget _nameChip(
    String label, {
    double? left,
    double? top,
    double? bottom,
    double? width,
  }) {
    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      width: width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GameTheme.hudPartyRowIdle.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(GameTheme.radiusHud),
            border: Border.all(color: GameTheme.equipChipNeutral),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.hint(color: GameTheme.parchment),
            ),
          ),
        ),
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
      fit: BoxFit.fitWidth,
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
      ..color = GameTheme.equipChipNeutral
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, 6), Offset(size.width, 6), line);
    const colors = [
      GameTheme.blood,
      GameTheme.borderLit,
      GameTheme.moss,
      GameTheme.navGear,
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
  const _PartyRow({required this.heroes, required this.compact});

  final List<PartyHero> heroes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : (heroes.length > 4 ? 36.0 : 42.0);
    return Semantics(
      label: 'Party resting in town',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < heroes.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeroDollSprite(hero: heroes[i], partyIndex: i, size: size),
                  Container(
                    width: size * 0.72,
                    height: 3,
                    decoration: BoxDecoration(
                      color: GameTheme.hudPartyRowIdle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
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
    required this.badge,
    required this.onTap,
  });

  final TownBuilding building;
  final String assetPath;
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetPath,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.none,
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
                      border: Border.all(color: GameTheme.stone, width: 2),
                    ),
                  ),
                ),
            ],
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
                          child: GameButton(label: 'CLOSE', onPressed: onClose),
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
      data: MediaQuery.of(
        context,
      ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
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
                  MenuSurface(director: director, router: router, home: false),
              ],
            );
          },
        ),
      ),
    );
  }
}
