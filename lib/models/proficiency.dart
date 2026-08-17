import 'hero.dart';
import 'hero_spec.dart';
import 'loot.dart';

/// Classic-style armor / weapon proficiency for Idle Party roles.
class ClassProficiency {
  ClassProficiency._();

  static bool canEquipArmor(HeroRole role, int level, ArmorType type) {
    assert(level >= 1);
    return switch (role) {
      HeroRole.warrior => type == ArmorType.plate,
      HeroRole.rogue => type == ArmorType.leather,
      HeroRole.healer || HeroRole.mage => type == ArmorType.cloth,
    };
  }

  static bool canEquipArmorForSpec(
    HeroSpecDef spec,
    int level,
    ArmorType type,
  ) {
    if (spec.classId == HeroClassId.hunter) {
      if (level < 40) return type == ArmorType.leather;
      return type == ArmorType.mail;
    }
    return spec.armorTypes.contains(type);
  }

  /// Heaviest legal armor at [level] (plate > mail > leather > cloth).
  static ArmorType? preferredArmor(HeroSpecDef spec, int level) {
    for (final type in [
      ArmorType.plate,
      ArmorType.mail,
      ArmorType.leather,
      ArmorType.cloth,
    ]) {
      if (canEquipArmorForSpec(spec, level, type)) return type;
    }
    return null;
  }

