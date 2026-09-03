import 'dart:math';

import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';
import '../visual/equipment_model_catalog.dart';
import '../visual/equipment_visual_resolver.dart';
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
        if (!ClassProficiency.canEquip(
          role: hero.gearAffinity,
          level: hero.level,
          item: entry.value,
          specId: hero.specId,
        )) {
          continue;
        }
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

    final loadout = _weaponLoadout(spec);
    out[EquipmentSlot.weapon] = loadout.weapon;
    if (loadout.offHand != null) {
      out[EquipmentSlot.offHand] = loadout.offHand!;
    } else {
      out.remove(EquipmentSlot.offHand);
    }
    if (loadout.ranged != null) {
      out[EquipmentSlot.ranged] = loadout.ranged!;
    } else {
      out.remove(EquipmentSlot.ranged);
    }

    // Stamp a stable model variant so starters aren't all identical *_t0.
    for (final e in out.entries.toList()) {
      final item = e.value;
      if (item.visualSetId != null && item.visualSetId!.isNotEmpty) continue;
      final base = EquipmentVisualResolver.resolveId(item);
      if (base == 'none') continue;
      final rng = Random(item.id.hashCode ^ e.key.index);
      out[e.key] = item.copyWith(
        visualSetId: EquipmentModelCatalog.pickVariant(
          base,
          rng,
          rarityTier: item.rarity.index,
        ),
      );
    }

    return out;
  }

  static ({
    EquipmentItem weapon,
    EquipmentItem? offHand,
    EquipmentItem? ranged,
  })
  _weaponLoadout(HeroSpecDef spec) {
    final tag = spec.shortLabel.toLowerCase();
    final caster = spec.isHealer || spec.roleTag == SpecRoleTag.caster;
    final agi = spec.gearAffinity == HeroRole.rogue;

    EquipmentItem mh({
      required String noun,
      required WeaponType type,
      required WeaponHanded handed,
    }) {
      return EquipmentItem(
        id: 'start_${tag}_wpn',
        name: '${spec.shortLabel} $noun',
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.common,
        weaponType: type,
        handed: handed,
        strengthBonus: caster
            ? 0
            : (handed == WeaponHanded.twoHand ? 4 : 3),
        agilityBonus: agi && !caster ? 3 : 0,
        staminaBonus: 2,
        intellectBonus: caster ? 2 : 0,
        spiritBonus: spec.isHealer ? 1 : 0,
        spellPowerBonus: caster ? 1 : 0,
        critChanceBonus: agi ? 1 : 0,
        attackSpeedBonus: handed == WeaponHanded.oneHand && !caster ? 1 : 0,
        mp5Bonus: spec.isHealer ? 1 : 0,
        itemLevel: 5,
      );
    }

    EquipmentItem shield() => EquipmentItem(
      id: 'start_${tag}_oh',
      name: '${spec.shortLabel} Shield',
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.common,
      offHandKind: OffHandKind.shield,
      strengthBonus: caster ? 0 : 1,
      staminaBonus: 2,
      intellectBonus: caster ? 1 : 0,
      spiritBonus: spec.isHealer ? 1 : 0,
      spellPowerBonus: caster ? 1 : 0,
      armorBonus: 3,
      itemLevel: 5,
    );

    EquipmentItem sidearm(WeaponType type) => EquipmentItem(
      id: 'start_${tag}_oh',
      name: '${spec.shortLabel} Sidearm',
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.common,
      offHandKind: OffHandKind.weapon,
      weaponType: type,
      handed: WeaponHanded.oneHand,
      strengthBonus: agi ? 0 : 2,
      agilityBonus: agi ? 2 : 0,
      staminaBonus: 1,
      critChanceBonus: 1,
      attackSpeedBonus: 1,
      itemLevel: 5,
    );

    EquipmentItem tome() => EquipmentItem(
      id: 'start_${tag}_oh',
      name: '${spec.shortLabel} Tome',
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.common,
      offHandKind: OffHandKind.frill,
      intellectBonus: 1,
      staminaBonus: 1,
      spiritBonus: spec.isHealer ? 1 : 0,
      spellPowerBonus: 2,
      mp5Bonus: spec.isHealer ? 1 : 0,
      itemLevel: 5,
    );

    EquipmentItem thrown() => EquipmentItem(
      id: 'start_${tag}_rng',
      name: '${spec.shortLabel} Thrown',
      slot: EquipmentSlot.ranged,
      rarity: LootRarity.common,
      weaponType: WeaponType.thrown,
      handed: WeaponHanded.oneHand,
      strengthBonus: agi ? 0 : 1,
      agilityBonus: agi ? 2 : 0,
      staminaBonus: 1,
      itemLevel: 5,
    );

    EquipmentItem bow() => EquipmentItem(
      id: 'start_${tag}_rng',
      name: '${spec.shortLabel} Bow',
      slot: EquipmentSlot.ranged,
      rarity: LootRarity.common,
      weaponType: WeaponType.bow,
      handed: WeaponHanded.twoHand,
      agilityBonus: 2,
      itemLevel: 5,
    );

    EquipmentItem wand() => EquipmentItem(
      id: 'start_${tag}_rng',
      name: '${spec.shortLabel} Wand',
      slot: EquipmentSlot.ranged,
      rarity: LootRarity.common,
      weaponType: WeaponType.wand,
      handed: WeaponHanded.oneHand,
      intellectBonus: 1,
      spellPowerBonus: 2,
      itemLevel: 5,
    );

    final oneMace = mh(
      noun: '1H Mace',
      type: WeaponType.mace,
      handed: WeaponHanded.oneHand,
    );
    final twoSword = mh(
      noun: '2H Sword',
      type: WeaponType.sword,
      handed: WeaponHanded.twoHand,
    );
    final oneAxe = mh(
      noun: '1H Axe',
      type: WeaponType.axe,
      handed: WeaponHanded.oneHand,
    );
    final twoPole = mh(
      noun: 'Polearm',
      type: WeaponType.polearm,
      handed: WeaponHanded.twoHand,
    );
    final staff = mh(
      noun: 'Staff',
      type: WeaponType.staff,
      handed: WeaponHanded.twoHand,
    );
    final dagger = mh(
      noun: 'Dagger',
      type: WeaponType.dagger,
      handed: WeaponHanded.oneHand,
    );
    final twoMace = mh(
      noun: '2H Mace',
      type: WeaponType.mace,
      handed: WeaponHanded.twoHand,
    );

    return switch (spec.id) {
      HeroSpecId.protection => (
        weapon: oneMace,
        offHand: shield(),
        ranged: thrown(),
      ),
      HeroSpecId.arms => (weapon: twoSword, offHand: null, ranged: thrown()),
      HeroSpecId.fury => (
        weapon: oneAxe,
        offHand: sidearm(WeaponType.axe),
        ranged: thrown(),
      ),
      HeroSpecId.holyPaladin || HeroSpecId.protPaladin => (
        weapon: oneMace,
        offHand: shield(),
        ranged: null,
      ),
      HeroSpecId.retribution => (weapon: twoSword, offHand: null, ranged: null),
      HeroSpecId.beastMastery || HeroSpecId.marksmanship => (
        weapon: twoPole,
        offHand: null,
        ranged: bow(),
      ),
      HeroSpecId.survival => (
        weapon: oneAxe,
        offHand: sidearm(WeaponType.axe),
        ranged: bow(),
      ),
      HeroSpecId.assassination ||
      HeroSpecId.combat ||
      HeroSpecId.subtlety => (
        weapon: dagger,
        offHand: sidearm(WeaponType.dagger),
        ranged: thrown(),
      ),
      HeroSpecId.discipline || HeroSpecId.holyPriest => (
        weapon: oneMace,
        offHand: tome(),
        ranged: wand(),
      ),
      HeroSpecId.shadow => (weapon: staff, offHand: null, ranged: wand()),
      HeroSpecId.blood => (weapon: twoMace, offHand: null, ranged: null),
      HeroSpecId.frostDk => (
        weapon: oneAxe,
        offHand: sidearm(WeaponType.axe),
        ranged: null,
      ),
      HeroSpecId.unholy => (weapon: twoSword, offHand: null, ranged: null),
      HeroSpecId.elemental => (
        weapon: oneMace,
        offHand: shield(),
        ranged: null,
      ),
      HeroSpecId.enhancement => (
        weapon: oneAxe,
        offHand: sidearm(WeaponType.axe),
        ranged: null,
      ),
      HeroSpecId.restorationShaman => (
        weapon: oneMace,
        offHand: shield(),
        ranged: null,
      ),
      HeroSpecId.arcane ||
      HeroSpecId.fire ||
      HeroSpecId.frostMage ||
      HeroSpecId.affliction ||
      HeroSpecId.demonology ||
      HeroSpecId.destruction => (
        weapon: staff,
        offHand: null,
        ranged: wand(),
      ),
      HeroSpecId.balance || HeroSpecId.restorationDruid => (
        weapon: staff,
        offHand: null,
        ranged: null,
      ),
      HeroSpecId.feral || HeroSpecId.guardian => (
        weapon: twoPole,
        offHand: null,
        ranged: null,
      ),
    };
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

  static ArmorType? preferredArmorForSpec(HeroSpecDef spec, int level) =>
      ClassProficiency.preferredArmor(spec, level);

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
      HeroRole.warrior => ArmorType.plate,
      HeroRole.rogue => ArmorType.leather,
      HeroRole.healer || HeroRole.mage => ArmorType.cloth,
    };
    final matName = armorMat.name[0].toUpperCase() + armorMat.name.substring(1);

    // Starter budget: modest — primaries mainly on weapon/chest.
    final p = switch (role) {
      HeroRole.warrior => (str: 1, agi: 0, sta: 1, intel: 0, spi: 0, sp: 0),
      HeroRole.rogue => (str: 0, agi: 1, sta: 1, intel: 0, spi: 0, sp: 0),
      HeroRole.healer => (str: 0, agi: 0, sta: 1, intel: 1, spi: 0, sp: 1),
      HeroRole.mage => (str: 0, agi: 0, sta: 1, intel: 1, spi: 0, sp: 1),
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
        name: '$prefix Staff',
        slot: EquipmentSlot.weapon,
        weaponType: WeaponType.staff,
        handed: WeaponHanded.twoHand,
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
        sta: 1,
      ),
      HeroRole.rogue => piece(
        id: 'start_rog_rng',
        name: '$prefix Thrown',
        slot: EquipmentSlot.ranged,
        weaponType: WeaponType.thrown,
        handed: WeaponHanded.oneHand,
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
