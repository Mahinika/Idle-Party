import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';

void main() {
  test('apex off-hand kinds match class fantasy (no fake shields)', () {
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.paladin, SpecRoleTag.tank),
      OffHandKind.shield,
    );
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.paladin, SpecRoleTag.healer),
      OffHandKind.shield,
    );
    // Ret is 2H — no off-hand recipe.
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.paladin, SpecRoleTag.meleeDps),
      isNull,
    );

    expect(
      ApexCraft.apexOffHandKind(HeroClassId.mage, SpecRoleTag.caster),
      OffHandKind.frill,
    );
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.warlock, SpecRoleTag.caster),
      OffHandKind.frill,
    );
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.priest, SpecRoleTag.healer),
      OffHandKind.frill,
    );

    // Hunter BM/MM/SV disagree (2H vs DW) → no shared OH.
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.hunter, SpecRoleTag.rangedDps),
      isNull,
    );
    expect(
      ApexCraft.craftSlotsFor(
        HeroClassId.hunter,
        SpecRoleTag.rangedDps,
      ).contains(EquipmentSlot.offHand),
      isFalse,
    );

    // Arms (no DW) vs Fury (DW) → no shared OH / no shield dump.
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.warrior, SpecRoleTag.meleeDps),
      isNull,
    );
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.warrior, SpecRoleTag.tank),
      OffHandKind.shield,
    );

    // Enhancement dual-wields — weapon, not shield.
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.shaman, SpecRoleTag.meleeDps),
      OffHandKind.weapon,
    );
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.shaman, SpecRoleTag.healer),
      OffHandKind.shield,
    );
    expect(
      ApexCraft.apexOffHandKind(HeroClassId.shaman, SpecRoleTag.caster),
      OffHandKind.shield,
    );
  });

  test('every crafted Apex MH+OH pair is equippable on that class×role', () {
    for (final classId in HeroClassId.values) {
      for (final role in ApexCraft.validRolesFor(classId)) {
        final ohKind = ApexCraft.apexOffHandKind(classId, role);
        final weapon = ApexCraft.buildItem(
          classId: classId,
          role: role,
          slot: EquipmentSlot.weapon,
          rank: 1,
          ascensionLevel: 0,
        );
        final spec = ApexCraft.representativeSpec(classId, role)!;
        expect(
          ClassProficiency.canEquip(
            role: spec.gearAffinity,
            level: 80,
            item: weapon,
            specId: spec.id,
          ),
          isTrue,
          reason: '${weapon.name} not equippable on ${spec.shortLabel}',
        );

        if (ohKind == null) {
          expect(
            ApexCraft.craftSlotsFor(classId, role)
                .contains(EquipmentSlot.offHand),
            isFalse,
          );
          continue;
        }

        expect(
          ClassProficiency.weaponBlocksOffHand(weapon),
          isFalse,
          reason: '${weapon.name} blocks OH but recipe crafts OH',
        );
        final off = ApexCraft.buildItem(
          classId: classId,
          role: role,
          slot: EquipmentSlot.offHand,
          rank: 1,
          ascensionLevel: 0,
        );
        expect(off.offHandKind, ohKind);
        expect(
          ClassProficiency.canEquip(
            role: spec.gearAffinity,
            level: 80,
            item: off,
            specId: spec.id,
          ),
          isTrue,
          reason: '${off.name} (${off.offHandKind}) not usable on '
              '${spec.shortLabel}',
        );
      }
    }
  });

  test('apex armor uses preferred armor for the class', () {
    final hunter = ApexCraft.buildItem(
      classId: HeroClassId.hunter,
      role: SpecRoleTag.rangedDps,
      slot: EquipmentSlot.chest,
      rank: 1,
      ascensionLevel: 0,
    );
    expect(hunter.armorType, ArmorType.mail);

    final mage = ApexCraft.buildItem(
      classId: HeroClassId.mage,
      role: SpecRoleTag.caster,
      slot: EquipmentSlot.chest,
      rank: 1,
      ascensionLevel: 0,
    );
    expect(mage.armorType, ArmorType.cloth);

    final paladin = ApexCraft.buildItem(
      classId: HeroClassId.paladin,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.chest,
      rank: 1,
      ascensionLevel: 0,
    );
    expect(paladin.armorType, ArmorType.plate);
  });
}
