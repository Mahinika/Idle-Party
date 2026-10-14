import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/zone_art.dart';
import 'package:idle_party/spatial/floor_blueprint.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  test('a hall is wide and a choke is a pinch', () {
    var sawWideHall = false;
    var sawPinch = false;
    for (var seed = 0; seed < 12; seed++) {
      final map = RoomLayouts.forFloor(
        floorNumber: 4,
        room: const DungeonRoom(
          floorNumber: 4,
          roomIndex: 0,
          type: RoomType.normal,
          enemyLevel: 8,
          enemyCount: 8,
        ),
        dungeonId: 'sandy',
        layoutSeed: seed,
      );
      for (final c in map.chambers) {
        if (c.beatKind == FloorBeatKind.approach && c.w >= c.h + 2) {
          sawWideHall = true;
        }
        if (c.beatKind == FloorBeatKind.choke) {
          final short = c.w < c.h ? c.w : c.h;
          if (short <= 11) sawPinch = true;
        }
      }
    }
    expect(sawWideHall, isTrue);
    expect(sawPinch, isTrue);
  });

  test('an elite picture is not the trash picture, and neighbors do not share one', () {
    final ids = [for (final d in DungeonCatalog.all) d.id];
    for (final id in ids) {
      final art = ZoneArt.byId(id).enemies;
      expect(art.elite, isNot(art.trash), reason: id);
    }
    final overlaps = <String>[];
    for (var i = 0; i < ids.length - 1; i++) {
      final a = ZoneArt.byId(ids[i]).enemies.all;
      final b = ZoneArt.byId(ids[i + 1]).enemies.all;
      final shared = a.intersection(b);
      if (shared.isNotEmpty) {
        overlaps.add('${ids[i]} ∩ ${ids[i + 1]} = $shared');
      }
    }
    expect(overlaps, isEmpty, reason: overlaps.join('\n'));
  });
}
