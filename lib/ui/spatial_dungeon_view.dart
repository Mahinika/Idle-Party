import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
import '../spatial/tile_map.dart';
import 'custom_assets.dart';
import 'decoded_image_cache.dart';
import 'dungeon_environment.dart';
import 'game_audio.dart';
import 'game_theme.dart';
import 'hero_paper_doll.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';
import 'meta_overlays.dart';

/// Top-down tile dungeon — painted, not 100+ Image widgets.
class SpatialDungeonView extends StatefulWidget {
  const SpatialDungeonView({
    super.key,
    required this.director,
  });

  final GameDirector director;

  @override
  State<SpatialDungeonView> createState() => _SpatialDungeonViewState();
}

class _SpatialDungeonViewState extends State<SpatialDungeonView> {
  List<ui.Image> _floorReady = const [];
  List<ui.Image> _wallReady = const [];
  ui.Image? _stairs;
  ui.Image? _stairsBoss;
  ui.Image? _doorClosed;
  ui.Image? _doorOpen;
  Map<MapPropKind, ui.Image?> _propImages = const {};
  ui.Image? _hero0;
  ui.Image? _hero1;
  ui.Image? _hero2;
  ui.Image? _hero3;
  final Map<HeroClassId, ui.Image?> _heroesByClass = {};
  ui.Image? _charAtlas;
  ui.Image? _chest;
  ui.Image? _coin;
  ui.Image? _sword;
  ui.Image? _vial;
  final Map<String, ui.Image> _lootByPath = <String, ui.Image>{};
  final Map<String, ui.Image> _petsByPath = <String, ui.Image>{};
  List<ui.Image?> _enemySprites = const [];
  String? _loadedDungeonId;
  bool _sharedLoaded = false;

  bool get _tilesReady =>
      _floorReady.isNotEmpty &&
      _wallReady.isNotEmpty &&
      _stairs != null &&
      _stairsBoss != null &&
      _doorClosed != null &&
      _doorOpen != null;

  @override
  void initState() {
    super.initState();
    _loadImages(widget.director.state.dungeonId);
  }

  @override
  void didUpdateWidget(covariant SpatialDungeonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.director.state.dungeonId;
    if (id != _loadedDungeonId) {
      _loadImages(id);
    }
  }

