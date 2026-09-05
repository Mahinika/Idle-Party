import 'hero.dart';
import 'loot.dart';
import 'stats.dart';

/// Ten WotLK-style class identities (shared sprite / armor family).
enum HeroClassId {
  warrior,
  paladin,
  hunter,
  rogue,
  priest,
  deathKnight,
  shaman,
  mage,
  warlock,
  druid,
}

/// Party role tags — use these for tank/healer/DPS identity (not [HeroRole]).
enum SpecRoleTag { tank, healer, meleeDps, rangedDps, caster }

/// Plain English job words for players who never played an RPG.
extension SpecRoleTagPlain on SpecRoleTag {
  String get plainLabel => switch (this) {
    SpecRoleTag.tank => 'Shield',
    SpecRoleTag.healer => 'Healer',
    SpecRoleTag.meleeDps => 'Damage',
    SpecRoleTag.rangedDps => 'Damage',
    SpecRoleTag.caster => 'Damage',
  };

  String get plainJob => switch (this) {
    SpecRoleTag.tank => 'soaks hits so others can fight',
    SpecRoleTag.healer => 'keeps the party alive',
    SpecRoleTag.meleeDps => 'fights up close',
    SpecRoleTag.rangedDps => 'fights from range',
    SpecRoleTag.caster => 'casts spells',
  };
}

/// Resource type for HUD / regen.
enum SpecResource { rage, mana, energy, runic }

/// All playable WotLK talent-tree kits.
enum HeroSpecId {
  // Warrior
  arms,
  fury,
  protection,
  // Paladin
  holyPaladin,
  protPaladin,
  retribution,
  // Hunter
  beastMastery,
  marksmanship,
  survival,
  // Rogue
  assassination,
  combat,
  subtlety,
  // Priest
  discipline,
  holyPriest,
  shadow,
  // Death Knight
  blood,
  frostDk,
  unholy,
  // Shaman
  elemental,
  enhancement,
  restorationShaman,
  // Mage
  arcane,
  fire,
  frostMage,
  // Warlock
  affliction,
  demonology,
  destruction,
  // Druid
  balance,
  feral,
  guardian,
  restorationDruid,
}

class HeroSpecDef {
  const HeroSpecDef({
    required this.id,
    required this.classId,
    required this.name,
    required this.shortLabel,
    required this.roleTag,
    required this.resource,
    required this.gearAffinity,
    required this.armorTypes,
    required this.ranged,
    required this.preferredRange,
    required this.attackRange,
    required this.startingStats,
    required this.defaultName,
    this.unlockHint = '',
  });

  final HeroSpecId id;
  final HeroClassId classId;
  final String name;
  final String shortLabel;
  final SpecRoleTag roleTag;
  final SpecResource resource;

  /// Gear/ratings affinity bucket — not tank/healer/DPS. Prefer [roleTag].
  final HeroRole gearAffinity;
  final Set<ArmorType> armorTypes;
  final bool ranged;
  final double preferredRange;
  final double attackRange;
  final Stats startingStats;
  final String defaultName;
  final String unlockHint;

  bool get isTank => roleTag == SpecRoleTag.tank;
  bool get isHealer => roleTag == SpecRoleTag.healer;

  /// New-game / roster line: "Shield — soaks hits so others can fight".
  String get plainRoleLine => '${roleTag.plainLabel} — ${roleTag.plainJob}';
}

/// Catalog + helpers for [HeroSpecId].
abstract final class HeroSpecs {
  static const _plate = {ArmorType.plate};
  static const _mail = {ArmorType.mail};
  static const _hunter = {ArmorType.leather, ArmorType.mail};
  static const _rogue = {ArmorType.leather};
  static const _druid = {ArmorType.cloth, ArmorType.leather};
  static const _cloth = {ArmorType.cloth};

