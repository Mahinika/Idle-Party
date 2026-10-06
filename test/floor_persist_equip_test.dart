import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('syncPartyFromState keeps enemy HP and hero positions', () {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 27)),
      dungeonId: 'sandy',
    );
    var world = SpatialCombat.build(state);
    for (final h in world.heroes) {
      h.x += 2.4;
      h.y += 1.1;
      h.rage = 40;
    }
    for (final e in world.enemies) {
      e.hp = (e.hp * 0.6).round().clamp(1, e.maxHp);
      e.x += 0.8;
    }
    final heroX = world.heroes.first.x;
    final enemyHp = [for (final e in world.enemies) e.hp];
    final enemyX = world.enemies.first.x;

    // Mid-fight equip: bump warrior cloak stats via state heroes.
    final warrior = state.heroes.first;
    final cloak = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 5,
    ).copyWith(
      strengthBonus: 6,
      staminaBonus: 5,
      armorBonus: 8,
      clearAffinity: true,
    );
    final equipped = Map<EquipmentSlot, EquipmentItem>.from(warrior.equipped)
      ..[EquipmentSlot.cloak] = cloak;
    final heroes = [...state.heroes];
    heroes[0] = warrior.copyWith(
      equipped: equipped,
      currentHp: warrior.currentHp,
    );
    state = state.copyWith(heroes: heroes);

    world = SpatialCombat.syncPartyFromState(world, state);

    expect(world.heroes.first.x, closeTo(heroX, 0.001));
    expect(world.heroes.first.rage, 40);
    expect(world.enemies.first.x, closeTo(enemyX, 0.001));
    expect([for (final e in world.enemies) e.hp], enemyHp);
    expect(
      world.heroes.first.defense,
      state.effectiveHeroDefense(state.heroes.first),
    );
  });

  test('director autoEquip does not reset spatial mid-floor', () async {
    final director = GameDirector.preview();
    await director.boot();
    director.enterDungeon(dungeonId: 'sandy');
    final world = director.spatial!;
    world.heroes.first.x += 3.0;
    world.enemies.first.hp =
        (world.enemies.first.hp - 21).clamp(1, world.enemies.first.maxHp);
    final heroX = world.heroes.first.x;
    final enemyHp = world.enemies.first.hp;

    final upgrade = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 4,
    ).copyWith(
      id: 'midfight_cloak',
      strengthBonus: 5,
      staminaBonus: 4,
      armorBonus: 6,
      clearAffinity: true,
    );
    director.debugInjectStash([upgrade]);
    director.autoEquipBetterGear();

    expect(director.spatial!.heroes.first.x, closeTo(heroX, 0.001));
    expect(director.spatial!.enemies.first.hp, enemyHp);
  });

  test('first wipe wears the bag upgrade and fights the same floor', () async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        highestFloorCleared: 1,
      ),
    );
    await director.boot();
    director.enterDungeon(dungeonId: 'sandy');
    final floor = director.state.currentRoom.floorNumber;
    expect(floor, 2);
    const upgrade = EquipmentItem(
      id: 'cave_sword',
      name: 'Cave Sword',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      attackBonus: 40,
      itemLevel: 20,
    );
    director.debugInjectStash(const [upgrade]);
    for (final hero in director.spatial!.heroes) {
      hero.hp = 0;
    }
    director.spatialTick();

    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.currentRoom.floorNumber, floor);
    expect(director.state.wipeStreakCount, 1);
    expect(
      director.state.heroes.any(
        (hero) => hero.equipped.values.any((item) => item.id == 'cave_sword'),
      ),
      isTrue,
    );
    expect(director.toast, 'Better gear on — fight on');

    for (final hero in director.spatial!.heroes) {
      hero.hp = 0;
    }
    director.spatialTick();
    expect(director.awaitingWipeChoice, isTrue);
    expect(director.state.currentRoom.floorNumber, floor);
  });

  test('silent tile flag does not notify while the dungeon view unmounts', () {
    final director = GameDirector.preview();
    director.setDungeonTilesReady(true);
    var notes = 0;
    director.addListener(() => notes++);
    director.setDungeonTilesReady(false, notify: false);
    expect(director.dungeonTilesReady, isFalse);
    expect(notes, 0);
    director.setDungeonTilesReady(true);
    expect(notes, 1);
  });
}