  Future<void> _loadImages(String dungeonId) async {
    Future<ui.Image> load(
      String asset, {
      int? targetWidth,
      int? targetHeight,
    }) =>
        DecodedImageCache.load(
          asset,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );

    final floorPaths = KenneyAssets.floorVariantsForDungeon(dungeonId);
    final wallPaths = KenneyAssets.wallVariantsForDungeon(dungeonId);
    final propKinds = KenneyAssets.propPoolForDungeon(dungeonId).toSet();
    final enemyAssets = KenneyAssets.enemySpriteCatalog;

    // Shared combat icons — decode once, keep across dungeon switches.
    if (!_sharedLoaded) {
      final lootPaths = <String>{
        KenneyAssets.chestClosed,
        KenneyAssets.coinGold,
        KenneyAssets.sword,
        KenneyAssets.swordAlt,
        KenneyAssets.axe,
        KenneyAssets.dagger,
        KenneyAssets.hammer,
        KenneyAssets.staff,
        KenneyAssets.staffBlue,
        KenneyAssets.spear,
        KenneyAssets.shield,
        KenneyAssets.shieldRound,
        KenneyAssets.book,
        KenneyAssets.helmet,
        KenneyAssets.chestArmor,
        KenneyAssets.cloak,
        KenneyAssets.boots,
        KenneyAssets.gloves,
        KenneyAssets.shoulders,
        KenneyAssets.belt,
        CustomAssets.iconRing,
        KenneyAssets.ring,
        KenneyAssets.potionRed,
        KenneyAssets.potionGreen,
        KenneyAssets.potionBlue,
        KenneyAssets.vialBlue,
        KenneyAssets.iconBow,
      }.toList();

      final petPaths = <String>[
        CustomAssets.petEmberPup,
        CustomAssets.petCaveBat,
        CustomAssets.petLootSprite,
        CustomAssets.petWardenCub,
        CustomAssets.petEgg,
      ];

      final shared = await Future.wait([
        load(KenneyAssets.stairs, targetWidth: 64),
        load(KenneyAssets.stairsBoss, targetWidth: 64),
        load(KenneyAssets.doorClosed, targetWidth: 64),
        load(KenneyAssets.doorOpen, targetWidth: 64),
        load(KenneyAssets.heroKnight, targetWidth: 128),
        load(KenneyAssets.heroHealer, targetWidth: 128),
        load(KenneyAssets.heroWizard, targetWidth: 128),
        load(KenneyAssets.heroRogue, targetWidth: 128),
        load(CustomAssets.heroPaladin, targetWidth: 128),
        load(CustomAssets.heroHunter, targetWidth: 128),
        load(CustomAssets.heroDeathKnight, targetWidth: 128),
        load(CustomAssets.heroShaman, targetWidth: 128),
        load(CustomAssets.heroWarlock, targetWidth: 128),
        load(CustomAssets.heroDruid, targetWidth: 128),
        load(RoguelikeCharAtlas.assetPath, targetWidth: 512),
        ...enemyAssets.map((a) => load(a, targetWidth: 128)),
        load(KenneyAssets.chestClosed, targetWidth: 64),
        load(KenneyAssets.coinGold, targetWidth: 48),
        load(KenneyAssets.sword, targetWidth: 48),
        load(KenneyAssets.vialBlue, targetWidth: 48),
        ...lootPaths.map((a) => load(a, targetWidth: 64)),
        ...petPaths.map((a) => load(a, targetWidth: 96)),
      ]);
      if (!mounted) return;

      var i = 0;
      _stairs = shared[i++];
      _stairsBoss = shared[i++];
      _doorClosed = shared[i++];
      _doorOpen = shared[i++];
      _hero0 = shared[i++];
      _hero1 = shared[i++];
      _hero2 = shared[i++];
      _hero3 = shared[i++];
      _heroesByClass
        ..clear()
        ..[HeroClassId.warrior] = _hero0
        ..[HeroClassId.priest] = _hero1
        ..[HeroClassId.mage] = _hero2
        ..[HeroClassId.rogue] = _hero3
        ..[HeroClassId.paladin] = shared[i++]
        ..[HeroClassId.hunter] = shared[i++]
        ..[HeroClassId.deathKnight] = shared[i++]
        ..[HeroClassId.shaman] = shared[i++]
        ..[HeroClassId.warlock] = shared[i++]
        ..[HeroClassId.druid] = shared[i++];
      _charAtlas = shared[i++];
      _enemySprites = shared.sublist(i, i + enemyAssets.length);
      i += enemyAssets.length;
      _chest = shared[i++];
      _coin = shared[i++];
      _sword = shared[i++];
      _vial = shared[i++];
      _lootByPath
        ..clear()
        ..addEntries([
          for (final path in lootPaths) MapEntry(path, shared[i++]),
        ]);
      _petsByPath
        ..clear()
        ..addEntries([
          for (final path in petPaths) MapEntry(path, shared[i++]),
        ]);
      _sharedLoaded = true;
    }

    final zone = await Future.wait([
      ...floorPaths.map((a) => load(a, targetWidth: 64)),
      ...wallPaths.map((a) => load(a, targetWidth: 64)),
      ...propKinds.map(
        (k) => load(KenneyAssets.propAsset(k), targetWidth: 64),
      ),
    ]);
    if (!mounted) return;

    var zi = 0;
    final floorVariants = zone.sublist(zi, zi + floorPaths.length);
    zi += floorPaths.length;
    final wallVariants = zone.sublist(zi, zi + wallPaths.length);
    zi += wallPaths.length;
    final propKindList = propKinds.toList();
    final propImages = <MapPropKind, ui.Image>{};
    for (final kind in propKindList) {
      propImages[kind] = zone[zi++];
    }

    setState(() {
      _loadedDungeonId = dungeonId;
      _floorReady = floorVariants;
      _wallReady = wallVariants;
      _propImages = propImages;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final room = state.currentRoom;
    final farm = state.dungeonMode == DungeonMode.farm;

    final frameColor = room.type == RoomType.boss
        ? GameTheme.borderLit
        : GameTheme.mossLit;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: frameColor.withValues(alpha: 0.85), width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final camera = _TileCamera.forWorld(world, constraints);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Dungeon map — tap to use God Hand',
                      child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (widget.director.awaitingWipeChoice) return;
                        if (state.isPartyDefeated) {
                          widget.director.reviveParty();
                          return;
                        }
                        GameAudio.hit();
                        widget.director.godHandAtWorld(
                          camera.camX +
                              details.localPosition.dx / camera.tileSize,
                          camera.camY +
                              details.localPosition.dy / camera.tileSize,
                        );
                      },
                      child: world == null ||
                              !_tilesReady ||
                              _enemySprites.isEmpty ||
                              _sword == null ||
                              _vial == null ||
                              _charAtlas == null
                          ? const ColoredBox(color: GameTheme.stone)
                          : RepaintBoundary(
                              child: CustomPaint(
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              painter: _TileRoomPainter(
                                world: world,
                                party: state.heroes,
                                floorVariants: _floorReady,
                                wallVariants: _wallReady,
                                stairs: _stairs!,
                                stairsBoss: _stairsBoss!,
                                doorClosed: _doorClosed!,
                                doorOpen: _doorOpen!,
                                propImages: _propImages,
                                roomType: room.type,
                                dungeonId: state.dungeonId,
                                layoutSeed: world.map.layoutSeed,
                                clearedChambers: world.clearedChambers,
                                charAtlas: _charAtlas!,
                                heroes: <ui.Image?>[
                                  _hero0,
                                  _hero1,
                                  _hero2,
                                  _hero3,
                                ],
                                heroesByClass: _heroesByClass,
                                enemies: _enemySprites,
                                chest: _chest!,
                                coin: _coin!,
                                sword: _sword!,
                                vial: _vial!,
                                lootByPath: _lootByPath,
                                petsByPath: _petsByPath,
                                camera: camera,
                                reducedVfx: state.reducedVfx,
                                visualFrame: widget.director.visualFrame,
                              ),
                            ),
                            ),
                      ),
                    ),
                    if (world != null && world.bossBannerTimer > 0)
                      Align(
                        alignment: const Alignment(0, -0.72),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE3A1810),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GameTheme.torchHot),
                          ),
                          child: Text(
                            'BOSS — ${world.bossBannerName}',
                            style: GameTheme.pixel(
                              size: 8,
                              color: GameTheme.torchHot,
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.clearSummary != null)
                      Align(
                        alignment: const Alignment(0, -0.35),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE1A2410),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GameTheme.clear),
                          ),
                          child: Text(
                            widget.director.clearSummary!,
                            style: GameTheme.pixel(
                              size: GameTheme.hudPixel,
                              color: GameTheme.clear,
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.offlineSummary != null)
                      Align(
                        alignment: const Alignment(0, -0.55),
                        child: GestureDetector(
                          onTap: () => showOfflineProgressDialog(
                            context,
                            widget.director,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xEE1A2030),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: GameTheme.mossLit),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.director.offlineSummary!.headline,
                                  textAlign: TextAlign.center,
                                  style: GameTheme.pixel(
                                    size: GameTheme.hudPixel,
                                    color: GameTheme.mossLit,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap for details',
                                  style: GameTheme.body(
                                    size: 12,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.toast != null)
                      Align(
                        // Keep clear of bottom party HUD on phones.
                        alignment: const Alignment(0, -0.42),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xF214110C),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: GameTheme.borderLit),
                          ),
                          child: Text(
                            widget.director.toast!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.body(size: 15),
                          ),
                        ),
                      ),
                    if (widget.director.awaitingWipeChoice)
                      ColoredBox(
                        color: MenuChrome.scrim,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: DecoratedBox(
                              decoration: MenuChrome.panel(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'PARTY WIPED',
                                      style: GameTheme.pixel(
                                        size: 12,
                                        color: GameTheme.bloodLit,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      farm
                                          ? 'RETRY restarts this floor. HUB ends the run.'
                                          : 'RETRY retreats to your last cleared floor (still PUSH). HUB ends the run.',
                                      textAlign: TextAlign.center,
                                      style: GameTheme.body(
                                        size: 15,
                                        color: GameTheme.parchmentDim,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    KenneyButton(
                                      label: 'RETRY FLOOR',
                                      primary: true,
                                      onPressed: widget.director.retryAfterWipe,
                                    ),
                                    const SizedBox(height: 8),
                                    KenneyButton(
                                      label: 'RETURN TO HUB',
                                      style: KenneyButtonStyle.grey,
                                      primary: true,
                                      onPressed: widget.director.hubAfterWipe,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (!widget.director.awaitingWipeChoice &&
              (state.isPartyDefeated || (world?.awaitingExit ?? false)))
            Container(
              width: double.infinity,
              color: state.isPartyDefeated
                  ? GameTheme.blood.withValues(alpha: 0.55)
                  : const Color(0xCC0A0907),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                state.isPartyDefeated
                    ? 'WIPED — use the Retry / Hub panel'
                    : 'STAIRS OPEN — party advances when someone reaches exit',
                textAlign: TextAlign.center,
                style: GameTheme.body(
                  size: 13,
                  color: state.isPartyDefeated
                      ? GameTheme.torchHot
                      : GameTheme.parchmentDim,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChamberDots extends StatelessWidget {
  const ChamberDots({super.key, required this.world});
  final SpatialWorld world;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, world.map.chambers.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: world.clearedChambers.contains(i)
                  ? GameTheme.clear
                  : (i == world.activeChamber
                        ? GameTheme.torchHot
                        : const Color(0xFF4A4030)),
              border: Border.all(color: GameTheme.border),
            ),
          ),
      ],
    );
  }
}

class DungeonModeChip extends StatelessWidget {
  const DungeonModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF3A2810) : const Color(0xFF1A1610),
      borderRadius: BorderRadius.circular(3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          constraints: BoxConstraints(
            minHeight: dense ? 36 : GameTheme.minTouch,
          ),
          padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: selected ? GameTheme.torchHot : const Color(0xFF4A4030),
            ),
          ),
          child: Text(
            label,
            style: GameTheme.pixel(
              size: GameTheme.hudPixel,
              color: selected ? GameTheme.torchHot : GameTheme.parchmentDim,
            ),
          ),
        ),
      ),
    );
  }
}

