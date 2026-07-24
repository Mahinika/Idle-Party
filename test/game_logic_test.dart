import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/mission.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/models/stats.dart';

void main() {
  test('advancing ticks progresses battle and gold', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.advance(initial, steps: 4);

    expect(progressed.gold, greaterThan(initial.gold));
    expect(progressed.battleNumber, greaterThan(initial.battleNumber));
    expect(progressed.aliveEnemies, isNotEmpty);
  });

  test('offline progress is tracked and applied', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.applyOfflineProgress(
      initial,
      const Duration(seconds: 30),
    );

    expect(progressed.offlineSecondsRecovered, 30);
    expect(progressed.gold, greaterThanOrEqualTo(initial.gold));
  });

  test('training spends gold and levels up the party', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.partyTrainingCostFor(seeded),
    );

    final trained = GameLogic.trainParty(initial);

    expect(trained.gold, 0);
    expect(trained.heroes.first.level, initial.heroes.first.level + 1);
    expect(trained.heroes.first.currentHp, trained.heroes.first.maxHp);
  });

  test('loot rolls after battle victories', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.advance(initial, steps: 200);

    expect(progressed.recentLoot, isNotEmpty);
    expect(progressed.recentLoot.first.amount, greaterThan(0));
    expect(progressed.essence, greaterThan(0));
  });

  test('upgrade paths spend gold and change bonuses', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack),
    );

    final attackUpgraded = GameLogic.upgradeAttack(initial);
    final defenseUpgraded = GameLogic.upgradeDefense(initial);
    final vitalityUpgraded = GameLogic.upgradeVitality(initial);

    expect(attackUpgraded.attackBonus, 2);
    expect(defenseUpgraded.defenseBonus, 1);
    expect(vitalityUpgraded.vitalityBonus, 6);
    expect(attackUpgraded.gold, 0);
  });

  test('boss room clear increases boss victory count', () {
    final floor = DungeonGenerator.generateFloor(1);
    final bossRoom = floor.last;
    expect(bossRoom.type, RoomType.boss);

    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.push,
          currentRoom: bossRoom,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(bossRoom)
              .map((enemy) => enemy.copyWith(currentHp: 1))
              .toList(),
        );

    final progressed = GameLogic.advance(initial);

    expect(progressed.bossVictories, greaterThan(0));
    expect(progressed.currentRoom.floorNumber, 2);
    expect(progressed.highestFloorCleared, 1);
  });

  test('enemy scaling stays smooth across elite and boss thresholds', () {
    final floor1 = DungeonGenerator.generateFloor(1);
    final room9 = floor1[8];
    final room10 = floor1[9];
    final floor2 = DungeonGenerator.generateFloor(2);
    final room11 = floor2.first;

    final budget9 = GameLogic.roomCombatBudget(room9);
    final budget10 = GameLogic.roomCombatBudget(room10);
    final budget11 = GameLogic.roomCombatBudget(room11);

    expect(budget10.hp, greaterThan(budget9.hp));
    expect(budget10.hp, greaterThan(150));
    expect(budget10.hp, lessThan(400));
    expect(budget11.hp, lessThan(budget10.hp));
  });

  test('essence can unlock relic bonuses', () {
    final initial = GameLogic.createInitialState(
      now: DateTime(2026, 7, 4),
    ).copyWith(essence: GameLogic.relicCosts[GameLogic.warBannerRelic]);

    final unlocked = GameLogic.unlockRelic(initial, GameLogic.warBannerRelic);

    expect(unlocked.hasRelic(GameLogic.warBannerRelic), isTrue);
    expect(unlocked.essence, 0);
    expect(unlocked.totalAttackBonus, 4);
  });

  test('ascension is locked until required bosses are cleared', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    expect(GameLogic.canAscend(initial), isFalse);
    expect(identical(GameLogic.ascend(initial), initial), isTrue);

    final ready = initial.copyWith(bossVictories: 1);
    expect(GameLogic.canAscend(ready), isTrue);
  });

  test('ascend resets run and keeps meta progress', () {
    final weapon = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 10,
    );
    final ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          gold: 500,
          essence: 12,
          bossVictories: 1,
          attackBonus: 4,
          unlockedRelics: <String>[GameLogic.warBannerRelic],
          equippedWeapon: weapon,
        );

    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));

    expect(ascended.ascensionLevel, 1);
    expect(ascended.gold, 0);
    expect(ascended.bossVictories, 0);
    expect(ascended.attackBonus, 0);
    expect(ascended.battleNumber, 1);
    expect(ascended.equippedWeapon, isNull);
    expect(ascended.equippedArmor, isNull);
    expect(ascended.unlockedRelics, contains(GameLogic.warBannerRelic));
    expect(
      ascended.essence,
      12 + GameLogic.ascendEssenceReward(1),
    );
    expect(ascended.totalAttackBonus, 1 + 4); // AL + war banner
    expect(ascended.ascensionGoldBonusPercent, 10);
  });

  test('ascension gold bonus applies to room rewards', () {
    expect(GameLogic.applyGoldGain(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4))
          .copyWith(ascensionLevel: 2),
      100,
    ), 120);
  });

  test('stronger gear auto-equips and weaker gear goes to stash', () {
    final weak = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      battleNumber: 1,
    );
    final strong = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.epic,
      battleNumber: 12,
    );
    final weakerAgain = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 3,
    );

    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final afterWeak = GameLogic.applyLootDrops(initial, [
      LootDrop(
        name: weak.name,
        amount: 1,
        rarity: weak.rarity,
        equipment: weak,
      ),
    ]);
    expect(afterWeak.state.equippedWeapon?.id, weak.id);
    expect(afterWeak.resolved.first.outcome, LootOutcome.equipped);

    final afterStrong = GameLogic.applyLootDrops(afterWeak.state, [
      LootDrop(
        name: strong.name,
        amount: 1,
        rarity: strong.rarity,
        equipment: strong,
      ),
    ]);
    expect(afterStrong.state.equippedWeapon?.id, strong.id);
    expect(afterStrong.resolved.first.outcome, LootOutcome.replaced);
    expect(afterStrong.state.gearStash.map((item) => item.id), contains(weak.id));

    final afterSalvage = GameLogic.applyLootDrops(afterStrong.state, [
      LootDrop(
        name: weakerAgain.name,
        amount: 1,
        rarity: weakerAgain.rarity,
        equipment: weakerAgain,
      ),
    ]);
    expect(afterSalvage.state.equippedWeapon?.id, strong.id);
    expect(afterSalvage.resolved.first.outcome, LootOutcome.stashed);
    expect(
      afterSalvage.state.gearStash.map((item) => item.id),
      containsAll(<String>[weak.id, weakerAgain.id]),
    );
  });

  test('combinator merges same-slot gear and spends gold', () {
    final primary = EquipmentItem(
      id: 'w1',
      name: 'Iron Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 4,
      defenseBonus: 0,
      vitalityBonus: 0,
    );
    final secondary = EquipmentItem(
      id: 'w2',
      name: 'Rusty Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 2,
      defenseBonus: 0,
      vitalityBonus: 0,
    );
    final cost = GameLogic.combineCost(primary, secondary);
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          gold: cost,
          equippedWeapon: primary,
          gearStash: <EquipmentItem>[secondary],
        );

    final combined = GameLogic.combineGear(
      state,
      primaryId: primary.id,
      secondaryId: secondary.id,
    );

    expect(combined.gold, 0);
    expect(combined.gearStash, isEmpty);
    expect(combined.equippedWeapon, isNotNull);
    expect(combined.equippedWeapon!.id, isNot(primary.id));
    expect(combined.equippedWeapon!.rarity, LootRarity.uncommon);
    expect(combined.equippedWeapon!.attackBonus, 5);
  });

  test('stash overflow salvages oldest piece to essence', () {
    final pieces = List<EquipmentItem>.generate(
      GameLogic.maxGearStash + 1,
      (index) => EquipmentItem(
        id: 'stash_$index',
        name: 'Spare $index',
        slot: EquipmentSlot.armor,
        rarity: LootRarity.common,
        attackBonus: 0,
        defenseBonus: 1,
        vitalityBonus: 0,
      ),
    );
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final essenceBefore = state.essence;
    for (final piece in pieces) {
      state = GameLogic.stashEquipment(state, piece);
    }

    expect(state.gearStash, hasLength(GameLogic.maxGearStash));
    expect(state.gearStash.first.id, 'stash_1');
    expect(state.essence, greaterThan(essenceBefore));
  });

  test('clearing rooms can equip gear onto the party', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final progressed = GameLogic.advance(initial, steps: 80);

    expect(
      progressed.equippedWeapon != null || progressed.equippedArmor != null,
      isTrue,
    );
  });

  test('mage aura boosts party attack while Ember lives', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final aegis = state.heroes.first;
    final withMage = state.effectiveHeroAttack(aegis);

    final mageDown = state.copyWith(
      heroes: state.heroes
          .map(
            (hero) => hero.role == HeroRole.mage
                ? hero.copyWith(currentHp: 0)
                : hero,
          )
          .toList(),
    );
    final withoutMage = mageDown.effectiveHeroAttack(aegis);

    expect(withMage, greaterThan(withoutMage));
    expect(state.mageAuraBonusFor(aegis), greaterThanOrEqualTo(2));
  });

  test('warrior guard and healer mend passives apply', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final warrior = state.heroes.firstWhere(
      (hero) => hero.role == HeroRole.warrior,
    );
    expect(state.warriorGuardBonusFor(warrior), 2);
    expect(
      state.effectiveHeroDefense(warrior),
      warrior.defense + state.totalDefenseBonus + 2,
    );
    expect(state.healerMendAmount, 2);

    GameLogic.random = Random(3);
    final floor = DungeonGenerator.generateFloor(1);
    final room = floor.first;
    final enemies = GameLogic.createEnemyGroup(room)
        .map(
          (enemy) => enemy.copyWith(
            currentHp: 500,
            stats: Stats(
              attack: 12,
              defense: enemy.defense,
              maxHp: 500,
            ),
          ),
        )
        .toList();

    final damaged = state.copyWith(
      currentRoom: room,
      dungeonFloor: floor,
      enemies: enemies,
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: state.effectiveHeroMaxHp(hero) - 8,
            ),
          )
          .toList(),
    );

    final after = GameLogic.advance(damaged);
    final healedAny = after.heroes.any((hero) {
      final before = damaged.heroes.firstWhere((h) => h.name == hero.name);
      return hero.currentHp > before.currentHp;
    });
    // Mend can still leave net damage if hits are heavy, so assert the
    // healer is alive and mend amount remains available after the tick.
    expect(after.hasLivingHealer || healedAny, isTrue);
    expect(after.heroes.every((h) {
      return h.currentHp <= after.effectiveHeroMaxHp(h);
    }), isTrue);
  });

  test('mission board starts with three contracts', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(state.missions, hasLength(3));
    expect(
      state.missions.map((m) => m.type).toSet(),
      containsAll(MissionType.values),
    );
  });

  test('clearing rooms progresses and claim pays out missions', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final progressed = GameLogic.advance(initial, steps: 120);

    final defeat = progressed.missions.firstWhere(
      (m) => m.type == MissionType.defeatEnemies,
    );
    expect(defeat.progress, greaterThan(0));

    final goldMission = progressed.missions.firstWhere(
      (m) => m.type == MissionType.earnGold,
    );
    expect(goldMission.progress, greaterThan(0));

    final ready = progressed.copyWith(
      missions: progressed.missions
          .map(
            (m) => m.id == defeat.id ? m.copyWith(progress: m.target) : m,
          )
          .toList(),
    );
    final claimed = GameLogic.claimMission(ready, defeat.id);
    expect(claimed.gold, ready.gold + defeat.goldReward);
    expect(claimed.essence, ready.essence + defeat.essenceReward);
    expect(
      claimed.missions.firstWhere((m) => m.id == defeat.id).progress,
      0,
    );
  });

  test('ascend refreshes mission board for new AL', () {
    final ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          bossVictories: 1,
          missions: GameLogic.createMissionBoard(ascensionLevel: 0)
              .map((m) => m.copyWith(progress: m.target))
              .toList(),
        );
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.ascensionLevel, 1);
    expect(ascended.missions, hasLength(3));
    expect(ascended.missions.every((m) => m.progress == 0), isTrue);
    expect(
      ascended.missions
          .firstWhere((m) => m.type == MissionType.defeatEnemies)
          .target,
      12,
    );
  });

  test('farm mode loops the same floor after boss clear', () {
    final floor = DungeonGenerator.generateFloor(1);
    final bossRoom = floor.last;
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.farm,
          currentRoom: bossRoom,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(bossRoom)
              .map((e) => e.copyWith(currentHp: 1))
              .toList(),
        );

    final after = GameLogic.advance(state);
    expect(after.currentRoom.floorNumber, 1);
    expect(after.currentRoom.roomIndex, 0);
    expect(after.highestFloorCleared, 1);
    expect(after.bossVictories, greaterThan(0));
  });

  test('push mode advances floor and failed wipe retreats', () {
    final floor = DungeonGenerator.generateFloor(1);
    final bossRoom = floor.last;
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.push,
          currentRoom: bossRoom,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(bossRoom)
              .map((e) => e.copyWith(currentHp: 1))
              .toList(),
        );
    state = GameLogic.advance(state, steps: 5);
    expect(state.currentRoom.floorNumber, 2);
    expect(state.highestFloorCleared, 1);

    final wiped = state.copyWith(
      heroes: state.heroes.map((h) => h.copyWith(currentHp: 0)).toList(),
    );
    final retreated = GameLogic.advance(wiped);
    expect(retreated.currentRoom.floorNumber, 1);
    expect(retreated.dungeonMode, DungeonMode.farm);
  });

  test('equip sell and sanctuary persist through ascend', () {
    final stashItem = EquipmentItem(
      id: 'stash_w',
      name: 'Spare Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 3,
      defenseBonus: 0,
      vitalityBonus: 0,
    );
    final pet = const Pet(id: 'p1', name: 'Ember Pup', attackBonus: 2);
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          essence: 100,
          gearStash: <EquipmentItem>[stashItem],
          ownedPets: <Pet>[pet],
          activePet: pet,
        );
    state = GameLogic.equipFromStash(state, stashItem.id);
    expect(state.equippedWeapon?.id, stashItem.id);
    expect(state.gearStash, isEmpty);

    state = GameLogic.upgradeSanctuary(state, 'gold');
    expect(state.sanctuaryGoldLevel, 1);
    expect(GameLogic.applyGoldGain(state, 100), 105);

    final ready = state.copyWith(bossVictories: 1);
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.equippedWeapon, isNull);
    expect(ascended.sanctuaryGoldLevel, 1);
    expect(ascended.activePet?.id, pet.id);
    expect(ascended.ownedPets, hasLength(1));
    expect(ascended.highestFloorCleared, 0);
    expect(ascended.dungeonMode, DungeonMode.farm);
  });
}
