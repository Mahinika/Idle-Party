import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/spatial/room_happening.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  TileMap mapFor(int floor, RoomType type) {
    return RoomLayouts.forFloor(
      floorNumber: floor,
      room: DungeonRoom(
        floorNumber: floor,
        roomIndex: 0,
        type: type,
        enemyLevel: 4,
        enemyCount: type == RoomType.boss ? 1 : 6,
      ),
      dungeonId: 'sandy',
    );
  }

  MapProp? happeningOn(TileMap map) {
    for (final p in map.props) {
      if (p.happening) return p;
    }
    return null;
  }

  test('first room has one walk-up, bosses have none', () {
    final chest = happeningOn(mapFor(1, RoomType.normal));
    expect(chest, isNotNull);
    expect(chest!.kind, MapPropKind.chest);
    final spawn = mapFor(1, RoomType.normal).spawnPoints.first;
    final placed = happeningOn(mapFor(1, RoomType.normal))!;
    expect(
      (placed.x - spawn.$1).abs() + (placed.y - spawn.$2).abs(),
      greaterThanOrEqualTo(3),
    );

    expect(happeningOn(mapFor(2, RoomType.normal))!.kind, MapPropKind.trap);
    expect(happeningOn(mapFor(3, RoomType.normal))!.kind, MapPropKind.altar);
    expect(happeningOn(mapFor(5, RoomType.boss)), isNull);

    final floor = mapFor(1, RoomType.normal);
    for (final c in floor.chambers) {
      final heroes = floor.props
          .where((p) => p.hero && c.containsTile(p.x, p.y))
          .length;
      expect(heroes, lessThanOrEqualTo(1));
    }
  });

  test('walking onto the chest pays gold once', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 10, 8));
    expect(RoomHappening.forRoom(state.currentRoom), RoomHappeningKind.chest);
    var world = SpatialCombat.build(state);
    final prop = happeningOn(world.map);
    expect(prop, isNotNull);
    for (final hero in world.heroes) {
      hero.x = prop!.x + 0.5;
      hero.y = prop.y + 0.5;
    }
    final step = SpatialCombat.step(world, state, dt: 0.05);
    expect(step.state.gold, greaterThan(state.gold));
    expect(step.state.roomHappeningClaim, RoomHappening.claimKey(step.state));
    expect(step.world.happeningSpent, isTrue);

    final again = SpatialCombat.build(step.state);
    expect(again.happeningSpent, isTrue);
    for (final hero in again.heroes) {
      hero.x = prop!.x + 0.5;
      hero.y = prop.y + 0.5;
    }
    final second = SpatialCombat.step(again, step.state, dt: 0.05);
    expect(second.state.gold, step.state.gold);
  });

  test('a trap stings and an altar mends, neither kills', () {
    GameState room(int floor) {
      final spec = DungeonRoom(
        floorNumber: floor,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 4,
        enemyCount: 4,
      );
      return GameLogic.createInitialState(
        now: DateTime(2026, 10, 8),
      ).copyWith(currentRoom: spec, dungeonFloor: [spec]);
    }

    final trapState = room(2);
    var trapWorld = SpatialCombat.build(trapState);
    final trap = happeningOn(trapWorld.map)!;
    expect(trap.kind, MapPropKind.trap);
    for (final hero in trapWorld.heroes) {
      hero.x = trap.x + 0.5;
      hero.y = trap.y + 0.5;
      hero.hp = hero.effectiveMaxHp;
    }
    final stung = SpatialCombat.step(trapWorld, trapState, dt: 0.05);
    expect(
      stung.world.heroes.every((h) => h.hp >= 1 && h.hp < h.effectiveMaxHp),
      isTrue,
    );
    final stingHp = stung.world.heroes.first.hp;
    for (final hero in stung.world.heroes) {
      hero.x = trap.x + 0.5;
      hero.y = trap.y + 0.5;
    }
    final stingAgain = SpatialCombat.step(stung.world, stung.state, dt: 0.05);
    expect(stingAgain.world.heroes.first.hp, stingHp);

    final altarState = room(3);
    var altarWorld = SpatialCombat.build(altarState);
    final altar = happeningOn(altarWorld.map)!;
    expect(altar.kind, MapPropKind.altar);
    for (final hero in altarWorld.heroes) {
      hero.x = altar.x + 0.5;
      hero.y = altar.y + 0.5;
      hero.hp = 1;
    }
    final blessed = SpatialCombat.step(altarWorld, altarState, dt: 0.05);
    expect(blessed.world.heroes.every((h) => h.hp > 1), isTrue);
    expect(blessed.world.heroes.every((h) => h.hp <= h.effectiveMaxHp), isTrue);
  });

  test('the party walks onto the chest on the way out', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 10, 8));
    var world = SpatialCombat.build(state);
    world.mendTimer = 30;
    var stepped = state;
    var fired = false;
    for (var i = 0; i < 900 && !fired; i++) {
      final step = SpatialCombat.step(world, stepped, dt: 1 / 30);
      world = step.world;
      stepped = step.state;
      fired = stepped.roomHappeningClaim.isNotEmpty;
    }
    expect(fired, isTrue);
    expect(stepped.gold, greaterThan(0));
  });

  test('old saves load with no claim', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 10, 8));
    final json = state.toJson()..remove('roomHappeningClaim');
    final loaded = GameState.fromJson(json);
    expect(loaded.roomHappeningClaim, isEmpty);
  });
}