class GodHandRing extends StatelessWidget {
  const GodHandRing({
    super.key,
    required this.cooldown,
    this.onTap,
  });
  final double cooldown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ready = cooldown <= 0;
    final t = ready ? 1.0 : (1.0 - (cooldown / 1.1).clamp(0.0, 1.0));
    final color = ready ? GameTheme.torchHot : GameTheme.parchmentDim;
    final label = ready ? 'God Hand ready' : 'God Hand cooling down';
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap != null && ready ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Semantics(
            button: true,
            enabled: onTap != null && ready,
            label: label,
            excludeSemantics: true,
            child: SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(
                painter: _GodHandRingPainter(
                  progress: t,
                  color: color,
                  ready: ready,
                ),
                child: Center(
                  child: Text(
                    'GH',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: color,
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

class _GodHandRingPainter extends CustomPainter {
  _GodHandRingPainter({
    required this.progress,
    required this.color,
    required this.ready,
  });

  final double progress;
  final Color color;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 1.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = GameTheme.ink.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = GameTheme.border.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ready ? 2.8 : 2.2
        ..strokeCap = StrokeCap.square,
    );
    if (ready) {
      canvas.drawCircle(
        c,
        r + 1.5,
        Paint()
          ..color = GameTheme.torch.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GodHandRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.ready != ready;
}

class _TileRoomPainter extends CustomPainter {
  _TileRoomPainter({
    required this.world,
    required this.party,
    required this.floorVariants,
    required this.wallVariants,
    required this.stairs,
    required this.stairsBoss,
    required this.doorClosed,
    required this.doorOpen,
    required this.propImages,
    required this.roomType,
    required this.dungeonId,
    required this.layoutSeed,
    required this.clearedChambers,
    required this.charAtlas,
    required this.heroes,
    required this.heroesByClass,
    required this.enemies,
    required this.chest,
    required this.coin,
    required this.sword,
    required this.vial,
    required this.lootByPath,
    required this.petsByPath,
    required this.camera,
    this.reducedVfx = false,
    required this.visualFrame,
  });

  final SpatialWorld world;
  final List<PartyHero> party;
  final List<ui.Image> floorVariants;
  final List<ui.Image> wallVariants;
  final ui.Image stairs;
  final ui.Image stairsBoss;
  final ui.Image doorClosed;
  final ui.Image doorOpen;
  final Map<MapPropKind, ui.Image?> propImages;
  final RoomType roomType;
  final String dungeonId;
  final int layoutSeed;
  final Set<int> clearedChambers;
  final ui.Image charAtlas;
  final List<ui.Image?> heroes;
  final Map<HeroClassId, ui.Image?> heroesByClass;
  final List<ui.Image?> enemies;
  final ui.Image chest;
  final ui.Image coin;
  final ui.Image sword;
  final ui.Image vial;
  final Map<String, ui.Image> lootByPath;
  final Map<String, ui.Image> petsByPath;
  final _TileCamera camera;
  final bool reducedVfx;
  final int visualFrame;

  Size? _vignetteSize;
  Paint? _vignettePaint;
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  static int _hashPick(int x, int y, int seed, int len) {
    if (len <= 0) return 0;
    final h = x * 73856093 ^ y * 19349663 ^ seed;
    return ((h % len) + len) % len;
  }

  bool _inView(double tx, double ty, {double pad = 1.25}) {
    return tx >= camera.camX - pad &&
        tx <= camera.camX + camera.visibleCols + pad &&
        ty >= camera.camY - pad &&
        ty <= camera.camY + camera.visibleRows + pad;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = camera.tileSize;
    final originX = -camera.camX * tile;
    final originY = -camera.camY * tile;
    final ambient = DungeonEnvironment.ambient(dungeonId);
    // Let the painted zone backdrop show through void / wall space.
    _fillPaint.color = ambient.withValues(alpha: 0.55);
    canvas.drawRect(Offset.zero & size, _fillPaint);

    final startX = camera.camX.floor().clamp(0, world.cols - 1);
    final endX = (camera.camX + camera.visibleCols).ceil().clamp(0, world.cols);
    final startY = camera.camY.floor().clamp(0, world.rows - 1);
    final endY = (camera.camY + camera.visibleRows).ceil().clamp(0, world.rows);

    final floorBlend = DungeonEnvironment.floorBlend(dungeonId);
    final corridorShade = DungeonEnvironment.corridorShade(dungeonId);

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final kind = world.map.at(x, y);
        final gate = kind == TileKind.gate ? world.map.gateAt(x, y) : null;
        final gateOpen = gate != null && world.openGateIds.contains(gate.id);
        final dst = Rect.fromLTWH(
          originX + x * tile,
          originY + y * tile,
          tile + 0.5,
          tile + 0.5,
        );

        if (kind == TileKind.wall) {
          // Void fill + thin wall caps toward carved space (no solid brick mass).
          if (DungeonEnvironment.wallTouchesCarved(world.map, x, y) &&
              wallVariants.isNotEmpty) {
            final img = wallVariants[
                _hashPick(x, y, layoutSeed + 17, wallVariants.length)];
            _drawWallCaps(canvas, x, y, dst, tile, img);
          }
          continue;
        }

        // All carved tiles share one floor base.
        final floorImg = floorVariants[
            _hashPick(x, y, layoutSeed, floorVariants.length)];
        _drawImage(canvas, floorImg, dst);
        // Mute Kenney tile chroma so painted backdrop + zone wash dominate.
        _fillPaint.color = floorBlend;
        canvas.drawRect(dst, _fillPaint);

        final noise = DungeonEnvironment.floorNoise(x, y, layoutSeed);
        if (noise.a > 0) {
          _fillPaint.color = noise;
          canvas.drawRect(dst, _fillPaint);
        }

        if (!DungeonEnvironment.inChamber(world.map, x, y) &&
            kind != TileKind.spawn &&
            kind != TileKind.exit) {
          _fillPaint.color = corridorShade;
          canvas.drawRect(dst, _fillPaint);
        }

        if (kind == TileKind.gate) {
          // Only the center cell of a 3-wide gate strip draws a door sprite.
          if (_isGateDoorCenter(x, y)) {
            final door = gateOpen ? doorOpen : doorClosed;
            final eastWest =
                DungeonEnvironment.gateRunsEastWest(world.map, x, y);
            _drawOrientedDoor(canvas, door, dst, rotate: eastWest);
            if (!gateOpen) {
              _fillPaint.color = const Color(0x44000000);
              canvas.drawRect(dst, _fillPaint);
            }
          } else if (!gateOpen) {
            // Side cells: sealed stubs, not extra door panels.
            _fillPaint.color = const Color(0x55000000);
            canvas.drawRect(dst, _fillPaint);
          }
        } else if (kind == TileKind.exit) {
          final exitImg = roomType == RoomType.boss ? stairsBoss : stairs;
          _drawImage(canvas, exitImg, dst);
        } else if (kind == TileKind.spawn) {
          _fillPaint.color = const Color(0x14C88840);
          canvas.drawRect(dst, _fillPaint);
        }
      }
    }

    // Zone atmosphere wash over terrain (under actors).
    _fillPaint.color = DungeonEnvironment.atmosphereWash(dungeonId);
    canvas.drawRect(Offset.zero & size, _fillPaint);

    // Soft vignette so the play space feels framed by the cave.
    if (_vignettePaint == null || _vignetteSize != size) {
      _vignetteSize = size;
      _vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.longestSide * 0.78,
          const [Color(0x00000000), Color(0x55000000), Color(0xBB000000)],
          const [0.28, 0.65, 1.0],
        );
    }
    canvas.drawRect(Offset.zero & size, _vignettePaint!);

    for (final chamber in world.map.chambers) {
      if (!clearedChambers.contains(chamber.index)) continue;
      // Soft clear wash only — no giant stamp clutter.
      canvas.drawRect(
        Rect.fromLTWH(
          originX + chamber.x * tile,
          originY + chamber.y * tile,
          chamber.w * tile,
          chamber.h * tile,
        ),
        Paint()..color = const Color(0x1818A050),
      );
    }

    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    void drawSprite(
      ui.Image image,
      Offset c,
      double scale, {
      double alpha = 1,
    }) {
      final s = tile * scale;
      final dst = Rect.fromCenter(center: c, width: s, height: s);
      _drawImage(canvas, image, dst, alpha: alpha);
    }

    for (final prop in world.map.props) {
      if (!_inView(prop.x + 0.5, prop.y + 0.5, pad: 0.75)) continue;
      final img = propImages[prop.kind];
      if (img == null) continue;
      drawSprite(img, center(prop.x + 0.5, prop.y + 0.5), 0.55);
    }

    void drawBar(Offset c, int hp, int maxHp, double width) {
      final frac = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
      final top = c.dy - tile * 0.55;
      final left = c.dx - width / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, 4),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width * frac, 4),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFFE05050),
      );
    }

