import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
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
    expect(ApexCraft.isValidPair(HeroClassId.warrior, SpecRoleTag.tank), isTrue);
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
    final mats = <String, int>{
      for (final m in ApexCraft.materials) m.id: 99,
    };
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
    final normal = GameLogic.createEquipment(
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
    final w = state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.warrior);
    expect(w, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    heroes[w] = heroes[w].copyWith(
      level: 40,
      equipped: {
        ...heroes[w].equipped,
        EquipmentSlot.chest: apex,
      },
    );
    state = state.copyWith(
      heroes: heroes,
      gearStash: [normal],
    );
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
    final normal = GameLogic.createEquipment(
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
    final w = state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.warrior);
    expect(w, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    heroes[w] = heroes[w].copyWith(
      level: 40,
      equipped: {
        ...heroes[w].equipped,
        EquipmentSlot.chest: apex,
      },
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

  test('weapon R1 is cheaper slag and lighter slot mult', () {
    expect(ApexCraft.slotCostMult(EquipmentSlot.weapon), 2.0);
    final r1 = ApexCraft.absoluteCost(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 1,
    );
    expect(r1['apex_slag'], 1);
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
      roster[ri] = hero.copyWith(
        specId: HeroSpecId.protection,
      );
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
    expect(
      state.heroes[wIdx].itemIn(EquipmentSlot.weapon)?.isApex,
      isTrue,
    );
  });

  test('legacy save defaults apex target fields', () {
    final loaded = MetaDepthState.fromJson(<String, dynamic>{});
    expect(loaded.apexCraftClassId, '');
    expect(loaded.apexTargetProgress, 0);
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
}
