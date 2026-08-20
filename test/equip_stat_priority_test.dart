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
    int crit = 0,
    int haste = 0,
    int mp5 = 0,
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
      critChanceBonus: crit,
      attackSpeedBonus: haste,
      mp5Bonus: mp5,
      armorType: armorType,
      itemLevel: 40,
    );
  }

  PartyHero hero(HeroSpecId id, {int level = 40}) {
    final spec = HeroSpecs.def(id);
    return PartyHero(
      id: id.name,
      name: spec.shortLabel,
      level: level,
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

  test('Enhancement values Str closer to Agi than pure Rogue', () {
    final enh = hero(HeroSpecId.enhancement);
    final combat = hero(HeroSpecId.combat);
    final strHeavy =
        item(str: 12, agi: 4, armorType: ArmorType.mail);
    final agiHeavy =
        item(str: 4, agi: 12, armorType: ArmorType.mail);

    final enhStr = GameLogic.specEquipScore(enh, strHeavy);
    final enhAgi = GameLogic.specEquipScore(enh, agiHeavy);
    final combStr = GameLogic.specEquipScore(combat, strHeavy);
    final combAgi = GameLogic.specEquipScore(combat, agiHeavy);

    // Both prefer Agi piece, but Enh's Str gap is smaller.
    expect(enhAgi, greaterThan(enhStr));
    expect(combAgi, greaterThan(combStr));
    expect(enhAgi - enhStr, lessThan(combAgi - combStr));
  });

  test('Enhancement: strong leather beats weak preferred mail', () {
    final enh = hero(HeroSpecId.enhancement);
    final weakMail = item(agi: 4, str: 2, armorType: ArmorType.mail);
    final strongLeather = item(agi: 14, str: 6, armorType: ArmorType.leather);
    expect(
      GameLogic.specEquipScore(enh, strongLeather),
      greaterThan(GameLogic.specEquipScore(enh, weakMail)),
    );
  });

  test('Prot: equal-stat plate and cloth score the same (budget honesty)', () {
    // Armor type is a canEquip / loot-bias concern, not a BiS crumb.
    final prot = hero(HeroSpecId.protection);
    final plate = item(str: 6, sta: 8, armor: 10, armorType: ArmorType.plate);
    final cloth = item(str: 6, sta: 8, armor: 10, armorType: ArmorType.cloth);
    expect(
      GameLogic.specEquipScore(prot, plate),
      GameLogic.specEquipScore(prot, cloth),
    );
  });

  test('Hunter prefers Agi more extremely than Combat Rogue', () {
    final bm = hero(HeroSpecId.beastMastery);
    final combat = hero(HeroSpecId.combat);
    final agi = item(agi: 14, str: 2, armorType: ArmorType.mail);
    final str = item(agi: 2, str: 14, armorType: ArmorType.mail);

    final bmGap =
        GameLogic.specEquipScore(bm, agi) - GameLogic.specEquipScore(bm, str);
    final combGap = GameLogic.specEquipScore(combat, agi) -
        GameLogic.specEquipScore(combat, str);
    expect(bmGap, greaterThan(combGap));
  });

  test('Shadow values Spirit more than Fire', () {
    final shadow = hero(HeroSpecId.shadow);
    final fire = hero(HeroSpecId.fire);
    final spi = item(intel: 6, spi: 10, armorType: ArmorType.cloth);
    final rawInt = item(intel: 12, spi: 0, armorType: ArmorType.cloth);

    final shadowSpiGap = GameLogic.specEquipScore(shadow, spi) -
        GameLogic.specEquipScore(shadow, rawInt);
    final fireSpiGap = GameLogic.specEquipScore(fire, spi) -
        GameLogic.specEquipScore(fire, rawInt);
    expect(shadowSpiGap, greaterThan(fireSpiGap));
  });

  test('priorityBlurb lists top stats for a spec', () {
    final blurb = EquipStatWeights.priorityBlurb(
      HeroSpecs.def(HeroSpecId.protection),
    );
    expect(blurb, contains('PROT'));
    expect(blurb.toLowerCase(), contains('stamina'));
  });

  test('Arms: equal-stat plate and cloth score the same (budget honesty)', () {
    final arms = hero(HeroSpecId.arms);
    final plate = item(str: 8, sta: 4, armorType: ArmorType.plate);
    final cloth = item(str: 8, sta: 4, armorType: ArmorType.cloth);
    expect(
      GameLogic.specEquipScore(arms, plate),
      GameLogic.specEquipScore(arms, cloth),
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

    final healer = EquipStatWeights.lootShares(
      bias: HeroRole.healer,
      roleTag: SpecRoleTag.healer,
    );
    expect(healer[3] + healer[5], greaterThan(healer[4])); // Int+SP > Spirit
  });

  test('Enhancement loot shares keep meaningful Str', () {
    final shares = EquipStatWeights.lootShares(
      bias: HeroRole.rogue,
      roleTag: SpecRoleTag.meleeDps,
      specId: HeroSpecId.enhancement,
    );
    expect(shares[0], greaterThan(0.25)); // str still real
    expect(shares[1], greaterThan(shares[0])); // agi > str (2 AP vs 1)
  });

  test('naked Combat still values Crit over equal Haste', () {
    final combat = hero(HeroSpecId.combat);
    final critPiece = item(agi: 2, crit: 12, armorType: ArmorType.leather);
    final hastePiece = item(agi: 2, haste: 12, armorType: ArmorType.leather);
    expect(
      GameLogic.specEquipScore(combat, critPiece),
      greaterThan(GameLogic.specEquipScore(combat, hastePiece)),
    );
  });

  test('Combat near 75% sheet crit stops paying for more Crit', () {
    final combat = hero(HeroSpecId.combat, level: 60).copyWith(
      equipped: {
        EquipmentSlot.chest: item(
          agi: 550,
          crit: 80,
          armorType: ArmorType.leather,
        ),
      },
    );
    expect(combat.gearCritChance, 40);
    final critPiece = item(agi: 2, crit: 12, armorType: ArmorType.leather);
    final hastePiece = item(agi: 2, haste: 12, armorType: ArmorType.leather);
    expect(
      GameLogic.specEquipScore(combat, hastePiece),
      greaterThan(GameLogic.specEquipScore(combat, critPiece)),
    );
  });

  test('Healer BiS prefers Mp5 over equal Haste', () {
    final disc = hero(HeroSpecId.discipline);
    final mp5Piece = item(intel: 4, mp5: 10, armorType: ArmorType.cloth);
    final hastePiece = item(intel: 4, haste: 10, armorType: ArmorType.cloth);
    expect(
      GameLogic.specEquipScore(disc, mp5Piece),
      greaterThan(GameLogic.specEquipScore(disc, hastePiece)),
    );
  });
}
