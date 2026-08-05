import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/equip_stat_weights.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  EquipmentItem item({
    int str = 0,
    int agi = 0,
    int sta = 0,
    int intel = 0,
    int spi = 0,
    int sp = 0,
    int armor = 0,
    ArmorType? armorType,
  }) {
    return EquipmentItem(
      id: 't',
      name: 'T',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      strengthBonus: str,
      agilityBonus: agi,
      staminaBonus: sta,
      intellectBonus: intel,
      spiritBonus: spi,
      spellPowerBonus: sp,
      armorBonus: armor,
      armorType: armorType,
      itemLevel: 40,
    );
  }

  PartyHero hero(HeroSpecId id) {
    final spec = HeroSpecs.def(id);
    return PartyHero(
      id: id.name,
      name: spec.shortLabel,
      level: 20,
      currentHp: 100,
      stats: spec.startingStats,
      specId: id,
      equipped: const {},
    );
  }

  test('Arms prefers Str over Sta; Prot prefers Sta/Armor over Str', () {
    final arms = hero(HeroSpecId.arms);
    final prot = hero(HeroSpecId.protection);
    final strPiece = item(str: 12, sta: 2, armor: 2, armorType: ArmorType.plate);
    final tankPiece =
        item(str: 2, sta: 12, armor: 14, armorType: ArmorType.plate);

    expect(
      GameLogic.specEquipScore(arms, strPiece),
      greaterThan(GameLogic.specEquipScore(arms, tankPiece)),
    );
    expect(
      GameLogic.specEquipScore(prot, tankPiece),
      greaterThan(GameLogic.specEquipScore(prot, strPiece)),
    );
  });

  test('Caster Int beats equal SP; Spirit loses to Int for Fire', () {
    final mage = hero(HeroSpecId.fire);
    final intPiece =
        item(intel: 12, sp: 0, armorType: ArmorType.cloth);
    final spPiece = item(intel: 0, sp: 12, armorType: ArmorType.cloth);
    final spiPiece =
        item(intel: 0, spi: 12, armorType: ArmorType.cloth);

    expect(
      GameLogic.specEquipScore(mage, intPiece),
      greaterThan(GameLogic.specEquipScore(mage, spPiece)),
    );
    expect(
      GameLogic.specEquipScore(mage, intPiece),
      greaterThan(GameLogic.specEquipScore(mage, spiPiece)),
    );
  });

  test('Healer prefers Int/SP throughput over Spirit', () {
    final healer = hero(HeroSpecId.discipline);
    final throughput =
        item(intel: 8, sp: 8, spi: 0, armorType: ArmorType.cloth);
    final spirit =
        item(intel: 0, sp: 0, spi: 16, armorType: ArmorType.cloth);

    expect(
      GameLogic.specEquipScore(healer, throughput),
      greaterThan(GameLogic.specEquipScore(healer, spirit)),
    );
  });

  test('Rogue/Hunter prefer Agi over Str', () {
    final combat = hero(HeroSpecId.combat);
    final bm = hero(HeroSpecId.beastMastery);
    final agi = item(agi: 12, str: 2, armorType: ArmorType.leather);
    final str = item(agi: 2, str: 12, armorType: ArmorType.leather);

    expect(
      GameLogic.specEquipScore(combat, agi),
      greaterThan(GameLogic.specEquipScore(combat, str)),
    );
    expect(
      GameLogic.specEquipScore(bm, agi),
      greaterThan(GameLogic.specEquipScore(bm, str)),
    );
  });

  test('EquipStatWeights loot shares: tank Sta-heavy, caster Int>SP', () {
    final tank = EquipStatWeights.lootShares(
      bias: HeroRole.warrior,
      roleTag: SpecRoleTag.tank,
    );
    expect(tank[2], greaterThan(tank[0])); // sta > str

    final caster = EquipStatWeights.lootShares(
      bias: HeroRole.mage,
      roleTag: SpecRoleTag.caster,
    );
    expect(caster[3], greaterThan(caster[5])); // intel > sp
    expect(caster[3], greaterThan(caster[4])); // intel > spi

    final arms = EquipStatWeights.lootShares(
      bias: HeroRole.warrior,
      roleTag: SpecRoleTag.meleeDps,
    );
    expect(arms[0], greaterThan(arms[2])); // str > sta
  });
}
