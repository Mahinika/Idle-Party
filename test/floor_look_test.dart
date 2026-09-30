import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/spatial/floor_blueprint.dart';
import 'package:idle_party/spatial/floor_theme.dart';
import 'package:idle_party/spatial/tile_map.dart';

DungeonRoom _normal(int floor, {int enemies = 8}) => DungeonRoom(
  floorNumber: floor,
  roomIndex: 0,
  type: RoomType.normal,
  enemyLevel: floor + 4,
  enemyCount: enemies,
);

TileMap _map(String zone, int seed, {RoomType type = RoomType.normal}) {
  final room = DungeonRoom(
    floorNumber: 5,
    roomIndex: 0,
    type: type,
    enemyLevel: 9,
    enemyCount: type == RoomType.treasure ? 0 : 8,
  );
  return RoomLayouts.forFloor(
    floorNumber: 5,
    room: room,
    dungeonId: zone,
    layoutSeed: seed,
  );
}

/// Every walkable cell reachable from the party spawn with gates open.
Set<(int, int)> _reach(TileMap map) {
  final start = map.spawnPoints.first;
  final seen = <(int, int)>{start};
  final queue = [start];
  final open = {for (final g in map.gates) g.id};
  for (var i = 0; i < queue.length; i++) {
    final (x, y) = queue[i];
    for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final n = (x + d.$1, y + d.$2);
      if (seen.contains(n)) continue;
      if (!map.isWalkable(n.$1, n.$2, openGateIds: open)) continue;
      seen.add(n);
      queue.add(n);
    }
  }
  return seen;
}

