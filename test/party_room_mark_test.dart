import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/party_room_mark.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  final starter = [
    HeroSpecs.def(HeroSpecId.protection),
    HeroSpecs.def(HeroSpecId.discipline),
    HeroSpecs.def(HeroSpecId.fire),
  ];
  const names = ['Aegis', 'Grace', 'Ember'];

  test('each floor shows the next party member', () {
    expect(
      PartyFloorMark.pick(specs: starter, names: names, floorNumber: 1)?.line,
      'Aegis smashed a way through.',
    );
    expect(
      PartyFloorMark.pick(specs: starter, names: names, floorNumber: 2)?.line,
      'Grace lit a shrine.',
    );
    expect(
      PartyFloorMark.pick(specs: starter, names: names, floorNumber: 3)?.line,
      'Ember set a crystal.',
    );
    expect(
      PartyFloorMark.pick(specs: starter, names: names, floorNumber: 4)?.line,
      'Aegis smashed a way through.',
    );
    expect(
      PartyFloorMark.pick(specs: const [], names: const [], floorNumber: 1),
      isNull,
    );
  });

  test('a rogue leaves a stash, not a loot chest', () {
    final mark = PartyFloorMark.pick(
      specs: [HeroSpecs.def(HeroSpecId.combat)],
      names: const ['Shade'],
      floorNumber: 1,
    );
    expect(mark?.kind, PartyRoomMark.stash);
    expect(mark?.line, 'Shade tucked a stash.');

    final map = RoomLayouts.forFloor(
      floorNumber: 1,
      room: DungeonRoom(
        floorNumber: 1,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 1,
        enemyCount: 4,
      ),
      dungeonId: 'sandy',
      layoutSeed: 7,
      partyMark: mark,
    );
    final marked = map.props.where((p) => p.partyMark).toList();
    expect(marked, isNotEmpty);
    expect(marked.any((p) => p.kind == MapPropKind.sacks), isTrue);
    expect(
      map.lootChestPoints.any(
        (c) => marked.any((p) => p.x == c.$1 && p.y == c.$2),
      ),
      isFalse,
    );
    expect(map.partyMarkLine, 'Shade tucked a stash.');
  });

  test('no party leaves the floor unmarked', () {
    final map = RoomLayouts.forFloor(
      floorNumber: 1,
      room: DungeonRoom(
        floorNumber: 1,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 1,
        enemyCount: 4,
      ),
      dungeonId: 'sandy',
      layoutSeed: 7,
    );
    expect(map.props.where((p) => p.partyMark), isEmpty);
    expect(map.partyMarkLine, isNull);
  });
}
