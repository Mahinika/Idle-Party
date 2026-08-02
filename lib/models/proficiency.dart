import 'hero.dart';
import 'hero_spec.dart';
import 'loot.dart';

/// Classic-style armor / weapon proficiency for Idle Party roles.
class ClassProficiency {
  ClassProficiency._();

  static bool canEquipArmor(HeroRole role, int level, ArmorType type) {
    return switch (role) {
      HeroRole.warrior => type != ArmorType.plate || level >= 40,
      HeroRole.rogue =>
        type == ArmorType.cloth || type == ArmorType.leather,
      HeroRole.healer || HeroRole.mage => type == ArmorType.cloth,
    };
  }

  static bool canEquipArmorForSpec(HeroSpecDef spec, int level, ArmorType type) {
    if (!spec.armorTypes.contains(type)) return false;
    // Plate unlocks at 40 except Death Knights (start in plate).
    if (type == ArmorType.plate &&
        level < 40 &&
        spec.classId != HeroClassId.deathKnight) {
      return false;
    }
    return true;
  }

  static bool canEquipWeapon(
    HeroRole role,
    WeaponType type,
    WeaponHanded handed, {
    required bool rangedSlot,
  }) {
    if (rangedSlot) {
      return switch (role) {
        HeroRole.warrior || HeroRole.rogue =>
          type == WeaponType.bow ||
              type == WeaponType.crossbow ||
              type == WeaponType.gun ||
              type == WeaponType.thrown,
        HeroRole.healer || HeroRole.mage => type == WeaponType.wand,
      };
    }

    return switch (role) {
      HeroRole.warrior => switch (type) {
          WeaponType.axe ||
          WeaponType.sword ||
          WeaponType.mace ||
          WeaponType.dagger ||
          WeaponType.fist ||
          WeaponType.staff ||
          WeaponType.polearm =>
            true,
          WeaponType.bow ||
          WeaponType.crossbow ||
          WeaponType.gun ||
          WeaponType.thrown ||
          WeaponType.wand =>
            false,
        },
      HeroRole.rogue => switch (type) {
          WeaponType.axe ||
          WeaponType.sword ||
          WeaponType.mace ||
          WeaponType.dagger ||
          WeaponType.fist =>
            handed == WeaponHanded.oneHand,
          _ => false,
        },
      HeroRole.healer => switch (type) {
          WeaponType.mace => handed == WeaponHanded.oneHand,
          WeaponType.dagger || WeaponType.staff => true,
          _ => false,
        },
      HeroRole.mage => switch (type) {
          WeaponType.sword => handed == WeaponHanded.oneHand,
          WeaponType.dagger || WeaponType.staff => true,
          _ => false,
        },
    };
  }

  /// Class-aware weapons (falls back to [legacyRole] rules when unspecified).
  static bool canEquipWeaponForSpec(
    HeroSpecDef spec,
    WeaponType type,
    WeaponHanded handed, {
    required bool rangedSlot,
  }) {
    if (rangedSlot) {
      return switch (spec.classId) {
        HeroClassId.hunter =>
          type == WeaponType.bow ||
              type == WeaponType.crossbow ||
              type == WeaponType.gun ||
              type == WeaponType.thrown,
        HeroClassId.warrior ||
        HeroClassId.rogue ||
        HeroClassId.deathKnight ||
        HeroClassId.paladin ||
        HeroClassId.shaman ||
        HeroClassId.druid =>
          type == WeaponType.bow ||
              type == WeaponType.crossbow ||
              type == WeaponType.gun ||
              type == WeaponType.thrown,
        HeroClassId.priest ||
        HeroClassId.mage ||
        HeroClassId.warlock =>
          type == WeaponType.wand,
      };
    }

    return switch (spec.classId) {
      HeroClassId.hunter => switch (type) {
          WeaponType.axe ||
          WeaponType.sword ||
          WeaponType.polearm ||
          WeaponType.staff ||
          WeaponType.dagger ||
          WeaponType.fist =>
            true,
          _ => false,
        },
      HeroClassId.shaman => switch (type) {
          WeaponType.axe ||
          WeaponType.mace ||
          WeaponType.staff ||
          WeaponType.dagger ||
          WeaponType.fist =>
            true,
          _ => false,
        },
      HeroClassId.deathKnight => switch (type) {
          WeaponType.axe ||
          WeaponType.sword ||
          WeaponType.mace ||
          WeaponType.polearm =>
            true,
          _ => false,
        },
      HeroClassId.paladin => switch (type) {
          WeaponType.axe ||
          WeaponType.sword ||
          WeaponType.mace ||
          WeaponType.polearm =>
            true,
          _ => false,
        },
      HeroClassId.druid => switch (type) {
          WeaponType.staff ||
          WeaponType.dagger ||
          WeaponType.mace ||
          WeaponType.fist ||
          WeaponType.polearm =>
            true,
          _ => false,
        },
      HeroClassId.warlock => switch (type) {
          WeaponType.sword => handed == WeaponHanded.oneHand,
          WeaponType.dagger || WeaponType.staff => true,
          _ => false,
        },
      _ => canEquipWeapon(
          spec.legacyRole,
          type,
          handed,
          rangedSlot: false,
        ),
    };
  }