void main() {
  final zones = [for (final d in DungeonCatalog.all) d.id];

  test('decoy rooms are gone; shrine / wonder / setpiece exist', () {
    final names = FloorBeatKind.values.map((k) => k.name).toSet();
    expect(names, isNot(contains('decoy')));
    expect(names, containsAll(['shrine', 'wonder', 'setpiece']));
  });

  test('theme, decals and props are deterministic for a fixed seed', () {
    for (final zone in ['rime', 'king', 'fen']) {
      final a = _map(zone, 41);
      final b = _map(zone, 41);
      expect(a.floorTheme, b.floorTheme, reason: zone);
      expect(
        a.decals.map((d) => '${d.kind}@${d.x},${d.y}').toList(),
        b.decals.map((d) => '${d.kind}@${d.x},${d.y}').toList(),
        reason: zone,
      );
      expect(
        a.props.map((p) => '${p.kind}@${p.x},${p.y}${p.hero}').toList(),
        b.props.map((p) => '${p.kind}@${p.x},${p.y}${p.hero}').toList(),
        reason: zone,
      );
    }
  });

  test('every zone rolls its signature setpiece room', () {
    for (final zone in zones) {
      var hits = 0;
      for (var seed = 0; seed < 30; seed++) {
        final bp = FloorBlueprint.forRoom(
          _normal(6),
          dungeonId: zone,
          layoutSeed: seed,
        );
        if (bp.beats.any((b) => b.kind == FloorBeatKind.setpiece)) hits++;
      }
      expect(hits, greaterThan(10), reason: zone);
    }
  });

  test('setpiece sits in the last third of the main path (peak-end)', () {
    for (final zone in zones) {
      for (var seed = 0; seed < 20; seed++) {
        final bp = FloorBlueprint.forRoom(
          _normal(8),
          dungeonId: zone,
          layoutSeed: seed,
        );
        final main = [
          for (final b in bp.storyChambers)
            if (!b.isSide) b,
        ];
        final i = main.indexWhere((b) => b.kind == FloorBeatKind.setpiece);
        if (i < 0) continue;
        expect(
          i,
          greaterThanOrEqualTo(((main.length - 1) * 2 / 3).floor()),
          reason: '$zone seed $seed',
        );
      }
    }
  });

  test('enemy budget is unchanged by the new rooms', () {
    for (final zone in zones) {
      for (var seed = 0; seed < 12; seed++) {
        for (final n in [4, 8, 13]) {
          final bp = FloorBlueprint.forRoom(
            _normal(7, enemies: n),
            dungeonId: zone,
            layoutSeed: seed,
          );
          expect(bp.combatEnemyBudget, n, reason: '$zone seed $seed n $n');
          for (final b in bp.beats) {
            if (b.kind == FloorBeatKind.shrine ||
                b.kind == FloorBeatKind.wonder) {
              expect(b.enemyBudget, 0);
            }
          }
        }
      }
    }
  });

  test('wonder rooms show up on about 1 floor in 12', () {
    var wonders = 0;
    const samples = 240;
    for (var seed = 0; seed < samples; seed++) {
      final bp = FloorBlueprint.forRoom(
        _normal(3 + seed % 9),
        dungeonId: zones[seed % zones.length],
        layoutSeed: seed * 7,
      );
      if (bp.beats.any((b) => b.kind == FloorBeatKind.wonder)) wonders++;
    }
    final share = wonders / samples;
    expect(share, inInclusiveRange(0.04, 0.13), reason: '$wonders/$samples');
  });

  test('pillars and rough edges never cut off floor, gates, or stairs', () {
    for (final zone in zones) {
      for (var seed = 0; seed < 6; seed++) {
        final map = _map(zone, seed);
        final reached = _reach(map);
        expect(reached, contains(map.exitPoint), reason: '$zone seed $seed');
        for (final g in map.gates) {
          expect(reached, contains((g.x, g.y)), reason: '$zone gate $seed');
        }
        for (final e in map.enemySpawns) {
          expect(reached, contains(e), reason: '$zone enemy $seed');
        }
        for (final c in map.lootChestPoints) {
          expect(reached, contains(c), reason: '$zone chest $seed');
        }
      }
    }
  });

  test('decals never sit on a gate or the stairs', () {
    for (final zone in zones) {
      for (var seed = 0; seed < 5; seed++) {
        final map = _map(zone, seed);
        for (final d in map.decals) {
          for (var y = d.y; y < d.y + d.h; y++) {
            for (var x = d.x; x < d.x + d.w; x++) {
              expect(map.at(x, y), isNot(TileKind.gate), reason: zone);
              expect((x, y), isNot(map.exitPoint), reason: zone);
            }
          }
        }
        expect(map.decals, isNotEmpty, reason: zone);
      }
    }
  });

  test('each chamber has at most one hero prop', () {
    for (final zone in zones) {
      for (var seed = 0; seed < 5; seed++) {
        for (final type in [RoomType.normal, RoomType.elite, RoomType.boss]) {
          final map = _map(zone, seed, type: type);
          for (final c in map.chambers) {
            final heroes = map.props
                .where((p) => p.hero && c.containsTile(p.x, p.y))
                .length;
            expect(heroes, lessThanOrEqualTo(1), reason: '$zone $type $seed');
          }
          expect(map.props.where((p) => p.hero), isNotEmpty, reason: zone);
        }
      }
    }
  });

  test('floors in one zone differ in shape and mood (not oatmeal)', () {
    for (final zone in ['sandy', 'king', 'storm']) {
      final themes = <FloorTheme?>{};
      final shapes = <String>{};
      for (var seed = 0; seed < 50; seed++) {
        final map = _map(zone, seed);
        themes.add(map.floorTheme);
        var rectish = 0;
        for (final c in map.chambers) {
          var carved = 0;
          for (var y = c.y; y < c.y + c.h; y++) {
            for (var x = c.x; x < c.x + c.w; x++) {
              if (map.at(x, y) != TileKind.wall) carved++;
            }
          }
          if (carved >= c.w * c.h * 0.92) rectish++;
        }
        shapes.add('${map.chambers.length}:$rectish:${map.floorTheme}');
      }
      expect(themes.length, greaterThanOrEqualTo(2), reason: zone);
      expect(shapes.length, greaterThanOrEqualTo(8), reason: zone);
    }
  });

  test('fen floor mood is mire, not Bone Galleries', () {
    for (var seed = 0; seed < 40; seed++) {
      final theme = _map('fen', seed).floorTheme;
      expect(theme, isNotNull);
      expect(theme!.label.toLowerCase(), isNot(contains('bone')));
      expect(
        theme == FloorTheme.mire || theme == FloorTheme.flooded,
        isTrue,
        reason: 'fen seed $seed got ${theme.label}',
      );
    }
  });

  test('every zone ships a PNG for every prop kind', () {
    for (final zone in CustomAssets.customDungeonZones) {
      for (final kind in MapPropKind.values) {
        final path = CustomAssets.dungeonPropPath(zone, kind)!;
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      // Signature pieces live in the zone's own folder only.
      expect(
        CustomAssets.dungeonPropPath(zone, MapPropKind.signatureA),
        contains('/$zone/'),
      );
    }
  });
}
