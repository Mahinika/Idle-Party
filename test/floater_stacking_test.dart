import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/ui/floater_banner_stack.dart';
import 'package:idle_party/ui/floater_label_cache.dart';
import 'package:idle_party/ui/floater_paint.dart';
import 'package:idle_party/ui/game_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(debugResetFloaterCaches);
  tearDown(debugResetFloaterCaches);

  test(
    'ELITE DOWN, LEVEL UP and ABSORB spawned same step do not overlap',
    () {
      // Authored offsets from spatial_combat / combat_damage, no spawn jitter,
      // so the three banners share one anchor more tightly than in a live fight.
      const heroX = 8.0;
      const heroY = 8.0;
      const tile = 32.0;
      final banners = <SpatialFloater>[
        SpatialFloater(
          x: heroX,
          y: heroY - 0.7,
          text: 'ELITE DOWN',
          argb: 0xFFFFE08A,
          life: 1.15,
          priority: 2,
        ),
        SpatialFloater(
          x: heroX,
          y: heroY - 0.9,
          text: 'LEVEL UP!',
          argb: 0xFF9AD0FF,
          life: 1.45,
          priority: 2,
        ),
        SpatialFloater(
          x: heroX,
          y: heroY - 0.5,
          text: 'ABSORB 12',
          argb: 0xFF80C0FF,
          life: 0.4,
          priority: 0,
        ),
      ];

      final atSpawn = _layout(banners, tile: tile, born: const [0, 1, 2]);
      _expectNoPairOverlaps(atSpawn, reason: 'at spawn');
      _expectAboveHeroHead(atSpawn, heroX: heroX, heroY: heroY, tile: tile);

      final later = _layout(
        _afterDt(banners, 0.3),
        tile: tile,
        born: const [0, 1, 2],
      );
      _expectNoPairOverlaps(later, reason: 'after 0.3s');
      _expectAboveHeroHead(later, heroX: heroX, heroY: heroY, tile: tile);
    },
  );

  test('stacking order is deterministic', () {
    const tile = 32.0;
    final banners = <SpatialFloater>[
      SpatialFloater(
        x: 8,
        y: 7.3,
        text: 'ELITE DOWN',
        argb: 0xFFFFE08A,
        life: 1.15,
        priority: 2,
      ),
      SpatialFloater(
        x: 8,
        y: 7.1,
        text: 'LEVEL UP!',
        argb: 0xFF9AD0FF,
        life: 1.45,
        priority: 2,
      ),
      SpatialFloater(
        x: 8,
        y: 7.5,
        text: 'ABSORB 12',
        argb: 0xFF80C0FF,
        life: 0.4,
        priority: 0,
      ),
    ];

    final first = _layout(banners, tile: tile, born: const [0, 1, 2]);
    debugResetFloaterCaches();
    final second = _layout(banners, tile: tile, born: const [0, 1, 2]);
    expect(first.map((e) => e.displayY).toList(), second.map((e) => e.displayY).toList());
    expect(first.map((e) => e.dy).toList(), second.map((e) => e.dy).toList());

    // Reverse spawn order, born following that order. Placement is still
    // priority descending, then born ascending: prio 3 > 2 > 1 > 0 is placed
    // first and keeps authored Y; later banners lift up (smaller world Y).
    final reversed = [banners[2], banners[1], banners[0]];
    final rev = _layout(reversed, tile: tile, born: const [0, 1, 2]);
    _expectNoPairOverlaps(rev, reason: 'reversed spawn');
    final byText = {for (final e in rev) e.floater.text: e};
    expect(byText['ELITE DOWN']!.priority, 2);
    expect(byText['LEVEL UP!']!.priority, 2);
    expect(byText['ABSORB 12']!.priority, 0);
    expect(
      byText['ABSORB 12']!.displayY,
      lessThan(byText['ELITE DOWN']!.displayY),
      reason: 'ABSORB (prio 0) lifts above the prio-2 banners',
    );
    expect(
      byText['ABSORB 12']!.displayY,
      lessThan(byText['LEVEL UP!']!.displayY),
    );
  });

  test(
    'ABSORB is dropped by the routine cap of 4 (documented spawn behavior)',
    () {
      // ABSORB is spawned at priority 0 (combat_damage.dart). The routine cap
      // of 4 in spawnFloater can therefore drop it. Paint-time stacking treats
      // text starting with ABSORB as stackable but does not raise its spawn
      // priority, so visibility and caps stay unchanged.
      final world = _emptyWorld();
      for (var i = 0; i < 4; i++) {
        SpatialCombat.spawnFloater(
          world,
          x: 4,
          y: 4,
          text: '${10 + i}',
          argb: 0xFFFF6A4A,
        );
      }
      expect(world.floaters.where((f) => f.priority <= 0).length, 4);
      SpatialCombat.spawnFloater(
        world,
        x: 8,
        y: 8,
        text: 'ABSORB 12',
        argb: 0xFF80C0FF,
      );
      expect(
        world.floaters.any((f) => f.text.startsWith('ABSORB')),
        isFalse,
        reason: 'routine cap 4 drops ABSORB when four priority-0 numbers are live',
      );
    },
  );

  test(
    'ABSORB stacks with ELITE DOWN and LEVEL UP when the routine cap leaves room',
    () {
      final world = _emptyWorld();
      SpatialCombat.spawnFloater(
        world,
        x: 8,
        y: 8 - 0.7,
        text: 'ELITE DOWN',
        argb: 0xFFFFE08A,
        life: 1.15,
        priority: 2,
      );
      SpatialCombat.spawnFloater(
        world,
        x: 8,
        y: 8 - 0.9,
        text: 'LEVEL UP!',
        argb: 0xFF9AD0FF,
        life: 1.45,
        priority: 2,
      );
      SpatialCombat.spawnFloater(
        world,
        x: 8,
        y: 8 - 0.5,
        text: 'ABSORB 12',
        argb: 0xFF80C0FF,
        life: 0.4,
      );
      expect(world.floaters.any((f) => f.text.startsWith('ABSORB')), isTrue);
      // spawnFloater also dedupes identical prio>=2 text within 3.5 tiles,
      // so a second ELITE DOWN at this anchor would not appear. Caps are
      // unchanged; stacking is paint-only.
      SpatialCombat.spawnFloater(
        world,
        x: 8.2,
        y: 8 - 0.7,
        text: 'ELITE DOWN',
        argb: 0xFFFFE08A,
        life: 1.15,
        priority: 2,
      );
      expect(world.floaters.where((f) => f.text == 'ELITE DOWN').length, 1);

      final placed = _layout(world.floaters, tile: 32, born: const [0, 1, 2]);
      _expectNoPairOverlaps(placed, reason: 'spawnFloater jitter included');
      _expectAboveHeroHead(placed, heroX: 8, heroY: 8, tile: 32);
    },
  );

  test(
    'rare (prio ≥3) BOSS DOWN keeps lift 1.35 and is never pushed off-screen',
    () {
      const tile = 32.0;
      const viewTop = 0.0;
      const viewHeight = 768.0;
      final banners = <SpatialFloater>[
        SpatialFloater(
          x: 8,
          y: 4.0,
          text: 'BOSS DOWN',
          argb: 0xFFFFC14A,
          life: 1.55,
          priority: 3,
        ),
        // Place the others within the 1-tile cluster of the lifted BOSS
        // (display Y = 4.0 - 1.35 = 2.65) so a bad sort would push it up.
        SpatialFloater(
          x: 8,
          y: 2.85,
          text: 'ELITE DOWN',
          argb: 0xFFFFE08A,
          life: 1.15,
          priority: 2,
        ),
        SpatialFloater(
          x: 8,
          y: 2.70,
          text: 'LEVEL UP!',
          argb: 0xFF9AD0FF,
          life: 1.45,
          priority: 2,
        ),
        SpatialFloater(
          x: 8,
          y: 3.00,
          text: 'ABSORB 12',
          argb: 0xFF80C0FF,
          life: 0.4,
          priority: 0,
        ),
      ];
      final placed = _layout(banners, tile: tile, born: const [0, 1, 2, 3]);
      final boss = placed.firstWhere((e) => e.floater.text == 'BOSS DOWN');
      expect(boss.dy, 0.0, reason: 'highest priority keeps authored Y');
      expect(
        boss.displayY,
        closeTo(4.0 - 1.35, 1e-9),
        reason: 'rare lift 1.35 is applied and not reduced or increased',
      );
      expect(boss.rect.top, greaterThanOrEqualTo(viewTop));
      expect(boss.rect.bottom, lessThanOrEqualTo(viewTop + viewHeight));
      _expectNoPairOverlaps(placed, reason: 'BOSS cluster');
      for (final e in placed) {
        expect(
          e.rect.top,
          greaterThanOrEqualTo(viewTop),
          reason: '${e.floater.text} pushed off the top of the view',
        );
      }
    },
  );

  test('fight-hit golden floaters stay unstacked at 1.2 tiles apart', () {
    // Mirrors shell_golden_harness stageFightHitProof. Using real text height
    // so a tighter cluster radius cannot sneak in and shift those goldens.
    const tile = 32.0;
    const heroX = 8.0;
    const heroY = 8.0;
    final placed = _layout(
      [
        SpatialFloater(
          x: heroX + 1.1,
          y: heroY - 0.2,
          text: '18',
          argb: 0xFFFF6A4A,
          life: 0.45,
          priority: 1,
        ),
        SpatialFloater(
          x: heroX,
          y: heroY - 0.7,
          text: '8g',
          argb: 0xFFFFE08A,
          life: 0.55,
          priority: 2,
        ),
      ],
      tile: tile,
      born: const [1, 2],
    );
    expect(placed[0].dy, 0.0);
    expect(placed[1].dy, 0.0);
  });
}

