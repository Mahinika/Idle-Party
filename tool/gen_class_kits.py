#!/usr/bin/env python3
"""Generate lib/models/class_ability.dart with full Phase 1-3 combat kits."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "lib" / "models" / "class_ability.dart"

# effect: passive|damage|aoe|heal|absorb|selfBuff|root|grantResource|emergencyDefend|emergencyHeal
# tier: passive|emergency|signature|filler
# tuple: (id, name, short, desc, level, cd, cost, effect, tier, coeff, show_hud, requires_shield)

LEGACY = r'''
    // —— Warrior (Protection) ——
    ClassAbilityDef(
      id: AbilityId.defensiveStance,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Defensive Stance',
      shortLabel: 'Stance',
      description: 'Extra guard DEF, stronger aggro, slightly less damage dealt.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
      effect: AbilityEffectKind.passive,
      tier: AbilityCastTier.passive,
    ),
    ClassAbilityDef(
      id: AbilityId.shieldBlock,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Shield Block',
      shortLabel: 'Block',
      description: 'Damage reduction window. Enables Revenge. Requires shield.',
      unlockLevel: 3,
      cooldown: 8,
      resourceCost: 15,
      requiresShield: true,
      effect: AbilityEffectKind.emergencyDefend,
      tier: AbilityCastTier.emergency,
      coeff: 0.35,
    ),
    ClassAbilityDef(
      id: AbilityId.thunderClap,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Thunder Clap',
      shortLabel: 'Clap',
      description: 'AoE smash that slows enemy attacks.',
      unlockLevel: 5,
      cooldown: 7,
      resourceCost: 20,
      effect: AbilityEffectKind.aoe,
      tier: AbilityCastTier.filler,
      coeff: 0.55,
    ),
    ClassAbilityDef(
      id: AbilityId.devastate,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Devastate',
      shortLabel: 'Dev',
      description: 'Strike that applies Sunder Armor stacks.',
      unlockLevel: 6,
      cooldown: 2.8,
      resourceCost: 15,
      requiresShield: true,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.filler,
      coeff: 0.55,
    ),
    ClassAbilityDef(
      id: AbilityId.taunt,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Taunt',
      shortLabel: 'Taunt',
      description: 'Force a loose enemy to attack you.',
      unlockLevel: 7,
      cooldown: 10,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.demoralizingShout,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Demoralizing Shout',
      shortLabel: 'Demo',
      description: 'Weaken nearby enemies\' attack power.',
      unlockLevel: 8,
      cooldown: 12,
      resourceCost: 18,
      effect: AbilityEffectKind.aoe,
      tier: AbilityCastTier.filler,
      coeff: 0.2,
    ),
    ClassAbilityDef(
      id: AbilityId.shieldSlam,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Shield Slam',
      shortLabel: 'Slam',
      description: 'Heavy shield bash. Requires shield.',
      unlockLevel: 9,
      cooldown: 5.5,
      resourceCost: 25,
      requiresShield: true,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.filler,
      coeff: 1.1,
    ),
    ClassAbilityDef(
      id: AbilityId.revenge,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Revenge',
      shortLabel: 'Revenge',
      description: 'After blocking, next attack hits much harder.',
      unlockLevel: 11,
      cooldown: 0,
      resourceCost: 5,
      showInHud: false,
      effect: AbilityEffectKind.passive,
      tier: AbilityCastTier.passive,
    ),
    ClassAbilityDef(
      id: AbilityId.shockwave,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Shockwave',
      shortLabel: 'Shock',
      description: 'Cone smash — AoE damage and stun.',
      unlockLevel: 13,
      cooldown: 16,
      resourceCost: 22,
      effect: AbilityEffectKind.aoe,
      tier: AbilityCastTier.signature,
      coeff: 0.9,
    ),
    ClassAbilityDef(
      id: AbilityId.lastStand,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Last Stand',
      shortLabel: 'Stand',
      description: 'Emergency temporary bonus health.',
      unlockLevel: 14,
      cooldown: 45,
      effect: AbilityEffectKind.emergencyDefend,
      tier: AbilityCastTier.emergency,
    ),
    ClassAbilityDef(
      id: AbilityId.shieldWall,
      role: HeroRole.warrior,
      specId: HeroSpecId.protection,
      name: 'Shield Wall',
      shortLabel: 'Wall',
      description: 'Massive damage reduction. Requires shield.',
      unlockLevel: 15,
      cooldown: 60,
      requiresShield: true,
      effect: AbilityEffectKind.emergencyDefend,
      tier: AbilityCastTier.emergency,
    ),

    // —— Disc Priest ——
    ClassAbilityDef(
      id: AbilityId.innerFire,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Inner Fire',
      shortLabel: 'Inner',
      description: 'Always on: tougher shields and stronger heals.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
      effect: AbilityEffectKind.passive,
      tier: AbilityCastTier.passive,
    ),
    ClassAbilityDef(
      id: AbilityId.powerWordShield,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Power Word: Shield',
      shortLabel: 'Shield',
      description: 'Absorb shield on the lowest-health ally.',
      unlockLevel: 3,
      cooldown: 7,
      resourceCost: 20,
      effect: AbilityEffectKind.absorb,
      tier: AbilityCastTier.filler,
      coeff: 1.2,
    ),
    ClassAbilityDef(
      id: AbilityId.prayerOfMending,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Prayer of Mending',
      shortLabel: 'PoM',
      description: 'Bounce heal that triggers when an ally is hit.',
      unlockLevel: 5,
      cooldown: 9,
      resourceCost: 18,
      effect: AbilityEffectKind.heal,
      tier: AbilityCastTier.filler,
      coeff: 0.8,
    ),
    ClassAbilityDef(
      id: AbilityId.penance,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Penance',
      shortLabel: 'Penance',
      description: 'Channel holy bolts — damages foes or tops allies.',
      unlockLevel: 7,
      cooldown: 8,
      resourceCost: 28,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.signature,
      coeff: 0.7,
    ),
    ClassAbilityDef(
      id: AbilityId.powerWordFortitude,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Power Word: Fortitude',
      shortLabel: 'Fort',
      description: 'Party vitality buff — more max HP for a while.',
      unlockLevel: 9,
      cooldown: 30,
      resourceCost: 25,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.flashHeal,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Flash Heal',
      shortLabel: 'Flash',
      description: 'Direct heal on the most injured ally.',
      unlockLevel: 11,
      cooldown: 5,
      resourceCost: 22,
      effect: AbilityEffectKind.heal,
      tier: AbilityCastTier.filler,
      coeff: 1.4,
    ),
    ClassAbilityDef(
      id: AbilityId.painSuppression,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Pain Suppression',
      shortLabel: 'PS',
      description: 'Emergency damage reduction on a critically low ally.',
      unlockLevel: 13,
      cooldown: 40,
      resourceCost: 10,
      effect: AbilityEffectKind.emergencyDefend,
      tier: AbilityCastTier.emergency,
    ),
    ClassAbilityDef(
      id: AbilityId.powerInfusion,
      role: HeroRole.healer,
      specId: HeroSpecId.discipline,
      name: 'Power Infusion',
      shortLabel: 'PI',
      description: 'Haste buff on your strongest damage dealer.',
      unlockLevel: 15,
      cooldown: 55,
      resourceCost: 15,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.signature,
    ),

    // —— Mage (Fire) ——
    ClassAbilityDef(
      id: AbilityId.arcaneIntellect,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Arcane Intellect',
      shortLabel: 'Intellect',
      description: 'Always on: party attack aura.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
      effect: AbilityEffectKind.passive,
      tier: AbilityCastTier.passive,
    ),
    ClassAbilityDef(
      id: AbilityId.fireball,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Fireball',
      shortLabel: 'Fireball',
      description: 'Empowered next bolt — heavy single-target damage.',
      unlockLevel: 3,
      cooldown: 5,
      resourceCost: 18,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.filler,
      coeff: 1.35,
    ),
    ClassAbilityDef(
      id: AbilityId.livingBomb,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Living Bomb',
      shortLabel: 'Bomb',
      description: 'DoT that explodes for splash damage.',
      unlockLevel: 5,
      cooldown: 8,
      resourceCost: 22,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.filler,
      coeff: 0.9,
    ),
    ClassAbilityDef(
      id: AbilityId.frostNova,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Frost Nova',
      shortLabel: 'Nova',
      description: 'Freeze nearby enemies in place briefly.',
      unlockLevel: 7,
      cooldown: 10,
      resourceCost: 20,
      effect: AbilityEffectKind.root,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.blastWave,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Blast Wave',
      shortLabel: 'Blast',
      description: 'Fire AoE knock — burns packs around you.',
      unlockLevel: 9,
      cooldown: 8,
      resourceCost: 25,
      effect: AbilityEffectKind.aoe,
      tier: AbilityCastTier.filler,
      coeff: 0.75,
    ),
    ClassAbilityDef(
      id: AbilityId.blink,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Blink',
      shortLabel: 'Blink',
      description: 'Teleport toward preferred casting range.',
      unlockLevel: 10,
      cooldown: 12,
      resourceCost: 10,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.combustion,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Combustion',
      shortLabel: 'Combust',
      description: 'Short window of massive spell damage.',
      unlockLevel: 11,
      cooldown: 35,
      resourceCost: 30,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.signature,
    ),
    ClassAbilityDef(
      id: AbilityId.pyroblast,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Pyroblast',
      shortLabel: 'Pyro',
      description: 'Huge fire nuke (Hot Streak style).',
      unlockLevel: 13,
      cooldown: 14,
      resourceCost: 35,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.signature,
      coeff: 2.0,
    ),
    ClassAbilityDef(
      id: AbilityId.iceBlock,
      role: HeroRole.mage,
      specId: HeroSpecId.fire,
      name: 'Ice Block',
      shortLabel: 'Ice Block',
      description: 'Emergency immunity bubble when near death.',
      unlockLevel: 15,
      cooldown: 50,
      effect: AbilityEffectKind.emergencyDefend,
      tier: AbilityCastTier.emergency,
    ),

    // —— Rogue (Combat) ——
    ClassAbilityDef(
      id: AbilityId.sinisterStrike,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Sinister Strike',
      shortLabel: 'Strike',
      description: 'Build combo points on every swing.',
      unlockLevel: 1,
      cooldown: 0,
      showInHud: false,
      effect: AbilityEffectKind.passive,
      tier: AbilityCastTier.passive,
    ),
    ClassAbilityDef(
      id: AbilityId.sliceAndDice,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Slice and Dice',
      shortLabel: 'SnD',
      description: 'Spend combo for attack-speed buff.',
      unlockLevel: 3,
      cooldown: 1,
      resourceCost: 20,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.eviscerate,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Eviscerate',
      shortLabel: 'Evis',
      description: 'Finisher — damage scales with combo points.',
      unlockLevel: 5,
      cooldown: 1.2,
      resourceCost: 25,
      effect: AbilityEffectKind.damage,
      tier: AbilityCastTier.filler,
      coeff: 1.2,
    ),
    ClassAbilityDef(
      id: AbilityId.kidneyShot,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Kidney Shot',
      shortLabel: 'Kidney',
      description: 'Stun the focus target briefly.',
      unlockLevel: 7,
      cooldown: 14,
      resourceCost: 25,
      effect: AbilityEffectKind.root,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.bladeFlurry,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Blade Flurry',
      shortLabel: 'Flurry',
      description: 'Cleave nearby enemies for a short window.',
      unlockLevel: 9,
      cooldown: 18,
      resourceCost: 20,
      effect: AbilityEffectKind.aoe,
      tier: AbilityCastTier.filler,
      coeff: 0.6,
    ),
    ClassAbilityDef(
      id: AbilityId.sprint,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Sprint',
      shortLabel: 'Sprint',
      description: 'Burst of move speed to close or kite.',
      unlockLevel: 11,
      cooldown: 20,
      effect: AbilityEffectKind.selfBuff,
      tier: AbilityCastTier.filler,
    ),
    ClassAbilityDef(
      id: AbilityId.vanish,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Vanish',
      shortLabel: 'Vanish',
      description: 'Drop aggro and reset when low.',
      unlockLevel: 13,
      cooldown: 40,
      effect: AbilityEffectKind.emergencyDefend,
      tier: AbilityCastTier.emergency,
    ),
    ClassAbilityDef(
      id: AbilityId.killingSpree,
      role: HeroRole.rogue,
      specId: HeroSpecId.combat,
      name: 'Killing Spree',
      shortLabel: 'Spree',
      description: 'Dash between foes with a flurry of strikes.',
      unlockLevel: 15,
      cooldown: 55,
      resourceCost: 0,
      effect: AbilityEffectKind.aoe,
      tier: AbilityCastTier.signature,
      coeff: 1.1,
    ),
'''

# Spec kits: (specId, legacyRole, abilities list)
# Each ability: (id, name, short, desc, level, cd, cost, effect, tier, coeff, show)
# Levels pattern: 1,3,5,7,9,11,13,15

def kit(abilities):
    return abilities

SPECS = []

def add_spec(spec_id, role, abilities):
    SPECS.append((spec_id, role, abilities))

# Arms
add_spec("arms", "warrior", [
    ("armsStance", "Battle Stance", "Stance", "Always on: stronger attacks, less guard.", 1, 0, 0, "passive", "passive", 0, False),
    ("mortalStrike", "Mortal Strike", "Mortal", "Heavy single-target strike.", 3, 5.5, 20, "damage", "filler", 1.45, True),
    ("overpower", "Overpower", "Over", "Quick follow-up slash.", 5, 4.0, 10, "damage", "filler", 0.95, True),
    ("rend", "Rend", "Rend", "Bleed the nearest foe.", 7, 7.0, 15, "damage", "filler", 0.7, True),
    ("sweepingStrikes", "Sweeping Strikes", "Sweep", "Cleave nearby enemies briefly.", 9, 18.0, 20, "aoe", "filler", 0.65, True),
    ("bladestorm", "Bladestorm", "Storm", "Spinning AoE carnage.", 11, 35.0, 25, "aoe", "signature", 1.0, True),
    ("armsExecute", "Execute", "Exec", "Finisher on wounded foes.", 13, 8.0, 15, "damage", "signature", 1.8, True),
    ("armsRally", "Rallying Cry", "Rally", "Emergency party absorb.", 15, 45.0, 0, "emergencyDefend", "emergency", 1.0, True),
])

# Fury
add_spec("fury", "warrior", [
    ("berserkerStance", "Berserker Stance", "Stance", "Always on: haste at a cost.", 1, 0, 0, "passive", "passive", 0, False),
    ("bloodthirst", "Bloodthirst", "Thirst", "Strike that returns rage.", 3, 4.5, 20, "damage", "filler", 1.2, True),
    ("whirlwind", "Whirlwind", "Whirl", "Spin attack around you.", 5, 7.0, 22, "aoe", "filler", 0.7, True),
    ("ragingBlow", "Raging Blow", "Rage", "Empowered twin strike.", 7, 5.0, 15, "damage", "filler", 1.35, True),
    ("enrageBuff", "Enrage", "Enrage", "Self haste window.", 9, 20.0, 0, "selfBuff", "filler", 0, True),
    ("deathWish", "Death Wish", "Wish", "Signature damage buff.", 11, 40.0, 10, "selfBuff", "signature", 0, True),
    ("furyExecute", "Rampage", "Ramp", "Burst finisher flurry.", 13, 12.0, 25, "damage", "signature", 1.7, True),
    ("furyRecklessness", "Recklessness", "Reck", "Emergency offense when low.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Holy Paladin
add_spec("holyPaladin", "healer", [
    ("holyLightAura", "Devotion", "Aura", "Always on: stronger heals.", 1, 0, 0, "passive", "passive", 0, False),
    ("holyShock", "Holy Shock", "Shock", "Instant heal or damage.", 3, 6.0, 18, "heal", "filler", 1.3, True),
    ("flashOfLight", "Flash of Light", "Flash", "Fast heal on lowest ally.", 5, 4.5, 16, "heal", "filler", 1.1, True),
    ("sacredShield", "Sacred Shield", "SShield", "Absorb on lowest ally.", 7, 8.0, 20, "absorb", "filler", 1.15, True),
    ("holyLight", "Holy Light", "Light", "Big heal on injured ally.", 9, 7.0, 28, "heal", "filler", 1.7, True),
    ("beaconOfLight", "Beacon", "Beacon", "Haste buff while healing.", 11, 30.0, 15, "selfBuff", "filler", 0, True),
    ("divineFavor", "Divine Favor", "Favor", "Signature heal amplify.", 13, 40.0, 10, "selfBuff", "signature", 0, True),
    ("layOnHands", "Lay on Hands", "LoH", "Emergency full-party top.", 15, 60.0, 0, "emergencyHeal", "emergency", 2.5, True),
])

# Prot Paladin
add_spec("protPaladin", "warrior", [
    ("righteousFury", "Righteous Fury", "Fury", "Always on: stronger aggro.", 1, 0, 0, "passive", "passive", 0, False),
    ("avengersShield", "Avenger's Shield", "AShield", "Ranged bash on nearest foe.", 3, 8.0, 18, "damage", "filler", 1.1, True),
    ("holyShield", "Holy Shield", "HShield", "Self damage reduction.", 5, 10.0, 15, "emergencyDefend", "emergency", 0, True),
    ("hammerOfTheRighteous", "Hammer of the Righteous", "HotR", "AoE holy smash.", 7, 6.0, 12, "aoe", "filler", 0.7, True),
    ("consecration", "Consecration", "Cons", "Ground AoE burn.", 9, 9.0, 20, "aoe", "filler", 0.55, True),
    ("shieldOfRighteousness", "Shield of Righteousness", "SoR", "Heavy shield strike.", 11, 5.5, 20, "damage", "filler", 1.25, True),
    ("holyWrath", "Holy Wrath", "Wrath", "Signature stun AoE.", 13, 22.0, 25, "aoe", "signature", 0.95, True),
    ("divineProtection", "Divine Protection", "DProt", "Emergency DR bubble.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Retribution
add_spec("retribution", "warrior", [
    ("sealOfCommand", "Seal of Command", "Seal", "Always on: bonus strike power.", 1, 0, 0, "passive", "passive", 0, False),
    ("crusaderStrike", "Crusader Strike", "CS", "Core melee holy strike.", 3, 4.0, 12, "damage", "filler", 1.15, True),
    ("judgment", "Judgment", "Judge", "Ranged holy verdict.", 5, 6.0, 15, "damage", "filler", 1.25, True),
    ("divineStorm", "Divine Storm", "Storm", "AoE holy whirl.", 7, 9.0, 20, "aoe", "filler", 0.8, True),
    ("hammerOfWrath", "Hammer of Wrath", "HoW", "Execute-style holy hammer.", 9, 7.0, 12, "damage", "filler", 1.5, True),
    ("zealotry", "Zealotry", "Zeal", "Self haste window.", 11, 35.0, 15, "selfBuff", "filler", 0, True),
    ("templarsVerdict", "Templar's Verdict", "TV", "Signature heavy finisher.", 13, 8.0, 25, "damage", "signature", 1.85, True),
    ("divineShield", "Divine Shield", "Bubble", "Emergency immunity.", 15, 60.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Beast Mastery
add_spec("beastMastery", "mage", [
    ("aspectOfHawk", "Aspect of the Hawk", "Hawk", "Always on: ranged power.", 1, 0, 0, "passive", "passive", 0, False),
    ("arcaneShot", "Arcane Shot", "ArcShot", "Quick ranged bolt.", 3, 4.0, 12, "damage", "filler", 1.1, True),
    ("killCommand", "Kill Command", "KC", "Pet-style heavy hit.", 5, 6.0, 18, "damage", "filler", 1.4, True),
    ("multiShot", "Multi-Shot", "Multi", "AoE around focus.", 7, 8.0, 22, "aoe", "filler", 0.7, True),
    ("bestialWrath", "Bestial Wrath", "Wrath", "Self haste buff.", 9, 30.0, 10, "selfBuff", "filler", 0, True),
    ("intimidation", "Intimidation", "Intim", "Root nearest foe.", 11, 16.0, 15, "root", "filler", 0, True),
    ("beastWithin", "The Beast Within", "Beast", "Signature damage window.", 13, 40.0, 20, "selfBuff", "signature", 0, True),
    ("feignDeath", "Feign Death", "Feign", "Emergency drop aggro.", 15, 45.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Marksmanship
add_spec("marksmanship", "mage", [
    ("trueshotAura", "Trueshot Aura", "Aura", "Always on: crit lean.", 1, 0, 0, "passive", "passive", 0, False),
    ("steadyShot", "Steady Shot", "Steady", "Reliable ranged shot.", 3, 3.5, 10, "damage", "filler", 1.05, True),
    ("aimedShot", "Aimed Shot", "Aimed", "Heavy carefully aimed bolt.", 5, 7.0, 22, "damage", "filler", 1.55, True),
    ("chimeraShot", "Chimera Shot", "Chim", "Nature + frost hybrid hit.", 7, 8.0, 20, "damage", "filler", 1.35, True),
    ("scatterShot", "Scatter Shot", "Scatter", "Root nearest foe.", 9, 14.0, 12, "root", "filler", 0, True),
    ("rapidFire", "Rapid Fire", "Rapid", "Self haste window.", 11, 32.0, 15, "selfBuff", "filler", 0, True),
    ("trueshot", "Trueshot", "True", "Signature ranged amplify.", 13, 45.0, 20, "selfBuff", "signature", 0, True),
    ("deterrence", "Deterrence", "Deter", "Emergency self shield.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Survival
add_spec("survival", "rogue", [
    ("trapMastery", "Trap Mastery", "Traps", "Always on: stronger roots.", 1, 0, 0, "passive", "passive", 0, False),
    ("explosiveShot", "Explosive Shot", "Expl", "Burst fire shot.", 3, 5.0, 15, "damage", "filler", 1.25, True),
    ("serpentSting", "Serpent Sting", "Sting", "Poisoned ranged hit.", 5, 6.0, 12, "damage", "filler", 0.85, True),
    ("explosiveTrap", "Explosive Trap", "ETrap", "AoE around self.", 7, 12.0, 20, "aoe", "filler", 0.75, True),
    ("freezingTrap", "Freezing Trap", "Freeze", "Root nearest foe.", 9, 16.0, 15, "root", "filler", 0, True),
    ("mongooseBite", "Mongoose Bite", "Mongo", "Melee-range snap.", 11, 5.0, 18, "damage", "filler", 1.3, True),
    ("blackArrow", "Black Arrow", "BArrow", "Signature dark bolt.", 13, 14.0, 25, "damage", "signature", 1.7, True),
    ("disengage", "Disengage", "Dis", "Emergency kite buff.", 15, 25.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Assassination
add_spec("assassination", "rogue", [
    ("improvedPoisons", "Improved Poisons", "Poison", "Always on: toxin damage.", 1, 0, 0, "passive", "passive", 0, False),
    ("mutilate", "Mutilate", "Mut", "Twin dagger strike.", 3, 4.0, 18, "damage", "filler", 1.3, True),
    ("envenom", "Envenom", "Env", "Poison finisher.", 5, 5.0, 22, "damage", "filler", 1.4, True),
    ("garrote", "Garrote", "Gar", "Silence-style bleed hit.", 7, 10.0, 20, "damage", "filler", 0.9, True),
    ("rupture", "Rupture", "Rupt", "DoT-style strike.", 9, 8.0, 18, "damage", "filler", 1.0, True),
    ("coldBlood", "Cold Blood", "Cold", "Self crit buff.", 11, 35.0, 0, "selfBuff", "filler", 0, True),
    ("vendetta", "Vendetta", "Vend", "Signature mark amplify.", 13, 45.0, 15, "selfBuff", "signature", 0, True),
    ("cloakOfShadows", "Cloak of Shadows", "Cloak", "Emergency cleanse DR.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Subtlety
add_spec("subtlety", "rogue", [
    ("masterOfSubtlety", "Master of Subtlety", "MoS", "Always on: opener power.", 1, 0, 0, "passive", "passive", 0, False),
    ("hemorrhage", "Hemorrhage", "Hemo", "Bleed strike.", 3, 3.5, 15, "damage", "filler", 1.15, True),
    ("backstab", "Backstab", "Stab", "Heavy positional strike.", 5, 5.0, 20, "damage", "filler", 1.45, True),
    ("shadowstep", "Shadowstep", "Step", "Close gap / haste burst.", 7, 14.0, 10, "selfBuff", "filler", 0, True),
    ("Premeditation", "Premeditation", "Prem", "Grant combo resource.", 9, 12.0, 0, "grantResource", "filler", 25, True),
    ("shadowDance", "Shadow Dance", "Dance", "Signature stealth window.", 11, 40.0, 15, "selfBuff", "signature", 0, True),
    ("cheapShot", "Cheap Shot", "Cheap", "Stun nearest foe.", 13, 16.0, 20, "root", "filler", 0, True),
    ("preparation", "Preparation", "Prep", "Emergency CD reset haste.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])
# Fix Premeditation id - must be camelCase
SPECS[-1] = ("subtlety", "rogue", [
    ("masterOfSubtlety", "Master of Subtlety", "MoS", "Always on: opener power.", 1, 0, 0, "passive", "passive", 0, False),
    ("hemorrhage", "Hemorrhage", "Hemo", "Bleed strike.", 3, 3.5, 15, "damage", "filler", 1.15, True),
    ("backstab", "Backstab", "Stab", "Heavy positional strike.", 5, 5.0, 20, "damage", "filler", 1.45, True),
    ("shadowstep", "Shadowstep", "Step", "Close gap / haste burst.", 7, 14.0, 10, "selfBuff", "filler", 0, True),
    ("premeditation", "Premeditation", "Prem", "Grant combo resource.", 9, 12.0, 0, "grantResource", "filler", 25, True),
    ("shadowDance", "Shadow Dance", "Dance", "Signature stealth window.", 11, 40.0, 15, "selfBuff", "signature", 0, True),
    ("cheapShot", "Cheap Shot", "Cheap", "Stun nearest foe.", 13, 16.0, 20, "root", "filler", 0, True),
    ("preparation", "Preparation", "Prep", "Emergency CD reset haste.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Holy Priest
add_spec("holyPriest", "healer", [
    ("spiritOfRedemption", "Spirit of Redemption", "Spirit", "Always on: stronger heals.", 1, 0, 0, "passive", "passive", 0, False),
    ("renew", "Renew", "Renew", "HoT-style heal pulse.", 3, 5.0, 14, "heal", "filler", 0.9, True),
    ("holyPriestFlash", "Flash Heal", "Flash", "Quick emergency heal.", 5, 4.0, 18, "heal", "filler", 1.25, True),
    ("circleOfHealing", "Circle of Healing", "CoH", "Heal lowest, splash ally.", 7, 8.0, 24, "heal", "filler", 1.1, True),
    ("guardianSpirit", "Guardian Spirit", "GS", "Absorb on lowest ally.", 9, 35.0, 15, "absorb", "signature", 1.5, True),
    ("holyPriestNova", "Holy Nova", "Nova", "Light AoE around self.", 11, 10.0, 20, "aoe", "filler", 0.45, True),
    ("divineHymn", "Divine Hymn", "Hymn", "Signature party heal.", 13, 40.0, 30, "heal", "signature", 1.8, True),
    ("desperatePrayer", "Desperate Prayer", "DP", "Emergency self heal.", 15, 50.0, 0, "emergencyHeal", "emergency", 2.0, True),
])

# Shadow
add_spec("shadow", "mage", [
    ("shadowform", "Shadowform", "Form", "Always on: shadow power.", 1, 0, 0, "passive", "passive", 0, False),
    ("mindFlay", "Mind Flay", "Flay", "Channeled shadow damage.", 3, 4.0, 12, "damage", "filler", 1.05, True),
    ("vampiricTouch", "Vampiric Touch", "VT", "Drain hit that grants mana.", 5, 7.0, 16, "grantResource", "filler", 18, True),
    ("devouringPlague", "Devouring Plague", "DP", "Heavy shadow strike.", 7, 8.0, 22, "damage", "filler", 1.35, True),
    ("shadowWordPain", "Shadow Word: Pain", "SWP", "DoT-style bolt.", 9, 6.0, 14, "damage", "filler", 0.85, True),
    ("psychicScream", "Psychic Scream", "Fear", "Root nearby foes.", 11, 18.0, 15, "root", "filler", 0, True),
    ("mindBlast", "Mind Blast", "Blast", "Signature shadow nuke.", 13, 7.0, 25, "damage", "signature", 1.75, True),
    ("dispersion", "Dispersion", "Disp", "Emergency DR / mana.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Blood DK
add_spec("blood", "warrior", [
    ("bloodPresence", "Blood Presence", "Pres", "Always on: tankier.", 1, 0, 0, "passive", "passive", 0, False),
    ("deathStrike", "Death Strike", "DS", "Strike that heals you.", 3, 5.5, 20, "heal", "filler", 0.8, True),
    ("heartStrike", "Heart Strike", "HS", "Cleave strike.", 5, 4.5, 15, "aoe", "filler", 0.7, True),
    ("runeTap", "Rune Tap", "Tap", "Convert runes to heal.", 7, 12.0, 10, "heal", "filler", 1.2, True),
    ("bloodBoil", "Blood Boil", "Boil", "AoE disease burst.", 9, 8.0, 18, "aoe", "filler", 0.65, True),
    ("vampiricBlood", "Vampiric Blood", "VB", "Emergency max HP.", 11, 40.0, 0, "emergencyDefend", "emergency", 0, True),
    ("dancingRuneWeapon", "Dancing Rune Weapon", "DRW", "Signature damage buff.", 13, 45.0, 20, "selfBuff", "signature", 0, True),
    ("iceboundFortitude", "Icebound Fortitude", "IBF", "Emergency DR.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Frost DK
add_spec("frostDk", "warrior", [
    ("frostPresence", "Frost Presence", "Pres", "Always on: frost power.", 1, 0, 0, "passive", "passive", 0, False),
    ("obliterate", "Obliterate", "Oblit", "Heavy dual strike.", 3, 5.0, 20, "damage", "filler", 1.4, True),
    ("frostStrike", "Frost Strike", "FS", "Icy finisher.", 5, 4.0, 18, "damage", "filler", 1.25, True),
    ("howlingBlast", "Howling Blast", "Howl", "Frost AoE.", 7, 7.0, 22, "aoe", "filler", 0.75, True),
    ("chainsOfIce", "Chains of Ice", "Chains", "Root nearest foe.", 9, 12.0, 12, "root", "filler", 0, True),
    ("pillarOfFrost", "Pillar of Frost", "Pillar", "Self damage buff.", 11, 30.0, 15, "selfBuff", "filler", 0, True),
    ("hungeringCold", "Hungering Cold", "Hunger", "Signature AoE root.", 13, 35.0, 25, "aoe", "signature", 0.5, True),
    ("frostDkIbf", "Icebound Fortitude", "IBF", "Emergency DR.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Unholy
add_spec("unholy", "warrior", [
    ("unholyPresence", "Unholy Presence", "Pres", "Always on: haste lean.", 1, 0, 0, "passive", "passive", 0, False),
    ("scourgeStrike", "Scourge Strike", "Scourge", "Plague-powered hit.", 3, 4.5, 18, "damage", "filler", 1.3, True),
    ("deathCoil", "Death Coil", "Coil", "Ranged shadow bolt.", 5, 5.5, 20, "damage", "filler", 1.2, True),
    ("bloodBoilUnholy", "Blood Boil", "Boil", "AoE disease burst.", 7, 8.0, 18, "aoe", "filler", 0.7, True),
    ("gargoyle", "Summon Gargoyle", "Garg", "Signature damage window.", 9, 45.0, 25, "selfBuff", "signature", 0, True),
    ("antiMagicShell", "Anti-Magic Shell", "AMS", "Absorb on self.", 11, 30.0, 10, "absorb", "filler", 1.0, True),
    ("armyOfDead", "Army of the Dead", "Army", "Burst AoE pulse.", 13, 50.0, 30, "aoe", "signature", 1.1, True),
    ("unholyIbf", "Icebound Fortitude", "IBF", "Emergency DR.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Elemental
add_spec("elemental", "mage", [
    ("elementalFocus", "Elemental Focus", "Focus", "Always on: spell power.", 1, 0, 0, "passive", "passive", 0, False),
    ("lightningBolt", "Lightning Bolt", "Bolt", "Core nature bolt.", 3, 3.5, 12, "damage", "filler", 1.15, True),
    ("lavaBurst", "Lava Burst", "Lava", "Heavy fire nuke.", 5, 7.0, 22, "damage", "filler", 1.55, True),
    ("chainLightning", "Chain Lightning", "Chain", "AoE lightning hops.", 7, 8.0, 24, "aoe", "filler", 0.8, True),
    ("thunderstorm", "Thunderstorm", "Storm", "Knock / AoE around self.", 9, 16.0, 18, "aoe", "filler", 0.65, True),
    ("elementalMastery", "Elemental Mastery", "EM", "Self haste buff.", 11, 35.0, 15, "selfBuff", "filler", 0, True),
    ("earthShock", "Earth Shock", "Shock", "Signature interrupt hit.", 13, 6.0, 18, "damage", "signature", 1.4, True),
    ("astralShift", "Astral Shift", "Shift", "Emergency DR.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Enhancement
add_spec("enhancement", "rogue", [
    ("enhancementWeapons", "Enhanced Weapons", "Weap", "Always on: melee power.", 1, 0, 0, "passive", "passive", 0, False),
    ("stormstrike", "Stormstrike", "Storm", "Twin nature strike.", 3, 5.0, 18, "damage", "filler", 1.35, True),
    ("lavaLash", "Lava Lash", "Lash", "Off-hand fire smash.", 5, 6.0, 16, "damage", "filler", 1.25, True),
    ("fireNova", "Fire Nova", "Nova", "AoE fire pulse.", 7, 9.0, 20, "aoe", "filler", 0.75, True),
    ("feralSpirit", "Feral Spirit", "Spirits", "Self haste window.", 9, 35.0, 15, "selfBuff", "filler", 0, True),
    ("frostShock", "Frost Shock", "FShock", "Root nearest foe.", 11, 12.0, 12, "root", "filler", 0, True),
    ("shamanisticRage", "Shamanistic Rage", "SRage", "Grant resource + DR.", 13, 30.0, 0, "grantResource", "signature", 30, True),
    ("enhancementAstral", "Astral Shift", "Shift", "Emergency DR.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Resto Shaman
add_spec("restorationShaman", "healer", [
    ("ancestralAwakening", "Ancestral Awakening", "Awake", "Always on: heal amplify.", 1, 0, 0, "passive", "passive", 0, False),
    ("riptide", "Riptide", "Rip", "HoT-style heal.", 3, 5.5, 14, "heal", "filler", 1.0, True),
    ("healingWave", "Healing Wave", "Wave", "Solid single heal.", 5, 5.0, 18, "heal", "filler", 1.35, True),
    ("chainHeal", "Chain Heal", "Chain", "Bounce heal pulse.", 7, 7.0, 24, "heal", "filler", 1.15, True),
    ("earthShield", "Earth Shield", "EShield", "Absorb on lowest ally.", 9, 10.0, 20, "absorb", "filler", 1.2, True),
    ("healingRain", "Healing Rain", "Rain", "AoE ally heal.", 11, 12.0, 28, "heal", "filler", 0.9, True),
    ("spiritLink", "Spirit Link", "Link", "Signature party mend.", 13, 40.0, 25, "heal", "signature", 1.6, True),
    ("natureSwiftness", "Nature's Swiftness", "NS", "Emergency big heal.", 15, 55.0, 0, "emergencyHeal", "emergency", 2.2, True),
])

# Arcane
add_spec("arcane", "mage", [
    ("arcanePowerPassive", "Arcane Brilliance", "Brill", "Always on: mana lean.", 1, 0, 0, "passive", "passive", 0, False),
    ("arcaneBlast", "Arcane Blast", "ABlast", "Stacking arcane bolt.", 3, 3.5, 16, "damage", "filler", 1.2, True),
    ("arcaneMissiles", "Arcane Missiles", "Missiles", "Barrage damage.", 5, 6.0, 20, "damage", "filler", 1.3, True),
    ("arcaneExplosion", "Arcane Explosion", "AE", "AoE around self.", 7, 7.0, 22, "aoe", "filler", 0.7, True),
    ("slow", "Slow", "Slow", "Root nearest foe.", 9, 14.0, 12, "root", "filler", 0, True),
    ("presenceOfMind", "Presence of Mind", "PoM", "Self haste buff.", 11, 30.0, 10, "selfBuff", "filler", 0, True),
    ("arcanePower", "Arcane Power", "AP", "Signature damage window.", 13, 40.0, 25, "selfBuff", "signature", 0, True),
    ("arcaneIceBlock", "Ice Block", "Block", "Emergency immunity.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Frost Mage
add_spec("frostMage", "mage", [
    ("frostArmor", "Frost Armor", "Armor", "Always on: chill defense.", 1, 0, 0, "passive", "passive", 0, False),
    ("frostbolt", "Frostbolt", "Bolt", "Chilling bolt.", 3, 3.5, 12, "damage", "filler", 1.15, True),
    ("iceLance", "Ice Lance", "Lance", "Shatter-style hit.", 5, 4.0, 10, "damage", "filler", 1.25, True),
    ("coneOfCold", "Cone of Cold", "Cone", "Frost AoE.", 7, 8.0, 20, "aoe", "filler", 0.7, True),
    ("frostNovaMage", "Frost Nova", "Nova", "Root nearby foes.", 9, 12.0, 18, "root", "filler", 0, True),
    ("icyVeins", "Icy Veins", "Veins", "Self haste buff.", 11, 35.0, 15, "selfBuff", "filler", 0, True),
    ("summonWaterElemental", "Water Elemental", "Water", "Signature damage window.", 13, 40.0, 20, "selfBuff", "signature", 0, True),
    ("frostMageIceBlock", "Ice Block", "Block", "Emergency immunity.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Affliction
add_spec("affliction", "mage", [
    ("soulSiphon", "Soul Siphon", "Siphon", "Always on: drain lean.", 1, 0, 0, "passive", "passive", 0, False),
    ("corruption", "Corruption", "Corr", "DoT-style bolt.", 3, 5.0, 12, "damage", "filler", 0.9, True),
    ("unstableAffliction", "Unstable Affliction", "UA", "Heavy affliction hit.", 5, 7.0, 20, "damage", "filler", 1.35, True),
    ("haunt", "Haunt", "Haunt", "Shadow nuke.", 7, 8.0, 22, "damage", "filler", 1.45, True),
    ("drainLife", "Drain Life", "Drain", "Damage + self heal.", 9, 6.0, 16, "heal", "filler", 0.7, True),
    ("curseOfAgony", "Curse of Agony", "Agony", "Sustained damage mark.", 11, 9.0, 14, "damage", "filler", 1.0, True),
    ("hauntBurst", "Haunt Burst", "Burst", "Signature shadow finisher.", 13, 18.0, 28, "damage", "signature", 1.8, True),
    ("soulburn", "Soulburn", "Burn", "Emergency self shield.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Demonology
add_spec("demonology", "mage", [
    ("demonicKnowledge", "Demonic Knowledge", "Know", "Always on: pet lean.", 1, 0, 0, "passive", "passive", 0, False),
    ("shadowBolt", "Shadow Bolt", "SBolt", "Core shadow bolt.", 3, 3.5, 14, "damage", "filler", 1.15, True),
    ("handOfGuldan", "Hand of Gul'dan", "HoG", "Fel AoE smash.", 5, 8.0, 22, "aoe", "filler", 0.85, True),
    ("immolateDemo", "Immolate", "Immo", "Fire DoT hit.", 7, 6.0, 16, "damage", "filler", 1.0, True),
    ("metamorphosis", "Metamorphosis", "Meta", "Signature form buff.", 9, 45.0, 25, "selfBuff", "signature", 0, True),
    ("demonCharge", "Demon Charge", "Charge", "Close / haste burst.", 11, 16.0, 10, "selfBuff", "filler", 0, True),
    ("chaosBoltDemo", "Chaos Bolt", "Chaos", "Heavy chaos nuke.", 13, 10.0, 30, "damage", "signature", 1.85, True),
    ("sacrifice", "Demonic Sacrifice", "Sac", "Emergency absorb.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Destruction
add_spec("destruction", "mage", [
    ("cataclysm", "Cataclysm", "Cata", "Always on: fire power.", 1, 0, 0, "passive", "passive", 0, False),
    ("incinerate", "Incinerate", "Incin", "Core fire bolt.", 3, 3.5, 14, "damage", "filler", 1.2, True),
    ("conflagrate", "Conflagrate", "Conf", "Burst fire hit.", 5, 6.0, 18, "damage", "filler", 1.4, True),
    ("immolateDestro", "Immolate", "Immo", "DoT fire mark.", 7, 7.0, 16, "damage", "filler", 0.95, True),
    ("shadowfury", "Shadowfury", "Fury", "AoE stun pulse.", 9, 16.0, 20, "aoe", "filler", 0.7, True),
    ("backdraft", "Backdraft", "Draft", "Self haste buff.", 11, 25.0, 10, "selfBuff", "filler", 0, True),
    ("chaosBolt", "Chaos Bolt", "Chaos", "Signature chaos nuke.", 13, 10.0, 32, "damage", "signature", 2.0, True),
    ("shadowWard", "Shadow Ward", "Ward", "Emergency absorb.", 15, 50.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Balance
add_spec("balance", "mage", [
    ("moonkinForm", "Moonkin Form", "Form", "Always on: astral power.", 1, 0, 0, "passive", "passive", 0, False),
    ("wrath", "Wrath", "Wrath", "Nature bolt.", 3, 3.5, 12, "damage", "filler", 1.15, True),
    ("starfire", "Starfire", "Star", "Heavy arcane bolt.", 5, 6.0, 20, "damage", "filler", 1.45, True),
    ("moonfire", "Moonfire", "Moon", "Astral DoT hit.", 7, 5.0, 14, "damage", "filler", 0.9, True),
    ("hurricane", "Hurricane", "Hurri", "AoE astral storm.", 9, 12.0, 24, "aoe", "filler", 0.75, True),
    ("typhoon", "Typhoon", "Typh", "Knock / root pulse.", 11, 16.0, 15, "root", "filler", 0, True),
    ("starfall", "Starfall", "Fall", "Signature AoE rain.", 13, 40.0, 30, "aoe", "signature", 1.0, True),
    ("barkskinBal", "Barkskin", "Bark", "Emergency DR.", 15, 45.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Feral
add_spec("feral", "rogue", [
    ("catForm", "Cat Form", "Cat", "Always on: melee haste.", 1, 0, 0, "passive", "passive", 0, False),
    ("shred", "Shred", "Shred", "Core cat strike.", 3, 3.5, 16, "damage", "filler", 1.25, True),
    ("rake", "Rake", "Rake", "Bleed opener.", 5, 5.0, 14, "damage", "filler", 0.95, True),
    ("ferociousBite", "Ferocious Bite", "Bite", "Finisher bite.", 7, 5.5, 22, "damage", "filler", 1.5, True),
    ("tigersFury", "Tiger's Fury", "TF", "Grant energy + buff.", 9, 18.0, 0, "grantResource", "filler", 30, True),
    ("berserk", "Berserk", "Berserk", "Signature haste window.", 11, 40.0, 15, "selfBuff", "signature", 0, True),
    ("mangle", "Mangle", "Mangle", "Armor-shred hit.", 13, 6.0, 18, "damage", "filler", 1.2, True),
    ("survivalInstincts", "Survival Instincts", "SI", "Emergency DR.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Guardian
add_spec("guardian", "warrior", [
    ("bearForm", "Bear Form", "Bear", "Always on: tankiness.", 1, 0, 0, "passive", "passive", 0, False),
    ("mangleBear", "Mangle", "Mangle", "Bear swipe strike.", 3, 4.5, 15, "damage", "filler", 1.1, True),
    ("swipe", "Swipe", "Swipe", "AoE claw.", 5, 6.0, 18, "aoe", "filler", 0.7, True),
    ("maul", "Maul", "Maul", "Heavy threat hit.", 7, 5.0, 20, "damage", "filler", 1.3, True),
    ("frenziedRegen", "Frenzied Regeneration", "FR", "Self heal.", 9, 16.0, 20, "heal", "filler", 1.2, True),
    ("barkskinGuard", "Barkskin", "Bark", "Emergency DR.", 11, 40.0, 0, "emergencyDefend", "emergency", 0, True),
    ("berserkGuard", "Berserk", "Berserk", "Signature rage window.", 13, 45.0, 0, "grantResource", "signature", 40, True),
    ("survivalInstinctsGuard", "Survival Instincts", "SI", "Emergency big DR.", 15, 55.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Resto Druid
add_spec("restorationDruid", "healer", [
    ("treeOfLife", "Tree of Life", "Tree", "Always on: heal amplify.", 1, 0, 0, "passive", "passive", 0, False),
    ("rejuvenation", "Rejuvenation", "Rejuv", "HoT-style heal.", 3, 4.5, 12, "heal", "filler", 0.95, True),
    ("regrowth", "Regrowth", "Regrow", "Fast heal.", 5, 5.0, 18, "heal", "filler", 1.25, True),
    ("wildGrowth", "Wild Growth", "WG", "Party heal pulse.", 7, 8.0, 24, "heal", "filler", 1.1, True),
    ("lifebloom", "Lifebloom", "Bloom", "Absorb + heal mark.", 9, 9.0, 16, "absorb", "filler", 1.0, True),
    ("nourish", "Nourish", "Nourish", "Efficient big heal.", 11, 6.0, 20, "heal", "filler", 1.4, True),
    ("tranquility", "Tranquility", "Tranq", "Signature party mend.", 13, 45.0, 35, "heal", "signature", 1.9, True),
    ("barkskinResto", "Barkskin", "Bark", "Emergency DR.", 15, 45.0, 0, "emergencyDefend", "emergency", 0, True),
])

# Collect AbilityIds
legacy_ids = [
    "defensiveStance", "shieldBlock", "thunderClap", "devastate", "taunt",
    "demoralizingShout", "shieldSlam", "revenge", "shockwave", "lastStand", "shieldWall",
    "innerFire", "powerWordShield", "prayerOfMending", "penance", "powerWordFortitude",
    "flashHeal", "painSuppression", "powerInfusion",
    "arcaneIntellect", "fireball", "livingBomb", "frostNova", "blastWave", "blink",
    "combustion", "pyroblast", "iceBlock",
    "sinisterStrike", "sliceAndDice", "eviscerate", "kidneyShot", "bladeFlurry",
    "sprint", "vanish", "killingSpree",
]

new_ids = []
seen = set(legacy_ids)
for spec_id, role, abs_ in SPECS:
    for a in abs_:
        aid = a[0]
        if aid in seen:
            raise SystemExit(f"Duplicate AbilityId: {aid}")
        seen.add(aid)
        new_ids.append(aid)

ROLE_MAP = {
    "warrior": "HeroRole.warrior",
    "healer": "HeroRole.healer",
    "mage": "HeroRole.mage",
    "rogue": "HeroRole.rogue",
}


def emit_ability(spec_id, role, a):
    aid, name, short, desc, level, cd, cost, effect, tier, coeff, show = a
    lines = [
        "    ClassAbilityDef(",
        f"      id: AbilityId.{aid},",
        f"      role: {ROLE_MAP[role]},",
        f"      specId: HeroSpecId.{spec_id},",
        f"      name: '{name.replace(chr(39), chr(92)+chr(39))}',",
        f"      shortLabel: '{short}',",
        f"      description: '{desc.replace(chr(39), chr(92)+chr(39))}',",
        f"      unlockLevel: {level},",
        f"      cooldown: {cd if cd != int(cd) else int(cd)},",
    ]
    if cost:
        lines.append(f"      resourceCost: {int(cost) if cost == int(cost) else cost},")
    if not show:
        lines.append("      showInHud: false,")
    lines.append(f"      effect: AbilityEffectKind.{effect},")
    lines.append(f"      tier: AbilityCastTier.{tier},")
    if coeff:
        lines.append(f"      coeff: {coeff},")
    lines.append("    ),")
    return "\n".join(lines)


# Enum body
enum_lines = ["enum AbilityId {"]
enum_lines.append("  // Warrior — Protection")
for i in legacy_ids[:11]:
    enum_lines.append(f"  {i},")
enum_lines.append("")
enum_lines.append("  // Healer — Discipline Priest")
for i in legacy_ids[11:19]:
    enum_lines.append(f"  {i},")
enum_lines.append("")
enum_lines.append("  // Mage — Fire")
for i in legacy_ids[19:28]:
    enum_lines.append(f"  {i},")
enum_lines.append("")
enum_lines.append("  // Rogue — Combat")
for i in legacy_ids[28:]:
    enum_lines.append(f"  {i},")
enum_lines.append("")

# Group new by spec
idx = 0
for spec_id, role, abs_ in SPECS:
    enum_lines.append(f"  // {spec_id}")
    for a in abs_:
        enum_lines.append(f"  {a[0]},")
    enum_lines.append("")
enum_lines[-1] = enum_lines[-1].rstrip()  # last blank
# Fix trailing comma on last id - Dart allows trailing commas
# Ensure last ability line ends with ; not ,
# Find last ability id line
for i in range(len(enum_lines) - 1, -1, -1):
    if enum_lines[i].strip().endswith(","):
        enum_lines[i] = enum_lines[i].rstrip(",") + ";"
        break
enum_lines.append("}")

new_defs = []
for spec_id, role, abs_ in SPECS:
    new_defs.append(f"\n    // —— {spec_id} ——")
    for a in abs_:
        new_defs.append(emit_ability(spec_id, role, a))

header = '''import 'hero.dart';
import 'hero_spec.dart';

/// How an ability resolves in the generic [AbilityEffectRunner] path.
enum AbilityEffectKind {
  passive,
  damage,
  aoe,
  heal,
  absorb,
  selfBuff,
  root,
  grantResource,
  emergencyDefend,
  emergencyHeal,
}

/// Cast priority for auto-combat kits.
enum AbilityCastTier {
  passive,
  emergency,
  signature,
  filler,
}

/// Combat abilities unlocked by hero level (WotLK-inspired kits).
'''

class_def = '''
class ClassAbilityDef {
  const ClassAbilityDef({
    required this.id,
    required this.role,
    required this.name,
    required this.shortLabel,
    required this.description,
    required this.unlockLevel,
    required this.cooldown,
    this.specId,
    this.resourceCost = 0,
    this.requiresShield = false,
    this.showInHud = true,
    this.effect = AbilityEffectKind.damage,
    this.tier = AbilityCastTier.filler,
    this.coeff = 1.0,
  });

  final AbilityId id;
  /// Legacy combat family (ratings / original four kits).
  final HeroRole role;
  final HeroSpecId? specId;
  final String name;
  final String shortLabel;
  final String description;
  final int unlockLevel;
  final double cooldown;
  final int resourceCost;
  final bool requiresShield;
  final bool showInHud;
  final AbilityEffectKind effect;
  final AbilityCastTier tier;
  /// Damage / heal / absorb multiplier vs attack (or resource grant amount).
  final double coeff;

  /// Hover / long-press chip text for the party HUD.
  String get tooltipMessage {
    final cd = cooldown <= 0
        ? 'Passive'
        : cooldown == cooldown.roundToDouble()
            ? 'CD ${cooldown.round()}s'
            : 'CD ${cooldown.toStringAsFixed(1)}s';
    final cost = resourceCost > 0 ? ' · Cost $resourceCost' : '';
    final gate = requiresShield ? ' · Needs shield' : '';
    return '$name\\n$description\\n$cd$cost$gate';
  }
}

/// Class kits adapted for Idle Party auto-combat (Wrath of the Lich King).
class ClassKits {
  ClassKits._();

  static const List<ClassAbilityDef> all = <ClassAbilityDef>[
'''

footer = '''
  ];

  static ClassAbilityDef? defFor(AbilityId id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<ClassAbilityDef> forRole(HeroRole role) =>
      all.where((d) => d.role == role && d.specId == null ||
              (d.specId != null &&
                  HeroSpecs.def(d.specId!).legacyRole == role &&
                  _isLegacySpec(d.specId!)))
          .toList(growable: false);

  static bool _isLegacySpec(HeroSpecId id) =>
      id == HeroSpecId.protection ||
      id == HeroSpecId.discipline ||
      id == HeroSpecId.fire ||
      id == HeroSpecId.combat;

  /// Abilities for a talent-tree kit. Falls back to the legacy role kit for
  /// the original four specs (or any spec without dedicated rows).
  static List<ClassAbilityDef> forSpec(HeroSpecId specId) {
    final direct =
        all.where((d) => d.specId == specId).toList(growable: false);
    if (direct.isNotEmpty) return direct;
    return forRole(HeroSpecs.def(specId).legacyRole);
  }

  static bool isUnlocked(AbilityId id, int level) {
    final d = defFor(id);
    return d != null && level >= d.unlockLevel;
  }

  static List<ClassAbilityDef> unlockedAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> unlockedAtSpec(HeroSpecId specId, int level) =>
      forSpec(specId)
          .where((d) => level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => d.showInHud && level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAtSpec(
    HeroSpecId specId,
    int level,
  ) =>
      forSpec(specId)
          .where((d) => d.showInHud && level >= d.unlockLevel)
          .toList(growable: false);

  static ClassAbilityDef? nextUnlock(HeroRole role, int level) {
    for (final d in forRole(role)) {
      if (level < d.unlockLevel) return d;
    }
    return null;
  }

  static ClassAbilityDef? nextUnlockSpec(HeroSpecId specId, int level) {
    for (final d in forSpec(specId)) {
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

  static String kitSummaryForSpec(HeroSpecId specId, int level) {
    final unlocked = unlockedAtSpec(specId, level);
    if (unlocked.isEmpty) return HeroSpecs.def(specId).shortLabel;
    final next = nextUnlockSpec(specId, level);
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

  static String resourceLabelForSpec(HeroSpecId specId) =>
      switch (HeroSpecs.def(specId).resource) {
        SpecResource.rage => 'RAGE',
        SpecResource.mana => 'MANA',
        SpecResource.energy => 'ENERGY',
        SpecResource.runic => 'RUNIC',
      };

  static int resourceColor(HeroRole role) => switch (role) {
        HeroRole.warrior => 0xFFC04030,
        HeroRole.healer => 0xFF5090E0,
        HeroRole.mage => 0xFF7060D0,
        HeroRole.rogue => 0xFFE0C040,
      };

  static int resourceColorForSpec(HeroSpecId specId) =>
      switch (HeroSpecs.def(specId).resource) {
        SpecResource.rage => 0xFFC04030,
        SpecResource.mana => 0xFF5090E0,
        SpecResource.energy => 0xFFE0C040,
        SpecResource.runic => 0xFF60C0C0,
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
          ? ClassKits.unlockedAtSpec(hero.specId, hero.level)
          : const [];
}
'''

# Fix forRole - the operator precedence is wrong. Better rewrite:
footer_fixed = '''
  ];

  static ClassAbilityDef? defFor(AbilityId id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static bool isLegacySpec(HeroSpecId id) =>
      id == HeroSpecId.protection ||
      id == HeroSpecId.discipline ||
      id == HeroSpecId.fire ||
      id == HeroSpecId.combat;

  /// Legacy role kits (original four specs only).
  static List<ClassAbilityDef> forRole(HeroRole role) {
    final legacySpec = HeroSpecs.fromLegacyRole(role);
    return all
        .where((d) => d.specId == legacySpec || (d.specId == null && d.role == role))
        .toList(growable: false);
  }

  /// Abilities for a talent-tree kit. Falls back to the legacy role kit when
  /// no dedicated rows exist.
  static List<ClassAbilityDef> forSpec(HeroSpecId specId) {
    final direct =
        all.where((d) => d.specId == specId).toList(growable: false);
    if (direct.isNotEmpty) return direct;
    return forRole(HeroSpecs.def(specId).legacyRole);
  }

  static bool isUnlocked(AbilityId id, int level) {
    final d = defFor(id);
    return d != null && level >= d.unlockLevel;
  }

  static List<ClassAbilityDef> unlockedAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> unlockedAtSpec(HeroSpecId specId, int level) =>
      forSpec(specId)
          .where((d) => level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => d.showInHud && level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAtSpec(
    HeroSpecId specId,
    int level,
  ) =>
      forSpec(specId)
          .where((d) => d.showInHud && level >= d.unlockLevel)
          .toList(growable: false);

  static ClassAbilityDef? nextUnlock(HeroRole role, int level) {
    for (final d in forRole(role)) {
      if (level < d.unlockLevel) return d;
    }
    return null;
  }

  static ClassAbilityDef? nextUnlockSpec(HeroSpecId specId, int level) {
    for (final d in forSpec(specId)) {
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

  static String kitSummaryForSpec(HeroSpecId specId, int level) {
    final unlocked = unlockedAtSpec(specId, level);
    if (unlocked.isEmpty) return HeroSpecs.def(specId).shortLabel;
    final next = nextUnlockSpec(specId, level);
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

  static String resourceLabelForSpec(HeroSpecId specId) =>
      switch (HeroSpecs.def(specId).resource) {
        SpecResource.rage => 'RAGE',
        SpecResource.mana => 'MANA',
        SpecResource.energy => 'ENERGY',
        SpecResource.runic => 'RUNIC',
      };

  static int resourceColor(HeroRole role) => switch (role) {
        HeroRole.warrior => 0xFFC04030,
        HeroRole.healer => 0xFF5090E0,
        HeroRole.mage => 0xFF7060D0,
        HeroRole.rogue => 0xFFE0C040,
      };

  static int resourceColorForSpec(HeroSpecId specId) =>
      switch (HeroSpecs.def(specId).resource) {
        SpecResource.rage => 0xFFC04030,
        SpecResource.mana => 0xFF5090E0,
        SpecResource.energy => 0xFFE0C040,
        SpecResource.runic => 0xFF60C0C0,
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
          ? ClassKits.unlockedAtSpec(hero.specId, hero.level)
          : const [];
}
'''

body = "\n".join(enum_lines) + "\n" + class_def + LEGACY + "\n".join(new_defs) + footer_fixed
OUT.write_text(header + body, encoding="utf-8")
print(f"Wrote {OUT}")
print(f"New AbilityIds: {len(new_ids)}")
print(f"Total AbilityIds: {len(seen)}")
