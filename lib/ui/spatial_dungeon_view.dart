import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/class_ability.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
import '../spatial/tile_map.dart';
import 'game_audio.dart';
import 'game_theme.dart';
import 'hero_paper_doll.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';

/// Top-down tile dungeon — painted, not 100+ Image widgets.
class SpatialDungeonView extends StatefulWidget {
  const SpatialDungeonView({
    super.key,
    required this.director,
    this.abilityHeroIndex,
    this.onAbilityHeroChanged,
  });

  final GameDirector director;
  final int? abilityHeroIndex;
  final ValueChanged<int>? onAbilityHeroChanged;

  @override
  State<SpatialDungeonView> createState() => _SpatialDungeonViewState();
}

class _SpatialDungeonViewState extends State<SpatialDungeonView> {
  List<ui.Image?> _floorVariants = const [];
  List<ui.Image?> _wallVariants = const [];
  ui.Image? _stairs;
  ui.Image? _stairsBoss;
  ui.Image? _doorClosed;
  ui.Image? _doorOpen;
  Map<MapPropKind, ui.Image?> _propImages = const {};
  ui.Image? _hero0;
  ui.Image? _hero1;
  ui.Image? _hero2;
  ui.Image? _hero3;
  ui.Image? _charAtlas;
  ui.Image? _chest;
  ui.Image? _coin;
  ui.Image? _sword;
  ui.Image? _vial;
  List<ui.Image?> _enemySprites = const [];
  String? _loadedDungeonId;

