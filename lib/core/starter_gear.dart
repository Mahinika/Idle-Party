import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';
import 'game_state.dart';

/// The gear a hero starts with, and the rules for topping empty slots back up.
///
/// This is a lookup table with a couple of renaming rules on top: ~460 lines of
/// data that used to sit in the middle of the rules engine, pushing everything
/// else apart.
abstract final class StarterGear {
  /// Fills empty equipment slots with class starter pieces (keeps worn gear).
  static GameState fillMissingStarterGear(GameState state) {
    var changed = false;
    final rebuilt = <PartyHero>[];
    for (final hero in state.heroRoster) {
      final starter = forSpec(hero.specId);
      final next = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
      var heroChanged = false;
      final blocksOh = ClassProficiency.weaponBlocksOffHand(
        next[EquipmentSlot.weapon],
      );
      for (final entry in starter.entries) {
        if (next.containsKey(entry.key)) continue;
        // Never put a starter OH under a kept Apex (or any) 2H weapon.
        if (blocksOh && entry.key == EquipmentSlot.offHand) continue;
        next[entry.key] = entry.value.copyWith(id: '${entry.value.id}_fill');
        heroChanged = true;
        changed = true;
      }
      rebuilt.add(heroChanged ? hero.copyWith(equipped: next) : hero);
    }
    if (!changed) return state;
    return state.copyWith(heroRoster: rebuilt, lastUpdated: DateTime.now());
  }

  /// Starter kit keyed by talent tree — armor follows [HeroSpecDef.armorTypes].
  static Map<EquipmentSlot, EquipmentItem> forSpec(HeroSpecId specId) {
    final spec = HeroSpecs.def(specId);
    final kitRole = _starterKitRole(spec);
    final base = forRole(kitRole);
    final armorMat = preferredArmorForSpec(spec, 1);
    final matName = armorMat == null
        ? null
        : armorMat.name[0].toUpperCase() + armorMat.name.substring(1);
    final out = <EquipmentSlot, EquipmentItem>{};
    for (final e in base.entries) {
      final item = e.value;
      final id = item.id.replaceFirst(
        kitRole.name,
        spec.shortLabel.toLowerCase(),
      );
      if (armorMat != null &&
          matName != null &&
          item.slot.isArmorSlot &&
          item.armorType != null) {
        final oldMat = item.armorType!.name;
        final oldTitle = oldMat[0].toUpperCase() + oldMat.substring(1);
        final renamed = item.name.contains(oldTitle)
            ? item.name.replaceFirst(oldTitle, matName)
            : item.name;
        out[e.key] = item.copyWith(id: id, name: renamed, armorType: armorMat);
      } else {
        out[e.key] = item.copyWith(id: id);
      }
    }

    // Swap illegal off-hands (e.g. Guardian Druid inheriting a warrior shield).
    final oh = out[EquipmentSlot.offHand];
    if (oh != null &&
        !ClassProficiency.canEquip(
          role: spec.gearAffinity,
          level: 1,
          item: oh,
          specId: specId,
        )) {
      if (ClassProficiency.canEquipOffHandForSpec(spec, OffHandKind.frill)) {
        out[EquipmentSlot.offHand] = EquipmentItem(
          id: 'start_${spec.shortLabel.toLowerCase()}_oh',
          name: '${spec.shortLabel} Charm',
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.common,
          offHandKind: OffHandKind.frill,
          intellectBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster
              ? 1
              : 0,
          staminaBonus: 1,
          spiritBonus: spec.isHealer ? 1 : 0,
          spellPowerBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster
              ? 1
              : 0,
          itemLevel: 5,
        );
      } else if (ClassProficiency.canEquipOffHandForSpec(
        spec,
        OffHandKind.weapon,
      )) {
        out[EquipmentSlot.offHand] = EquipmentItem(
          id: 'start_${spec.shortLabel.toLowerCase()}_oh',
          name: '${spec.shortLabel} Sidearm',
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.common,
          offHandKind: OffHandKind.weapon,
          weaponType: WeaponType.dagger,
          handed: WeaponHanded.oneHand,
          agilityBonus: 1,
          staminaBonus: 1,
          itemLevel: 5,
        );
      } else {
        out.remove(EquipmentSlot.offHand);
      }
    }

    // Swap illegal ranged (Holy Paladin inheriting a priest wand, etc.).
    final ranged = out[EquipmentSlot.ranged];
    if (ranged != null &&
        !ClassProficiency.canEquip(
          role: spec.gearAffinity,
          level: 1,
          item: ranged,
          specId: specId,
        )) {
      final preferWand = ClassProficiency.canEquipWeaponForSpec(
        spec,
        WeaponType.wand,
        WeaponHanded.oneHand,
        rangedSlot: true,
      );
      out[EquipmentSlot.ranged] = EquipmentItem(
        id: 'start_${spec.shortLabel.toLowerCase()}_rng',
        name: preferWand
            ? '${spec.shortLabel} Wand'
            : '${spec.shortLabel} Thrown',
        slot: EquipmentSlot.ranged,
        rarity: LootRarity.common,
        weaponType: preferWand ? WeaponType.wand : WeaponType.thrown,
        handed: WeaponHanded.oneHand,
        intellectBonus: preferWand ? 1 : 0,
        spellPowerBonus: preferWand ? 2 : 0,
        strengthBonus: preferWand ? 0 : 1,
        agilityBonus: preferWand ? 0 : 1,
        itemLevel: 5,
      );
    }

    // Swap illegal main-hand weapons.
    final weapon = out[EquipmentSlot.weapon];
    if (weapon != null &&
        !ClassProficiency.canEquip(
          role: spec.gearAffinity,
          level: 1,
          item: weapon,
          specId: specId,
        )) {
      final useStaff = ClassProficiency.canEquipWeaponForSpec(
        spec,
        WeaponType.staff,
        WeaponHanded.twoHand,
        rangedSlot: false,
      );
      final useMace = ClassProficiency.canEquipWeaponForSpec(
        spec,
        WeaponType.mace,
        WeaponHanded.oneHand,
        rangedSlot: false,
      );
      out[EquipmentSlot.weapon] = EquipmentItem(
        id: 'start_${spec.shortLabel.toLowerCase()}_wpn',
        name: useStaff ? '${spec.shortLabel} Staff' : '${spec.shortLabel} Mace',
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.common,
        weaponType: useStaff ? WeaponType.staff : WeaponType.mace,
        handed: useStaff ? WeaponHanded.twoHand : WeaponHanded.oneHand,
        intellectBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster
            ? 2
            : 0,
        spiritBonus: spec.isHealer ? 1 : 0,
        spellPowerBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster
            ? 1
            : 0,
        strengthBonus: useMace && !spec.isHealer ? 2 : 0,
        staminaBonus: 1,
        itemLevel: 5,
      );
      if (useStaff) {
        out.remove(EquipmentSlot.offHand);
      }
    }

    return out;
  }