    for (final loot in world.groundLoot) {
      if (!_inView(loot.x, loot.y)) continue;
      final bob = math.sin(loot.age * 9) * 0.12;
      final path = KenneyAssets.lootDropIconFor(loot.drop);
      final img = lootByPath[path] ??
          switch (loot.kind) {
            GroundLootKind.gold => coin,
            GroundLootKind.essence => vial,
            GroundLootKind.gear => sword,
            GroundLootKind.chest => chest,
          };
      final c = center(loot.x, loot.y + bob);
      final glow = switch (loot.drop.rarity) {
        LootRarity.common => const Color(0x66C8C0A8),
        LootRarity.uncommon => const Color(0x8870C050),
        LootRarity.rare => const Color(0x9950A0FF),
        LootRarity.epic => const Color(0xBBFFE08A),
        LootRarity.legendary => const Color(0xDDFF8C40),
      };
      final pulse = reducedVfx
          ? 1.0
          : 0.85 + 0.15 * math.sin(loot.age * 6);
      _fillPaint.color = glow;
      canvas.drawCircle(
        c,
        tile * (0.32 + loot.drop.rarity.index * 0.04) * pulse,
        _fillPaint,
      );
      if (!reducedVfx && loot.drop.rarity.index >= LootRarity.rare.index) {
        _strokePaint
          ..color = glow.withValues(alpha: 0.35)
          ..strokeWidth = 2;
        canvas.drawCircle(c, tile * 0.42 * pulse, _strokePaint);
      }
      drawSprite(img, c, loot.kind == GroundLootKind.chest ? 0.55 : 0.48);
    }