  bool get _tilesReady =>
      _floorVariants.isNotEmpty &&
      _wallVariants.isNotEmpty &&
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
    Future<ui.Image> load(String asset) async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }

    final floorPaths = KenneyAssets.floorVariantsForDungeon(dungeonId);
    final wallPaths = KenneyAssets.wallVariantsForDungeon(dungeonId);
    final propKinds = KenneyAssets.propPoolForDungeon(dungeonId).toSet();
    final enemyAssets = KenneyAssets.enemySpriteCatalog;

    final results = await Future.wait([
      ...floorPaths.map(load),
      ...wallPaths.map(load),
      load(KenneyAssets.stairs),
      load(KenneyAssets.stairsBoss),
      load(KenneyAssets.doorClosed),
      load(KenneyAssets.doorOpen),
      ...propKinds.map((k) => load(KenneyAssets.propAsset(k))),
      load(KenneyAssets.heroKnight),
      load(KenneyAssets.heroHealer),
      load(KenneyAssets.heroWizard),
      load(KenneyAssets.heroRogue),
      load(RoguelikeCharAtlas.assetPath),
      ...enemyAssets.map(load),
      load(KenneyAssets.chestClosed),
      load(KenneyAssets.coinGold),
      load(KenneyAssets.sword),
      load(KenneyAssets.vialBlue),
    ]);
    if (!mounted) return;

    var i = 0;
    final floorVariants = results.sublist(i, i + floorPaths.length);
    i += floorPaths.length;
    final wallVariants = results.sublist(i, i + wallPaths.length);
    i += wallPaths.length;
    final stairs = results[i++];
    final stairsBoss = results[i++];
    final doorClosed = results[i++];
    final doorOpen = results[i++];
    final propKindList = propKinds.toList();
    final propImages = <MapPropKind, ui.Image>{};
    for (final kind in propKindList) {
      propImages[kind] = results[i++];
    }
    final hero0 = results[i++];
    final hero1 = results[i++];
    final hero2 = results[i++];
    final hero3 = results[i++];
    final charAtlas = results[i++];
    final enemySprites = results.sublist(i, i + enemyAssets.length);
    i += enemyAssets.length;
    final chest = results[i++];
    final coin = results[i++];
    final sword = results[i++];
    final vial = results[i++];

    setState(() {
      _loadedDungeonId = dungeonId;
      _floorVariants = floorVariants;
      _wallVariants = wallVariants;
      _stairs = stairs;
      _stairsBoss = stairsBoss;
      _doorClosed = doorClosed;
      _doorOpen = doorOpen;
      _propImages = propImages;
      _hero0 = hero0;
      _hero1 = hero1;
      _hero2 = hero2;
      _hero3 = hero3;
      _charAtlas = charAtlas;
      _enemySprites = enemySprites;
      _chest = chest;
      _coin = coin;
      _sword = sword;
      _vial = vial;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final room = state.currentRoom;
    final dungeonName =
        GameLogic.dungeonNames[state.dungeonId] ?? state.dungeonId;
    final farm = state.dungeonMode == DungeonMode.farm;

    final frameColor = room.type == RoomType.boss
        ? GameTheme.borderLit
        : GameTheme.mossLit;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: frameColor.withValues(alpha: 0.55), width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC24180E), Color(0x9914110C)],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$dungeonName  F${room.floorNumber}'
                    '${room.type == RoomType.boss ? '  BOSS' : ''}'
                    '${room.type == RoomType.elite ? '  ELITE' : ''}'
                    '${room.type == RoomType.treasure ? '  LOOT' : ''}'
                    '  ·  ${farm ? 'FARM' : 'PUSH'}',
                    style: GameTheme.pixel(size: GameTheme.hudPixel),
                  ),
                ),
                if (world != null) ...[
                  _ChamberDots(world: world),
                  const SizedBox(width: 6),
                  _GodHandRing(cooldown: world.godHandCooldown),
                  const SizedBox(width: 4),
                ],
                SizedBox(
                  width: GameTheme.minTouch,
                  height: GameTheme.minTouch,
                  child: PopupMenuButton<String>(
                    tooltip: 'Stage options',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_horiz,
                      color: GameTheme.torchHot,
                      size: 22,
                    ),
                    color: GameTheme.stoneDeep,
                    onSelected: (value) {
                      switch (value) {
                        case 'farm':
                          widget.director.setDungeonMode(DungeonMode.farm);
                        case 'push':
                          widget.director.setDungeonMode(DungeonMode.push);
                        case 'down':
                          widget.director.travelToFloor(room.floorNumber - 1);
                        case 'up':
                          widget.director.travelToFloor(room.floorNumber + 1);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'farm',
                        enabled: !farm,
                        child: Text(
                          'FARM MODE',
                          style: GameTheme.pixel(
                            size: GameTheme.hudPixel,
                            color: farm ? GameTheme.torchHot : GameTheme.parchment,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'push',
                        enabled: farm,
                        child: Text(
                          'PUSH MODE',
                          style: GameTheme.pixel(
                            size: GameTheme.hudPixel,
                            color: !farm
                                ? GameTheme.torchHot
                                : GameTheme.parchment,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: GameLogic.canTravelToFloor(
                          state,
                          room.floorNumber - 1,
                        ),
                        child: Text(
                          'FLOOR −1',
                          style: GameTheme.pixel(size: GameTheme.hudPixel),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'up',
                        enabled: GameLogic.canTravelToFloor(
                          state,
                          room.floorNumber + 1,
                        ),
                        child: Text(
                          'FLOOR +1',
                          style: GameTheme.pixel(size: GameTheme.hudPixel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final camera = _TileCamera.forWorld(world, constraints);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
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
                          : CustomPaint(
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              painter: _TileRoomPainter(
                                world: world,
                                party: state.heroes,
                                floorVariants: _floorVariants
                                    .whereType<ui.Image>()
                                    .toList(),
                                wallVariants: _wallVariants
                                    .whereType<ui.Image>()
                                    .toList(),
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
                                enemies: _enemySprites,
                                chest: _chest!,
                                coin: _coin!,
                                sword: _sword!,
                                vial: _vial!,
                                camera: camera,
                                reducedVfx: state.reducedVfx,
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
                            'BOSS â€” ${world.bossBannerName}',
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
                          onTap: widget.director.dismissOfflineSummary,
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
                            child: Text(
                              widget.director.offlineSummary!.headline,
                              textAlign: TextAlign.center,
                              style: GameTheme.pixel(
                                size: GameTheme.hudPixel,
                                color: GameTheme.mossLit,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.toast != null)
                      Align(
                        alignment: const Alignment(0, 0.55),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE14110C),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: GameTheme.borderLit),
                          ),
                          child: Text(
                            widget.director.toast!,
                            style: GameTheme.body(size: 16),
                          ),
                        ),
                      ),
                    if (world != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: GameTheme.isCompactWidth(context) ? 78 : 56,
                          ),
                          child: _PartyAbilityHud(
                            state: state,
                            world: world,
                            selectedHeroIndex: widget.abilityHeroIndex,
                            onSelectHero: widget.onAbilityHeroChanged,
                          ),
                        ),
                      ),
                    if (widget.director.awaitingWipeChoice)
                      ColoredBox(
                        color: const Color(0xCC0A0604),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
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
                                  'Retry the floor or return to hub.',
                                  textAlign: TextAlign.center,
                                  style: GameTheme.body(
                                    size: 16,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                KenneyButton(
                                  label: 'RETRY',
                                  onPressed: widget.director.retryAfterWipe,
                                ),
                                const SizedBox(height: 8),
                                KenneyButton(
                                  label: 'HUB',
                                  style: KenneyButtonStyle.grey,
                                  onPressed: widget.director.hubAfterWipe,
                                ),
                              ],
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
                    ? 'WIPED â€” choose Retry or Hub'
                    : 'STAIRS OPEN â€” party advances when someone reaches exit',
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

class _ChamberDots extends StatelessWidget {
  const _ChamberDots({required this.world});
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

class _GodHandRing extends StatelessWidget {
  const _GodHandRing({required this.cooldown});
  final double cooldown;

  @override
  Widget build(BuildContext context) {
    final ready = cooldown <= 0;
    final t = ready ? 1.0 : (1.0 - (cooldown / 1.1).clamp(0.0, 1.0));
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: t,
            strokeWidth: 2.5,
            color: ready ? GameTheme.torchHot : GameTheme.parchmentDim,
            backgroundColor: const Color(0xFF2A2418),
          ),
          Text(
            'GH',
            style: GameTheme.pixel(
              size: 6,
              color: ready ? GameTheme.torchHot : GameTheme.parchmentDim,
            ),
          ),
        ],
      ),
    );
  }
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
    required this.enemies,
    required this.chest,
    required this.coin,
    required this.sword,
    required this.vial,
    required this.camera,
    this.reducedVfx = false,
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
  final List<ui.Image?> enemies;
  final ui.Image chest;
  final ui.Image coin;
  final ui.Image sword;
  final ui.Image vial;
  final _TileCamera camera;
  final bool reducedVfx;

  static int _hashPick(int x, int y, int seed, int len) {
    if (len <= 0) return 0;
    final h = x * 73856093 ^ y * 19349663 ^ seed;
    return ((h % len) + len) % len;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = camera.tileSize;
    final originX = -camera.camX * tile;
    final originY = -camera.camY * tile;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0C0B09),
    );

    final startX = camera.camX.floor().clamp(0, world.cols - 1);
    final endX = (camera.camX + camera.visibleCols).ceil().clamp(0, world.cols);
    final startY = camera.camY.floor().clamp(0, world.rows - 1);
    final endY = (camera.camY + camera.visibleRows).ceil().clamp(0, world.rows);

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
          final img = wallVariants[
              _hashPick(x, y, layoutSeed + 17, wallVariants.length)];
          _drawImage(canvas, img, dst);
        } else if (kind == TileKind.gate && !gateOpen) {
          // Floor under closed door so gates don't read as random wall art.
          _drawImage(canvas, floorVariants.first, dst);
          _drawImage(canvas, doorClosed, dst);
        } else if (kind == TileKind.gate && gateOpen) {
          _drawImage(canvas, floorVariants.first, dst);
          _drawImage(canvas, doorOpen, dst);
        } else if (kind == TileKind.exit) {
          _drawImage(canvas, floorVariants.first, dst);
          final exitImg = roomType == RoomType.boss ? stairsBoss : stairs;
          _drawImage(canvas, exitImg, dst);
        } else {
          final img = floorVariants[
              _hashPick(x, y, layoutSeed, floorVariants.length)];
          _drawImage(canvas, img, dst);
          // Soft checker tint â€” variation without wrong sprites.
          if (((x + y) & 1) == 1) {
            canvas.drawRect(dst, Paint()..color = const Color(0x14000000));
          }
          if (kind == TileKind.spawn) {
            canvas.drawRect(dst, Paint()..color = const Color(0x224080FF));
          }
        }
      }
    }

    for (final chamber in world.map.chambers) {
      if (!clearedChambers.contains(chamber.index)) continue;
      // Soft clear wash only â€” no giant stamp clutter.
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
      final bob = math.sin(loot.age * 9) * 0.12;
      final img = switch (loot.kind) {
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
      };
      final pulse = 0.85 + 0.15 * math.sin(loot.age * 6);
      canvas.drawCircle(
        c,
        tile * (0.32 + loot.drop.rarity.index * 0.04) * pulse,
        Paint()..color = glow,
      );
      if (loot.drop.rarity.index >= LootRarity.rare.index) {
        canvas.drawCircle(
          c,
          tile * 0.42 * pulse,
          Paint()
            ..color = glow.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
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
      final c = center(p.x, p.y);
      final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      final angle = speed > 0.01 ? math.atan2(p.vy, p.vx) : 0.0;
      final color = p.team == SpatialTeam.hero
          ? (p.isCrit ? const Color(0xFFFFF0C0) : const Color(0xFFFFE08A))
          : const Color(0xFFFF6A4A);
      final len = tile * (p.pierce ? 0.55 : 0.42);
      final thick = math.max(2.0, tile * (p.pierce ? 0.14 : 0.1));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      // Soft trail
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-len * 0.85, -thick * 0.9, len * 1.1, thick * 1.8),
          Radius.circular(thick),
        ),
        Paint()..color = color.withValues(alpha: 0.28),
      );
      // Core bolt
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-len * 0.55, -thick * 0.45, len, thick * 0.9),
          Radius.circular(thick * 0.5),
        ),
        Paint()..color = color,
      );
      // Tip spark
      canvas.drawCircle(
        Offset(len * 0.45, 0),
        thick * 0.7,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.restore();
    }

    if (world.isTreasure) {
      final ex = world.map.exitPoint;
      drawSprite(chest, center(ex.$1 + 0.5, ex.$2 + 0.5), 1.1);
    }

    for (final enemy in world.enemies) {
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
        drawBar(c, enemy.hp, enemy.maxHp, tile * 0.85);
      }
    }

    for (final hero in world.heroes) {
      final idx = hero.assetIndex
          .clamp(0, math.max(0, party.length - 1))
          .toInt();
      final partyHero = party.isEmpty ? null : party[idx];
      final flash = hero.attackFlash;
      final c = center(hero.x, hero.y);
      final scale = 0.95 * (1 + flash * 0.2);
      final alpha = hero.isAlive ? 1.0 : 0.25;
      if (partyHero != null) {
        final walk = ((hero.x + hero.y) * 3).floor().abs() % 2;
        HeroPaperDoll.paint(
          canvas,
          charAtlas,
          c,
          tile * scale,
          hero: partyHero,
          partyIndex: idx,
          walkFrame: walk,
          alpha: alpha,
        );
      } else {
        final img = heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
        if (img != null) {
          drawSprite(img, c, scale, alpha: alpha);
        }
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
          tile * 0.38 * flash,
          Paint()..color = const Color(0x77FFF0C0),
        );
      }
      if (hero.isAlive) {
        drawBar(c, hero.hp, hero.effectiveMaxHp, tile * 0.8);
      }
    }

    for (final pet in world.pets) {
      final flash = pet.attackFlash;
      final c = center(pet.x, pet.y);
      drawSprite(
        heroes.length > 3 && heroes[3] != null ? heroes[3]! : coin,
        c,
        0.48 * (1 + flash * 0.22),
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
        final maxLife = burst.slash ? 0.28 : 0.35;
        final alpha = (burst.life / maxLife).clamp(0.0, 1.0);
        final c = center(burst.x, burst.y);
        if (burst.slash && burst.angle != null) {
          final sweep = 1.15;
          final start = burst.angle! - sweep * 0.5;
          final r = tile * burst.radius * (0.75 + (1 - alpha) * 0.35);
          final paint = Paint()
            ..color = Color(burst.argb).withValues(alpha: alpha * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.5, tile * 0.16)
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            start,
            sweep * alpha.clamp(0.35, 1.0),
            false,
            paint,
          );
          // Soft inner glow
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.72),
            start,
            sweep * alpha.clamp(0.35, 1.0),
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.08)
              ..strokeCap = StrokeCap.round,
          );
        } else {
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

    for (final floater in world.floaters) {
      final alpha = (floater.life / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: floater.text,
          style: TextStyle(
            color: Color(floater.argb).withValues(alpha: alpha),
            fontSize: math.max(11, tile * 0.42),
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(
                color: Color(0xCC000000),
                blurRadius: 2,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final c = center(floater.x, floater.y);
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect dst, {
    double alpha = 1,
  }) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _TileRoomPainter oldDelegate) => true;
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
    final visibleCols = math.min(14.0, world.cols.toDouble());
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

class _PartyAbilityHud extends StatefulWidget {
  const _PartyAbilityHud({
    required this.state,
    required this.world,
    this.selectedHeroIndex,
    this.onSelectHero,
  });

  final GameState state;
  final SpatialWorld world;
  final int? selectedHeroIndex;
  final ValueChanged<int>? onSelectHero;

  @override
  State<_PartyAbilityHud> createState() => _PartyAbilityHudState();
}

class _PartyAbilityHudState extends State<_PartyAbilityHud> {
  int? _localHero;
  bool _showAll = false;

  int _defaultHeroIndex() {
    for (var i = 0; i < widget.state.heroes.length; i++) {
      if (widget.state.heroes[i].isAlive) return i;
    }
    return 0;
  }

  int get _selected =>
      widget.selectedHeroIndex ?? _localHero ?? _defaultHeroIndex();

  void _selectHero(int i) {
    widget.onSelectHero?.call(i);
    setState(() {
      _localHero = i;
      _showAll = false;
    });
  }

  Widget? _heroRow(int i) {
    final partyHero = widget.state.heroes[i];
    if (!partyHero.isAlive) return null;
    SpatialActor? spatial;
    for (final a in widget.world.heroes) {
      if (!a.isPet && a.assetIndex == i && a.isAlive) {
        spatial = a;
        break;
      }
    }
    if (spatial == null) return null;
    final abilities =
        ClassKits.hudAbilitiesAt(partyHero.role, partyHero.level);
    if (abilities.isEmpty) return null;
    final resource = spatial.rage.clamp(0.0, 100.0).toDouble();
    final off = partyHero.itemIn(EquipmentSlot.offHand);
    final hasShield = off?.offHandKind == OffHandKind.shield;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              partyHero.roleLabel.substring(0, 3),
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.parchmentDim,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              ClassKits.resourceLabel(partyHero.role),
              style: GameTheme.body(
                size: 13,
                color: GameTheme.parchmentDim,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: resource / 100,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF2A1810),
                  color: Color(ClassKits.resourceColor(partyHero.role)),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${resource.round()}',
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.parchment,
              ),
            ),
            if (partyHero.role == HeroRole.warrior && !hasShield) ...[
              const SizedBox(width: 6),
              Text(
                'NO SHIELD',
                style: GameTheme.pixel(
                  size: 6,
                  color: GameTheme.bloodLit,
                ),
              ),
            ],
            if (partyHero.role == HeroRole.rogue &&
                spatial.comboPoints > 0) ...[
              const SizedBox(width: 6),
              Text(
                'CP${spatial.comboPoints}',
                style: GameTheme.pixel(
                  size: 6,
                  color: GameTheme.torchHot,
                ),
              ),
            ],
            if (spatial.absorbShield > 0) ...[
              const SizedBox(width: 6),
              Text(
                'ABS${spatial.absorbShield}',
                style: GameTheme.pixel(
                  size: 6,
                  color: const Color(0xFF80C0FF),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final ability in abilities)
              _AbilityCdChip(
                ability: ability,
                cdLeft: spatial.abilityCd[ability.id.name] ?? 0,
                rage: resource,
                hasShield: hasShield,
                activeBuff: switch (ability.id) {
                  AbilityId.shieldBlock => spatial.shieldBlockTimer > 0,
                  AbilityId.shieldWall => spatial.shieldWallTimer > 0,
                  AbilityId.lastStand => spatial.lastStandTimer > 0,
                  AbilityId.shieldSlam => spatial.queuedShieldSlam,
                  AbilityId.powerWordShield => spatial.absorbShield > 0,
                  AbilityId.painSuppression =>
                    spatial.painSuppressionTimer > 0,
                  AbilityId.combustion => spatial.combustionTimer > 0,
                  AbilityId.iceBlock => spatial.iceBlockTimer > 0,
                  AbilityId.fireball => spatial.queuedFireball,
                  AbilityId.pyroblast => spatial.queuedPyroblast,
                  AbilityId.sliceAndDice => spatial.sliceAndDiceTimer > 0,
                  AbilityId.bladeFlurry => spatial.bladeFlurryTimer > 0,
                  AbilityId.sprint => spatial.sprintTimer > 0,
                  AbilityId.vanish => spatial.vanishTimer > 0,
                  AbilityId.adrenalineRush => spatial.adrenalineTimer > 0,
                  _ => false,
                },
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final rows = <Widget>[];
    if (_showAll) {
      for (var i = 0; i < widget.state.heroes.length; i++) {
        final row = _heroRow(i);
        if (row == null) continue;
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 4),
            child: row,
          ),
        );
      }
    } else {
      final row = _heroRow(selected);
      if (row != null) rows.add(row);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: const Color(0xDD14110C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x665A5040)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.state.heroes.length; i++)
                  if (widget.state.heroes[i].isAlive)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () => _selectHero(i),
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 32,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !_showAll && selected == i
                                ? const Color(0xFF5A3828)
                                : const Color(0xFF2A2418),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: !_showAll && selected == i
                                  ? GameTheme.torch
                                  : const Color(0xFF7A6840),
                            ),
                          ),
                          child: Text(
                            widget.state.heroes[i].roleLabel.substring(0, 3),
                            style: GameTheme.pixel(
                              size: 7,
                              color: GameTheme.parchment,
                            ),
                          ),
                        ),
                      ),
                    ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _showAll = !_showAll),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _showAll
                          ? const Color(0xFF5A3828)
                          : const Color(0xFF2A2418),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: _showAll
                            ? GameTheme.torch
                            : const Color(0xFF7A6840),
                      ),
                    ),
                    child: Text(
                      _showAll ? 'ONE' : 'ALL',
                      style: GameTheme.pixel(
                        size: 7,
                        color: GameTheme.parchment,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _AbilityCdChip extends StatelessWidget {
  const _AbilityCdChip({
    required this.ability,
    required this.cdLeft,
    required this.rage,
    required this.hasShield,
    required this.activeBuff,
  });

  final ClassAbilityDef ability;
  final double cdLeft;
  final double rage;
  final bool hasShield;
  final bool activeBuff;

  @override
  Widget build(BuildContext context) {
    final gated = ability.requiresShield && !hasShield;
    final onCd = cdLeft > 0.05;
    final noRage = rage + 0.001 < ability.resourceCost;
    final ready = !gated && !onCd && !noRage;
    final border = activeBuff
        ? GameTheme.torchHot
        : ready
            ? GameTheme.clear
            : gated
                ? GameTheme.blood
                : GameTheme.border;
    final label = onCd
        ? cdLeft < 10
            ? cdLeft.toStringAsFixed(1)
            : cdLeft.round().toString()
        : ability.shortLabel;
    return Opacity(
      opacity: gated ? 0.4 : (ready || activeBuff ? 1 : 0.7),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 36,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activeBuff
              ? const Color(0xFF3A2A14)
              : const Color(0xFF221810),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: border, width: activeBuff || ready ? 1.5 : 1),
        ),
        child: Text(
          gated ? '${ability.shortLabel}!' : label,
          textAlign: TextAlign.center,
          style: GameTheme.pixel(
            size: 7,
            color: gated
                ? GameTheme.bloodLit
                : onCd
                    ? GameTheme.parchmentDim
                    : GameTheme.parchment,
          ),
        ),
      ),
    );
  }
}