  static HeroRole _starterKitRole(HeroSpecDef spec) => switch (spec.classId) {
    HeroClassId.hunter => HeroRole.rogue,
    HeroClassId.shaman => switch (spec.roleTag) {
      SpecRoleTag.meleeDps => HeroRole.rogue,
      SpecRoleTag.healer => HeroRole.healer,
      _ => HeroRole.mage, // elemental caster
    },
    HeroClassId.deathKnight => HeroRole.warrior,
    HeroClassId.paladin => spec.isHealer ? HeroRole.healer : HeroRole.warrior,
    HeroClassId.warlock => HeroRole.mage,
    HeroClassId.druid => switch (spec.roleTag) {
      SpecRoleTag.tank => HeroRole.warrior,
      SpecRoleTag.healer => HeroRole.healer,
      SpecRoleTag.caster => HeroRole.mage,
      _ => HeroRole.rogue,
    },
    _ => spec.gearAffinity,
  };

  /// Heaviest armor the hero may wear at [level] (plate@40 except DK).
  static ArmorType? preferredArmorForSpec(HeroSpecDef spec, int level) {
    if (ClassProficiency.canEquipArmorForSpec(spec, level, ArmorType.plate)) {
      return ArmorType.plate;
    }
    if (spec.armorTypes.contains(ArmorType.mail)) return ArmorType.mail;
    if (spec.armorTypes.contains(ArmorType.leather)) return ArmorType.leather;
    if (spec.armorTypes.contains(ArmorType.cloth)) return ArmorType.cloth;
    return null;
  }