class _PlacedBanner {
  _PlacedBanner({
    required this.floater,
    required this.rect,
    required this.displayY,
    required this.dy,
    required this.priority,
  });

  final SpatialFloater floater;
  final Rect rect;
  final double displayY;
  final double dy;
  final int priority;
}

List<_PlacedBanner> _layout(
  List<SpatialFloater> floaters, {
  required double tile,
  required List<int> born,
  double originX = 0,
  double originY = 0,
}) {
  assert(born.length == floaters.length);
  const maxWFactor = 4.4;
  final maxW = tile * maxWFactor;
  final fills = <TextPainter>[];
  final displayYs = <double>[];
  final specs = <FloaterBannerSpec>[];
  for (var i = 0; i < floaters.length; i++) {
    final floater = floaters[i];
    final speech = floater.kind == SpatialFloaterKind.speech;
    final raw =
        tile *
        (speech ? 0.28 : 0.32) *
        SpatialCombat.floaterReadScale(floater.priority);
    final size = raw < GameTheme.hudPixel ? GameTheme.hudPixel : raw;
    final pair = FloaterLabelCache.pair(
      text: floater.text,
      size: size,
      color: Color(floater.argb),
      outline: GameTheme.lootInkShadow,
      maxWidth: maxW,
    );
    fills.add(pair.fill);
    final displayY = floaterDisplayY(
      y: floater.y,
      speech: speech,
      priority: floater.priority,
    );
    displayYs.add(displayY);
    if (FloaterBannerStack.isStackable(
      speech: speech,
      priority: floater.priority,
      text: floater.text,
    )) {
      specs.add(
        FloaterBannerSpec(
          id: i,
          x: floater.x,
          y: displayY,
          priority: floater.priority,
          born: born[i],
          heightTiles: pair.fill.height / tile,
        ),
      );
    }
  }
  final stackDy = FloaterBannerStack.dyById(specs);
  final placed = <_PlacedBanner>[];
  for (var i = 0; i < floaters.length; i++) {
    final floater = floaters[i];
    final speech = floater.kind == SpatialFloaterKind.speech;
    final dy = stackDy[i] ?? 0.0;
    final displayY = displayYs[i] + dy;
    final center = Offset(originX + floater.x * tile, originY + displayY * tile);
    final rect = floaterLabelRect(
      center: center,
      speech: speech,
      tile: tile,
      width: fills[i].width,
      height: fills[i].height,
    );
    placed.add(
      _PlacedBanner(
        floater: floater,
        rect: rect,
        displayY: displayY,
        dy: dy,
        priority: floater.priority,
      ),
    );
  }
  return placed;
}

