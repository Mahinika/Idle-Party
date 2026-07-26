import 'hero.dart';

/// Combat abilities unlocked by hero level (all roles).
enum AbilityId {
  // Warrior — Protection
  defensiveStance,
  shieldBlock,
  thunderClap,
  sunderArmor,
  taunt,
  demoralizingShout,
  shieldSlam,
  revenge,
  lastStand,
  shieldWall,

  // Healer — Discipline Priest
  atonement,
  powerWordShield,
  shadowWordPain,
  penance,
  powerWordFortitude,
  flashHeal,
  painSuppression,
  rapture,

  // Mage — Arcane / Fire hybrid
  arcaneIntellect,
  fireball,
  frostNova,
  arcaneExplosion,
  blink,
  combustion,
  iceBlock,
  pyroblast,

  // Rogue — Assassination / Combat hybrid
  sinisterStrike,
  sliceAndDice,
  eviscerate,
  kidneyShot,
  bladeFlurry,
  sprint,
  vanish,
  adrenalineRush,
}

class ClassAbilityDef {
  const ClassAbilityDef({
    required this.id,
    required this.role,
    required this.name,
    required this.shortLabel,
    required this.description,
    required this.unlockLevel,
    required this.cooldown,
    this.resourceCost = 0,
    this.requiresShield = false,
    this.showInHud = true,
  });

  final AbilityId id;
  final HeroRole role;
  final String name;
  final String shortLabel;
  final String description;
  final int unlockLevel;
  final double cooldown;
  final int resourceCost;
  final bool requiresShield;
  final bool showInHud;
}

/// Class kits adapted for Idle Party auto-combat.
class ClassKits {
  ClassKits._();