  static bool canEquipOffHand(HeroRole role, OffHandKind kind) {
    return switch (role) {
      HeroRole.warrior => kind == OffHandKind.shield,
      HeroRole.healer || HeroRole.mage => kind == OffHandKind.frill,
      HeroRole.rogue => kind == OffHandKind.weapon,
    };
  }

  static bool canEquipOffHandForSpec(HeroSpecDef spec, OffHandKind kind) {
    return switch (spec.classId) {
      HeroClassId.warrior || HeroClassId.deathKnight =>
        kind == OffHandKind.shield ||
            (spec.roleTag == SpecRoleTag.meleeDps &&
                kind == OffHandKind.weapon),
      HeroClassId.paladin =>
        kind == OffHandKind.shield ||
            (spec.isHealer && kind == OffHandKind.frill) ||
            (spec.roleTag == SpecRoleTag.meleeDps &&
                kind == OffHandKind.weapon),
      HeroClassId.shaman =>
        kind == OffHandKind.shield ||
            kind == OffHandKind.frill ||
            (spec.id == HeroSpecId.enhancement &&
                kind == OffHandKind.weapon),
      HeroClassId.rogue => kind == OffHandKind.weapon,
      HeroClassId.hunter =>
        kind == OffHandKind.weapon || kind == OffHandKind.frill,
      HeroClassId.druid =>
        spec.isTank
            ? kind == OffHandKind.frill
            : (kind == OffHandKind.frill || kind == OffHandKind.weapon),
      HeroClassId.priest ||
      HeroClassId.mage ||
      HeroClassId.warlock =>
        kind == OffHandKind.frill,
    };
  }

  /// Returns null if OK, otherwise a short reject reason.
  static String? rejectReason({
    required HeroRole role,
    required int level,
    required EquipmentItem item,
    HeroSpecId? specId,
  }) {
    final spec = specId == null ? null : HeroSpecs.def(specId);
    final label = spec?.shortLabel ?? role.name;
    final slot = item.slot;

    if (slot == EquipmentSlot.offHand) {
      final kind = item.offHandKind ?? OffHandKind.shield;
      final ok = spec == null
          ? canEquipOffHand(role, kind)
          : canEquipOffHandForSpec(spec, kind);
      if (!ok) {
        return '$label cannot use this off-hand';
      }
      if (kind == OffHandKind.weapon) {
        final wt = item.weaponType;
        if (wt == null) return 'Off-hand weapon missing type';
        final handed = item.handed ?? defaultHanded(wt);
        if (handed == WeaponHanded.twoHand) {
          return 'Off-hand must be one-handed';
        }
        final weaponOk = spec == null
            ? canEquipWeapon(role, wt, handed, rangedSlot: false)
            : canEquipWeaponForSpec(spec, wt, handed, rangedSlot: false);
        if (!weaponOk) {
          return '$label cannot dual-wield ${wt.name}';
        }
      }
      return null;
    }

    if (slot.isArmorSlot) {
      final armor = item.armorType ?? ArmorType.cloth;
      final ok = spec == null
          ? canEquipArmor(role, level, armor)
          : canEquipArmorForSpec(spec, level, armor);
      if (!ok) {
        if (armor == ArmorType.plate &&
            (role == HeroRole.warrior ||
                spec?.armorTypes.contains(ArmorType.plate) == true)) {
          return 'Requires Plate (40+)';
        }
        return '$label cannot equip ${armor.name}';
      }
      return null;
    }

    if (slot == EquipmentSlot.weapon || slot == EquipmentSlot.ranged) {
      final wt = item.weaponType;
      if (wt == null) return null;
      final handed = item.handed ?? defaultHanded(wt);
      final ranged = slot == EquipmentSlot.ranged;
      final ok = spec == null
          ? canEquipWeapon(role, wt, handed, rangedSlot: ranged)
          : canEquipWeaponForSpec(spec, wt, handed, rangedSlot: ranged);
      if (!ok) {
        return '$label cannot equip ${wt.name}';
      }
      return null;
    }

    return null;
  }

  static bool canEquip({
    required HeroRole role,
    required int level,
    required EquipmentItem item,
    HeroSpecId? specId,
  }) =>
      rejectReason(
        role: role,
        level: level,
        item: item,
        specId: specId,
      ) ==
      null;

  /// Two-handed main-hand conflicts with off-hand.
  static bool weaponBlocksOffHand(EquipmentItem? weapon) {
    if (weapon == null || weapon.slot != EquipmentSlot.weapon) return false;
    final wt = weapon.weaponType;
    if (wt == null) return false;
    final handed = weapon.handed ?? defaultHanded(wt);
    return handed == WeaponHanded.twoHand;
  }

  static WeaponHanded defaultHanded(WeaponType type) => switch (type) {
        WeaponType.dagger ||
        WeaponType.fist ||
        WeaponType.wand ||
        WeaponType.thrown =>
          WeaponHanded.oneHand,
        WeaponType.staff ||
        WeaponType.polearm ||
        WeaponType.bow ||
        WeaponType.crossbow ||
        WeaponType.gun =>
          WeaponHanded.twoHand,
        WeaponType.axe || WeaponType.sword || WeaponType.mace =>
          WeaponHanded.oneHand,
      };
}
