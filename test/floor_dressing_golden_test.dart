import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/floor_theme.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/ui/spatial_dungeon_view.dart';

import 'shell_golden_harness.dart';

int _within12(int a, int b) => (a - b).abs();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('custom zone floor_a and floor_b are never byte-identical', () {
    for (final zone in CustomAssets.customDungeonZones) {
      final a = File(CustomAssets.dungeonTile(zone, 'floor_a'));
      final b = File(CustomAssets.dungeonTile(zone, 'floor_b'));
      expect(a.readAsBytesSync(), isNot(equals(b.readAsBytesSync())), reason: zone);
    }
  });

  test('sandy loading colour tracks floor_a median', () {
    final style = ZoneFloorStyle.byId('sandy');
    final loading = style.loadingArgb & 0x00FFFFFF;
    const median = 0x00D6B070;
    expect(_within12((loading >> 16) & 0xFF, (median >> 16) & 0xFF), lessThanOrEqualTo(12));
    expect(_within12((loading >> 8) & 0xFF, (median >> 8) & 0xFF), lessThanOrEqualTo(12));
    expect(_within12(loading & 0xFF, median & 0xFF), lessThanOrEqualTo(12));
  });

  test('floor decals are single-cell clumps', () {
    final map = RoomLayouts.forFloor(
      floorNumber: 5,
      room: const DungeonRoom(
        floorNumber: 5,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 9,
        enemyCount: 8,
      ),
      dungeonId: 'sandy',
      layoutSeed: 4,
    );
    final cells = map.decals.where((d) => d.w == 1 && d.h == 1).toList();
    expect(cells.length, greaterThan(8));
    var clusters = 0;
    final seen = <String>{};
    for (final c in cells) {
      final k = '${c.x},${c.y}';
      if (seen.contains(k)) continue;
      var size = 0;
      final stack = <(int, int)>[(c.x, c.y)];
      while (stack.isNotEmpty) {
        final (x, y) = stack.removeLast();
        final key = '$x,$y';
        if (seen.contains(key)) continue;
        if (!cells.any((d) => d.x == x && d.y == y)) continue;
        seen.add(key);
        size++;
        for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
          stack.add((nx, ny));
        }
      }
      if (size >= 2) clusters++;
      expect(size, lessThanOrEqualTo(4));
    }
    expect(clusters, greaterThan(2));
  });

  test('floor painters use nearest-neighbor sampling', () {
    final tile = File('lib/ui/dungeon_tile_painter.dart').readAsStringSync();
    final layer = File('lib/ui/dungeon_floor_layer.dart').readAsStringSync();
    expect(tile, contains('FilterQuality.none'));
    expect(layer, contains('FilterQuality.none'));
  });

  testWidgets('minimal VFX leaves dungeon ambient widget still', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DungeonAmbientParticles(
          quality: VfxQuality.minimal,
          child: SizedBox(width: 10, height: 10),
        ),
      ),
    );
    final state = tester.state<DungeonAmbientParticlesState>(
      find.byType(DungeonAmbientParticles),
    );
    expect(state.hasActiveController, isFalse);
  });

  testWidgets('sandy floor crop golden 360x200', (tester) async {
    bindA56View(tester);
    await ensureShellGoldenFonts();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const SizedBox(
            width: 360,
            height: 200,
            child: DungeonFloorLayer(dungeonId: 'sandy', layoutSeed: 4),
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(CustomPaint), findsWidgets);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/floors/sandy_floor_crop_a56.png'),
    );
  });
}
