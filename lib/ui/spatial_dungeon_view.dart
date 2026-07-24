import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/dungeon_generator.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../spatial/spatial_combat.dart';
import 'kenney_assets.dart';

/// Top-down corridor dungeon — painted, not 100+ Image widgets.
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
  ui.Image? _floor;
  ui.Image? _wall;
  ui.Image? _hero0;
  ui.Image? _hero1;
  ui.Image? _hero2;
  ui.Image? _slime;
  ui.Image? _golem;
  ui.Image? _boss;
  ui.Image? _chest;
  ui.Image? _coin;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    Future<ui.Image> load(String asset) async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }

    final images = await Future.wait([
      load(KenneyAssets.floorStone),
      load(KenneyAssets.wallStone),
      load(KenneyAssets.heroKnight),
      load(KenneyAssets.heroHealer),
      load(KenneyAssets.heroWizard),
      load(KenneyAssets.enemySlime),
      load(KenneyAssets.enemyGolem),
      load(KenneyAssets.enemyBoss),
      load(KenneyAssets.chestClosed),
      load(KenneyAssets.coinGold),
    ]);
    if (!mounted) return;
    setState(() {
      _floor = images[0];
      _wall = images[1];
      _hero0 = images[2];
      _hero1 = images[3];
      _hero2 = images[4];
      _slime = images[5];
      _golem = images[6];
      _boss = images[7];
      _chest = images[8];
      _coin = images[9];
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final room = state.currentRoom;
    final zone = DungeonGenerator.zoneNameForFloor(room.floorNumber);
    final farm = state.dungeonMode == DungeonMode.farm;

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: room.type == RoomType.boss
              ? const Color(0xFFC9A24A)
              : const Color(0xFF5A6A40),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xCC14120C),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$zone  F${room.floorNumber}  '
                    '${room.type == RoomType.boss ? 'BOSS' : 'R${room.roomIndex + 1}/10'}',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 8,
                      color: const Color(0xFFFFE8AA),
                    ),
                  ),
                ),
                _Pill(
                  label: 'FARM',
                  active: farm,
                  onTap: () =>
                      widget.director.setDungeonMode(DungeonMode.farm),
                ),
                const SizedBox(width: 4),
                _Pill(
                  label: 'PUSH',
                  active: !farm,
                  onTap: () =>
                      widget.director.setDungeonMode(DungeonMode.push),
                ),
                const SizedBox(width: 4),
                _Pill(
                  label: '◀',
                  active: false,
                  onTap: GameLogic.canTravelToFloor(state, room.floorNumber - 1)
                      ? () =>
                          widget.director.travelToFloor(room.floorNumber - 1)
                      : null,
                ),
                const SizedBox(width: 2),
                _Pill(
                  label: '▶',
                  active: false,
                  onTap: GameLogic.canTravelToFloor(state, room.floorNumber + 1)
                      ? () =>
                          widget.director.travelToFloor(room.floorNumber + 1)
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (state.isPartyDefeated) {
                      widget.director.reviveParty();
                      return;
                    }
                    final nx =
                        details.localPosition.dx / constraints.maxWidth;
                    final ny =
                        details.localPosition.dy / constraints.maxHeight;
                    widget.director.godHandAt(nx, ny);
                  },
                  child: world == null || _floor == null
                      ? const ColoredBox(color: Color(0xFF1A1814))
                      : CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _CorridorPainter(
                            world: world,
                            floor: _floor!,
                            wall: _wall!,
                            heroes: <ui.Image?>[_hero0, _hero1, _hero2],
                            slime: _slime!,
                            golem: _golem!,
                            boss: _boss!,
                            chest: _chest!,
                            coin: _coin!,
                          ),
                        ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xCC14120C),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              state.isPartyDefeated
                  ? 'WIPED — tap to restart'
                  : 'Tap = God Hand  ·  Corridor crawl  ·  '
                      '${farm ? 'FARMING' : 'PUSHING'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFD9CBB0)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorridorPainter extends CustomPainter {
  _CorridorPainter({
    required this.world,
    required this.floor,
    required this.wall,
    required this.heroes,
    required this.slime,
    required this.golem,
    required this.boss,
    required this.chest,
    required this.coin,
  });

  final SpatialWorld world;
  final ui.Image floor;
  final ui.Image wall;
  final List<ui.Image?> heroes;
  final ui.Image slime;
  final ui.Image golem;
  final ui.Image boss;
  final ui.Image chest;
  final ui.Image coin;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill width with square-ish tiles; center the corridor vertically.
    final tile = size.width / world.cols;
    final fieldH = tile * world.rows;
    final originY = (size.height - fieldH) / 2;
    const originX = 0.0;

    final srcFloor = Rect.fromLTWH(
      0,
      0,
      floor.width.toDouble(),
      floor.height.toDouble(),
    );
    final srcWall = Rect.fromLTWH(
      0,
      0,
      wall.width.toDouble(),
      wall.height.toDouble(),
    );

    // Dark backdrop outside corridor
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0C0B09),
    );

    for (var y = 0; y < world.rows; y++) {
      final isWall = y < 2 || y > 4;
      for (var x = 0; x < world.cols; x++) {
        final dst = Rect.fromLTWH(
          originX + x * tile,
          originY + y * tile,
          tile + 0.5,
          tile + 0.5,
        );
        canvas.drawImageRect(
          isWall ? wall : floor,
          isWall ? srcWall : srcFloor,
          dst,
          Paint()..filterQuality = FilterQuality.none,
        );
        if (isWall) {
          canvas.drawRect(
            dst,
            Paint()..color = const Color(0x66000000),
          );
        }
      }
    }

    // Lane highlight
    final laneTop = originY + SpatialCombat.laneMinY * tile - tile * 0.5;
    final laneBot = originY + SpatialCombat.laneMaxY * tile + tile * 0.5;
    canvas.drawRect(
      Rect.fromLTRB(0, laneTop, size.width, laneBot),
      Paint()..color = const Color(0x14FFE08A),
    );

    Offset center(double tx, double ty) => Offset(
          originX + tx * tile,
          originY + ty * tile,
        );

    void drawSprite(ui.Image image, Offset c, double scale, {double alpha = 1}) {
      final s = tile * scale;
      final dst = Rect.fromCenter(center: c, width: s, height: s);
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 255, 255, alpha);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        paint,
      );
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
      drawSprite(coin, center(loot.x, loot.y), 0.45);
    }

    for (final p in world.projectiles) {
      final c = center(p.x, p.y);
      canvas.drawCircle(
        c,
        3.5,
        Paint()
          ..color = p.team == SpatialTeam.hero
              ? const Color(0xFFFFE08A)
              : const Color(0xFFFF6A4A),
      );
    }

    if (world.isTreasure) {
      drawSprite(chest, center(world.cols / 2, SpatialCombat.laneCenterY), 1.1);
    }

    for (final enemy in world.enemies) {
      final img = switch (enemy.role) {
        EnemyRole.boss => boss,
        EnemyRole.elite => golem,
        EnemyRole.normal => slime,
      };
      final c = center(enemy.x, enemy.y);
      drawSprite(
        img,
        c,
        enemy.role == EnemyRole.boss ? 1.05 : 0.9,
        alpha: enemy.isAlive ? 1 : 0.2,
      );
      if (enemy.isAlive) {
        drawBar(c, enemy.hp, enemy.maxHp, tile * 0.85);
      }
    }

    for (final hero in world.heroes) {
      final img = heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
      if (img == null) continue;
      final c = center(hero.x, hero.y);
      drawSprite(img, c, 0.9, alpha: hero.isAlive ? 1 : 0.25);
      if (hero.isAlive) {
        drawBar(c, hero.hp, hero.maxHp, tile * 0.8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CorridorPainter oldDelegate) => true;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, this.onTap});
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6A3A28) : const Color(0xAA1A1814),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: active ? const Color(0xFFE09060) : const Color(0xFF5A5040),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.pressStart2p(
            fontSize: 7,
            color: onTap == null
                ? const Color(0xFF666055)
                : const Color(0xFFFFE8AA),
          ),
        ),
      ),
    );
  }
}