    if (world.pulseTimer > 0 && world.pulseX != null && world.pulseY != null) {
      final progress = (1 - world.pulseTimer / 0.35).clamp(0.0, 1.0);
      canvas.drawCircle(
        center(world.pulseX!, world.pulseY!),
        tile * (0.4 + progress * 2.4),
        Paint()
          ..color = const Color(0xDFFFF0A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, tile * 0.1),
      );
    }

    for (final p in world.projectiles) {
      if (p.delay > 0) continue;
      if (!_inView(p.x, p.y)) continue;
      final c = center(p.x, p.y);
      final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      final angle = speed > 0.01 ? math.atan2(p.vy, p.vx) : 0.0;
      final baseColor = switch (p.style) {
        SpellBoltStyle.fire =>
          p.label == 'PYRO' ? const Color(0xFFFF4010) : const Color(0xFFFF9030),
        SpellBoltStyle.holy => const Color(0xFFFFF0A0),
        SpellBoltStyle.frost => const Color(0xFF90D8FF),
        SpellBoltStyle.arcane => const Color(0xFFC070FF),
        SpellBoltStyle.shadow => const Color(0xFFB060E0),
        SpellBoltStyle.nature => const Color(0xFF70D070),
        SpellBoltStyle.lightning => const Color(0xFFB8F0FF),
        SpellBoltStyle.arrow => const Color(0xFFD8C070),
        SpellBoltStyle.weapon => p.team == SpatialTeam.hero
            ? (p.isCrit ? const Color(0xFFFFF0C0) : const Color(0xFFFFE08A))
            : const Color(0xFFFF6A4A),
      };
      final zoneTint = DungeonEnvironment.projectileTint(dungeonId);
      final color = Color.lerp(baseColor, zoneTint, 0.28)!;
      final len = tile * (p.pierce ? 0.55 : (0.35 + p.radius));
      final thick = math.max(2.0, tile * (0.08 + p.radius * 0.45));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);