  static const List<ClassAbilityDef> all = <ClassAbilityDef>[
    // —— Warrior (Protection) ——
    ClassAbilityDef(
      id: AbilityId.defensiveStance,
      role: HeroRole.warrior,
      name: 'Defensive Stance',
      shortLabel: 'Stance',
      description: 'Extra guard DEF, stronger aggro, slightly less damage dealt.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
    ),
    ClassAbilityDef(
      id: AbilityId.shieldBlock,
      role: HeroRole.warrior,
      name: 'Shield Block',
      shortLabel: 'Block',
      description: 'Damage reduction window. Enables Revenge. Requires shield.',
      unlockLevel: 3,
      cooldown: 8,
      resourceCost: 15,
      requiresShield: true,
    ),
    ClassAbilityDef(
      id: AbilityId.thunderClap,
      role: HeroRole.warrior,
      name: 'Thunder Clap',
      shortLabel: 'Clap',
      description: 'AoE smash that slows enemy attacks.',
      unlockLevel: 5,
      cooldown: 7,
      resourceCost: 20,
    ),
    ClassAbilityDef(
      id: AbilityId.sunderArmor,
      role: HeroRole.warrior,
      name: 'Sunder Armor',
      shortLabel: 'Sunder',
      description: 'Stack armor shred on the focus target.',
      unlockLevel: 6,
      cooldown: 3.2,
      resourceCost: 12,
    ),
    ClassAbilityDef(
      id: AbilityId.taunt,
      role: HeroRole.warrior,
      name: 'Taunt',
      shortLabel: 'Taunt',
      description: 'Force a loose enemy to attack you.',
      unlockLevel: 7,
      cooldown: 10,
    ),
    ClassAbilityDef(
      id: AbilityId.demoralizingShout,
      role: HeroRole.warrior,
      name: 'Demoralizing Shout',
      shortLabel: 'Demo',
      description: 'Weaken nearby enemies\' attack power.',
      unlockLevel: 8,
      cooldown: 12,
      resourceCost: 18,
    ),
    ClassAbilityDef(
      id: AbilityId.shieldSlam,
      role: HeroRole.warrior,
      name: 'Shield Slam',
      shortLabel: 'Slam',
      description: 'Heavy shield bash. Requires shield.',
      unlockLevel: 9,
      cooldown: 5.5,
      resourceCost: 25,
      requiresShield: true,
    ),
    ClassAbilityDef(
      id: AbilityId.revenge,
      role: HeroRole.warrior,
      name: 'Revenge',
      shortLabel: 'Revenge',
      description: 'After blocking, next attack hits much harder.',
      unlockLevel: 11,
      cooldown: 0,
      resourceCost: 5,
      showInHud: false,
    ),
    ClassAbilityDef(
      id: AbilityId.lastStand,
      role: HeroRole.warrior,
      name: 'Last Stand',
      shortLabel: 'Stand',
      description: 'Emergency temporary bonus health.',
      unlockLevel: 13,
      cooldown: 45,
    ),
    ClassAbilityDef(
      id: AbilityId.shieldWall,
      role: HeroRole.warrior,
      name: 'Shield Wall',
      shortLabel: 'Wall',
      description: 'Massive damage reduction. Requires shield.',
      unlockLevel: 15,
      cooldown: 60,
      requiresShield: true,
    ),

    // —— Disc Priest ——
    ClassAbilityDef(
      id: AbilityId.atonement,
      role: HeroRole.healer,
      name: 'Atonement',
      shortLabel: 'Atone',
      description: 'Damage you deal heals the most injured ally.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
    ),
    ClassAbilityDef(
      id: AbilityId.powerWordShield,
      role: HeroRole.healer,
      name: 'Power Word: Shield',
      shortLabel: 'Shield',
      description: 'Absorb shield on the lowest-health ally.',
      unlockLevel: 3,
      cooldown: 7,
      resourceCost: 20,
    ),
    ClassAbilityDef(
      id: AbilityId.shadowWordPain,
      role: HeroRole.healer,
      name: 'Shadow Word: Pain',
      shortLabel: 'Pain',
      description: 'DoT on the focus enemy — fuels Atonement.',
      unlockLevel: 5,
      cooldown: 4.5,
      resourceCost: 15,
    ),
    ClassAbilityDef(
      id: AbilityId.penance,
      role: HeroRole.healer,
      name: 'Penance',
      shortLabel: 'Penance',
      description: 'Burst holy bolts that hit hard and heal via Atonement.',
      unlockLevel: 7,
      cooldown: 8,
      resourceCost: 28,
    ),
    ClassAbilityDef(
      id: AbilityId.powerWordFortitude,
      role: HeroRole.healer,
      name: 'Power Word: Fortitude',
      shortLabel: 'Fort',
      description: 'Party vitality buff — more max HP for a while.',
      unlockLevel: 9,
      cooldown: 30,
      resourceCost: 25,
    ),
    ClassAbilityDef(
      id: AbilityId.flashHeal,
      role: HeroRole.healer,
      name: 'Flash Heal',
      shortLabel: 'Flash',
      description: 'Direct heal on the most injured ally.',
      unlockLevel: 11,
      cooldown: 5,
      resourceCost: 22,
    ),
    ClassAbilityDef(
      id: AbilityId.painSuppression,
      role: HeroRole.healer,
      name: 'Pain Suppression',
      shortLabel: 'PS',
      description: 'Emergency damage reduction on a critically low ally.',
      unlockLevel: 13,
      cooldown: 40,
      resourceCost: 10,
    ),
    ClassAbilityDef(
      id: AbilityId.rapture,
      role: HeroRole.healer,
      name: 'Rapture',
      shortLabel: 'Rapture',
      description: 'Big free shield wave across the party.',
      unlockLevel: 15,
      cooldown: 55,
    ),

    // —— Mage ——
    ClassAbilityDef(
      id: AbilityId.arcaneIntellect,
      role: HeroRole.mage,
      name: 'Arcane Intellect',
      shortLabel: 'Intellect',
      description: 'Always on: party attack aura.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
    ),
    ClassAbilityDef(
      id: AbilityId.fireball,
      role: HeroRole.mage,
      name: 'Fireball',
      shortLabel: 'Fireball',
      description: 'Empowered next bolt — heavy single-target damage.',
      unlockLevel: 3,
      cooldown: 5,
      resourceCost: 18,
    ),
    ClassAbilityDef(
      id: AbilityId.frostNova,
      role: HeroRole.mage,
      name: 'Frost Nova',
      shortLabel: 'Nova',
      description: 'Freeze nearby enemies in place briefly.',
      unlockLevel: 5,
      cooldown: 10,
      resourceCost: 20,
    ),
    ClassAbilityDef(
      id: AbilityId.arcaneExplosion,
      role: HeroRole.mage,
      name: 'Arcane Explosion',
      shortLabel: 'AoE',
      description: 'Arcane burst around you when surrounded.',
      unlockLevel: 7,
      cooldown: 6,
      resourceCost: 25,
    ),
    ClassAbilityDef(
      id: AbilityId.blink,
      role: HeroRole.mage,
      name: 'Blink',
      shortLabel: 'Blink',
      description: 'Teleport toward preferred casting range.',
      unlockLevel: 9,
      cooldown: 12,
      resourceCost: 10,
    ),
    ClassAbilityDef(
      id: AbilityId.combustion,
      role: HeroRole.mage,
      name: 'Combustion',
      shortLabel: 'Combust',
      description: 'Short window of massive spell damage.',
      unlockLevel: 11,
      cooldown: 35,
      resourceCost: 30,
    ),
    ClassAbilityDef(
      id: AbilityId.pyroblast,
      role: HeroRole.mage,
      name: 'Pyroblast',
      shortLabel: 'Pyro',
      description: 'Huge fire nuke on cooldown.',
      unlockLevel: 13,
      cooldown: 14,
      resourceCost: 35,
    ),
    ClassAbilityDef(
      id: AbilityId.iceBlock,
      role: HeroRole.mage,
      name: 'Ice Block',
      shortLabel: 'Ice Block',
      description: 'Emergency immunity bubble when near death.',
      unlockLevel: 15,
      cooldown: 50,
    ),

    // —— Rogue ——
    ClassAbilityDef(
      id: AbilityId.sinisterStrike,
      role: HeroRole.rogue,
      name: 'Sinister Strike',
      shortLabel: 'Strike',
      description: 'Build combo points on every swing.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
    ),
    ClassAbilityDef(
      id: AbilityId.sliceAndDice,
      role: HeroRole.rogue,
      name: 'Slice and Dice',
      shortLabel: 'SnD',
      description: 'Spend combo for attack-speed buff.',
      unlockLevel: 3,
      cooldown: 1,
      resourceCost: 20,
    ),
    ClassAbilityDef(
      id: AbilityId.eviscerate,
      role: HeroRole.rogue,
      name: 'Eviscerate',
      shortLabel: 'Evis',
      description: 'Finisher — damage scales with combo points.',
      unlockLevel: 5,
      cooldown: 1.2,
      resourceCost: 25,
    ),
    ClassAbilityDef(
      id: AbilityId.kidneyShot,
      role: HeroRole.rogue,
      name: 'Kidney Shot',
      shortLabel: 'Kidney',
      description: 'Stun the focus target briefly.',
      unlockLevel: 7,
      cooldown: 14,
      resourceCost: 25,
    ),
    ClassAbilityDef(
      id: AbilityId.bladeFlurry,
      role: HeroRole.rogue,
      name: 'Blade Flurry',
      shortLabel: 'Flurry',
      description: 'Cleave nearby enemies for a short window.',
      unlockLevel: 9,
      cooldown: 18,
      resourceCost: 20,
    ),
    ClassAbilityDef(
      id: AbilityId.sprint,
      role: HeroRole.rogue,
      name: 'Sprint',
      shortLabel: 'Sprint',
      description: 'Burst of move speed to close or kite.',
      unlockLevel: 11,
      cooldown: 20,
    ),
    ClassAbilityDef(
      id: AbilityId.vanish,
      role: HeroRole.rogue,
      name: 'Vanish',
      shortLabel: 'Vanish',
      description: 'Drop aggro and reset when low.',
      unlockLevel: 13,
      cooldown: 40,
    ),
    ClassAbilityDef(
      id: AbilityId.adrenalineRush,
      role: HeroRole.rogue,
      name: 'Adrenaline Rush',
      shortLabel: 'AR',
      description: 'Energy surge and faster attacks.',
      unlockLevel: 15,
      cooldown: 55,
    ),
  ];