  static const Stats _tankStats = Stats(
    strength: 14,
    agility: 7,
    stamina: 8,
    intellect: 1,
    spirit: 2,
  );
  static const Stats _meleeStats = Stats(
    strength: 12,
    agility: 10,
    stamina: 6,
    intellect: 1,
    spirit: 2,
  );
  static const Stats _agiMelee = Stats(
    strength: 8,
    agility: 15,
    stamina: 5,
    intellect: 1,
    spirit: 2,
  );
  static const Stats _healStats = Stats(
    strength: 2,
    agility: 3,
    stamina: 5,
    intellect: 7,
    spirit: 7,
  );
  static const Stats _casterStats = Stats(
    strength: 1,
    agility: 3,
    stamina: 5,
    intellect: 7,
    spirit: 4,
  );
  static const Stats _hunterStats = Stats(
    strength: 6,
    agility: 14,
    stamina: 6,
    intellect: 3,
    spirit: 3,
  );

  static final Map<HeroSpecId, HeroSpecDef> _byId = {
    for (final d in all) d.id: d,
  };

  static HeroSpecDef def(HeroSpecId id) => _byId[id]!;

  static HeroSpecId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final id in HeroSpecId.values) {
      if (id.name == raw) return id;
    }
    return null;
  }

  /// Maps save-era HeroRole / affinity names onto a default starter spec.
  static HeroSpecId fromGearAffinity(HeroRole affinity) => switch (affinity) {
    HeroRole.warrior => HeroSpecId.protection,
    HeroRole.healer => HeroSpecId.discipline,
    HeroRole.mage => HeroSpecId.fire,
    HeroRole.rogue => HeroSpecId.combat,
  };

  static HeroSpecId fromGearAffinityName(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed;
    return switch (raw) {
      'warrior' => HeroSpecId.protection,
      'healer' => HeroSpecId.discipline,
      'mage' => HeroSpecId.fire,
      'rogue' => HeroSpecId.combat,
      _ => HeroSpecId.combat,
    };
  }

  static List<HeroSpecId> forClass(HeroClassId classId) => [
    for (final d in all)
      if (d.classId == classId) d.id,
  ];

  /// Specs unlocked on a brand-new save.
  static const List<HeroSpecId> starterUnlocked = <HeroSpecId>[
    HeroSpecId.protection,
    HeroSpecId.discipline,
    HeroSpecId.fire,
  ];

  /// Always available after first Ascend (legacy rogue unlock).
  static const HeroSpecId ascendUnlockSpec = HeroSpecId.combat;

  static const List<HeroSpecDef> all = <HeroSpecDef>[
    // —— Warrior ——
    HeroSpecDef(
      id: HeroSpecId.arms,
      classId: HeroClassId.warrior,
      name: 'Arms Warrior',
      shortLabel: 'ARMS',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.rage,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.75,
      startingStats: _meleeStats,
      defaultName: 'Cleaver',
      unlockHint: 'Clear Goblin\'s Hideout or Ascend once',
    ),
    HeroSpecDef(
      id: HeroSpecId.fury,
      classId: HeroClassId.warrior,
      name: 'Fury Warrior',
      shortLabel: 'FURY',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.rage,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.15,
      attackRange: 1.7,
      startingStats: _meleeStats,
      defaultName: 'Rager',
      unlockHint: 'AL 2 or clear Sandy Caverns',
    ),
    HeroSpecDef(
      id: HeroSpecId.protection,
      classId: HeroClassId.warrior,
      name: 'Protection Warrior',
      shortLabel: 'PROT',
      roleTag: SpecRoleTag.tank,
      resource: SpecResource.rage,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.15,
      attackRange: 1.7,
      startingStats: _tankStats,
      defaultName: 'Aegis',
    ),
    // —— Paladin ——
    HeroSpecDef(
      id: HeroSpecId.holyPaladin,
      classId: HeroClassId.paladin,
      name: 'Holy Paladin',
      shortLabel: 'HOLY',
      roleTag: SpecRoleTag.healer,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.healer,
      armorTypes: _plate,
      ranged: true,
      preferredRange: 3.0,
      attackRange: 3.8,
      startingStats: _healStats,
      defaultName: 'Dawn',
      unlockHint: 'AL 1 or 25e in Prestige Shop',
    ),
    HeroSpecDef(
      id: HeroSpecId.protPaladin,
      classId: HeroClassId.paladin,
      name: 'Protection Paladin',
      shortLabel: 'PPal',
      roleTag: SpecRoleTag.tank,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.75,
      startingStats: _tankStats,
      defaultName: 'Bulwark',
      unlockHint: 'AL 3',
    ),
    HeroSpecDef(
      id: HeroSpecId.retribution,
      classId: HeroClassId.paladin,
      name: 'Retribution Paladin',
      shortLabel: 'RET',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.25,
      attackRange: 1.8,
      startingStats: _meleeStats,
      defaultName: 'Judicar',
      unlockHint: 'Clear King\'s Fort',
    ),
    // —— Hunter ——
    HeroSpecDef(
      id: HeroSpecId.beastMastery,
      classId: HeroClassId.hunter,
      name: 'Beast Mastery',
      shortLabel: 'BM',
      roleTag: SpecRoleTag.rangedDps,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.rogue,
      armorTypes: _hunter,
      ranged: true,
      preferredRange: 4.2,
      attackRange: 5.2,
      startingStats: _hunterStats,
      defaultName: 'Tracker',
      unlockHint: 'AL 2',
    ),
    HeroSpecDef(
      id: HeroSpecId.marksmanship,
      classId: HeroClassId.hunter,
      name: 'Marksmanship',
      shortLabel: 'MM',
      roleTag: SpecRoleTag.rangedDps,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.rogue,
      armorTypes: _hunter,
      ranged: true,
      preferredRange: 4.5,
      attackRange: 5.5,
      startingStats: _hunterStats,
      defaultName: 'Sharp',
      unlockHint: 'Clear Underworld',
    ),
    HeroSpecDef(
      id: HeroSpecId.survival,
      classId: HeroClassId.hunter,
      name: 'Survival Hunter',
      shortLabel: 'SV',
      roleTag: SpecRoleTag.rangedDps,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.rogue,
      armorTypes: _hunter,
      ranged: true,
      preferredRange: 3.6,
      attackRange: 4.5,
      startingStats: _hunterStats,
      defaultName: 'Trap',
      unlockHint: 'AL 4',
    ),
    // —— Rogue ——
    HeroSpecDef(
      id: HeroSpecId.assassination,
      classId: HeroClassId.rogue,
      name: 'Assassination',
      shortLabel: 'ASSN',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.energy,
      gearAffinity: HeroRole.rogue,
      armorTypes: _rogue,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.8,
      startingStats: _agiMelee,
      defaultName: 'Venom',
      unlockHint: 'AL 3',
    ),
    HeroSpecDef(
      id: HeroSpecId.combat,
      classId: HeroClassId.rogue,
      name: 'Combat Rogue',
      shortLabel: 'COM',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.energy,
      gearAffinity: HeroRole.rogue,
      armorTypes: _rogue,
      ranged: false,
      preferredRange: 1.25,
      attackRange: 1.85,
      startingStats: _agiMelee,
      defaultName: 'Shade',
      unlockHint: 'Ascend once',
    ),
    HeroSpecDef(
      id: HeroSpecId.subtlety,
      classId: HeroClassId.rogue,
      name: 'Subtlety',
      shortLabel: 'SUB',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.energy,
      gearAffinity: HeroRole.rogue,
      armorTypes: _rogue,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.8,
      startingStats: _agiMelee,
      defaultName: 'Shadeveil',
      unlockHint: 'Clear City of Dead',
    ),
    // —— Priest ——
    HeroSpecDef(
      id: HeroSpecId.discipline,
      classId: HeroClassId.priest,
      name: 'Discipline Priest',
      shortLabel: 'DISC',
      roleTag: SpecRoleTag.healer,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.healer,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 3.2,
      attackRange: 4.0,
      startingStats: _healStats,
      defaultName: 'Vale',
    ),
    HeroSpecDef(
      id: HeroSpecId.holyPriest,
      classId: HeroClassId.priest,
      name: 'Holy Priest',
      shortLabel: 'HolyP',
      roleTag: SpecRoleTag.healer,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.healer,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 3.4,
      attackRange: 4.2,
      startingStats: _healStats,
      defaultName: 'Grace',
      unlockHint: 'AL 2',
    ),
    HeroSpecDef(
      id: HeroSpecId.shadow,
      classId: HeroClassId.priest,
      name: 'Shadow Priest',
      shortLabel: 'Shdw',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Umbral',
      unlockHint: 'Clear Hell\'s Gate',
    ),
    // —— Death Knight ——
    HeroSpecDef(
      id: HeroSpecId.blood,
      classId: HeroClassId.deathKnight,
      name: 'Blood DK',
      shortLabel: 'BLOOD',
      roleTag: SpecRoleTag.tank,
      resource: SpecResource.runic,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.8,
      startingStats: _tankStats,
      defaultName: 'Sanguine',
      unlockHint: 'AL 5',
    ),
    HeroSpecDef(
      id: HeroSpecId.frostDk,
      classId: HeroClassId.deathKnight,
      name: 'Frost DK',
      shortLabel: 'Frost',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.runic,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.8,
      startingStats: _meleeStats,
      defaultName: 'Rime',
      unlockHint: 'AL 5',
    ),
    HeroSpecDef(
      id: HeroSpecId.unholy,
      classId: HeroClassId.deathKnight,
      name: 'Unholy DK',
      shortLabel: 'Unhly',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.runic,
      gearAffinity: HeroRole.warrior,
      armorTypes: _plate,
      ranged: false,
      preferredRange: 1.25,
      attackRange: 1.85,
      startingStats: _meleeStats,
      defaultName: 'Scourge',
      unlockHint: 'Clear Crystal Spire',
    ),
    // —— Shaman ——
    HeroSpecDef(
      id: HeroSpecId.elemental,
      classId: HeroClassId.shaman,
      name: 'Elemental',
      shortLabel: 'ELE',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _mail,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Storm',
      unlockHint: 'AL 4',
    ),
    HeroSpecDef(
      id: HeroSpecId.enhancement,
      classId: HeroClassId.shaman,
      name: 'Enhancement',
      shortLabel: 'ENH',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.rogue,
      armorTypes: _mail,
      ranged: false,
      preferredRange: 1.3,
      attackRange: 1.9,
      startingStats: _agiMelee,
      defaultName: 'Totem',
      unlockHint: 'AL 4',
    ),
    HeroSpecDef(
      id: HeroSpecId.restorationShaman,
      classId: HeroClassId.shaman,
      name: 'Resto Shaman',
      shortLabel: 'Resto',
      roleTag: SpecRoleTag.healer,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.healer,
      armorTypes: _mail,
      ranged: true,
      preferredRange: 3.2,
      attackRange: 4.0,
      startingStats: _healStats,
      defaultName: 'Tide',
      unlockHint: 'AL 3',
    ),
    // —— Mage ——
    HeroSpecDef(
      id: HeroSpecId.arcane,
      classId: HeroClassId.mage,
      name: 'Arcane Mage',
      shortLabel: 'ARC',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Prism',
      unlockHint: 'AL 2',
    ),
    HeroSpecDef(
      id: HeroSpecId.fire,
      classId: HeroClassId.mage,
      name: 'Fire Mage',
      shortLabel: 'FIRE',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Ember',
    ),
    HeroSpecDef(
      id: HeroSpecId.frostMage,
      classId: HeroClassId.mage,
      name: 'Frost Mage',
      shortLabel: 'FRST',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Glace',
      unlockHint: 'AL 3',
    ),
    // —— Warlock ——
    HeroSpecDef(
      id: HeroSpecId.affliction,
      classId: HeroClassId.warlock,
      name: 'Affliction',
      shortLabel: 'AFF',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Hex',
      unlockHint: 'AL 6',
    ),
    HeroSpecDef(
      id: HeroSpecId.demonology,
      classId: HeroClassId.warlock,
      name: 'Demonology',
      shortLabel: 'DEMO',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 3.8,
      attackRange: 4.8,
      startingStats: _casterStats,
      defaultName: 'Fel',
      unlockHint: 'AL 6',
    ),
    HeroSpecDef(
      id: HeroSpecId.destruction,
      classId: HeroClassId.warlock,
      name: 'Destruction',
      shortLabel: 'DESTRO',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _cloth,
      ranged: true,
      preferredRange: 4.2,
      attackRange: 5.2,
      startingStats: _casterStats,
      defaultName: 'Ash',
      unlockHint: 'Clear Hell\'s Gate',
    ),
    // —— Druid ——
    HeroSpecDef(
      id: HeroSpecId.balance,
      classId: HeroClassId.druid,
      name: 'Balance Druid',
      shortLabel: 'BAL',
      roleTag: SpecRoleTag.caster,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.mage,
      armorTypes: _druid,
      ranged: true,
      preferredRange: 4.0,
      attackRange: 5.0,
      startingStats: _casterStats,
      defaultName: 'Moon',
      unlockHint: 'AL 4',
    ),
    HeroSpecDef(
      id: HeroSpecId.feral,
      classId: HeroClassId.druid,
      name: 'Feral Druid',
      shortLabel: 'FERAL',
      roleTag: SpecRoleTag.meleeDps,
      resource: SpecResource.energy,
      gearAffinity: HeroRole.rogue,
      armorTypes: _druid,
      ranged: false,
      preferredRange: 1.2,
      attackRange: 1.8,
      startingStats: _agiMelee,
      defaultName: 'Claw',
      unlockHint: 'AL 4',
    ),
    HeroSpecDef(
      id: HeroSpecId.guardian,
      classId: HeroClassId.druid,
      name: 'Guardian Druid',
      shortLabel: 'GUARD',
      roleTag: SpecRoleTag.tank,
      resource: SpecResource.rage,
      gearAffinity: HeroRole.warrior,
      armorTypes: _druid,
      ranged: false,
      preferredRange: 1.15,
      attackRange: 1.7,
      startingStats: _tankStats,
      defaultName: 'Bark',
      unlockHint: 'AL 5',
    ),
    HeroSpecDef(
      id: HeroSpecId.restorationDruid,
      classId: HeroClassId.druid,
      name: 'Resto Druid',
      shortLabel: 'Tree',
      roleTag: SpecRoleTag.healer,
      resource: SpecResource.mana,
      gearAffinity: HeroRole.healer,
      armorTypes: _druid,
      ranged: true,
      preferredRange: 3.2,
      attackRange: 4.0,
      startingStats: _healStats,
      defaultName: 'Bloom',
      unlockHint: 'AL 3',
    ),
  ];

  static String classLabel(HeroClassId id) => switch (id) {
    HeroClassId.warrior => 'Warrior',
    HeroClassId.paladin => 'Paladin',
    HeroClassId.hunter => 'Hunter',
    HeroClassId.rogue => 'Rogue',
    HeroClassId.priest => 'Priest',
    HeroClassId.deathKnight => 'Death Knight',
    HeroClassId.shaman => 'Shaman',
    HeroClassId.mage => 'Mage',
    HeroClassId.warlock => 'Warlock',
    HeroClassId.druid => 'Druid',
  };
}