void _expectNoPairOverlaps(List<_PlacedBanner> placed, {required String reason}) {
  for (var i = 0; i < placed.length; i++) {
    for (var j = i + 1; j < placed.length; j++) {
      expect(
        placed[i].rect.overlaps(placed[j].rect),
        isFalse,
        reason:
            '$reason: ${placed[i].floater.text} vs ${placed[j].floater.text}',
      );
    }
  }
}

void _expectAboveHeroHead(
  List<_PlacedBanner> placed, {
  required double heroX,
  required double heroY,
  required double tile,
  double originX = 0,
  double originY = 0,
}) {
  // Upper half of the hero's tile — banners must not sit on the head.
  final head = Rect.fromCenter(
    center: Offset(
      originX + heroX * tile,
      originY + heroY * tile - tile * 0.2,
    ),
    width: tile * 0.7,
    height: tile * 0.55,
  );
  for (final e in placed) {
    expect(
      e.rect.overlaps(head),
      isFalse,
      reason: '${e.floater.text} overlaps the hero head',
    );
    expect(
      e.rect.bottom,
      lessThan(originY + heroY * tile),
      reason: '${e.floater.text} was pushed down onto the hero',
    );
  }
}

List<SpatialFloater> _afterDt(List<SpatialFloater> src, double dt) {
  return [
    for (final f in src)
      SpatialFloater(
        x: f.x + f.vx * dt,
        y: f.y + f.vy * dt,
        text: f.text,
        argb: f.argb,
        life: f.life - dt,
        vx: f.vx,
        vy: f.vy,
        priority: f.priority,
        kind: f.kind,
      ),
  ];
}

SpatialWorld _emptyWorld() {
  const cols = 16;
  const rows = 16;
  return SpatialWorld(
    map: TileMap(
      cols: cols,
      rows: rows,
      tiles: List<TileKind>.filled(cols * rows, TileKind.floor),
      spawnPoints: const [(2, 2)],
      exitPoint: (cols - 3, rows - 3),
      enemySpawns: const [(8, 8)],
    ),
    heroes: const <SpatialActor>[],
    enemies: const <SpatialActor>[],
    projectiles: <SpatialProjectile>[],
    groundLoot: const [],
    isTreasure: false,
  );
}