  static bool canEquipWeapon(
    HeroRole role,
    WeaponType type,
    WeaponHanded handed, {
    required bool rangedSlot,
  }) {
    if (rangedSlot) {
      return switch (role) {
        HeroRole.warrior || HeroRole.rogue => type == WeaponType.thrown,
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
        WeaponType.polearm => true,
        WeaponType.bow ||
        WeaponType.crossbow ||
        WeaponType.gun ||
        WeaponType.thrown ||
        WeaponType.wand => false,
      },
      HeroRole.rogue => switch (type) {
        WeaponType.axe ||
        WeaponType.sword ||
        WeaponType.mace ||
        WeaponType.dagger ||
        WeaponType.fist => handed == WeaponHanded.oneHand,
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

  /// WotLK-strict weapons. Paladin / DK / Shaman / Druid have no ranged slot.
  static bool canEquipWeaponForSpec(
    HeroSpecDef spec,
    WeaponType type,
    WeaponHanded handed, {
    required bool rangedSlot,
  }) {
    if (rangedSlot) {
      if (!usesRangedSlot(spec)) return false;
      return switch (spec.classId) {
        HeroClassId.hunter =>
          type == WeaponType.bow ||
              type == WeaponType.crossbow ||
              type == WeaponType.gun,
        HeroClassId.warrior || HeroClassId.rogue => type == WeaponType.thrown,
        HeroClassId.priest ||
        HeroClassId.mage ||
        HeroClassId.warlock => type == WeaponType.wand,
        _ => false,
      };
    }

    return switch (spec.classId) {
      HeroClassId.warrior => switch (type) {
        WeaponType.axe ||
        WeaponType.sword ||
        WeaponType.mace ||
        WeaponType.dagger ||
        WeaponType.fist ||
        WeaponType.staff ||
        WeaponType.polearm => true,
        _ => false,
      },
      HeroClassId.paladin => switch (type) {
        WeaponType.axe ||
        WeaponType.sword ||
        WeaponType.mace ||
        WeaponType.polearm => true,
        _ => false,
      },
      HeroClassId.hunter => switch (type) {
        WeaponType.axe ||
        WeaponType.sword ||
        WeaponType.polearm ||
        WeaponType.staff => true,
        WeaponType.dagger || WeaponType.fist => handed == WeaponHanded.oneHand,
        _ => false,
      },
      HeroClassId.rogue => switch (type) {
        WeaponType.axe ||
        WeaponType.sword ||
        WeaponType.mace ||
        WeaponType.dagger ||
        WeaponType.fist => handed == WeaponHanded.oneHand,
        _ => false,
      },
      HeroClassId.priest => switch (type) {
        WeaponType.mace => handed == WeaponHanded.oneHand,
        WeaponType.dagger || WeaponType.staff => true,
        _ => false,
      },
      HeroClassId.deathKnight => switch (type) {
        WeaponType.axe ||
        WeaponType.sword ||
        WeaponType.mace ||
        WeaponType.polearm => true,
        _ => false,
      },
      HeroClassId.shaman => switch (type) {
        WeaponType.axe || WeaponType.mace || WeaponType.staff => true,
        WeaponType.dagger || WeaponType.fist => handed == WeaponHanded.oneHand,
        _ => false,
      },
      HeroClassId.mage || HeroClassId.warlock => switch (type) {
        WeaponType.sword => handed == WeaponHanded.oneHand,
        WeaponType.dagger || WeaponType.staff => true,
        _ => false,
      },
      HeroClassId.druid => switch (type) {
        WeaponType.staff || WeaponType.polearm || WeaponType.mace => true,
        WeaponType.dagger || WeaponType.fist => handed == WeaponHanded.oneHand,
        _ => false,
      },
    };
  }

  /// Hunter bow/xbow/gun; Warrior/Rogue thrown; cloth casters wand.
  /// Paladin / DK / Shaman / Druid leave the slot empty.
  static bool usesRangedSlot(HeroSpecDef spec) => switch (spec.classId) {
    HeroClassId.hunter ||
    HeroClassId.warrior ||
    HeroClassId.rogue ||
    HeroClassId.priest ||
    HeroClassId.mage ||
    HeroClassId.warlock => true,
    _ => false,
  };

  /// Off-hand *weapon* (not shield): Rogue, Fury, Enhancement, Frost DK, Survival.
  static bool canDualWield(HeroSpecDef spec) =>
      spec.classId == HeroClassId.rogue ||
      spec.id == HeroSpecId.fury ||
      spec.id == HeroSpecId.enhancement ||
      spec.id == HeroSpecId.frostDk ||
      spec.id == HeroSpecId.survival;

  /// Shields: Warrior, Paladin, Shaman. Not DK / Druid / Hunter.
  static bool canUseShield(HeroSpecDef spec) => switch (spec.classId) {
    HeroClassId.warrior ||
    HeroClassId.paladin ||
    HeroClassId.shaman => true,
    _ => false,
  };

  static bool canEquipOffHand(HeroRole role, OffHandKind kind) {
    return switch (role) {
      HeroRole.warrior => kind == OffHandKind.shield,
      HeroRole.healer || HeroRole.mage => kind == OffHandKind.frill,
      HeroRole.rogue => kind == OffHandKind.weapon,
    };
  }

  static bool canEquipOffHandForSpec(HeroSpecDef spec, OffHandKind kind) {
    return switch (kind) {
      OffHandKind.shield => canUseShield(spec),
      OffHandKind.weapon => canDualWield(spec),
      OffHandKind.frill =>
        spec.classId == HeroClassId.priest ||
            spec.classId == HeroClassId.mage ||
            spec.classId == HeroClassId.warlock,
    };
  }

  static bool usesOffHandSlot(HeroSpecDef spec) =>
      canUseShield(spec) ||
      canDualWield(spec) ||
      canEquipOffHandForSpec(spec, OffHandKind.frill);

  /// Typical off-hand for loot / starters when the spec uses the slot.
  static OffHandKind? preferredOffHandKind(HeroSpecDef spec) {
    if (canDualWield(spec)) return OffHandKind.weapon;
    if (canEquipOffHandForSpec(spec, OffHandKind.frill)) {
      return OffHandKind.frill;
    }
    if (canUseShield(spec)) return OffHandKind.shield;
    return null;
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
        if (armor == ArmorType.mail &&
            spec?.classId == HeroClassId.hunter &&
            level < 40) {
          return 'Requires Mail (40+)';
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
      rejectReason(role: role, level: level, item: item, specId: specId) ==
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
    WeaponType.thrown => WeaponHanded.oneHand,
    WeaponType.staff ||
    WeaponType.polearm ||
    WeaponType.bow ||
    WeaponType.crossbow ||
    WeaponType.gun => WeaponHanded.twoHand,
    WeaponType.axe ||
    WeaponType.sword ||
    WeaponType.mace => WeaponHanded.oneHand,
  };
}