  static Map<EquipmentSlot, EquipmentItem> forRole(HeroRole role) {
    EquipmentItem piece({
      required String id,
      required String name,
      required EquipmentSlot slot,
      ArmorType? armorType,
      WeaponType? weaponType,
      WeaponHanded? handed,
      OffHandKind? offHandKind,
      int str = 0,
      int agi = 0,
      int sta = 0,
      int intel = 0,
      int spi = 0,
      int sp = 0,
      int armor = 0,
      int crit = 0,
      int aspd = 0,
      int move = 0,
      int mp5 = 0,
    }) {
      return EquipmentItem(
        id: id,
        name: name,
        slot: slot,
        rarity: LootRarity.common,
        strengthBonus: str,
        agilityBonus: agi,
        staminaBonus: sta,
        intellectBonus: intel,
        spiritBonus: spi,
        spellPowerBonus: sp,
        armorBonus: armor,
        critChanceBonus: crit,
        attackSpeedBonus: aspd,
        moveSpeedBonus: move,
        mp5Bonus: mp5,
        affinity: role.name,
        itemLevel: 5,
        armorType: armorType,
        weaponType: weaponType,
        handed: handed,
        offHandKind: offHandKind,
        iconId: slot == EquipmentSlot.consumable ? 'flask' : null,
      );
    }

    final prefix = switch (role) {
      HeroRole.warrior => 'Guard',
      HeroRole.healer => 'Soft',
      HeroRole.mage => 'Spark',
      HeroRole.rogue => 'Swift',
    };
    final armorMat = switch (role) {
      HeroRole.warrior => ArmorType.mail,
      HeroRole.rogue => ArmorType.leather,
      HeroRole.healer || HeroRole.mage => ArmorType.cloth,
    };
    final matName = armorMat.name[0].toUpperCase() + armorMat.name.substring(1);

    // Starter budget: modest — primaries mainly on weapon/chest.
    final p = switch (role) {
      HeroRole.warrior => (str: 1, agi: 0, sta: 1, intel: 0, spi: 0, sp: 0),
      HeroRole.rogue => (str: 0, agi: 1, sta: 1, intel: 0, spi: 0, sp: 0),
      HeroRole.healer => (str: 0, agi: 0, sta: 1, intel: 1, spi: 1, sp: 1),
      HeroRole.mage => (str: 0, agi: 0, sta: 1, intel: 1, spi: 1, sp: 1),
    };

    EquipmentItem armorPiece(
      EquipmentSlot slot,
      String noun, {
      int armorPts = 1,
    }) {
      final isCore =
          slot == EquipmentSlot.chest ||
          slot == EquipmentSlot.legs ||
          slot == EquipmentSlot.head;
      return piece(
        id: 'start_${role.name}_${slot.name}',
        name: '$prefix $matName $noun',
        slot: slot,
        armorType: armorMat,
        str: isCore ? p.str : 0,
        agi: isCore ? p.agi : 0,
        sta: isCore ? p.sta : (slot == EquipmentSlot.boots ? 1 : 0),
        intel: isCore ? p.intel : 0,
        spi: isCore ? p.spi : 0,
        sp: slot == EquipmentSlot.chest ? p.sp : 0,
        armor: role == HeroRole.warrior && isCore ? armorPts + 1 : armorPts,
        move: slot == EquipmentSlot.boots ? 2 : 0,
        aspd: slot == EquipmentSlot.hands || slot == EquipmentSlot.boots
            ? 1
            : 0,
        mp5: armorMat == ArmorType.cloth ? 1 : 0,
      );
    }

    EquipmentItem jewelry(EquipmentSlot slot, String noun) => piece(
      id: 'start_${role.name}_${slot.name}',
      name: '$prefix $noun',
      slot: slot,
      str: slot == EquipmentSlot.neck ? p.str : 0,
      agi: slot == EquipmentSlot.neck ? p.agi : 0,
      sta: 0,
      intel: slot == EquipmentSlot.neck ? p.intel : 0,
      spi: slot == EquipmentSlot.neck ? p.spi : 0,
      sp: p.sp > 0 && slot == EquipmentSlot.neck ? 1 : 0,
      crit: role == HeroRole.rogue && slot == EquipmentSlot.ring ? 1 : 0,
    );

    final weapon = switch (role) {
      HeroRole.warrior => piece(
        id: 'start_war_wpn',
        name: '$prefix 1H Mace',
        slot: EquipmentSlot.weapon,
        weaponType: WeaponType.mace,
        handed: WeaponHanded.oneHand,
        str: 3,
        sta: 2,
        aspd: 1,
      ),
      HeroRole.healer => piece(
        id: 'start_pri_wpn',
        name: '$prefix 1H Mace',
        slot: EquipmentSlot.weapon,
        weaponType: WeaponType.mace,
        handed: WeaponHanded.oneHand,
        intel: 2,
        spi: 1,
        sp: 1,
        mp5: 1,
      ),
      HeroRole.mage => piece(
        id: 'start_mag_wpn',
        name: '$prefix 1H Sword',
        slot: EquipmentSlot.weapon,
        weaponType: WeaponType.sword,
        handed: WeaponHanded.oneHand,
        intel: 2,
        spi: 1,
        sp: 1,
      ),
      HeroRole.rogue => piece(
        id: 'start_rog_wpn',
        name: '$prefix Dagger',
        slot: EquipmentSlot.weapon,
        weaponType: WeaponType.dagger,
        handed: WeaponHanded.oneHand,
        agi: 3,
        str: 1,
        crit: 1,
        aspd: 1,
      ),
    };

    final offHand = switch (role) {
      HeroRole.warrior => piece(
        id: 'start_war_oh',
        name: '$prefix Tower Shield',
        slot: EquipmentSlot.offHand,
        offHandKind: OffHandKind.shield,
        str: 1,
        sta: 2,
        armor: 3,
      ),
      HeroRole.healer || HeroRole.mage => piece(
        id: 'start_${role.name}_oh',
        name: '$prefix Tome',
        slot: EquipmentSlot.offHand,
        offHandKind: OffHandKind.frill,
        intel: 1,
        spi: 1,
        sp: 2,
        mp5: 1,
      ),
      HeroRole.rogue => piece(
        id: 'start_rog_oh',
        name: '$prefix Off-hand Dagger',
        slot: EquipmentSlot.offHand,
        offHandKind: OffHandKind.weapon,
        weaponType: WeaponType.dagger,
        handed: WeaponHanded.oneHand,
        agi: 2,
        crit: 1,
        aspd: 1,
      ),
    };

    final ranged = switch (role) {
      HeroRole.healer || HeroRole.mage => piece(
        id: 'start_${role.name}_rng',
        name: '$prefix Wand',
        slot: EquipmentSlot.ranged,
        weaponType: WeaponType.wand,
        handed: WeaponHanded.oneHand,
        intel: 1,
        sp: 2,
      ),
      HeroRole.warrior => piece(
        id: 'start_war_rng',
        name: '$prefix Thrown',
        slot: EquipmentSlot.ranged,
        weaponType: WeaponType.thrown,
        handed: WeaponHanded.oneHand,
        str: 1,
        agi: 1,
      ),
      HeroRole.rogue => piece(
        id: 'start_rog_rng',
        name: '$prefix Bow',
        slot: EquipmentSlot.ranged,
        weaponType: WeaponType.bow,
        handed: WeaponHanded.twoHand,
        agi: 2,
      ),
    };

    final flask = piece(
      id: 'start_${role.name}_flask',
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      sta: 1,
    );

    return {
      EquipmentSlot.weapon: weapon,
      EquipmentSlot.offHand: offHand,
      EquipmentSlot.ranged: ranged,
      EquipmentSlot.head: armorPiece(EquipmentSlot.head, 'Helm', armorPts: 2),
      EquipmentSlot.shoulder: armorPiece(
        EquipmentSlot.shoulder,
        'Pauldrons',
        armorPts: 1,
      ),
      EquipmentSlot.chest: armorPiece(
        EquipmentSlot.chest,
        'Chestguard',
        armorPts: 3,
      ),
      EquipmentSlot.waist: armorPiece(EquipmentSlot.waist, 'Belt'),
      EquipmentSlot.legs: armorPiece(
        EquipmentSlot.legs,
        'Legguards',
        armorPts: 2,
      ),
      EquipmentSlot.boots: armorPiece(EquipmentSlot.boots, 'Boots'),
      EquipmentSlot.wrist: armorPiece(EquipmentSlot.wrist, 'Bracers'),
      EquipmentSlot.hands: armorPiece(EquipmentSlot.hands, 'Gloves'),
      EquipmentSlot.cloak: jewelry(EquipmentSlot.cloak, 'Cloak'),
      EquipmentSlot.neck: jewelry(EquipmentSlot.neck, 'Amulet'),
      EquipmentSlot.ring: jewelry(EquipmentSlot.ring, 'Ring'),
      EquipmentSlot.ring2: jewelry(EquipmentSlot.ring2, 'Band'),
      EquipmentSlot.trinket: jewelry(EquipmentSlot.trinket, 'Trinket'),
      EquipmentSlot.trinket2: jewelry(EquipmentSlot.trinket2, 'Charm'),
      EquipmentSlot.consumable: flask,
    };
  }
}