      void drawOrb({required double core, Color? glow}) {
        canvas.drawCircle(
          Offset(-len * 0.15, 0),
          thick * 1.5,
          Paint()..color = (glow ?? color).withValues(alpha: 0.22),
        );
        canvas.drawCircle(Offset.zero, thick * core, Paint()..color = color);
        canvas.drawCircle(
          Offset.zero,
          thick * 0.4,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }

      void drawTrailBolt() {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.85, -thick * 0.9, len * 1.1, thick * 1.8),
            Radius.circular(thick),
          ),
          Paint()..color = color.withValues(alpha: 0.28),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.55, -thick * 0.45, len, thick * 0.9),
            Radius.circular(thick * 0.5),
          ),
          Paint()..color = color,
        );
        canvas.drawCircle(
          Offset(len * 0.45, 0),
          thick * 0.7,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }

      switch (p.style) {
        case SpellBoltStyle.fire:
          drawOrb(core: p.label == 'PYRO' ? 1.35 : 1.05);
        case SpellBoltStyle.holy:
          drawOrb(core: 1.1, glow: const Color(0xFFFFF8D0));
        case SpellBoltStyle.frost:
          // Icy shard / frostbolt orb
          canvas.drawCircle(
            Offset(-len * 0.2, 0),
            thick * 1.4,
            Paint()..color = color.withValues(alpha: 0.2),
          );
          final ice = Path()
            ..moveTo(len * 0.55, 0)
            ..lineTo(-len * 0.35, -thick * 1.1)
            ..lineTo(-len * 0.15, 0)
            ..lineTo(-len * 0.35, thick * 1.1)
            ..close();
          canvas.drawPath(ice, Paint()..color = color);
          canvas.drawCircle(
            Offset.zero,
            thick * 0.55,
            Paint()..color = const Color(0xFFE8F8FF),
          );
        case SpellBoltStyle.arcane:
          drawOrb(core: 1.15, glow: const Color(0xFFE0A0FF));
          canvas.drawCircle(
            Offset.zero,
            thick * 1.35,
            Paint()
              ..color = color.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, thick * 0.25),
          );
        case SpellBoltStyle.shadow:
          canvas.drawCircle(
            Offset(-len * 0.25, 0),
            thick * 1.7,
            Paint()..color = const Color(0x66201040),
          );
          drawOrb(core: 1.05, glow: const Color(0xFF602090));
        case SpellBoltStyle.nature:
          drawOrb(core: 1.05, glow: const Color(0xFFA0E080));
          // Leaf tip
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(len * 0.35, 0),
              width: thick * 1.4,
              height: thick * 0.7,
            ),
            Paint()..color = const Color(0xFFB8F090),
          );
        case SpellBoltStyle.lightning:
          // Zigzag bolt
          final zig = Path()
            ..moveTo(-len * 0.55, -thick * 0.2)
            ..lineTo(-len * 0.1, thick * 0.9)
            ..lineTo(len * 0.05, -thick * 0.6)
            ..lineTo(len * 0.55, thick * 0.15);
          canvas.drawPath(
            zig,
            Paint()
              ..color = color.withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = thick * 1.6
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            zig,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = thick * 0.55
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(
            Offset(len * 0.55, 0),
            thick * 0.65,
            Paint()..color = Colors.white,
          );
        case SpellBoltStyle.arrow:
          // Shaft
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-len * 0.65, -thick * 0.28, len * 1.05, thick * 0.56),
              Radius.circular(thick * 0.2),
            ),
            Paint()..color = const Color(0xFF8A6230),
          );
          // Fletching
          final fletch = Path()
            ..moveTo(-len * 0.55, 0)
            ..lineTo(-len * 0.85, -thick * 1.15)
            ..lineTo(-len * 0.4, 0)
            ..lineTo(-len * 0.85, thick * 1.15)
            ..close();
          canvas.drawPath(fletch, Paint()..color = const Color(0xFFC05040));
          // Arrowhead
          final head = Path()
            ..moveTo(len * 0.55, 0)
            ..lineTo(len * 0.15, -thick * 1.05)
            ..lineTo(len * 0.2, 0)
            ..lineTo(len * 0.15, thick * 1.05)
            ..close();
          canvas.drawPath(head, Paint()..color = const Color(0xFFD0D4D8));
        case SpellBoltStyle.weapon:
          drawTrailBolt();
      }
      canvas.restore();
    }

    if (world.isTreasure) {
      final ex = world.map.exitPoint;
      drawSprite(chest, center(ex.$1 + 0.5, ex.$2 + 0.5), 1.1);
    }

    for (final enemy in world.enemies) {
      if (enemy.dormant || !_inView(enemy.x, enemy.y)) continue;
      final img = enemies.isEmpty
          ? null
          : enemies[enemy.assetIndex.clamp(0, enemies.length - 1)];
      if (img == null) continue;
      final flash = enemy.attackFlash;
      final c = center(enemy.x, enemy.y);
      final scale = (enemy.role == EnemyRole.boss ? 1.05 : 0.9) *
          (1 + flash * 0.18);
      drawSprite(
        img,
        c,
        scale,
        alpha: enemy.isAlive ? 1 : 0.2,
      );
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.35 * flash,
          Paint()..color = const Color(0x66FFE8A0),
        );
      }
      if (enemy.isAlive) {
        if (enemy.livingBombTimer > 0) {
          final pulse =
              0.85 + 0.15 * math.sin(enemy.livingBombTimer * 10);
          canvas.drawCircle(
            c,
            tile * 0.5 * pulse,
            Paint()..color = const Color(0x66FF5020),
          );
          canvas.drawCircle(
            c,
            tile * 0.5 * pulse,
            Paint()
              ..color = const Color(0xCCFF7030)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.07),
          );
          // Fuse spark
          canvas.drawCircle(
            Offset(c.dx, c.dy - tile * 0.42),
            tile * 0.1,
            Paint()..color = const Color(0xFFFFF0A0),
          );
        }
        if (enemy.sunderStacks > 0 && enemy.sunderTimer > 0) {
          canvas.drawCircle(
            c,
            tile * 0.4,
            Paint()
              ..color = const Color(0x88C0A070)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, tile * 0.05),
          );
        }
        if (enemy.rootTimer > 0) {
          canvas.drawCircle(
            c,
            tile * 0.36,
            Paint()..color = const Color(0x6680D0FF),
          );
          // Stun stars
          for (var i = 0; i < 3; i++) {
            final a = enemy.rootTimer * 4 + i * 2.1;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * tile * 0.42,
                c.dy + math.sin(a) * tile * 0.28 - tile * 0.35,
              ),
              tile * 0.07,
              Paint()..color = const Color(0xFFFFF0A0),
            );
          }
        }
        drawBar(c, enemy.hp, enemy.maxHp, tile * 0.85);
      }
    }

    for (final hero in world.heroes) {
      final idx = hero.assetIndex
          .clamp(0, math.max(0, party.length - 1))
          .toInt();
      final partyHero = party.isEmpty ? null : party[idx];
      final flash = hero.attackFlash;
      var c = center(hero.x, hero.y);
      // Melee lunge toward the target while attacking (warrior especially).
      if (flash > 0.02 &&
          (hero.attackAimX != 0 || hero.attackAimY != 0)) {
        final adx = hero.attackAimX - hero.x;
        final ady = hero.attackAimY - hero.y;
        final alen = math.sqrt(adx * adx + ady * ady);
        if (alen > 0.05) {
          final punch = hero.heroRole == HeroRole.warrior ? 0.38 : 0.22;
          c = Offset(
            c.dx + (adx / alen) * tile * punch * flash,
            c.dy + (ady / alen) * tile * punch * flash,
          );
        }
      }
      final scale = 0.95 *
          (1 +
              flash *
                  (hero.heroRole == HeroRole.warrior ? 0.32 : 0.2));
      final alpha = hero.isAlive ? 1.0 : 0.25;
      // Prefer class sprite from active party hero when available.
      ui.Image? img;
      if (partyHero != null) {
        img = heroesByClass[partyHero.spec.classId];
      }
      img ??= heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
      if (img != null) {
        drawSprite(
          img,
          c,
          scale,
          alpha: hero.vanishTimer > 0 ? 0.35 : alpha,
        );
      } else if (partyHero != null) {
        final walk = flash > 0.05
            ? 1
            : ((hero.x + hero.y) * 3).floor().abs() % 2;
        HeroPaperDoll.paint(
          canvas,
          charAtlas,
          c,
          tile * scale,
          hero: partyHero,
          partyIndex: idx,
          walkFrame: walk,
          alpha: hero.vanishTimer > 0 ? 0.35 : alpha,
        );
      }
      // WoW-style persistent auras
      if (hero.iceBlockTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.62,
          Paint()..color = const Color(0x5540B0FF),
        );
        canvas.drawCircle(
          c,
          tile * 0.62,
          Paint()
            ..color = const Color(0xCCA0E8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.1),
        );
      }
      // Power Word: Shield — physical bubble around the target (WoW-style).
      if (hero.absorbShield > 0) {
        final pulse =
            0.92 + 0.08 * math.sin(hero.x * 3 + hero.absorbShield * 0.2);
        final br = tile * 0.72 * pulse;
        // Soft filled dome
        canvas.drawCircle(
          c,
          br,
          Paint()..color = const Color(0x5548A0E8),
        );
        canvas.drawCircle(
          c,
          br * 0.82,
          Paint()..color = const Color(0x3340B0FF),
        );
        // Outer rim
        canvas.drawCircle(
          c,
          br,
          Paint()
            ..color = const Color(0xEE90D8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.5, tile * 0.1),
        );
        // Specular highlight (top-left) like a glass bubble
        canvas.drawArc(
          Rect.fromCircle(center: c.translate(-br * 0.15, -br * 0.2), radius: br * 0.55),
          -2.4,
          1.2,
          false,
          Paint()
            ..color = const Color(0xAAF0FFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (hero.combustionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.5,
          Paint()
            ..color = const Color(0x88FF5020)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
      }
      if (hero.painSuppressionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.52,
          Paint()
            ..color = const Color(0x88FF8080)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
      }
      if (hero.fortitudeTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.44,
          Paint()
            ..color = const Color(0x55FFE8A0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, tile * 0.05),
        );
      }
      if (hero.bladeFlurryTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.7,
          Paint()
            ..color = const Color(0x55FF8060)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.05),
        );
      }
      if (hero.killingSpreeTimer > 0) {
        final pulse = 0.9 + 0.1 * math.sin(hero.killingSpreeTimer * 14);
        canvas.drawCircle(
          c,
          tile * 0.65 * pulse,
          Paint()
            ..color = const Color(0x88FF3030)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      }
      if (hero.powerInfusionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.58,
          Paint()
            ..color = const Color(0x88C070FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
        canvas.drawCircle(
          c,
          tile * 0.35,
          Paint()..color = const Color(0x44E0A0FF),
        );
      }
      if (hero.pomCharges > 0) {
        for (var i = 0; i < hero.pomCharges.clamp(0, 5); i++) {
          final a = hero.x + i * 1.25 + hero.pomCharges;
          canvas.drawCircle(
            Offset(
              c.dx + math.cos(a) * tile * 0.48,
              c.dy + math.sin(a) * tile * 0.48,
            ),
            tile * 0.08,
            Paint()..color = const Color(0xFFFFF0A0),
          );
        }
      }
      if (hero.innerFireActive && hero.heroRole == HeroRole.healer) {
        canvas.drawCircle(
          c,
          tile * 0.38,
          Paint()
            ..color = const Color(0x55FFE8A0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, tile * 0.05),
        );
      }
      if (hero.sliceAndDiceTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.46,
          Paint()
            ..color = const Color(0x88FFD070)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, tile * 0.05),
        );
      }
      if (hero.sprintTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.4,
          Paint()..color = const Color(0x44FFFFA0),
        );
      }
      if (hero.shieldWallTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.55,
          Paint()
            ..color = const Color(0x8890B8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      } else if (hero.shieldBlockTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.48,
          Paint()
            ..color = const Color(0x779AD0FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
      }
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.42 * flash,
          Paint()
            ..color = hero.heroRole == HeroRole.warrior
                ? const Color(0x99FFE080)
                : const Color(0x77FFF0C0),
        );
      }
      if (hero.isAlive) {
        drawBar(c, hero.hp, hero.effectiveMaxHp, tile * 0.8);
      }
    }

    for (final pet in world.pets) {
      final flash = pet.attackFlash;
      final c = center(pet.x, pet.y);
      final petKey = pet.id.startsWith('pet_') ? pet.id.substring(4) : pet.id;
      final petPath = CustomAssets.petForInstanceId(petKey);
      final petImg = petsByPath[petPath];
      drawSprite(
        petImg ?? coin,
        c,
        0.52 * (1 + flash * 0.22),
      );
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.28 * flash,
          Paint()..color = const Color(0x66FFE8A0),
        );
      }
    }

    if (!reducedVfx) {
      for (final burst in world.bursts) {
        final kind = burst.slash ? SpatialBurstKind.slash : burst.kind;
        if (kind == SpatialBurstKind.slash && burst.angle != null) {
          // Prefer longer slash window for readability.
          final alpha = (burst.life / 0.42).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final sweep = 1.45;
          final start = burst.angle! - sweep * 0.5;
          final r = tile * burst.radius * (0.7 + (1 - alpha) * 0.45);
          final paint = Paint()
            ..color = Color(burst.argb).withValues(alpha: alpha * 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(3.5, tile * 0.22)
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            start,
            sweep * alpha.clamp(0.4, 1.0),
            false,
            paint,
          );
          // Soft inner glow
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.72),
            start,
            sweep * alpha.clamp(0.4, 1.0),
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.0, tile * 0.1)
              ..strokeCap = StrokeCap.round,
          );
          // Tip spark at the leading edge of the swing
          final tipAng = start + sweep * 0.85;
          canvas.drawCircle(
            Offset(c.dx + math.cos(tipAng) * r, c.dy + math.sin(tipAng) * r),
            math.max(2.0, tile * 0.08),
            Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
          );
        } else if (kind == SpatialBurstKind.ring) {
          final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.55 + (1 - alpha) * 0.7);
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.5, tile * 0.12),
          );
          canvas.drawCircle(
            c,
            r * 0.72,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.06),
          );
        } else if (kind == SpatialBurstKind.cone && burst.angle != null) {
          final alpha = (burst.life / 0.45).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.85 + (1 - alpha) * 0.35);
          final sweep = 1.15;
          final start = burst.angle! - sweep * 0.5;
          final path = Path()
            ..moveTo(c.dx, c.dy)
            ..arcTo(
              Rect.fromCircle(center: c, radius: r),
              start,
              sweep,
              false,
            )
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.45),
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08),
          );
        } else if (kind == SpatialBurstKind.spark) {
          final alpha = (burst.life / 0.35).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.4 + alpha * 0.4);
          canvas.drawCircle(
            c,
            r,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.9),
          );
          canvas.drawCircle(
            c,
            r * 0.4,
            Paint()..color = Colors.white.withValues(alpha: alpha),
          );
          for (var i = 0; i < 4; i++) {
            final a = i * math.pi / 2 + burst.life * 8;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * r * 1.3,
                c.dy + math.sin(a) * r * 1.3,
              ),
              r * 0.25,
              Paint()
                ..color = Color(burst.argb).withValues(alpha: alpha * 0.7),
            );
          }
        } else {
          final maxLife = 0.45;
          final alpha = (burst.life / maxLife).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (1.2 - alpha * 0.35);
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.55),
          );
          canvas.drawCircle(
            c,
            r * 0.55,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.85),
          );
        }
      }
    }

    if (!reducedVfx) {
      final floaters = world.floaters;
      final start = floaters.length > 8 ? floaters.length - 8 : 0;
      final tp = TextPainter(textDirection: TextDirection.ltr);
      for (var i = start; i < floaters.length; i++) {
        final floater = floaters[i];
        if (!_inView(floater.x, floater.y, pad: 0.5)) continue;
        final alpha = (floater.life / 0.7).clamp(0.0, 1.0);
        tp.text = TextSpan(
          text: floater.text,
          style: GameTheme.pixelCached(
            size: math.max(8, tile * 0.32),
            color: Color(floater.argb).withValues(alpha: alpha),
          ),
        );
        tp.layout();
        final c = center(floater.x, floater.y);
        tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
      }
      tp.dispose();
    }
  }

  bool _isGateDoorCenter(int x, int y) {
    final map = world.map;
    final left = map.at(x - 1, y) == TileKind.gate;
    final right = map.at(x + 1, y) == TileKind.gate;
    final up = map.at(x, y - 1) == TileKind.gate;
    final down = map.at(x, y + 1) == TileKind.gate;
    if ((left && right) || (up && down)) return true; // middle of 3-strip
    if (!left && !right && !up && !down) return true; // lone gate
    return false; // strip end — no door panel
  }

  void _drawWallCaps(
    Canvas canvas,
    int x,
    int y,
    Rect dst,
    double tile,
    ui.Image wall,
  ) {
    final map = world.map;
    final t = tile * 0.34;
    // Filled strips are cheaper than clip+blit per edge.
    void strip(Rect r) {
      _drawImage(canvas, wall, r);
      _fillPaint.color = const Color(0x66000000);
      canvas.drawRect(r, _fillPaint);
    }

    if (DungeonEnvironment.isCarved(map.at(x, y + 1))) {
      strip(Rect.fromLTWH(dst.left, dst.bottom - t, dst.width, t));
    }
    if (DungeonEnvironment.isCarved(map.at(x, y - 1))) {
      strip(Rect.fromLTWH(dst.left, dst.top, dst.width, t));
    }
    if (DungeonEnvironment.isCarved(map.at(x + 1, y))) {
      strip(Rect.fromLTWH(dst.right - t, dst.top, t, dst.height));
    }
    if (DungeonEnvironment.isCarved(map.at(x - 1, y))) {
      strip(Rect.fromLTWH(dst.left, dst.top, t, dst.height));
    }
  }

  void _drawOrientedDoor(
    Canvas canvas,
    ui.Image door,
    Rect dst, {
    required bool rotate,
  }) {
    // Crop baked wall lip from the top ~20% of Kenney door tiles.
    final src = Rect.fromLTWH(
      0,
      door.height * 0.18,
      door.width.toDouble(),
      door.height * 0.82,
    );
    final doorDst = Rect.fromCenter(
      center: dst.center.translate(0, dst.height * 0.04),
      width: dst.width * 0.92,
      height: dst.height * 0.88,
    );

    if (!rotate) {
      _drawImageSrc(canvas, door, src, doorDst);
      return;
    }
    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    canvas.rotate(math.pi / 2);
    _drawImageSrc(
      canvas,
      door,
      src,
      Rect.fromCenter(
        center: Offset.zero,
        width: doorDst.width,
        height: doorDst.height,
      ),
    );
    canvas.restore();
  }

  void _drawImageSrc(
    Canvas canvas,
    ui.Image image,
    Rect src,
    Rect dst, {
    double alpha = 1,
  }) {
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect dst, {
    double alpha = 1,
  }) {
    _drawImageSrc(
      canvas,
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      alpha: alpha,
    );
  }

  @override
  bool shouldRepaint(covariant _TileRoomPainter oldDelegate) {
    return visualFrame != oldDelegate.visualFrame ||
        dungeonId != oldDelegate.dungeonId ||
        reducedVfx != oldDelegate.reducedVfx ||
        camera.camX != oldDelegate.camera.camX ||
        camera.camY != oldDelegate.camera.camY ||
        camera.tileSize != oldDelegate.camera.tileSize ||
        !identical(world, oldDelegate.world) ||
        !identical(floorVariants, oldDelegate.floorVariants) ||
        !identical(enemies, oldDelegate.enemies);
  }
}

