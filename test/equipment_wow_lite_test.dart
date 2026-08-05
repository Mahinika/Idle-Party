import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
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

  test('affix load parses structured prefixes and suffixes', () async {
    await EquipmentFactory.loadAffixes();
    expect(EquipmentFactory.affixPrefixDefs, isNotEmpty);
    expect(EquipmentFactory.affixSuffixDefs, isNotEmpty);
    expect(EquipmentFactory.affixPrefixDefs.first.id, isNotEmpty);
    expect(EquipmentFactory.affixNameById('savage'), isNotNull);
  });
}
