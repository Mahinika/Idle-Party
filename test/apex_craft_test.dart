import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/core/logic_notices.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  setUp(() {
    GameLogic.random = Random(42);
    LogicNotices.reset();
  });

  test('apex recipes only for valid class×role pairs', () {
    expect(ApexCraft.isValidPair(HeroClassId.mage, SpecRoleTag.tank), isFalse);
    expect(
      ApexCraft.isValidPair(HeroClassId.warrior, SpecRoleTag.tank),
      isTrue,
    );
    expect(
      ApexCraft.isValidPair(HeroClassId.priest, SpecRoleTag.healer),
      isTrue,
    );
    final recipe = ApexCraft.recipe(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    expect(recipe.costs.isNotEmpty, isTrue);
    expect(recipe.bossSources.isNotEmpty, isTrue);
  });

  test('boss clear can grant mats; trash clear does not', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      inDungeon: true,
      dungeonId: 'sandy',
      dungeonMode: DungeonMode.push,
      currentRoom: state.currentRoom.copyWith(type: RoomType.normal),
    );
    final before = Map<String, int>.from(state.craftMaterials);
    state = GameLogic.grantBossCraftMats(state, clearedBoss: false);
    expect(state.craftMaterials, before);

    state = GameLogic.grantBossCraftMats(state, clearedBoss: true);
    // Pity always bumps; mats may or may not roll.
    expect(state.craftPity.isNotEmpty, isTrue);
  });

  test('farm pity dilutes vs push', () {
    GameLogic.random = Random(1);
    var farm = GameLogic.createInitialState().copyWith(
      dungeonMode: DungeonMode.farm,
      dungeonId: 'sandy',
    );
    var push = GameLogic.createInitialState().copyWith(
      dungeonMode: DungeonMode.push,
      dungeonId: 'sandy',
    );
    for (var i = 0; i < 5; i++) {
      farm = GameLogic.grantBossCraftMats(farm, clearedBoss: true);
      push = GameLogic.grantBossCraftMats(push, clearedBoss: true);
    }
    final farmPity = farm.craftPity.values.fold<int>(0, (s, v) => s + v);
    final pushPity = push.craftPity.values.fold<int>(0, (s, v) => s + v);
    // Push accumulates pity faster (or equal if both granted resets).
    expect(pushPity >= farmPity || push.craftMaterials.isNotEmpty, isTrue);
  });

  test('craft weapon then armor gate; upgrade in place', () {
    var state = GameLogic.createInitialState();
    // Seed mats generously.
    final mats = <String, int>{for (final m in ApexCraft.materials) m.id: 99};
    state = state.copyWith(craftMaterials: mats);

    expect(
      GameLogic.canCraftApex(
        state,
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.chest,
      ),
      isFalse,
    );

    state = GameLogic.craftApex(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    final wIdx = state.heroes.indexWhere(
      (h) =>
          h.spec.classId == HeroClassId.warrior &&
          h.spec.roleTag == SpecRoleTag.tank,
    );
    expect(wIdx, greaterThanOrEqualTo(0));
    final weapon = state.heroes[wIdx].itemIn(EquipmentSlot.weapon);
    expect(weapon?.isApex, isTrue);
    expect(weapon?.apexRank, 1);
    expect(state.apexVault, isEmpty);
    expect(state.achievements, contains('apex_first'));

    expect(
      GameLogic.canCraftApex(
        state,
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.chest,
      ),
      isTrue,
    );

    final id = weapon!.id;
    state = GameLogic.upgradeApex(state, id);
    expect(state.heroes[wIdx].itemIn(EquipmentSlot.weapon)?.apexRank, 2);
    state = GameLogic.upgradeApex(state, id);
    expect(state.heroes[wIdx].itemIn(EquipmentSlot.weapon)?.apexRank, 3);
    expect(state.achievements, contains('apex_r3'));
    state = GameLogic.upgradeApex(state, id);
    expect(
      state.heroes[wIdx].itemIn(EquipmentSlot.weapon)?.apexRank,
      3,
      reason: 'AL0 caps at rank 3',
    );
  });

  test('ascend keeps mats, pity, vault, and equipped apex', () {
    var state = GameLogic.createInitialState();
    final mats = <String, int>{'shard_sandy': 7, 'apex_slag': 2};
    final pity = <String, int>{'pity_shard_sandy': 12};
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 0,
    );
    final hero = state.heroes.first.copyWith(
      equipped: {EquipmentSlot.weapon: apex},
    );
    state = state.copyWith(
      craftMaterials: mats,
      craftPity: pity,
      apexVault: [
        ApexCraft.buildItem(
          classId: HeroClassId.warrior,
          role: SpecRoleTag.tank,
          slot: EquipmentSlot.head,
          rank: 1,
          ascensionLevel: 0,
        ),
      ],
      heroes: [hero, ...state.heroes.skip(1)],
      bossVictories: 99,
      ascensionLevel: 0,
    );
    // Force ascend eligibility via boss victories already set; may need more.
    if (!GameLogic.canAscend(state)) {
      state = state.copyWith(
        bossVictories: GameLogic.bossesRequiredForAscension(0),
      );
    }
    expect(GameLogic.canAscend(state), isTrue);
    final ascended = GameLogic.ascend(state);
    expect(ascended.craftMaterials['shard_sandy'], 7);
    expect(ascended.craftPity['pity_shard_sandy'], 12);
    expect(ascended.apexVault.any((i) => i.slot == EquipmentSlot.head), isTrue);
    final worn = ascended.heroes.first.itemIn(EquipmentSlot.weapon);
    expect(worn?.isApex, isTrue);
    expect(worn?.apexRank, 1);
    expect(
      worn?.itemLevel,
      ApexCraft.itemLevelFor(
        rank: 1,
        ascensionLevel: 1,
        slot: EquipmentSlot.weapon,
      ),
    );
    final helm = ascended.apexVault
        .where((i) => i.slot == EquipmentSlot.head)
        .single;
    expect(
      helm.itemLevel,
      ApexCraft.itemLevelFor(
        rank: 1,
        ascensionLevel: 1,
        slot: EquipmentSlot.head,
      ),
    );
    expect(ascended.gearStash, isEmpty);
  });

  test('combinator rejects apex; auto-sell keeps apex', () {
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.mage,
      role: SpecRoleTag.caster,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 1,
    );
    final other = apex.copyWith(id: 'other', isApex: false, apexRank: 0);
    expect(GameLogic.canCombine(apex, other), isFalse);

    var state = GameLogic.createInitialState().copyWith(
      gearStash: [apex],
      autoSellMaxPower: 999,
    );
    // Apex in stash should be kept (not auto-sold junk).
    expect(
      GameLogic.autoSellJunk(state).gearStash.any((i) => i.id == apex.id),
      isTrue,
    );
  });

  test('equipFromStash refuses to overwrite Apex with normal gear', () {
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.chest,
      rank: 1,
      ascensionLevel: 0,
    );
    final normal =
        GameLogic.createEquipment(
          slot: EquipmentSlot.chest,
          rarity: LootRarity.epic,
          battleNumber: 20,
          bias: HeroRole.warrior,
        ).copyWith(
          id: 'normal_chest',
          armorType: ArmorType.plate,
          strengthBonus: 40,
          staminaBonus: 40,
          armorBonus: 40,
          itemLevel: 80,
          isApex: false,
          affinity: 'warrior',
        );
    var state = GameLogic.createInitialState();
    final w = state.heroes.indexWhere(
      (h) => h.gearAffinity == HeroRole.warrior,
    );
    expect(w, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    heroes[w] = heroes[w].copyWith(
      level: 40,
      equipped: {...heroes[w].equipped, EquipmentSlot.chest: apex},
    );
    state = state.copyWith(heroes: heroes, gearStash: [normal]);
    final next = GameLogic.equipFromStash(
      state,
      normal.id,
      heroIndex: w,
      intoSlot: EquipmentSlot.chest,
    );
    expect(next.heroes[w].itemIn(EquipmentSlot.chest)?.id, apex.id);
    expect(next.gearStash.any((g) => g.id == normal.id), isTrue);
    expect(GameLogic.compareForHero(next.heroes[w], normal).isUpgrade, isFalse);
  });

  test('bag EQUIP count ignores normal gear over worn Apex', () {
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.chest,
      rank: 1,
      ascensionLevel: 0,
    );
    final normal =
        GameLogic.createEquipment(
          slot: EquipmentSlot.chest,
          rarity: LootRarity.epic,
          battleNumber: 20,
          bias: HeroRole.warrior,
        ).copyWith(
          id: 'normal_chest_bis',
          armorType: ArmorType.plate,
          strengthBonus: 40,
          staminaBonus: 40,
          armorBonus: 40,
          itemLevel: 80,
          isApex: false,
          affinity: 'warrior',
        );
    var state = GameLogic.createInitialState();
    final w = state.heroes.indexWhere(
      (h) => h.gearAffinity == HeroRole.warrior,
    );
    expect(w, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    heroes[w] = heroes[w].copyWith(
      level: 40,
      equipped: {...heroes[w].equipped, EquipmentSlot.chest: apex},
    );
    state = state.copyWith(heroes: heroes, gearStash: [normal]);

    expect(MenuAlerts.bagUpgradeCount(state), 0);
    final after = GameLogic.autoEquipBetterGear(state);
    expect(after.heroes[w].itemIn(EquipmentSlot.chest)?.id, apex.id);
    expect(after.gearStash.any((g) => g.id == normal.id), isTrue);
  });

  test('save round-trip preserves craft fields and apex flags', () {
    var state = GameLogic.createInitialState().copyWith(
      craftMaterials: {'shard_crystal': 3},
      craftPity: {'pity_apex_slag': 9},
      apexVault: [
        ApexCraft.buildItem(
          classId: HeroClassId.rogue,
          role: SpecRoleTag.meleeDps,
          slot: EquipmentSlot.cloak,
          rank: 2,
          ascensionLevel: 4,
        ),
      ],
    );
    final raw = GameLogic.exportSaveJson(state);
    final loaded = GameLogic.importSaveJson(raw)!;
    expect(loaded.craftMaterials['shard_crystal'], 3);
    expect(loaded.craftPity['pity_apex_slag'], 9);
    expect(loaded.apexVault.single.isApex, isTrue);
    expect(loaded.apexVault.single.apexRank, 2);
    expect(loaded.apexVault.single.apexClassId, 'rogue');
  });

  test('upgrade delta costs less than absolute R2', () {
    final abs2 = ApexCraft.absoluteCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 2,
    );
    final delta = ApexCraft.upgradeDeltaCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      fromRank: 1,
      toRank: 2,
    );
    for (final e in delta.entries) {
      expect(e.value, lessThanOrEqualTo(abs2[e.key] ?? 0));
    }
  });

  test('weapon R1 is cheaper slag and any-zone shard pool', () {
    expect(ApexCraft.slotCostMult(EquipmentSlot.weapon), 2.0);
    final r1 = ApexCraft.absoluteCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 1,
    );
    expect(r1[ApexCraft.slagId], 1);
    expect(r1[ApexCraft.shardAnyId], 2);
    expect(r1.containsKey('shard_sandy'), isFalse);
  });

  test('late zone shards pay any-shard recipe costs', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      craftMaterials: {
        'shard_veil': 2,
        'core_tank': 2,
        'catalyst_warrior': 1,
        ApexCraft.slagId: 1,
      },
    );
    expect(
      GameLogic.canCraftApex(
        state,
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
      ),
      isTrue,
    );
    state = GameLogic.craftApex(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    expect(state.craftMaterials['shard_veil'], isNull);
    expect(
      state.heroes.any((h) => h.itemIn(EquipmentSlot.weapon)?.isApex == true),
      isTrue,
    );
  });

  test('upgrade delta stays short and same-shaped', () {
    final delta = ApexCraft.upgradeDeltaCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      fromRank: 1,
      toRank: 2,
    );
    expect(delta[ApexCraft.shardAnyId], 2);
    expect(delta['core_tank'], 1);
    expect(delta['catalyst_warrior'], 1);
    expect(delta[ApexCraft.slagId], 1);
  });

  test('target meter grants mat and resets on push boss clear', () {
    var state = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(
        apexCraftClassId: 'warrior',
        apexCraftRoleTag: 'tank',
        apexCraftSlot: 'weapon',
        apexTargetProgress: 90,
      ),
      dungeonMode: DungeonMode.push,
      inDungeon: true,
      dungeonId: 'sandy',
    );
    final beforeMats = Map<String, int>.from(state.craftMaterials);
    state = GameLogic.grantBossCraftMats(state, clearedBoss: true);
    expect(state.metaDepth.apexTargetProgress, 0);
    expect(
      state.craftMaterials.length > beforeMats.length ||
          state.craftMaterials.values.fold<int>(0, (s, v) => s + v) >
              beforeMats.values.fold<int>(0, (s, v) => s + v),
      isTrue,
    );
  });

  test('auto equip all places vault apex on matching party hero', () {
    var state = GameLogic.createInitialState();
    final wIdx = state.heroes.indexWhere(
      (h) =>
          h.spec.classId == HeroClassId.warrior &&
          h.spec.roleTag == SpecRoleTag.tank,
    );
    if (wIdx < 0) {
      final hero = state.heroes.first;
      final roster = [...state.heroRoster];
      final ri = roster.indexWhere((h) => h.id == hero.id);
      roster[ri] = hero.copyWith(specId: HeroSpecId.protection);
      state = state.copyWith(heroRoster: roster);
    }
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 0,
    );
    state = state.copyWith(apexVault: [apex]);
    final result = GameLogic.autoEquipAllApexVault(state);
    expect(result.equipped, 1);
    expect(result.state.apexVault, isEmpty);
    expect(
      result.state.heroes.any(
        (h) => h.equipped.values.any((g) => g.id == apex.id),
      ),
      isTrue,
    );
  });

  test('craft apex auto-equips when party hero matches', () {
    var state = GameLogic.createInitialState();
    final mats = <String, int>{for (final m in ApexCraft.materials) m.id: 99};
    state = state.copyWith(craftMaterials: mats);
    state = GameLogic.setApexCraftGoal(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    final wIdx = state.heroes.indexWhere(
      (h) =>
          h.spec.classId == HeroClassId.warrior &&
          h.spec.roleTag == SpecRoleTag.tank,
    );
    expect(wIdx, greaterThanOrEqualTo(0));
    state = GameLogic.craftApex(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    expect(state.apexVault, isEmpty);
    expect(state.heroes[wIdx].itemIn(EquipmentSlot.weapon)?.isApex, isTrue);
  });

  test('legacy save defaults apex target fields', () {
    final loaded = MetaDepthState.fromJson(<String, dynamic>{});
    expect(loaded.apexCraftClassId, '');
    expect(loaded.apexTargetProgress, 0);
  });

  test('IP-020 reselecting the same craft goal does not reset the meter', () {
    var state = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(
        apexCraftClassId: 'warrior',
        apexCraftRoleTag: 'tank',
        apexCraftSlot: 'weapon',
        apexTargetMatId: 'shard_sandy',
        apexTargetProgress: 72,
      ),
    );
    state = GameLogic.setApexCraftGoal(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    expect(state.metaDepth.apexTargetProgress, 72);
    expect(state.metaDepth.apexTargetMatId, 'shard_sandy');
  });

  test('craft goal and target mat changes reset target progress', () {
    var state = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(
        apexCraftClassId: 'warrior',
        apexCraftRoleTag: 'tank',
        apexCraftSlot: 'weapon',
        apexTargetMatId: 'shard_sandy',
        apexTargetProgress: 80,
      ),
    );
    state = GameLogic.setApexCraftGoal(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.head,
    );
    expect(state.metaDepth.apexTargetProgress, 0);
    expect(state.metaDepth.apexTargetMatId, '');

    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        apexTargetMatId: 'shard_sandy',
        apexTargetProgress: 55,
      ),
    );
    state = GameLogic.setApexTargetMat(state, 'apex_slag');
    expect(state.metaDepth.apexTargetMatId, 'apex_slag');
    expect(state.metaDepth.apexTargetProgress, 0);
  });

  test('unequip keeps the piece when a full bag evicts an apex item', () {
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 0,
    ).copyWith(id: 'bag_apex');
    final fillers = [
      for (var i = 0; i < GameLogic.maxGearStash - 1; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.common,
          battleNumber: 1,
        ).copyWith(id: 'fill_$i'),
    ];
    var state = GameLogic.createInitialState().copyWith(
      gearStash: [apex, ...fillers],
    );
    expect(state.gearStash.length, GameLogic.maxGearStash);
    final wornId = state.heroes[0].itemIn(EquipmentSlot.cloak)!.id;
    state = GameLogic.unequipSlot(state, EquipmentSlot.cloak, heroIndex: 0);
    expect(state.heroes[0].itemIn(EquipmentSlot.cloak), isNull);
    expect(state.gearStash.any((g) => g.id == wornId), isTrue);
    expect(state.apexVault.any((g) => g.id == 'bag_apex'), isTrue);
    expect(state.apexVault.any((g) => g.id == wornId), isFalse);
    expect(state.gearStash.length, GameLogic.maxGearStash);
  });

  test('max rank, power, and item level follow Ascend', () {
    expect(ApexCraft.maxRank(0), 3);
    expect(ApexCraft.maxRank(1), 3);
    expect(ApexCraft.maxRank(3), 3);
    expect(ApexCraft.maxRank(4), 3);
    expect(ApexCraft.maxRank(5), 4);
    expect(ApexCraft.maxRank(9), 4);
    expect(ApexCraft.maxRank(10), 5);
    expect(ApexCraft.maxRank(14), 5);
    expect(ApexCraft.maxRank(15), 6);
    expect(ApexCraft.maxRank(19), 6);
    expect(ApexCraft.maxRank(20), 7);
    expect(ApexCraft.maxRank(40), 7);
    expect(ApexCraft.maxRankLabel(0), 'Max rank 3');
    expect(ApexCraft.rankUnlockHint(0), 'Rank 4 unlocks at Ascend 5');
    expect(ApexCraft.rankUnlockHint(5), 'Rank 5 unlocks at Ascend 10');
    expect(ApexCraft.rankUnlockHint(10), 'Rank 6 unlocks at Ascend 15');
    expect(ApexCraft.rankUnlockHint(15), 'Rank 7 unlocks at Ascend 20');
    expect(ApexCraft.rankUnlockHint(20), isNull);

    const muls = <double>[1.06, 1.14, 1.22, 1.225, 1.230, 1.235, 1.240];
    for (var rank = 1; rank <= ApexCraft.absoluteMaxRank; rank++) {
      expect(ApexCraft.powerMulFor(rank), closeTo(muls[rank - 1], 1e-9));
    }

    expect(
      ApexCraft.itemLevelFor(
        rank: 3,
        ascensionLevel: 0,
        slot: EquipmentSlot.weapon,
      ),
      70,
    );
    expect(
      ApexCraft.itemLevelFor(
        rank: 4,
        ascensionLevel: 5,
        slot: EquipmentSlot.chest,
      ),
      82,
    );
    expect(
      ApexCraft.itemLevelFor(
        rank: 7,
        ascensionLevel: 20,
        slot: EquipmentSlot.weapon,
      ),
      142,
    );
  });

  test('ranks 1-3 keep their prices and 4-7 cost strictly more', () {
    void expectCost(EquipmentSlot slot, int rank, Map<String, int> mats) {
      expect(
        ApexCraft.absoluteCost(
          classId: HeroClassId.warrior,
          role: SpecRoleTag.tank,
          slot: slot,
          rank: rank,
        ),
        mats,
        reason: '${slot.name} R$rank',
      );
    }

    const shard = ApexCraft.shardAnyId;
    const slag = ApexCraft.slagId;
    const core = 'core_tank';
    const catalyst = 'catalyst_warrior';

    expectCost(EquipmentSlot.weapon, 1, {
      shard: 2,
      core: 2,
      catalyst: 1,
      slag: 1,
    });
    expectCost(EquipmentSlot.weapon, 2, {
      shard: 4,
      core: 3,
      catalyst: 2,
      slag: 2,
    });
    expectCost(EquipmentSlot.weapon, 3, {
      shard: 6,
      core: 4,
      catalyst: 3,
      slag: 3,
    });
    expectCost(EquipmentSlot.weapon, 4, {
      shard: 8,
      core: 5,
      catalyst: 4,
      slag: 4,
    });
    expectCost(EquipmentSlot.weapon, 5, {
      shard: 10,
      core: 6,
      catalyst: 5,
      slag: 5,
    });
    expectCost(EquipmentSlot.weapon, 6, {
      shard: 12,
      core: 7,
      catalyst: 6,
      slag: 6,
    });
    expectCost(EquipmentSlot.weapon, 7, {
      shard: 14,
      core: 8,
      catalyst: 7,
      slag: 7,
    });

    expectCost(EquipmentSlot.chest, 1, {shard: 2, core: 2, catalyst: 1});
    expectCost(EquipmentSlot.chest, 2, {
      shard: 4,
      core: 3,
      catalyst: 2,
      slag: 1,
    });
    expectCost(EquipmentSlot.chest, 3, {
      shard: 6,
      core: 4,
      catalyst: 3,
      slag: 2,
    });
    expectCost(EquipmentSlot.chest, 4, {
      shard: 8,
      core: 5,
      catalyst: 4,
      slag: 3,
    });
    expectCost(EquipmentSlot.chest, 5, {
      shard: 10,
      core: 6,
      catalyst: 5,
      slag: 4,
    });
    expectCost(EquipmentSlot.chest, 6, {
      shard: 12,
      core: 7,
      catalyst: 6,
      slag: 5,
    });
    expectCost(EquipmentSlot.chest, 7, {
      shard: 14,
      core: 8,
      catalyst: 7,
      slag: 6,
    });

    expectCost(EquipmentSlot.cloak, 1, {shard: 1, core: 1, catalyst: 1});
    expectCost(EquipmentSlot.cloak, 2, {
      shard: 2,
      core: 2,
      catalyst: 2,
      slag: 1,
    });
    expectCost(EquipmentSlot.cloak, 3, {
      shard: 4,
      core: 3,
      catalyst: 3,
      slag: 2,
    });
    expectCost(EquipmentSlot.cloak, 4, {
      shard: 6,
      core: 4,
      catalyst: 4,
      slag: 3,
    });
    expectCost(EquipmentSlot.cloak, 5, {
      shard: 8,
      core: 5,
      catalyst: 5,
      slag: 4,
    });
    expectCost(EquipmentSlot.cloak, 6, {
      shard: 10,
      core: 6,
      catalyst: 6,
      slag: 5,
    });
    expectCost(EquipmentSlot.cloak, 7, {
      shard: 12,
      core: 7,
      catalyst: 7,
      slag: 6,
    });

    final rank3 = ApexCraft.absoluteCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 3,
    );
    for (var rank = 4; rank <= 7; rank++) {
      final cost = ApexCraft.absoluteCost(
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
        rank: rank,
      );
      for (final entry in rank3.entries) {
        expect(
          cost[entry.key],
          greaterThan(entry.value),
          reason: 'R$rank ${entry.key}',
        );
      }
      final delta = ApexCraft.upgradeDeltaCost(
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
        fromRank: rank - 1,
        toRank: rank,
      );
      expect(delta.values.every((n) => n > 0), isTrue);
    }
  });

  test('an old rank 3 apex save loads unchanged and rebakes on Ascend', () {
    final fresh = GameLogic.createInitialState();
    final json = fresh.toJson();
    json['ascensionLevel'] = 9;
    json['apexVault'] = [
      {
        'id': 'apex_warrior_tank_weapon',
        'name': 'Apex Warrior Aegis Edge',
        'slot': 'weapon',
        'rarity': 'legendary',
        'strengthBonus': 20,
        'staminaBonus': 10,
        'itemLevel': 70,
        'isApex': true,
        'apexClassId': 'warrior',
        'apexRoleTag': 'tank',
        'apexRank': 3,
        'effectId': 'lifesteal',
        'effectValue': 9,
        'affixPrefixId': 'of_the_leech',
        'affixSuffixId': 'warded',
        'weaponType': 'mace',
        'handed': 'oneHand',
      },
    ];
    final loaded = GameLogic.stateFromJson(json);
    final saved = loaded.apexVault.single;
    expect(loaded.ascensionLevel, 9);
    expect(saved.apexRank, 3);
    expect(saved.itemLevel, 70);
    expect(saved.strengthBonus, 20);
    expect(saved.effectId, GearEffectId.lifesteal);
    expect(saved.effectValue, 9);
    expect(saved.affixPrefixId, 'of_the_leech');
    expect(saved.affixSuffixId, 'warded');

    final ascended = GameLogic.ascend(
      loaded.copyWith(bossVictories: GameLogic.bossesRequiredForAscension(9)),
    );
    expect(ascended.ascensionLevel, 10);
    final baked = ascended.apexVault.single;
    final freshBake = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 3,
      ascensionLevel: 10,
    );
    expect(baked.id, 'apex_warrior_tank_weapon');
    expect(baked.apexRank, 3);
    expect(baked.itemLevel, 90);
    expect(baked.strengthBonus, freshBake.strengthBonus);
    expect(baked.strengthBonus, isNot(20));
    expect(baked.effectId, GearEffectId.lifesteal);
    expect(baked.effectValue, 9);
    expect(baked.affixPrefixId, 'of_the_leech');
    expect(baked.affixSuffixId, 'warded');
  });

  test('ascend rebakes a worn apex piece and a bag piece at the same rank', () {
    final worn =
        ApexCraft.buildItem(
          classId: HeroClassId.warrior,
          role: SpecRoleTag.tank,
          slot: EquipmentSlot.weapon,
          rank: 3,
          ascensionLevel: 0,
        ).copyWith(
          effectId: GearEffectId.haste,
          effectValue: 4,
          affixSuffixId: 'warded',
        );
    final bag = ApexCraft.buildItem(
      classId: HeroClassId.mage,
      role: SpecRoleTag.caster,
      slot: EquipmentSlot.chest,
      rank: 2,
      ascensionLevel: 2,
    ).copyWith(effectId: GearEffectId.pierce, effectValue: 1);
    var state = GameLogic.createInitialState().copyWith(
      ascensionLevel: 4,
      bossVictories: GameLogic.bossesRequiredForAscension(4),
      gearStash: [bag],
    );
    final heroes = [...state.heroes];
    final index = heroes.indexWhere(
      (h) =>
          h.spec.classId == HeroClassId.warrior &&
          h.spec.roleTag == SpecRoleTag.tank,
    );
    expect(index, greaterThanOrEqualTo(0));
    heroes[index] = heroes[index].copyWith(
      equipped: {...heroes[index].equipped, EquipmentSlot.weapon: worn},
    );
    state = state.copyWith(heroes: heroes);

    expect(worn.itemLevel, 70);
    final ascended = GameLogic.ascend(state);
    expect(ascended.ascensionLevel, 5);
    final keptWorn = ascended.heroes[index].itemIn(EquipmentSlot.weapon)!;
    expect(keptWorn.apexRank, 3);
    expect(keptWorn.itemLevel, 80);
    expect(keptWorn.effectId, GearEffectId.haste);
    expect(keptWorn.effectValue, 4);
    expect(keptWorn.affixSuffixId, 'warded');
    final keptBag = ascended.apexVault.singleWhere(
      (item) => item.slot == EquipmentSlot.chest,
    );
    expect(keptBag.apexRank, 2);
    expect(
      keptBag.itemLevel,
      ApexCraft.itemLevelFor(
        rank: 2,
        ascensionLevel: 5,
        slot: EquipmentSlot.chest,
      ),
    );
    expect(keptBag.effectId, GearEffectId.pierce);
    expect(keptBag.effectValue, 1);
  });

  test('upgrade to a newly opened rank is optional and keeps affixes', () {
    final mats = <String, int>{for (final m in ApexCraft.materials) m.id: 99};
    var state = GameLogic.createInitialState().copyWith(
      craftMaterials: mats,
      ascensionLevel: 5,
    );
    state = GameLogic.craftApex(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    final index = state.heroes.indexWhere(
      (h) =>
          h.spec.classId == HeroClassId.warrior &&
          h.spec.roleTag == SpecRoleTag.tank,
    );
    final id = state.heroes[index].itemIn(EquipmentSlot.weapon)!.id;
    final heroes = [...state.heroes];
    heroes[index] = heroes[index].copyWith(
      equipped: {
        ...heroes[index].equipped,
        EquipmentSlot.weapon: heroes[index]
            .itemIn(EquipmentSlot.weapon)!
            .copyWith(
              effectId: GearEffectId.lifesteal,
              effectValue: 6,
              affixPrefixId: 'of_the_leech',
            ),
      },
    );
    state = state.copyWith(heroes: heroes);

    final before = Map<String, int>.from(state.craftMaterials);
    final delta = ApexCraft.upgradeDeltaCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      fromRank: 1,
      toRank: 2,
    );
    state = GameLogic.upgradeApex(state, id);
    final upgraded = state.heroes[index].itemIn(EquipmentSlot.weapon)!;
    expect(upgraded.apexRank, 2);
    expect(upgraded.effectId, GearEffectId.lifesteal);
    expect(upgraded.effectValue, 6);
    expect(upgraded.affixPrefixId, 'of_the_leech');
    for (final entry in delta.entries) {
      if (entry.key == ApexCraft.shardAnyId) {
        expect(
          ApexCraft.ownedShardCount(before) -
              ApexCraft.ownedShardCount(state.craftMaterials),
          entry.value,
        );
        continue;
      }
      final left = state.craftMaterials[entry.key] ?? 0;
      expect((before[entry.key] ?? 0) - left, entry.value);
    }

    state = GameLogic.upgradeApex(state, id);
    state = GameLogic.upgradeApex(state, id);
    expect(state.heroes[index].itemIn(EquipmentSlot.weapon)?.apexRank, 4);
    expect(GameLogic.canUpgradeApex(state, id), isFalse);
    state = GameLogic.upgradeApex(state, id);
    expect(state.heroes[index].itemIn(EquipmentSlot.weapon)?.apexRank, 4);

    state = state.copyWith(ascensionLevel: 10);
    expect(GameLogic.canUpgradeApex(state, id), isTrue);
    state = GameLogic.upgradeApex(state, id);
    expect(state.heroes[index].itemIn(EquipmentSlot.weapon)?.apexRank, 5);
    expect(state.heroes[index].itemIn(EquipmentSlot.weapon)?.effectValue, 6);
  });

  test('reborn at the AL cap rebakes an old apex item level', () {
    final old =
        ApexCraft.buildItem(
          classId: HeroClassId.warrior,
          role: SpecRoleTag.tank,
          slot: EquipmentSlot.weapon,
          rank: 3,
          ascensionLevel: 0,
        ).copyWith(
          itemLevel: 70,
          strengthBonus: 4,
          effectId: GearEffectId.goldFind,
          effectValue: 3,
        );
    final state = GameLogic.createInitialState().copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      apexVault: [old],
    );
    expect(GameLogic.canRebornAtCap(state), isTrue);
    final next = GameLogic.rebornAtCap(state);
    expect(next.ascensionLevel, GameLogic.maxAscensionLevel);
    final piece = next.apexVault.single;
    expect(piece.apexRank, 3);
    expect(piece.itemLevel, 110);
    expect(piece.effectId, GearEffectId.goldFind);
    expect(piece.effectValue, 3);
    expect(piece.strengthBonus, isNot(4));
  });

  test('max-rank apex budget versus a Mothveil boss legendary', () {
    for (final al in const <int>[0, 1, 3, 5, 10, 15, 20]) {
      final rank = ApexCraft.maxRank(al);
      final apex = ApexCraft.buildItem(
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
        rank: rank,
        ascensionLevel: al,
      );
      final apexBudget = ApexCraft.powerBudget(
        itemLevel: apex.itemLevel,
        rank: rank,
        slot: apex.slot,
        handed: apex.handed,
      );
      final dropIlvl = EquipmentFactory.itemLevelFor(
        battleNumber: 5 + al,
        rarity: LootRarity.legendary,
        dungeonId: 'veil',
        ascensionLevel: al,
      );
      final dropBudget = EquipmentFactory.budgetForItemLevel(
        itemLevel: dropIlvl,
        rarity: LootRarity.legendary,
        slot: EquipmentSlot.weapon,
        handed: apex.handed,
      );
      expect(apex.handed, WeaponHanded.oneHand);
      expect(
        apex.itemLevel,
        ApexCraft.itemLevelFor(
          rank: rank,
          ascensionLevel: al,
          slot: EquipmentSlot.weapon,
        ),
      );
      // 1H weapon. Drop is the Mothveil boss floor (5 + AL), legendary, no Keystone.
      const rows = <int, List<int>>{
        0: [3, 70, 84, 85, 84],
        1: [3, 72, 87, 89, 88],
        3: [3, 76, 92, 97, 96],
        5: [4, 88, 107, 102, 101],
        10: [5, 106, 128, 109, 107],
        15: [6, 124, 151, 116, 114],
        20: [7, 142, 174, 123, 121],
      };
      expect(
        [rank, apex.itemLevel, apexBudget, dropIlvl, dropBudget],
        rows[al],
        reason: 'AL $al',
      );
      if (al == 20) {
        expect(apexBudget / dropBudget, inInclusiveRange(1.25, 1.45));
      }
    }
  });
}