class _TileCamera {
  const _TileCamera({
    required this.camX,
    required this.camY,
    required this.tileSize,
    required this.visibleCols,
    required this.visibleRows,
  });

  final double camX;
  final double camY;
  final double tileSize;
  final double visibleCols;
  final double visibleRows;

  factory _TileCamera.forWorld(
    SpatialWorld? world,
    BoxConstraints constraints,
  ) {
    if (world == null) {
      return const _TileCamera(
        camX: 0,
        camY: 0,
        tileSize: 1,
        visibleCols: 1,
        visibleRows: 1,
      );
    }
    // Show more of the floor so combat doesn't feel claustrophobic.
    // ~20 tiles wide on phones; a bit more on tablets/desktop.
    final targetCols = constraints.maxWidth < 700 ? 20.0 : 24.0;
    final visibleCols = math.min(targetCols, world.cols.toDouble());
    final tileSize = constraints.maxWidth / visibleCols;
    final visibleRows = constraints.maxHeight / tileSize;
    final leader =
        world.leader ?? (world.heroes.isNotEmpty ? world.heroes.first : null);
    final centerX = leader?.x ?? world.cols / 2;
    final centerY = leader?.y ?? world.rows / 2;
    final maxCamX = math.max(0.0, world.cols - visibleCols);
    final maxCamY = math.max(0.0, world.rows - visibleRows);
    return _TileCamera(
      camX: (centerX - visibleCols / 2).clamp(0.0, maxCamX).toDouble(),
      camY: (centerY - visibleRows / 2).clamp(0.0, maxCamY).toDouble(),
      tileSize: tileSize,
      visibleCols: visibleCols,
      visibleRows: visibleRows,
    );
  }
}


