import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/ui/floater_label_cache.dart';
import 'package:idle_party/ui/floater_paint.dart';

/// Payoff gold / gear, matching SpatialCombat's private _floaterGold/_floaterGear.
const _gold = 0xFFFFE08A;
const _gear = 0xFFB8E986;

void main() {
  setUp(debugResetFloaterCaches);
  tearDown(debugResetFloaterCaches);

  testWidgets('paint with >24 unique labels does not throw', (tester) async {
    final world = _world(
      List<SpatialFloater>.generate(30, (i) {
        return SpatialFloater(
          x: 6 + (i % 5) * 0.15,
          y: 8,
          text: 'U$i',
          argb: _gold,
          life: 0.55,
          priority: 1,
        );
      }),
    );
    await _pumpFrames(tester, world, frames: const [0, 1, 2], tile: 32);
    expect(tester.takeException(), isNull);
    FloaterLabelCache.beginFrame();
    expect(FloaterLabelCache.length, lessThanOrEqualTo(FloaterLabelCache.cap));
  });

  testWidgets(
    'paint with mixed colors for identical text (payoff gold vs gear) does not throw',
    (tester) async {
      // 11 unique pairs + 1 same-text color flip + 1 more pair, then fill
      // to 30. That order puts an outline miss at cap 24 on the old cache.
      const payoff = '+12g · +8 XP';
      final floaters = <SpatialFloater>[];
      for (var i = 0; i < 11; i++) {
        floaters.add(
          SpatialFloater(
            x: 6 + i * 0.04,
            y: 8,
            text: i == 10 ? payoff : 'U$i',
            argb: _gold,
            life: 1.15,
            priority: 1,
          ),
        );
      }
      floaters.add(
        SpatialFloater(
          x: 6.5,
          y: 8,
          text: payoff,
          argb: _gear,
          life: 1.15,
          priority: 1,
        ),
      );
      floaters.add(
        SpatialFloater(
          x: 6.6,
          y: 8,
          text: 'Z',
          argb: _gold,
          life: 1.15,
          priority: 1,
        ),
      );
      for (var i = 0; i < 17; i++) {
        floaters.add(
          SpatialFloater(
            x: 7 + (i % 4) * 0.05,
            y: 8,
            text: 'E$i',
            argb: i.isEven ? _gold : _gear,
            life: 1.15,
            priority: 1,
          ),
        );
      }
      expect(floaters.length, 30);
      final world = _world(floaters);

      // visualFrame 0, 1, 2 plus later fade steps that snap alpha (and keys).
      await _pumpFrames(
        tester,
        world,
        frames: const [0, 1, 2, 8, 16],
        tile: 32,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tile size change mid-session does not throw', (tester) async {
    const payoff = '+12g · +8 XP';
    final floaters = <SpatialFloater>[
      for (var i = 0; i < 11; i++)
        SpatialFloater(
          x: 6 + i * 0.04,
          y: 8,
          text: i == 10 ? payoff : 'U$i',
          argb: _gold,
          life: 1.15,
          priority: 1,
        ),
      SpatialFloater(
        x: 6.5,
        y: 8,
        text: payoff,
        argb: _gear,
        life: 1.15,
        priority: 1,
      ),
      SpatialFloater(
        x: 6.6,
        y: 8,
        text: 'Z',
        argb: _gold,
        life: 1.15,
        priority: 1,
      ),
      for (var i = 0; i < 17; i++)
        SpatialFloater(
          x: 7,
          y: 8,
          text: 'E$i',
          argb: i.isEven ? _gold : _gear,
          life: 1.15,
          priority: 1,
        ),
    ];
    final world = _world(floaters);
    await _pumpFrames(tester, world, frames: const [0, 1], tile: 32);
    expect(tester.takeException(), isNull);
    // Camera cols change: every size/maxWidth key is new.
    await _pumpFrames(tester, world, frames: const [2], tile: 27.5);
    expect(tester.takeException(), isNull);
    FloaterLabelCache.beginFrame();
    expect(FloaterLabelCache.length, lessThanOrEqualTo(FloaterLabelCache.cap));
  });
}

SpatialWorld _world(List<SpatialFloater> floaters) {
  const cols = 16;
  const rows = 16;
  final tiles = List<TileKind>.filled(cols * rows, TileKind.floor);
  return SpatialWorld(
    map: TileMap(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: const [(2, 2)],
      exitPoint: (cols - 3, rows - 3),
      enemySpawns: const [(8, 8)],
    ),
    heroes: const <SpatialActor>[],
    enemies: const <SpatialActor>[],
    projectiles: <SpatialProjectile>[],
    groundLoot: const [],
    isTreasure: false,
    floaters: floaters,
  );
}

Future<void> _pumpFrames(
  WidgetTester tester,
  SpatialWorld world, {
  required List<int> frames,
  required double tile,
}) async {
  for (final frame in frames) {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 512,
          height: 768,
          child: CustomPaint(
            size: const Size(512, 768),
            painter: _FloaterCanvasPainter(
              floaters: world.floaters,
              visualFrame: frame,
              tile: tile,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull, reason: 'frame $frame tile $tile');
  }
}

class _FloaterCanvasPainter extends CustomPainter {
  _FloaterCanvasPainter({
    required this.floaters,
    required this.visualFrame,
    required this.tile,
  });

  final List<SpatialFloater> floaters;
  final int visualFrame;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    paintFloaterLabels(
      canvas: canvas,
      tile: tile,
      originX: 0,
      originY: 0,
      floaters: floaters,
      visualFrame: visualFrame,
      showBursts: true,
      showPriorityFloaters: true,
      inView: (x, y, {double pad = 1.25}) => true,
    );
  }

  @override
  bool shouldRepaint(covariant _FloaterCanvasPainter oldDelegate) => true;
}
