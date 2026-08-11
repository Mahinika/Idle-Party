import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/gear_set.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  setUp(() {
    GameLogic.random = Random(42);
    EquipmentFactory.random = Random(42);
  });

  test('crystal dungeon loot has higher ilvl and budget than sandy', () {
    EquipmentFactory.random = Random(7);
    final sandy = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 10,
      bias: HeroRole.warrior,
      preferredArmor: ArmorType.plate,
      dungeonId: 'sandy',
      ascensionLevel: 0,
    );
    EquipmentFactory.random = Random(7);
    final crystal = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 10,
      bias: HeroRole.warrior,
      preferredArmor: ArmorType.plate,
      dungeonId: 'crystal',
      ascensionLevel: 3,
    );
    expect(crystal.effectiveItemLevel, greaterThan(sandy.effectiveItemLevel));
    final sandyPower = sandy.strengthBonus +
        sandy.staminaBonus +
        sandy.armorBonus;
    final crystalPower = crystal.strengthBonus +
        crystal.staminaBonus +
        crystal.armorBonus;
    expect(crystalPower, greaterThan(sandyPower));
  });

  test('chest slot budget exceeds wrist at same floor', () {
    EquipmentFactory.random = Random(11);
    final chest = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
      dungeonId: 'sandy',
    );
    EquipmentFactory.random = Random(11);
    final wrist = EquipmentFactory.create(
      slot: EquipmentSlot.wrist,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
      dungeonId: 'sandy',
    );
    expect(chest.powerScore, greaterThan(wrist.powerScore));
  });

  test('rare armor stamps dungeon setId', () {
    final piece = EquipmentFactory.create(
      slot: EquipmentSlot.head,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.mage,
      preferredArmor: ArmorType.cloth,
      dungeonId: 'hell',
    );
    expect(piece.setId, 'hell_cloth');
    expect(GearSets.displayName(piece.setId!), contains('Infernal'));
  });

  test('set 2pc and 4pc grant bonuses', () {
    EquipmentItem piece(EquipmentSlot slot) => EquipmentItem(
          id: 's_${slot.name}',
          name: 'Set ${slot.name}',
          slot: slot,
          rarity: LootRarity.rare,
          armorType: ArmorType.plate,
          setId: 'sandy_plate',
          staminaBonus: 2,
          armorBonus: 4,
          itemLevel: 20,
        );
    final hero = PartyHero.starting(
      name: 'Aegis',
      specId: HeroSpecId.protection,
    ).copyWith(
      equipped: {
        EquipmentSlot.head: piece(EquipmentSlot.head),
        EquipmentSlot.shoulder: piece(EquipmentSlot.shoulder),
      },
    );
    expect(GearSets.setStaminaBonus(hero.equipped), 3);
    expect(hero.gearStaminaBonus, greaterThanOrEqualTo(3 + 4));

    final full = hero.copyWith(
      equipped: {
        ...hero.equipped,
        EquipmentSlot.chest: piece(EquipmentSlot.chest),
        EquipmentSlot.legs: piece(EquipmentSlot.legs),
      },
    );
    expect(GearSets.setStaminaBonus(full.equipped), 6);
    expect(GearSets.setCritBonus(full.equipped), 2);
    expect(GearSets.setRoleArmorBonus(full.equipped, HeroRole.warrior), 4);
    expect(GearSets.setRoleHasteBonus(full.equipped, HeroRole.rogue), 2);
    expect(GearSets.setRoleHasteBonus(full.equipped, HeroRole.warrior), 0);
    final proc = GearSets.fourPieceProc(full.equipped);
    expect(proc, isNotNull);
    expect(proc!.tag, 'CAVERN');
    expect(proc.chance, greaterThan(0));
    expect(GearSets.setBonusBlurb(full.equipped), contains('4pc'));
  });

  test('soulbound primaries feed meta attack', () {
    final weapon = EquipmentItem(
      id: 'sb_w',
      name: 'Bound Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.epic,
      strengthBonus: 20,
      agilityBonus: 4,
      staminaBonus: 8,
      itemLevel: 40,
    );
    var state = GameLogic.createInitialState();
    state = state.copyWith(soulboundItem: weapon);
    expect(state.soulboundAttackBonus, greaterThan(0));
    expect(state.soulboundAttackBonus, greaterThan(weapon.attackBonus));
    expect(state.soulboundVitalityBonus, 80);
  });

  test('powerScore includes item level', () {
    final a = EquipmentItem(
      id: 'a',
      name: 'A',
      slot: EquipmentSlot.ring,
      rarity: LootRarity.common,
      strengthBonus: 2,
      itemLevel: 10,
    );
    final b = a.copyWith(itemLevel: 40);
    expect(b.powerScore, greaterThan(a.powerScore));
    expect(b.powerScore - a.powerScore, 30);
  });

  test('specEquipScore prefers set completion', () {
    final hero = PartyHero.starting(
      name: 'Aegis',
      specId: HeroSpecId.protection,
      level: 20,
    ).copyWith(
      equipped: {
        EquipmentSlot.head: EquipmentItem(
          id: 'h',
          name: 'Helm',
          slot: EquipmentSlot.head,
          rarity: LootRarity.rare,
          armorType: ArmorType.mail,
          setId: 'sandy_mail',
          staminaBonus: 5,
          armorBonus: 8,
          itemLevel: 20,
        ),
        EquipmentSlot.shoulder: EquipmentItem(
          id: 's',
          name: 'Shoulders',
          slot: EquipmentSlot.shoulder,
          rarity: LootRarity.rare,
          armorType: ArmorType.mail,
          setId: 'sandy_mail',
          staminaBonus: 5,
          armorBonus: 8,
          itemLevel: 20,
        ),
      },
    );
    final setChest = EquipmentItem(
      id: 'c_set',
      name: 'Set Chest',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      armorType: ArmorType.mail,
      setId: 'sandy_mail',
      staminaBonus: 6,
      armorBonus: 10,
      strengthBonus: 4,
      itemLevel: 20,
      affinity: 'warrior',
    );
    final plainChest = setChest.copyWith(
      id: 'c_plain',
      name: 'Plain Chest',
      clearSetId: true,
      staminaBonus: 6,
      armorBonus: 10,
      strengthBonus: 4,
    );
    expect(
      GameLogic.specEquipScore(hero, setChest),
      greaterThan(GameLogic.specEquipScore(hero, plainChest)),
    );
  });

  test('rollLoot can return multiple drops for spatial spawn', () {
    GameLogic.random = Random(99);
    var multi = <LootDrop>[];
    for (var seed = 0; seed < 40; seed++) {
      GameLogic.random = Random(seed);
      final drops = GameLogic.rollKillLoot(
        10,
        party: GameLogic.createInitialState().heroes,
        dungeonId: 'sandy',
      );
      if (drops.length > 1) {
        multi = drops;
        break;
      }
    }
    expect(multi.length, greaterThan(1));
  });

  test('equipment save round-trip keeps affix and set fields', () {
    final item = EquipmentItem(
      id: 'rt',
      name: 'Savage Plate Chest of the Bear',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      armorType: ArmorType.plate,
      strengthBonus: 5,
      staminaBonus: 8,
      armorBonus: 12,
      itemLevel: 28,
      affixPrefixId: 'savage',
      affixSuffixId: 'of_the_bear',
      setId: 'sandy_plate',
    );
    final again = EquipmentItem.fromJson(item.toJson());
    expect(again.affixPrefixId, 'savage');
    expect(again.affixSuffixId, 'of_the_bear');
    expect(again.setId, 'sandy_plate');
    expect(again.powerScore, item.powerScore);
    expect(again.setLabel, 'Cavern Plate');
  });

  test('boss floor clear keeps Boss Sigil; kill loot does not', () {
    final floor = GameLogic.rollFloorClearLoot(8, roomType: RoomType.boss);
    expect(floor.any((d) => d.name == 'Boss Sigil'), isTrue);

    GameLogic.random = Random(1);
    final kill = GameLogic.rollKillLoot(
      8,
      ascensionLevel: 3,
      party: GameLogic.createInitialState().heroes,
      dungeonId: 'sandy',
      enemyRole: EnemyRole.boss,
    );
    expect(kill.any((d) => d.name == 'Boss Sigil'), isFalse);

    // Combined helper still soft-caps important fillers.
    GameLogic.random = Random(7);
    final combined = GameLogic.rollLoot(
      8,
      ascensionLevel: 3,
      party: GameLogic.createInitialState().heroes,
      dungeonId: 'sandy',
      roomType: RoomType.boss,
    );
    expect(combined.any((d) => d.name == 'Boss Sigil'), isTrue);
  });

  test('merge rebuilds affix names from ids', () async {
    await EquipmentFactory.loadAffixes();
    final primary = EquipmentItem(
      id: 'p',
      name: 'Broken Name',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      armorType: ArmorType.plate,
      strengthBonus: 4,
      staminaBonus: 6,
      armorBonus: 8,
      itemLevel: 20,
      affinity: 'warrior',
      affixPrefixId: 'savage',
      affixSuffixId: 'of_the_bear',
      setId: 'sandy_plate',
    );
    final secondary = EquipmentItem(
      id: 's',
      name: 'Other',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.uncommon,
      armorType: ArmorType.plate,
      strengthBonus: 2,
      staminaBonus: 2,
      itemLevel: 12,
    );
    final merged = GameLogic.mergeEquipment(primary, secondary);
    expect(merged.affixPrefixId, 'savage');
    expect(merged.affixSuffixId, 'of_the_bear');
    expect(merged.setId, 'sandy_plate');
    expect(merged.name.toLowerCase(), contains('savage'));
    expect(merged.name.toLowerCase(), contains('bear'));
  });

  test('gold value does not triple-count ilvl', () {
    final item = EquipmentItem(
      id: 'g',
      name: 'Ring',
      slot: EquipmentSlot.ring,
      rarity: LootRarity.rare,
      strengthBonus: 5,
      itemLevel: 40,
    );
    final gold = GameLogic.equipmentGoldValue(item);
    final expected = 40 + item.statPowerScore + 80;
    expect(gold, expected);
    expect(gold, lessThan(40 + item.powerScore + 80));
  });

  test('itemLevelFor matrix: zone, AL, rarity, soft-cap', () {
    final sandyCommon = EquipmentFactory.itemLevelFor(
      battleNumber: 1,
      rarity: LootRarity.common,
      dungeonId: 'sandy',
    );
    expect(sandyCommon, 5);

    final sandyF10Rare = EquipmentFactory.itemLevelFor(
      battleNumber: 10,
      rarity: LootRarity.rare,
      dungeonId: 'sandy',
    );
    expect(sandyF10Rare, 31);

    final crystal = EquipmentFactory.itemLevelFor(
      battleNumber: 10,
      rarity: LootRarity.rare,
      dungeonId: 'crystal',
      ascensionLevel: 0,
    );
    expect(crystal, greaterThan(sandyF10Rare));
    expect(crystal, 55);

    final withAl = EquipmentFactory.itemLevelFor(
      battleNumber: 10,
      rarity: LootRarity.rare,
      dungeonId: 'crystal',
      ascensionLevel: 10,
    );
    expect(withAl, greaterThan(crystal));

    final withHm = EquipmentFactory.itemLevelFor(
      battleNumber: 10,
      rarity: LootRarity.rare,
      dungeonId: 'sandy',
      hardmodeLevel: 10,
    );
    expect(withHm, greaterThan(sandyF10Rare));

    // Endless Spire soft-cap: raw would be huge, capped growth after 100.
    final deep = EquipmentFactory.itemLevelFor(
      battleNumber: 80,
      rarity: LootRarity.common,
      dungeonId: 'crystal',
      ascensionLevel: 20,
    );
    final raw = 80 * 2 + 0 + 3 + 6 * 4 + 20 * 2; // 163
    expect(deep, lessThan(raw));
    expect(deep, lessThanOrEqualTo(150));
  });

  test('budget grows continuously within a rarity band', () {
    EquipmentFactory.random = Random(3);
    final early = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 1,
      bias: HeroRole.warrior,
      dungeonId: 'sandy',
    );
    EquipmentFactory.random = Random(3);
    final late = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
      dungeonId: 'sandy',
    );
    expect(late.effectiveItemLevel, greaterThan(early.effectiveItemLevel));
    final earlyPower =
        early.strengthBonus + early.staminaBonus + early.armorBonus;
    final latePower = late.strengthBonus + late.staminaBonus + late.armorBonus;
    expect(latePower, greaterThan(earlyPower));
  });

  test('hardmode bumps same-tier budget', () {
    EquipmentFactory.random = Random(9);
    final base = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
      dungeonId: 'sandy',
      hardmodeLevel: 0,
    );
    EquipmentFactory.random = Random(9);
    final hm = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
      dungeonId: 'sandy',
      hardmodeLevel: 10,
    );
    final basePower = base.strengthBonus + base.staminaBonus + base.armorBonus;
    final hmPower = hm.strengthBonus + hm.staminaBonus + hm.armorBonus;
    expect(hmPower, greaterThanOrEqualTo(basePower));
    expect(hm.effectiveItemLevel, greaterThanOrEqualTo(base.effectiveItemLevel));
  });

  test('soulbound scales ilvl and primaries on Ascend AL', () {
    final bound = EquipmentItem(
      id: 'soulbound_sword',
      name: 'Soulbound Sword',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      strengthBonus: 4,
      staminaBonus: 2,
      critChanceBonus: 2,
      attackSpeedBonus: 3,
      mp5Bonus: 1,
      itemLevel: 20,
    );
    final scaled = GameLogic.scaleSoulboundForAl(bound, 10);
    expect(scaled.effectiveItemLevel, greaterThanOrEqualTo(50));
    expect(scaled.strengthBonus, greaterThanOrEqualTo(bound.strengthBonus));
    expect(scaled.critChanceBonus, greaterThan(bound.critChanceBonus));
    expect(scaled.attackSpeedBonus, greaterThan(bound.attackSpeedBonus));
    expect(scaled.mp5Bonus, greaterThanOrEqualTo(bound.mp5Bonus));
  });

  test('soulbound folds legacy Vit/Def then keeps them after Ascend scale', () {
    final legacy = EquipmentItem(
      id: 'old_bound',
      name: 'Old Bound',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      vitalityBonus: 10,
      defenseBonus: 8,
      itemLevel: 24,
    );
    final scaled = GameLogic.scaleSoulboundForAl(legacy, 8);
    expect(scaled.vitalityBonus, 0);
    expect(scaled.defenseBonus, 0);
    expect(scaled.resolvedStamina, greaterThanOrEqualTo(10));
    expect(scaled.resolvedArmor, greaterThanOrEqualTo(8));
  });

  test('soulbound target ilvl uses soft-cap like drops', () {
    final bound = EquipmentItem(
      id: 'deep_bound',
      name: 'Deep Bound',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.epic,
      strengthBonus: 20,
      staminaBonus: 10,
      itemLevel: 90,
    );
    final scaled = GameLogic.scaleSoulboundForAl(bound, 40);
    final raw = max(90, 20 + 40 * 3);
    expect(scaled.effectiveItemLevel, EquipmentFactory.softCapItemLevel(raw));
    expect(scaled.effectiveItemLevel, lessThan(raw));
  });

  test('auto-sell cap scales with dungeon clears and AL', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 5));
    expect(GameLogic.maxAutoSellIlvlCap(state), 60);
    state = state.copyWith(highestDungeonCleared: 6, ascensionLevel: 10);
    expect(GameLogic.maxAutoSellIlvlCap(state), 200);
  });

  test('affix load parses structured prefixes and suffixes', () async {
    await EquipmentFactory.loadAffixes();
    expect(EquipmentFactory.affixPrefixDefs, isNotEmpty);
    expect(EquipmentFactory.affixSuffixDefs, isNotEmpty);
    expect(EquipmentFactory.affixPrefixDefs.first.id, isNotEmpty);
    expect(EquipmentFactory.affixNameById('savage'), isNotNull);
  });

  test('primary budget tracks displayed item level (soft-cap honest)', () {
    final lowIlvl = EquipmentFactory.budgetForItemLevel(
      itemLevel: 40,
      rarity: LootRarity.rare,
      slot: EquipmentSlot.chest,
    );
    final highIlvl = EquipmentFactory.budgetForItemLevel(
      itemLevel: 80,
      rarity: LootRarity.rare,
      slot: EquipmentSlot.chest,
    );
    expect(highIlvl, greaterThan(lowIlvl));
    expect(highIlvl / lowIlvl, closeTo(2.0, 0.15));

    final soft = EquipmentFactory.itemLevelFor(
      battleNumber: 80,
      rarity: LootRarity.common,
      dungeonId: 'crystal',
      ascensionLevel: 20,
    );
    const raw = 80 * 2 + 0 + 3 + 6 * 4 + 20 * 2;
    expect(soft, lessThan(raw));
    final softBudget = EquipmentFactory.budgetForItemLevel(
      itemLevel: soft,
      rarity: LootRarity.common,
      slot: EquipmentSlot.chest,
    );
    final rawBudget = EquipmentFactory.budgetForItemLevel(
      itemLevel: raw,
      rarity: LootRarity.common,
      slot: EquipmentSlot.chest,
    );
    expect(softBudget, lessThan(rawBudget));
  });

  test('same displayed ilvl → drop budget equals budgetForItemLevel', () {
    final a = EquipmentFactory.budgetForDrop(
      rarity: LootRarity.rare,
      battleNumber: 10,
      slot: EquipmentSlot.chest,
      dungeonId: 'sandy',
      ascensionLevel: 0,
    );
    final ilvlA = EquipmentFactory.itemLevelFor(
      battleNumber: 10,
      rarity: LootRarity.rare,
      dungeonId: 'sandy',
    );
    final fromIlvl = EquipmentFactory.budgetForItemLevel(
      itemLevel: ilvlA,
      rarity: LootRarity.rare,
      slot: EquipmentSlot.chest,
    );
    expect(a, fromIlvl);
  });

  test('created piece primary sum stays near ilvl budget band', () {
    EquipmentFactory.random = Random(21);
    final piece = EquipmentFactory.create(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
      preferredArmor: ArmorType.plate,
      dungeonId: 'sandy',
    );
    final budget = EquipmentFactory.budgetForItemLevel(
      itemLevel: piece.effectiveItemLevel,
      rarity: piece.rarity,
      slot: piece.slot,
    );
    final primaries = piece.strengthBonus +
        piece.agilityBonus +
        piece.staminaBonus +
        piece.intellectBonus +
        piece.spiritBonus +
        piece.spellPowerBonus +
        piece.armorBonus;
    expect(primaries, lessThanOrEqualTo((budget * 1.45).round()));
    expect(primaries, greaterThanOrEqualTo((budget * 0.55).round()));
  });

  test('secondaries grow with item level for same rarity', () {
    EquipmentFactory.random = Random(5);
    final low = EquipmentFactory.create(
      slot: EquipmentSlot.boots,
      rarity: LootRarity.rare,
      battleNumber: 2,
      bias: HeroRole.rogue,
      dungeonId: 'sandy',
    );
    EquipmentFactory.random = Random(5);
    final high = EquipmentFactory.create(
      slot: EquipmentSlot.boots,
      rarity: LootRarity.rare,
      battleNumber: 40,
      bias: HeroRole.rogue,
      dungeonId: 'sandy',
      ascensionLevel: 5,
    );
    expect(high.effectiveItemLevel, greaterThan(low.effectiveItemLevel + 20));
    expect(
      high.moveSpeedBonus + high.attackSpeedBonus,
      greaterThan(low.moveSpeedBonus + low.attackSpeedBonus),
    );
  });

  test('Apex budget follows legendary ilvl curve', () {
    final apex = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.meleeDps,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 5,
    );
    final expected = EquipmentFactory.budgetForItemLevel(
      itemLevel: apex.effectiveItemLevel,
      rarity: LootRarity.legendary,
      slot: apex.slot,
      handed: apex.handed,
    );
    final primaries = apex.strengthBonus +
        apex.agilityBonus +
        apex.staminaBonus +
        apex.attackBonus;
    // Rank mul ~1.06 — stay near drop budget, not 1.6× stacked.
    expect(primaries, greaterThan((expected * 0.7).round()));
    expect(primaries, lessThanOrEqualTo((expected * 1.25).round()));
  });

  test('Apex tank armor is carved from budget (not stacked)', () {
    final chest = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.chest,
      rank: 1,
      ascensionLevel: 3,
    );
    final budget = EquipmentFactory.budgetForItemLevel(
      itemLevel: chest.effectiveItemLevel,
      rarity: LootRarity.legendary,
      slot: chest.slot,
    );
    final sum = chest.strengthBonus +
        chest.staminaBonus +
        chest.armorBonus +
        chest.agilityBonus;
    expect(sum, lessThanOrEqualTo((budget * 1.25).round()));
    expect(chest.armorBonus, greaterThan(0));
  });
}
