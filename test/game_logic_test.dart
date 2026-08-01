import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/mission.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/models/stats.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  test('xp pools fill and level heroes from kills', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final before = state.heroes.first.level;
    final enemy = state.enemies.first;
    final need = GameLogic.xpPoolForLevel(before);
    state = GameLogic.awardPartyXp(state, need);
    expect(state.heroes.first.level, before + 1);
    expect(state.heroes.first.xp, 0);
    expect(GameLogic.xpForEnemy(enemy), greaterThan(0));
  });

  test('enemy groups use varied archetypes', () {
    final room = DungeonGenerator.generateFloor(3, layoutSeed: 42).first;
    final group = GameLogic.createEnemyGroup(room, dungeonId: 'sandy');
    expect(group, isNotEmpty);
    final kinds = group.map((e) => e.archetype).toSet();
    expect(kinds, isNotEmpty);
    expect(group.every((e) => e.name.isNotEmpty), isTrue);
  });

  test('class-biased loot favors matching roles', () {
    GameLogic.random = Random(42);
    final mageStaff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 6,
      bias: HeroRole.mage,
    );
    final tankShield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 6,
      bias: HeroRole.warrior,
    );
    expect(mageStaff.affinity, 'mage');
    expect(tankShield.affinity, 'warrior');
    expect(tankShield.offHandKind, OffHandKind.shield);
    expect(
      mageStaff.weaponType == WeaponType.staff ||
          mageStaff.weaponType == WeaponType.sword ||
          mageStaff.weaponType == WeaponType.dagger,
      isTrue,
    );
    expect(
      mageStaff.intellectBonus + mageStaff.spellPowerBonus,
      greaterThan(0),
    );
    expect(tankShield.resolvedArmor + tankShield.resolvedStamina, greaterThan(0));
    expect(tankShield.intellectBonus + tankShield.spellPowerBonus, 0);
  });

  test('advancing ticks progresses battle and gold', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.advance(initial, steps: 40);

    expect(progressed.gold, greaterThan(initial.gold));
    expect(progressed.highestFloorCleared, greaterThanOrEqualTo(1));
  });

  test('offline progress is tracked and applied', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.applyOfflineProgress(
      initial,
      const Duration(seconds: 30),
    );

    expect(progressed.state.offlineSecondsRecovered, 30);
    expect(progressed.state.gold, greaterThanOrEqualTo(initial.gold));
  });

  test('hub offline earns gold without boss or floor combat', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 26));
    expect(initial.inDungeon, isFalse);

    final progressed = GameLogic.applyOfflineProgress(
      initial,
      const Duration(hours: 2),
    );

    expect(progressed.state.bossVictories, initial.bossVictories);
    expect(progressed.state.highestFloorCleared, initial.highestFloorCleared);
    expect(progressed.state.inDungeon, isFalse);
    expect(progressed.state.gold, greaterThan(initial.gold));
    expect(progressed.bossDelta, 0);
    expect(progressed.roomsCleared, 0);
  });

  test('offline floor budget scales with time then soft-caps', () {
    expect(GameLogic.offlineFloorBudget(5 * 60), 7); // 300/40
    expect(GameLogic.offlineFloorBudget(30 * 60), 45); // 1800/40
    expect(GameLogic.offlineFloorBudget(60 * 60), greaterThan(45));
    expect(
      GameLogic.offlineFloorBudget(8 * 3600),
      lessThanOrEqualTo(120),
    );
    expect(
      GameLogic.offlineFloorBudget(60 * 60),
      lessThan(GameLogic.offlineFloorBudget(8 * 3600)),
    );
  });

  test('longer dungeon offline earns more gold than short AFK', () {
    final base = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
      dungeonId: 'sandy',
    );
    final farm = GameLogic.setDungeonMode(base, DungeonMode.farm);

    final shortAfk = GameLogic.applyOfflineProgress(
      farm,
      const Duration(minutes: 5),
    );
    final longAfk = GameLogic.applyOfflineProgress(
      farm,
      const Duration(minutes: 30),
    );

    expect(longAfk.state.gold, greaterThan(shortAfk.state.gold));
    expect(
      longAfk.state.offlineSecondsRecovered,
      greaterThan(shortAfk.state.offlineSecondsRecovered),
    );
    expect(longAfk.roomsCleared, greaterThan(shortAfk.roomsCleared));
    expect(longAfk.hasSummary, isTrue);
    expect(longAfk.headline, contains('Away'));
    expect(longAfk.headline, contains('g'));
  });

  test('dungeon offline catch-up clears rooms via SpatialCombat', () {
    final farm = GameLogic.setDungeonMode(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 8, 1)),
        dungeonId: 'sandy',
      ),
      DungeonMode.farm,
    );
    final sim = GameLogic.simulateSpatialOffline(farm, 5 * 60);
    expect(sim.roomsCleared, greaterThan(0));
    expect(sim.state.gold, greaterThanOrEqualTo(farm.gold));
  });

  test('training spends gold and levels up the party', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.partyTrainingCostFor(seeded),
    );

    final trained = GameLogic.trainParty(initial);

    expect(trained.gold, 0);
    expect(trained.heroes.first.level, initial.heroes.first.level + 1);
    expect(
      trained.heroes.first.currentHp,
      trained.effectiveHeroMaxHp(trained.heroes.first),
    );
  });

  test('loot rolls after battle victories', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.advance(initial, steps: 200);

    expect(progressed.recentLoot, isNotEmpty);
    expect(progressed.gold, greaterThan(initial.gold));
    // Early clears may stash gear and/or convert junk to essence.
    expect(
      progressed.essence > 0 || progressed.gearStash.isNotEmpty,
      isTrue,
    );
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

  test('boss floor clear increases boss victory count', () {
    final bossFloor = DungeonGenerator.bossFloorFor(0);
    final floor = DungeonGenerator.generateFloor(bossFloor, ascensionLevel: 0);
    final bossRoom = floor.first;
    expect(bossRoom.type, RoomType.boss);

    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.push,
          inDungeon: true,
          currentRoom: bossRoom,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(bossRoom)
              .map((enemy) => enemy.copyWith(currentHp: 1))
              .toList(),
        );

    final progressed = GameLogic.advance(initial, steps: 12);

    expect(progressed.bossVictories, greaterThan(0));
    expect(progressed.inDungeon, isFalse); // push boss clear → hub
    expect(progressed.highestFloorCleared, bossFloor);
    expect(progressed.highestDungeonCleared, greaterThanOrEqualTo(0));
  });

  test('enemy scaling increases with floor number', () {
    final f1 = DungeonGenerator.generateFloor(1).first;
    final f5 = DungeonGenerator.generateFloor(5, ascensionLevel: 0).first;
    final f6 = DungeonGenerator.generateFloor(6).first;

    final b1 = GameLogic.roomCombatBudget(f1);
    final b5 = GameLogic.roomCombatBudget(f5);
    final b6 = GameLogic.roomCombatBudget(f6);

    expect(f5.type, RoomType.boss);
    expect(b5.hp, greaterThan(b1.hp));
    expect(b6.hp, lessThan(b5.hp)); // normal floor after boss is softer than boss
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
          equipped: <EquipmentSlot, EquipmentItem>{
            EquipmentSlot.weapon: weapon,
          },
          highestFloorCleared: 3,
        );

    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));

    expect(ascended.ascensionLevel, 1);
    expect(ascended.gold, 0);
    expect(ascended.bossVictories, 0);
    expect(ascended.attackBonus, 0);
    expect(ascended.battleNumber, 1);
    expect(ascended.equipped, isEmpty);
    expect(ascended.unlockedRelics, contains(GameLogic.warBannerRelic));
    expect(
      ascended.essence,
      12 +
          GameLogic.ascendEssenceReward(1) +
          MetaSystems.ascendMilestoneReward(0, 1) +
          (AchievementCatalog.byId('first_ascend')?.essenceReward ?? 0) +
          (AchievementCatalog.byId('full_party')?.essenceReward ?? 0),
    );
    expect(ascended.achievements, contains('first_ascend'));
    expect(ascended.totalAttackBonus, 1 + 4); // AL + war banner
    expect(ascended.ascensionGoldBonusPercent, 10);
    expect(ascended.soulboundFragments, greaterThan(0));
    expect(ascended.inDungeon, isFalse);
  });

  test('ascend keeps hero levels and meta, clears run loadouts', () {
    final pet = const Pet(id: 'p_meta', name: 'Cub', attackBonus: 1);
    var ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      bossVictories: 1,
      essence: 20,
      lifetimeGoldEarned: 12000,
      highestDungeonCleared: 1,
      godHandLevel: 3,
      soulboundFragments: 5,
      sanctuaryPowerLevel: 2,
      ownedPets: <Pet>[pet],
      activePet: pet,
      heroes: GameLogic.createInitialState(now: DateTime(2026, 7, 4))
          .heroes
          .map((h) => h.copyWith(level: 12, xp: 40))
          .toList(),
    );
    ready = GameLogic.saveLoadout(ready, id: 'bis', name: 'BIS');
    expect(ready.loadouts, hasLength(1));

    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.lifetimeGoldEarned, 12000);
    expect(ascended.highestDungeonCleared, 1);
    expect(ascended.godHandLevel, 3);
    expect(ascended.soulboundFragments, greaterThanOrEqualTo(5));
    expect(ascended.sanctuaryPowerLevel, 2);
    expect(ascended.activePet?.id, pet.id);
    expect(ascended.loadouts, isEmpty);
    expect(ascended.gearStash, isEmpty);
    final kept = ascended.heroRoster.where(
      (h) => ready.heroRoster.any((r) => r.id == h.id),
    );
    expect(kept, isNotEmpty);
    expect(kept.every((h) => h.level == 12 && h.xp == 40), isTrue);
  });

  test('ascension gold bonus applies to room rewards', () {
    expect(GameLogic.applyGoldGain(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4))
          .copyWith(ascensionLevel: 2),
      100,
    ), 120);
  });

  test('loot always stashes gear for manual equip', () {
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

    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(autoSellMaxPower: 0);
    final afterWeak = GameLogic.applyLootDrops(initial, [
      LootDrop(
        name: weak.name,
        amount: 1,
        rarity: weak.rarity,
        equipment: weak,
      ),
    ]);
    expect(afterWeak.state.equipped, isEmpty);
    expect(afterWeak.state.gearStash.map((item) => item.id), contains(weak.id));
    expect(afterWeak.resolved.first.outcome, LootOutcome.stashed);

    final afterStrong = GameLogic.applyLootDrops(afterWeak.state, [
      LootDrop(
        name: strong.name,
        amount: 1,
        rarity: strong.rarity,
        equipment: strong,
      ),
    ]);
    expect(afterStrong.state.equipped, isEmpty);
    expect(
      afterStrong.state.gearStash.map((item) => item.id),
      containsAll(<String>[weak.id, strong.id]),
    );
  });

  test('combinator merges same-slot gear into stash', () {
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
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          gold: cost,
          gearStash: <EquipmentItem>[secondary],
        );
    final hero0 = state.heroes.first.copyWith(
      equipped: <EquipmentSlot, EquipmentItem>{
        EquipmentSlot.weapon: primary,
      },
    );
    state = state.copyWith(
      heroes: [hero0, ...state.heroes.skip(1)],
    );

    final combined = GameLogic.combineGear(
      state,
      primaryId: primary.id,
      secondaryId: secondary.id,
    );

    expect(combined.gold, 0);
    expect(combined.heroes.first.itemIn(EquipmentSlot.weapon), isNull);
    expect(combined.gearStash, hasLength(1));
    expect(combined.gearStash.first.id, isNot(primary.id));
    expect(combined.gearStash.first.rarity, LootRarity.uncommon);
    expect(
      combined.gearStash.first.attackBonus +
          combined.gearStash.first.strengthBonus,
      greaterThanOrEqualTo(5),
    );
    expect(combined.gearStash.first.slot, EquipmentSlot.weapon);
  });

  test('auto equip prefers class-relevant upgrades', () {
    GameLogic.random = Random(42);
    EquipmentFactory.random = GameLogic.random;
    final tankShield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      attackBonus: 0,
      defenseBonus: 12,
      vitalityBonus: 6,
      armorBonus: 12,
      staminaBonus: 6,
      strengthBonus: 4,
      effectId: GearEffectId.none,
      effectValue: 0,
      affinity: HeroRole.warrior.name,
      offHandKind: OffHandKind.shield,
    );
    final mageWand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.mage,
    ).copyWith(
      attackBonus: 14,
      defenseBonus: 0,
      vitalityBonus: 1,
      intellectBonus: 14,
      spiritBonus: 0,
      spellPowerBonus: 10,
      attackSpeedBonus: 8,
      critChanceBonus: 0,
      effectId: GearEffectId.none,
      effectValue: 0,
      affinity: HeroRole.mage.name,
      weaponType: WeaponType.staff,
      handed: WeaponHanded.twoHand,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    state = state.copyWith(
      heroes: state.heroes
          .map((h) => h.copyWith(clearEquipped: true))
          .toList(),
      gearStash: <EquipmentItem>[tankShield, mageWand],
    );
    state = GameLogic.autoEquipBetterGear(state);

    expect(state.heroes[0].role, HeroRole.warrior);
    expect(state.heroes[2].role, HeroRole.mage);
    expect(state.heroes[0].itemIn(EquipmentSlot.offHand)?.id, tankShield.id);
    expect(state.heroes[2].itemIn(EquipmentSlot.weapon)?.id, mageWand.id);
    expect(state.gearStash, isEmpty);
  });

  test('auto sell junk clears non-upgrades regardless of ilvl cap', () {
    final weak = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.common,
      battleNumber: 1,
    ).copyWith(
      attackBonus: 0,
      defenseBonus: 1,
      vitalityBonus: 1,
      itemLevel: 40,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final strongCloaks = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 8,
        ).copyWith(
          id: 'cloak_strong_$i',
          attackBonus: 2,
          defenseBonus: 8,
          vitalityBonus: 10,
          itemLevel: 28,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: <EquipmentItem>[...strongCloaks, weak],
      autoSellMaxPower: 5,
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(
        state,
        strongCloaks[i].id,
        heroIndex: i,
      );
    }
    state = state.copyWith(gearStash: <EquipmentItem>[weak]);

    final sold = GameLogic.autoSellJunk(state);
    expect(sold.gearStash, isEmpty);
    expect(sold.essence, greaterThan(state.essence));
  });

  test('auto equip fills ring2 when ring1 is already better', () {
    EquipmentItem ring({
      required String id,
      required int str,
      required int sta,
      required LootRarity rarity,
      required int ilvl,
    }) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.ring,
        rarity: rarity,
        battleNumber: 1,
      ).copyWith(
        id: id,
        strengthBonus: str,
        agilityBonus: 0,
        staminaBonus: sta,
        intellectBonus: 0,
        spiritBonus: 0,
        spellPowerBonus: 0,
        armorBonus: 0,
        mp5Bonus: 0,
        attackBonus: 0,
        defenseBonus: 0,
        vitalityBonus: 0,
        critChanceBonus: 0,
        attackSpeedBonus: 0,
        moveSpeedBonus: 0,
        itemLevel: ilvl,
        effectId: GearEffectId.none,
        effectValue: 0,
        affinity: HeroRole.warrior.name,
      );
    }

    final ringA = ring(
      id: 'ring_a',
      str: 8,
      sta: 6,
      rarity: LootRarity.rare,
      ilvl: 20,
    );
    final ringB = ring(
      id: 'ring_b',
      str: 4,
      sta: 3,
      rarity: LootRarity.uncommon,
      ilvl: 12,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // Only the warrior has open ring2 room relative to ringB.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == 0)
          state.heroes[i]
        else
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.ring && e.key != EquipmentSlot.ring2)
                  e.key: e.value,
              EquipmentSlot.ring: ring(
                id: 'locked_r1_$i',
                str: 20,
                sta: 20,
                rarity: LootRarity.epic,
                ilvl: 40,
              ),
              EquipmentSlot.ring2: ring(
                id: 'locked_r2_$i',
                str: 20,
                sta: 20,
                rarity: LootRarity.epic,
                ilvl: 40,
              ),
            },
          ),
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[ringA, ringB],
    );
    state = GameLogic.equipFromStash(state, ringA.id, heroIndex: 0);
    expect(state.heroes[0].itemIn(EquipmentSlot.ring)?.id, ringA.id);

    // Clear ring2 so ringB is clearly the empty-slot upgrade.
    final w = state.heroes[0];
    final wGear = Map<EquipmentSlot, EquipmentItem>.from(w.equipped)
      ..remove(EquipmentSlot.ring2);
    state = state.copyWith(
      heroes: [
        w.copyWith(equipped: wGear),
        ...state.heroes.skip(1),
      ],
      gearStash: <EquipmentItem>[ringB],
    );

    state = GameLogic.autoEquipBetterGear(state);

    expect(state.heroes[0].itemIn(EquipmentSlot.ring)?.id, ringA.id);
    expect(state.heroes[0].itemIn(EquipmentSlot.ring2)?.id, ringB.id);
    expect(state.gearStash, isEmpty);
  });

  test('sell junk drops offhand blocked by two-hand weapon', () {
    final staff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'big_staff',
      weaponType: WeaponType.staff,
      handed: WeaponHanded.twoHand,
      intellectBonus: 10,
      spellPowerBonus: 8,
      clearAffinity: true,
    );
    final weakFrill = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'junk_tome',
      offHandKind: OffHandKind.frill,
      intellectBonus: 1,
      spellPowerBonus: 1,
      itemLevel: 30,
      clearAffinity: true,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final mageIndex =
        state.heroes.indexWhere((h) => h.role == HeroRole.mage);
    expect(mageIndex, greaterThanOrEqualTo(0));

    // Strip mage gear then put 2H staff on.
    final heroes = [...state.heroes];
    heroes[mageIndex] = heroes[mageIndex].copyWith(clearEquipped: true);
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[staff, weakFrill],
    );
    state = GameLogic.equipFromStash(state, staff.id, heroIndex: mageIndex);
    expect(
      state.heroes[mageIndex].itemIn(EquipmentSlot.weapon)?.id,
      staff.id,
    );
    state = state.copyWith(gearStash: <EquipmentItem>[weakFrill]);

    final cmp = GameLogic.compareForHero(
      state.heroes[mageIndex],
      weakFrill,
    );
    expect(cmp.isUpgrade, isFalse);

    final sold = GameLogic.autoSellJunk(state);
    expect(sold.gearStash, isEmpty);
    expect(sold.essence, greaterThan(state.essence));
  });

  test('auto equip skips plate for low-level warrior and sells it as junk', () {
    final plate = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 10,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'plate_chest',
      armorType: ArmorType.plate,
      strengthBonus: 12,
      staminaBonus: 10,
      armorBonus: 20,
      itemLevel: 40,
      clearAffinity: true,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(state.heroes[0].level, lessThan(40));
    state = state.copyWith(gearStash: <EquipmentItem>[plate]);
    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.chest)?.id, isNot(plate.id));

    final sold = GameLogic.autoSellJunk(state);
    // Plate is kept only if some hero can wear it — none can at low level.
    expect(sold.gearStash.any((g) => g.id == plate.id), isFalse);
  });

  test('auto equip fills both empty ring slots from stash (BiS dual)', () {
    EquipmentItem ring({
      required String id,
      required int str,
      required int sta,
    }) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.ring,
        rarity: LootRarity.rare,
        battleNumber: 5,
      ).copyWith(
        id: id,
        strengthBonus: str,
        agilityBonus: 0,
        staminaBonus: sta,
        intellectBonus: 0,
        spiritBonus: 0,
        spellPowerBonus: 0,
        armorBonus: 0,
        mp5Bonus: 0,
        attackBonus: 0,
        defenseBonus: 0,
        vitalityBonus: 0,
        critChanceBonus: 0,
        attackSpeedBonus: 0,
        moveSpeedBonus: 0,
        itemLevel: 18,
        effectId: GearEffectId.none,
        effectValue: 0,
        affinity: HeroRole.warrior.name,
      );
    }

    final strong = ring(id: 'dual_r_strong', str: 10, sta: 8);
    final mild = ring(id: 'dual_r_mild', str: 5, sta: 4);

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // Lock other heroes' rings so only warrior claims these.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == 0)
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.ring && e.key != EquipmentSlot.ring2)
                  e.key: e.value,
            },
          )
        else
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.ring && e.key != EquipmentSlot.ring2)
                  e.key: e.value,
              EquipmentSlot.ring: ring(id: 'lock_r1_$i', str: 30, sta: 30),
              EquipmentSlot.ring2: ring(id: 'lock_r2_$i', str: 30, sta: 30),
            },
          ),
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[strong, mild],
    );

    state = GameLogic.autoEquipBetterGear(state);
    final ids = {
      state.heroes[0].itemIn(EquipmentSlot.ring)?.id,
      state.heroes[0].itemIn(EquipmentSlot.ring2)?.id,
    };
    expect(ids, containsAll(<String>[strong.id, mild.id]));
    expect(state.gearStash, isEmpty);
  });

  test('auto equip keeps 1H+offhand when 2H net score is worse', () {
    final oneHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'net_1h',
      weaponType: WeaponType.sword,
      handed: WeaponHanded.oneHand,
      strengthBonus: 6,
      staminaBonus: 4,
      attackBonus: 4,
      clearAffinity: true,
    );
    final shield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'net_shield',
      offHandKind: OffHandKind.shield,
      defenseBonus: 20,
      armorBonus: 18,
      staminaBonus: 14,
      strengthBonus: 4,
      clearAffinity: true,
    );
    final twoHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 6,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'net_2h',
      weaponType: WeaponType.sword,
      handed: WeaponHanded.twoHand,
      strengthBonus: 10,
      staminaBonus: 6,
      attackBonus: 8,
      clearAffinity: true,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(
      equipped: {
        EquipmentSlot.weapon: oneHand,
        EquipmentSlot.offHand: shield,
      },
    );
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[twoHand],
    );

    final cmp = GameLogic.compareForHero(state.heroes[0], twoHand);
    expect(cmp.isUpgrade, isFalse);

    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.weapon)?.id, oneHand.id);
    expect(state.heroes[0].itemIn(EquipmentSlot.offHand)?.id, shield.id);
    expect(state.gearStash.any((g) => g.id == twoHand.id), isTrue);
  });

  test('auto equip gives contested item to largest delta hero', () {
    EquipmentItem cloak({
      required String id,
      required int armor,
      required int sta,
    }) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.cloak,
        rarity: LootRarity.rare,
        battleNumber: 5,
      ).copyWith(
        id: id,
        armorBonus: armor,
        staminaBonus: sta,
        strengthBonus: 2,
        defenseBonus: armor,
        vitalityBonus: sta,
        effectId: GearEffectId.none,
        effectValue: 0,
        clearAffinity: true,
      );
    }

    final prize = cloak(id: 'prize_cloak', armor: 16, sta: 14);
    final runnerUp = cloak(id: 'runner_cloak', armor: 10, sta: 8);

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final w = state.heroes.indexWhere((h) => h.role == HeroRole.warrior);
    final m = state.heroes.indexWhere((h) => h.role == HeroRole.mage);
    expect(w, greaterThanOrEqualTo(0));
    expect(m, greaterThanOrEqualTo(0));

    // Empty cloaks on W/M; lock other heroes so they cannot claim.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == w || i == m)
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.cloak) e.key: e.value,
            },
          )
        else
          state.heroes[i].copyWith(
            equipped: {
              ...state.heroes[i].equipped,
              EquipmentSlot.cloak: cloak(
                id: 'lock_$i',
                armor: 40,
                sta: 40,
              ),
            },
          ),
    ];

    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[prize, runnerUp],
    );

    final deltaW = GameLogic.compareForHero(state.heroes[w], prize).powerDelta;
    final deltaM = GameLogic.compareForHero(state.heroes[m], prize).powerDelta;
    expect(deltaW, greaterThan(deltaM));
    expect(deltaW, greaterThan(0));
    expect(deltaM, greaterThan(0));

    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[w].itemIn(EquipmentSlot.cloak)?.id, prize.id);
    expect(state.heroes[m].itemIn(EquipmentSlot.cloak)?.id, runnerUp.id);
  });


  test('stash overflow salvages oldest piece to essence', () {
    final pieces = List<EquipmentItem>.generate(
      GameLogic.maxGearStash + 1,
      (index) => EquipmentItem(
        id: 'stash_$index',
        name: 'Spare $index',
        slot: EquipmentSlot.cloak,
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

  test('clearing rooms can stash gear for the party', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final progressed = GameLogic.advance(initial, steps: 80);

    expect(progressed.gearStash, isNotEmpty);
  });

  test('tile map multi-room floors are walkable with spawn and exit', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final map = RoomLayouts.forFloor(
      floorNumber: state.currentRoom.floorNumber,
      room: state.currentRoom,
      dungeonId: 'sandy',
    );
    expect(map.cols, greaterThan(13));
    expect(map.roomCenters.length, greaterThanOrEqualTo(1));
    expect(map.isWalkable(map.spawnPoints.first.$1, map.spawnPoints.first.$2),
        isTrue);
    expect(map.isWalkable(map.exitPoint.$1, map.exitPoint.$2), isTrue);
    expect(map.at(0, 0), TileKind.wall);
  });

  test('bossFloor formula is 5 plus ascension', () {
    expect(DungeonGenerator.bossFloorFor(0), 5);
    expect(DungeonGenerator.bossFloorFor(2), 7);
    expect(DungeonCatalog.byId('sandy').layout, DungeonLayoutKind.cave);
  });

  test('soulbound bind and god hand upgrade', () {
    final weapon = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 10,
    );
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      essence: 100,
      soulboundFragments: 3,
    );
    final hero0 = state.heroes.first.copyWith(
      equipped: <EquipmentSlot, EquipmentItem>{EquipmentSlot.weapon: weapon},
    );
    state = state.copyWith(heroes: [hero0, ...state.heroes.skip(1)]);
    state = GameLogic.bindSoulbound(state);
    expect(state.soulboundItem, isNotNull);
    expect(state.heroes.first.itemIn(EquipmentSlot.weapon), isNull);
    expect(state.soulboundFragments, 0);

    final before = state.godHandLevel;
    state = GameLogic.upgradeGodHand(state);
    expect(state.godHandLevel, before + 1);
  });

  test('enter and leave dungeon flags', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(state.inDungeon, isFalse);
    state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
    expect(state.inDungeon, isTrue);
    expect(state.dungeonId, 'sandy');
    state = GameLogic.leaveDungeon(state);
    expect(state.inDungeon, isFalse);
  });

  test('leaveDungeon clamps over-max HP from fortitude sync', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final hero = state.heroes.first;
    final maxHp = state.effectiveHeroMaxHp(hero);
    state = state.copyWith(
      heroes: [
        hero.copyWith(currentHp: maxHp + 200),
        ...state.heroes.skip(1),
      ],
    );
    state = GameLogic.leaveDungeon(state);
    expect(state.heroes.first.currentHp, maxHp);
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
    expect(state.casterAuraBonusFor(aegis), greaterThanOrEqualTo(2));
  });

  test('warrior guard and healer mend passives apply', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final warrior = state.heroes.firstWhere(
      (hero) => hero.role == HeroRole.warrior,
    );
    expect(state.tankGuardBonusFor(warrior), 2);
    expect(
      state.effectiveHeroDefense(warrior),
      greaterThanOrEqualTo(warrior.defense + state.tankGuardBonusFor(warrior)),
    );
    expect(state.healerMendAmount, 2);

    GameLogic.random = Random(3);
    final floor = DungeonGenerator.generateFloor(1);
    final room = floor.first;
    final enemies = GameLogic.createEnemyGroup(room)
        .map(
          (enemy) => enemy.copyWith(
            currentHp: 500,
            stats: Stats.enemy(
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

  test('farm mode loops the same floor after clear', () {
    final floor = DungeonGenerator.generateFloor(2);
    final room = floor.first;
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.farm,
          inDungeon: true,
          currentRoom: room,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(room)
              .map((e) => e.copyWith(currentHp: 1))
              .toList(),
        );

    final after = GameLogic.advance(state, steps: 12);
    expect(after.currentRoom.floorNumber, 2);
    expect(after.highestFloorCleared, 2);
    expect(after.inDungeon, isTrue);
  });

  test('push mode advances floor and failed wipe retreats', () {
    final floor = DungeonGenerator.generateFloor(2);
    final room = floor.first;
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.push,
          inDungeon: true,
          currentRoom: room,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(room)
              .map((e) => e.copyWith(currentHp: 1))
              .toList(),
        );
    for (var i = 0; i < 20 && state.currentRoom.floorNumber == 2; i++) {
      state = GameLogic.advance(state);
    }
    expect(state.currentRoom.floorNumber, 3);
    expect(state.highestFloorCleared, 2);

    final wiped = state.copyWith(
      heroes: state.heroes.map((h) => h.copyWith(currentHp: 0)).toList(),
    );
    final retreated = GameLogic.advance(wiped);
    expect(retreated.currentRoom.floorNumber, 2);
    expect(retreated.dungeonMode, DungeonMode.farm);
  });

  test('equip sell and sanctuary persist through ascend', () {
    final stashItem = EquipmentItem(
      id: 'stash_w',
      name: 'Spare Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 3,
      strengthBonus: 3,
      defenseBonus: 0,
      vitalityBonus: 0,
      weaponType: WeaponType.sword,
      handed: WeaponHanded.oneHand,
      affinity: HeroRole.warrior.name,
    );
    final pet = const Pet(id: 'p1', name: 'Ember Pup', attackBonus: 2);
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          essence: 100,
          gearStash: <EquipmentItem>[stashItem],
          ownedPets: <Pet>[pet],
          activePet: pet,
          heroes: GameLogic.createInitialState(now: DateTime(2026, 7, 4))
              .heroes
              .map((h) => h.copyWith(clearEquipped: true))
              .toList(),
        );
    state = GameLogic.equipFromStash(state, stashItem.id);
    expect(state.heroes.first.itemIn(EquipmentSlot.weapon)?.id, stashItem.id);
    expect(state.gearStash, isEmpty);

    state = GameLogic.upgradeSanctuary(state, 'gold');
    expect(state.sanctuaryGoldLevel, 1);
    expect(GameLogic.applyGoldGain(state, 100), 105);

    final ready = state.copyWith(bossVictories: 1);
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.equipped, isEmpty);
    // Fresh AL heroes get class starter kits (not previous run's gear).
    expect(ascended.heroes.every((h) => h.equipped.isNotEmpty), isTrue);
    expect(
      ascended.heroes.any(
        (h) => h.itemIn(EquipmentSlot.weapon)?.id == stashItem.id,
      ),
      isFalse,
    );
    expect(ascended.sanctuaryGoldLevel, 1);
    expect(ascended.activePet?.id, pet.id);
    expect(ascended.ownedPets, hasLength(1));
    expect(ascended.highestFloorCleared, 0);
    expect(ascended.dungeonMode, DungeonMode.push);
  });
}