  static ClassAbilityDef? defFor(AbilityId id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<ClassAbilityDef> forRole(HeroRole role) =>
      all.where((d) => d.role == role).toList(growable: false);

  static bool isUnlocked(AbilityId id, int level) {
    final d = defFor(id);
    return d != null && level >= d.unlockLevel;
  }

  static List<ClassAbilityDef> unlockedAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => d.showInHud && level >= d.unlockLevel)
          .toList(growable: false);

  static ClassAbilityDef? nextUnlock(HeroRole role, int level) {
    for (final d in forRole(role)) {
      if (level < d.unlockLevel) return d;
    }
    return null;
  }

  static String kitSummary(HeroRole role, int level) {
    final unlocked = unlockedAt(role, level);
    if (unlocked.isEmpty) return role.name;
    final next = nextUnlock(role, level);
    final names = unlocked.map((d) => d.shortLabel).join(' · ');
    if (next == null) return names;
    return '$names  |  next L${next.unlockLevel}: ${next.shortLabel}';
  }

  static String resourceLabel(HeroRole role) => switch (role) {
        HeroRole.warrior => 'RAGE',
        HeroRole.healer => 'MANA',
        HeroRole.mage => 'MANA',
        HeroRole.rogue => 'ENERGY',
      };

  static int resourceColor(HeroRole role) => switch (role) {
        HeroRole.warrior => 0xFFC04030,
        HeroRole.healer => 0xFF5090E0,
        HeroRole.mage => 0xFF7060D0,
        HeroRole.rogue => 0xFFE0C040,
      };
}

/// Back-compat facade for warrior combat paths.
class WarriorAbilities {
  static ClassAbilityDef? defFor(AbilityId id) => ClassKits.defFor(id);
  static bool isUnlocked(AbilityId id, int level) =>
      ClassKits.isUnlocked(id, level);
  static List<ClassAbilityDef> unlockedAt(int level) =>
      ClassKits.unlockedAt(HeroRole.warrior, level);
  static List<ClassAbilityDef> hudAbilitiesAt(int level) =>
      ClassKits.hudAbilitiesAt(HeroRole.warrior, level);
  static ClassAbilityDef? nextUnlock(int level) =>
      ClassKits.nextUnlock(HeroRole.warrior, level);
  static String kitSummary(int level) =>
      ClassKits.kitSummary(HeroRole.warrior, level);
  static List<ClassAbilityDef> get all =>
      ClassKits.forRole(HeroRole.warrior);
  static List<ClassAbilityDef> forHero(PartyHero hero) =>
      hero.role == HeroRole.warrior
          ? ClassKits.unlockedAt(HeroRole.warrior, hero.level)
          : const [];
}
