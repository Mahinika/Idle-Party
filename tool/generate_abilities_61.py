#!/usr/bin/env python3
"""Generate AbilityId enum entries and ClassAbilityDef blocks for abilities-61 batch."""
from __future__ import annotations

import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# (id, spec, name, short, desc, unlock, cd, cost, effect, tier, coeff, extras dict)
# extras: shape, gate, custom, buff, style, vfx_cast, ground, summon*, passive, shield, fireMode, castDelay

ABILITIES: list[dict] = []


def add(**kw) -> None:
    ABILITIES.append(kw)


# —— Warrior Arms ——
add(id="colossusSmash", spec="arms", name="Colossus Smash", short="CSmash",
    desc="Armor-shattering heavy strike on your focus.", ul=8, cd=7, cost=18,
    effect="damage", tier="filler", coeff=2.1, style="weapon",
    vfx=0xFFFFC060, burst="cone", ground="steel")
add(id="dieByTheSword", spec="arms", name="Die by the Sword", short="DbS",
    desc="Personal mid-cooldown parry absorb.", ul=10, cd=35, cost=0,
    effect="absorb", tier="filler", coeff=0.85, style="weapon", vfx=0xFFFFD080)
add(id="armsCharge", spec="arms", name="Charge", short="Chrg",
    desc="Rush a foe, root them, and gain rage.", ul=6, cd=12, cost=10,
    effect="selfBuff", tier="filler", custom="charge",
    gate="requireFocus:true,minRange:3.5,maxRange:8.0,needClearCorridor:true")

# Fury
add(id="executeFury", spec="fury", name="Execute", short="Exec",
    desc="Finisher on wounded foes.", ul=10, cd=6, cost=20,
    effect="damage", tier="signature", coeff=3.2, style="weapon", vfx=0xFFFF9050,
    gate="executeHpFrac:0.25", burst="slash")
add(id="piercingHowl", spec="fury", name="Piercing Howl", short="Howl",
    desc="Root nearby foes in a shockwave.", ul=8, cd=16, cost=15,
    effect="root", tier="filler", gate="peelRange:2.0,peelScanRange:3.0",
    style="weapon", vfx=0xFFFFA070, burst="ring", ground="disc")

# Holy Paladin
add(id="lightOfDawn", spec="holyPaladin", name="Light of Dawn", short="LoD",
    desc="Cone heal on injured allies.", ul=8, cd=10, cost=22,
    effect="heal", tier="filler", coeff=1.05, style="holy", vfx=0xFFFFF0C0,
    burst="cross")
add(id="hammerOfJusticeHoly", spec="holyPaladin", name="Hammer of Justice", short="HoJ",
    desc="Root your focus briefly.", ul=10, cd=18, cost=15,
    effect="root", tier="filler", gate="requireFocus:true", style="holy",
    vfx=0xFFFFE8A0, burst="cross", ground="holy")

# Prot Paladin
add(id="ardentDefender", spec="protPaladin", name="Ardent Defender", short="Ardent",
    desc="Emergency DR — second panic button.", ul=10, cd=50, cost=0,
    effect="emergencyDefend", tier="emergency", coeff=1.0, style="holy", vfx=0xFFFFE0A0)
add(id="wordOfGloryProt", spec="protPaladin", name="Word of Glory", short="WoG",
    desc="Quick heal on the lowest ally.", ul=8, cd=10, cost=18,
    effect="heal", tier="filler", coeff=1.12, style="holy", vfx=0xFFFFF8D0)

# Retribution
add(id="consecrationRet", spec="retribution", name="Consecration", short="Cons",
    desc="Holy fire on the ground under foes.", ul=8, cd=9, cost=20,
    effect="aoe", tier="filler", coeff=0.30, shape="ground", style="holy",
    vfx=0xFFFFE8A0, ground_disc=True, ground_life=6.0, ground_argb=0x88FFE8A0,
    burst="cross", gkind="holy")
add(id="hammerOfJusticeRet", spec="retribution", name="Hammer of Justice", short="HoJ",
    desc="Root your focus briefly.", ul=10, cd=18, cost=15,
    effect="root", tier="filler", gate="requireFocus:true", style="holy",
    vfx=0xFFFFE8A0, burst="cross", ground="holy")
add(id="wordOfGloryRet", spec="retribution", name="Word of Glory", short="WoG",
    desc="Small heal on the lowest ally.", ul=9, cd=14, cost=18,
    effect="heal", tier="filler", coeff=1.1, style="holy", vfx=0xFFFFF0C0)

# Beast Mastery
add(id="stampede", spec="beastMastery", name="Stampede", short="Stamp",
    desc="Summon a beast rush; brief self haste.", ul=11, cd=42, cost=25,
    effect="selfBuff", tier="signature", style="arrow", vfx=0xFFE8C060,
    summon_c=3, summon_d=14, summon_atk=0.32, summon_name="Stampede Beast",
    summon_prefix="stamp", summon_haste=10)
add(id="killShotBm", spec="beastMastery", name="Kill Shot", short="KillSh",
    desc="Execute shot on wounded foes.", ul=10, cd=9, cost=16,
    effect="damage", tier="signature", coeff=1.65, style="arrow", vfx=0xFFE8D080,
    gate="executeHpFrac:0.25", burst="rain")
add(id="claw", spec="beastMastery", name="Claw", short="Claw",
    desc="Your companion leaps in and rips focus.", ul=7, cd=6.5, cost=14,
    effect="damage", tier="filler", coeff=1.35, style="weapon", vfx=0xFFD8A060,
    burst="slash")

# Marksmanship
add(id="killShotMm", spec="marksmanship", name="Kill Shot", short="KillSh",
    desc="Execute shot on wounded foes.", ul=10, cd=9, cost=16,
    effect="damage", tier="signature", coeff=1.72, style="arrow", vfx=0xFFE8D080,
    gate="executeHpFrac:0.25", burst="beam")
add(id="bindingShot", spec="marksmanship", name="Binding Shot", short="Bind",
    desc="Pin the pack around your focus.", ul=9, cd=16, cost=15,
    effect="root", tier="filler", gate="requireFocus:true", style="arrow",
    vfx=0xFFE0C878, ground_disc=True, ground_life=2.2, ground_argb=0x66D0A050,
    burst="beam", gkind="disc")

# Survival
add(id="wildfireBomb", spec="survival", name="Wildfire Bomb", short="WBomb",
    desc="Bomb blooms into a fire pool on focus.", ul=8, cd=9, cost=18,
    effect="aoe", tier="filler", coeff=1.22, shape="ground", style="fire",
    vfx=0xFFFF5020, ground_disc=True, ground_life=3.5, ground_argb=0x88FF5020,
    burst="flame", gkind="fire")
add(id="harpoonSurvival", spec="survival", name="Harpoon", short="Harp",
    desc="Harpoon root on focus at range.", ul=10, cd=14, cost=12,
    effect="root", tier="filler", gate="requireFocus:true,maxRange:6.5",
    style="arrow", vfx=0xFFD0B060, burst="beam")

# Assassination
add(id="kidneyShotAssa", spec="assassination", name="Kidney Shot", short="Kidney",
    desc="Stun finisher on focus.", ul=10, cd=14, cost=20,
    effect="root", tier="filler", custom="kidneyShot", gate="comboMin:3",
    style="weapon", vfx=0xFFFFC090, burst="slash")
add(id="crimsonVial", spec="assassination", name="Crimson Vial", short="Vial",
    desc="Self-sustain when hurt.", ul=9, cd=30, cost=0,
    effect="heal", tier="filler", coeff=0.55, gate="casterHpMax:0.72",
    style="poison", vfx=0xFFE04060, burst="poison")

# Combat
add(id="adrenalineRush", spec="combat", name="Adrenaline Rush", short="Adren",
    desc="Attack haste window.", ul=9, cd=35, cost=15,
    effect="selfBuff", tier="filler", buff="haste", style="weapon", vfx=0xFFFF9090,
    burst="slash")
add(id="revealingStrike", spec="combat", name="Revealing Strike", short="Reveals",
    desc="Builder strike that leaves a glowing wound.", ul=6, cd=4, cost=12,
    effect="damage", tier="filler", coeff=0.82, style="weapon", vfx=0xFFFFA070,
    burst="slash")

# Subtlety
add(id="secretTechnique", spec="subtlety", name="Secret Technique", short="Secret",
    desc="Shadow clones rip through the pack.", ul=11, cd=22, cost=22,
    effect="aoe", tier="signature", coeff=1.25, shape="nova", style="shadow",
    vfx=0xFF8040C0, burst="slash", gkind="shadow")

# Discipline
add(id="powerWordBarrier", spec="discipline", name="Power Word: Barrier", short="Barrie",
    desc="Weaker absorb on the lowest ally (party fallback).", ul=10, cd=35, cost=25,
    effect="absorb", tier="filler", coeff=1.15, style="holy", vfx=0xFFE8E0FF,
    ground_disc=True, ground_life=3.0, ground_argb=0x88E8E0FF, burst="cross")
add(id="halo", spec="discipline", name="Halo", short="Halo",
    desc="Expanding holy ring heals the party.", ul=11, cd=18, cost=22,
    effect="heal", tier="signature", coeff=1.25, style="holy", vfx=0xFFFFF0E0,
    ground_disc=True, ground_life=2.5, ground_argb=0x66FFF0D0, burst="cross", gkind="holy")
add(id="shadowfiendDisc", spec="discipline", name="Shadowfiend", short="SFien",
    desc="Summon a shadow ally to strike foes.", ul=11, cd=45, cost=20,
    effect="selfBuff", tier="signature", style="shadow", vfx=0xFF9060C0,
    summon_c=1, summon_d=22, summon_atk=0.38, summon_name="Shadowfiend",
    summon_prefix="sfiend", burst="skull")

# Holy Priest
add(id="holyFire", spec="holyPriest", name="Holy Fire", short="HFire",
    desc="Holy flame pillar on focus.", ul=8, cd=7.5, cost=18,
    effect="damage", tier="filler", coeff=1.08, style="holy", vfx=0xFFFFE060,
    gate="maintainDot:true", burst="cross")
add(id="holyWordSanctify", spec="holyPriest", name="Holy Word: Sanctify", short="Sanct",
    desc="Holy ground pulse heals allies.", ul=10, cd=14, cost=24,
    effect="heal", tier="filler", coeff=1.45, style="holy", vfx=0xFFFFF8E0,
    ground_disc=True, ground_life=2.8, ground_argb=0x88FFF8E0, burst="cross", gkind="holy")
add(id="prayerOfMendingHoly", spec="holyPriest", name="Prayer of Mending", short="Mend",
    desc="Bounce heal when an ally is hit.", ul=9, cd=9, cost=18,
    effect="heal", tier="filler", coeff=1.0, style="holy", vfx=0xFFFFF0C0,
    custom="prayerOfMending", fireMode="onHitBounce", gate="needsPomTarget:true")

# Shadow
add(id="shadowWordDeath", spec="shadow", name="Shadow Word: Death", short="SWD",
    desc="Execute shadow spike on wounded foes.", ul=10, cd=8, cost=18,
    effect="damage", tier="signature", coeff=1.65, style="shadow", vfx=0xFF9040D0,
    gate="executeHpFrac:0.25", burst="skull")
add(id="shadowfiendShadow", spec="shadow", name="Shadowfiend", short="SFien",
    desc="Summon a shadow ally to strike foes.", ul=11, cd=45, cost=20,
    effect="selfBuff", tier="signature", style="shadow", vfx=0xFF9060C0,
    summon_c=1, summon_d=22, summon_atk=0.38, summon_name="Shadowfiend",
    summon_prefix="sfiend", burst="skull")

# Frost DK
add(id="frozenOrb", spec="frostDk", name="Frozen Orb", short="FOrb",
    desc="Orb pulses frost over the pack.", ul=9, cd=18, cost=22,
    effect="aoe", tier="signature", coeff=0.95, shape="rain", style="frost",
    vfx=0xFF90E8FF, ground_disc=True, ground_life=3.0, ground_argb=0x6690D8FF,
    burst="shards", gkind="frost")
add(id="breathOfSindragosa", spec="frostDk", name="Breath of Sindragosa", short="Breath",
    desc="Frost dragon breath cones through the pack.", ul=11, cd=30, cost=30,
    effect="aoe", tier="signature", coeff=1.65, shape="fan", style="frost",
    vfx=0xFFB0F0FF, burst="shards")
add(id="empowerRuneWeapon", spec="frostDk", name="Empower Rune Weapon", short="ERW",
    desc="Instant rune refill.", ul=10, cd=35, cost=0,
    effect="grantResource", tier="filler", style="frost", vfx=0xFF80C8FF, burst="shards")

# Unholy
add(id="soulReaper", spec="unholy", name="Soul Reaper", short="Reaper",
    desc="Reap wounded foes with a shadow scythe.", ul=10, cd=7, cost=20,
    effect="damage", tier="signature", coeff=1.55, style="shadow", vfx=0xFF8060A0,
    gate="executeHpFrac:0.25", burst="skull")
add(id="darkTransformation", spec="unholy", name="Dark Transformation", short="DTrans",
    desc="Damage amp — your ghoul swells with unholy power.", ul=11, cd=42, cost=20,
    effect="selfBuff", tier="signature", buff="amp", buff_dur=8, style="shadow",
    vfx=0xFF9050B0, burst="skull")

# Elemental
add(id="fireElemental", spec="elemental", name="Fire Elemental", short="FElem",
    desc="Summon a fire elemental ally.", ul=11, cd=42, cost=22,
    effect="selfBuff", tier="signature", style="fire", vfx=0xFFFF6030,
    summon_c=1, summon_d=26, summon_atk=0.40, summon_name="Fire Elemental",
    summon_prefix="fireelem", burst="flame")

# Enhancement
add(id="crashLightning", spec="enhancement", name="Crash Lightning", short="Crash",
    desc="Lightning chain cleave through the pack.", ul=8, cd=8, cost=16,
    effect="aoe", tier="filler", coeff=1.15, shape="chain", style="lightning",
    vfx=0xFFB8F0FF, burst="beam")
add(id="healingSurge", spec="enhancement", name="Healing Surge", short="HSurge",
    desc="Quick heal on the lowest ally.", ul=10, cd=12, cost=18,
    effect="heal", tier="filler", coeff=1.08, style="nature", vfx=0xFF90E8C0)

# Resto Shaman
add(id="healingTideTotem", spec="restorationShaman", name="Healing Tide Totem", short="Tide",
    desc="Totem pulse heals the party.", ul=10, cd=25, cost=28,
    effect="heal", tier="signature", coeff=1.55, style="nature", vfx=0xFF80E0C0,
    ground_disc=True, ground_life=3.5, ground_argb=0x6680E0C0, burst="leaf", gkind="nature")
add(id="earthbindTotem", spec="restorationShaman", name="Earthbind Totem", short="EBind",
    desc="Totem roots nearby foes.", ul=8, cd=16, cost=15,
    effect="root", tier="filler", gate="peelRange:2.2,peelScanRange:3.2",
    style="nature", vfx=0xFF9A7850, ground_disc=True, ground_life=2.0,
    ground_argb=0x669A7850, burst="leaf", gkind="nature")
add(id="manaTideTotem", spec="restorationShaman", name="Mana Tide Totem", short="MTide",
    desc="Restore mana to yourself.", ul=11, cd=45, cost=0,
    effect="grantResource", tier="filler", style="nature", vfx=0xFF70B0FF)

# Arcane
add(id="arcaneBarrage", spec="arcane", name="Arcane Barrage", short="Barrage",
    desc="Violet chain jumps between foes.", ul=8, cd=5.5, cost=20,
    effect="aoe", tier="filler", coeff=1.22, shape="chain", style="arcane",
    vfx=0xFFE040FF, burst="beam")
add(id="prismaticBarrier", spec="arcane", name="Prismatic Barrier", short="Prism",
    desc="Self absorb mid-cooldown.", ul=10, cd=22, cost=15,
    effect="absorb", tier="filler", coeff=1.0, style="arcane", vfx=0xFFE0A0FF)
add(id="evocation", spec="arcane", name="Evocation", short="Evoc",
    desc="Channel mana back into yourself.", ul=11, cd=42, cost=0,
    effect="grantResource", tier="filler", style="arcane", vfx=0xFFD080FF)

# Fire Mage
add(id="meteor", spec="fire", name="Meteor", short="Meteor",
    desc="A burning meteor slams the pack.", ul=11, cd=35, cost=30,
    effect="aoe", tier="signature", coeff=1.65, shape="ground", style="fire",
    vfx=0xFFFF4010, ground_disc=True, ground_life=3.2, ground_argb=0x88FF4010,
    gate="packMin:2", burst="flame", gkind="fire", big=True)

# Frost Mage
add(id="iceBarrierFrost", spec="frostMage", name="Ice Barrier", short="IBarr",
    desc="Self frost absorb.", ul=10, cd=22, cost=15,
    effect="absorb", tier="filler", coeff=1.0, style="frost", vfx=0xFF90E8FF)
add(id="frostMageConeOfCold", spec="frostMage", name="Cone of Cold", short="Cone",
    desc="Wide frost breath in front of you.", ul=9, cd=9, cost=16,
    effect="aoe", tier="filler", coeff=0.92, shape="fan", style="frost",
    vfx=0xFFB0F0FF, burst="shards")

# Affliction
add(id="darkSoul", spec="affliction", name="Dark Soul", short="DSoul",
    desc="Damage amp surrounded by swirling souls.", ul=10, cd=38, cost=15,
    effect="selfBuff", tier="filler", buff="amp", buff_dur=8, style="shadow",
    vfx=0xFF7040A0, burst="skull")
add(id="howlOfTerror", spec="affliction", name="Howl of Terror", short="Howl",
    desc="Fear-ring roots nearby foes.", ul=9, cd=18, cost=18,
    effect="root", tier="filler", gate="peelRange:2.0,peelScanRange:3.0",
    style="shadow", vfx=0xFF8040B0, burst="skull", ground="shadow")

# Demonology
add(id="callDreadstalkers", spec="demonology", name="Call Dreadstalkers", short="Dreads",
    desc="Two demon hounds burst from a fel gate.", ul=9, cd=22, cost=22,
    effect="selfBuff", tier="signature", style="demon", vfx=0xFF70FF40,
    summon_c=2, summon_d=18, summon_atk=0.36, summon_name="Dreadstalker",
    summon_prefix="dread", burst="skull")
add(id="soulFireDemo", spec="demonology", name="Soul Fire", short="SFire",
    desc="Fel meteor pillar on focus.", ul=10, cd=8, cost=20,
    effect="damage", tier="filler", coeff=1.35, style="demon", vfx=0xFF60E030,
    burst="flame")

# Destruction
add(id="summonInfernal", spec="destruction", name="Summon Infernal", short="Infer",
    desc="Infernal meteor lands and burns the pack.", ul=11, cd=45, cost=30,
    effect="aoe", tier="signature", coeff=0.85, shape="ground", style="demon",
    vfx=0xFF50C020, ground_disc=True, ground_life=3.5, ground_argb=0x8850C020,
    summon_c=1, summon_d=20, summon_atk=0.42, summon_name="Infernal",
    summon_prefix="infer", burst="flame", gkind="fire")
add(id="shadowburn", spec="destruction", name="Shadowburn", short="SBurn",
    desc="Execute fel brand on wounded foes.", ul=10, cd=7, cost=18,
    effect="damage", tier="signature", coeff=1.38, style="demon", vfx=0xFF70FF50,
    gate="executeHpFrac:0.25", burst="skull")

# Balance
add(id="starsurge", spec="balance", name="Starsurge", short="Surge",
    desc="Astral lance strikes focus.", ul=10, cd=9, cost=18,
    effect="damage", tier="signature", coeff=1.48, style="nature", vfx=0xFFB0E0FF,
    burst="beam")
add(id="forceOfNature", spec="balance", name="Force of Nature", short="Treant",
    desc="Three treants rise from the ground.", ul=11, cd=40, cost=22,
    effect="selfBuff", tier="signature", style="nature", vfx=0xFF80C060,
    summon_c=3, summon_d=22, summon_atk=0.34, summon_name="Treant",
    summon_prefix="treant", burst="leaf")

# Feral
add(id="maim", spec="feral", name="Maim", short="Maim",
    desc="Stunning bite when you have combo points.", ul=10, cd=14, cost=22,
    effect="root", tier="filler", gate="comboMin:2", style="weapon", vfx=0xFFFFC070,
    burst="slash")

# Resto Druid
add(id="ironbark", spec="restorationDruid", name="Ironbark", short="Iron",
    desc="Bark armor absorb on the lowest ally.", ul=10, cd=35, cost=20,
    effect="absorb", tier="filler", coeff=1.25, style="nature", vfx=0xFF8A6840)
add(id="innervateDruid", spec="restorationDruid", name="Innervate", short="Innerv",
    desc="Restore mana to yourself.", ul=11, cd=45, cost=0,
    effect="grantResource", tier="filler", style="nature", vfx=0xFF90D060)
add(id="entanglingRoots", spec="restorationDruid", name="Entangling Roots", short="Roots",
    desc="Vines root your focus.", ul=8, cd=14, cost=15,
    effect="root", tier="filler", gate="requireFocus:true", style="nature",
    vfx=0xFF60A040, ground_disc=True, ground_life=2.2, ground_argb=0x6660A040,
    burst="leaf", gkind="nature")

SPEC_TO_KIT = {
    "arms": "warrior",
    "fury": "warrior",
    "protection": "warrior",
    "holyPaladin": "paladin",
    "protPaladin": "paladin",
    "retribution": "paladin",
    "beastMastery": "hunter",
    "marksmanship": "hunter",
    "survival": "hunter",
    "assassination": "rogue",
    "combat": "rogue",
    "subtlety": "rogue",
    "discipline": "priest",
    "holyPriest": "priest",
    "shadow": "priest",
    "blood": "death_knight",
    "frostDk": "death_knight",
    "unholy": "death_knight",
    "elemental": "shaman",
    "enhancement": "shaman",
    "restorationShaman": "shaman",
    "arcane": "mage",
    "fire": "mage",
    "frostMage": "mage",
    "affliction": "warlock",
    "demonology": "warlock",
    "destruction": "warlock",
    "balance": "druid",
    "feral": "druid",
    "guardian": "druid",
    "restorationDruid": "druid",
}

SPEC_ROLE = {
    "arms": "warrior",
    "fury": "warrior",
    "protection": "warrior",
    "holyPaladin": "paladin",
    "protPaladin": "paladin",
    "retribution": "paladin",
    "blood": "warrior",
    "frostDk": "warrior",
    "unholy": "warrior",
    "assassination": "rogue",
    "combat": "rogue",
    "subtlety": "rogue",
    "discipline": "healer",
    "holyPriest": "healer",
    "shadow": "healer",
    "beastMastery": "mage",
    "marksmanship": "mage",
    "survival": "mage",
    "elemental": "mage",
    "enhancement": "mage",
    "restorationShaman": "healer",
    "arcane": "mage",
    "fire": "mage",
    "frostMage": "mage",
    "affliction": "mage",
    "demonology": "mage",
    "destruction": "mage",
    "balance": "mage",
    "feral": "rogue",
    "guardian": "rogue",
    "restorationDruid": "healer",
}


def gear(spec: str) -> str:
    return f"HeroRole.{SPEC_ROLE[spec]}"


def render_def(a: dict) -> str:
    lines = [
        "    ClassAbilityDef(",
        f"      id: AbilityId.{a['id']},",
        f"      gearAffinity: {gear(a['spec'])},",
        f"      specId: HeroSpecId.{a['spec']},",
        f"      name: '{a['name']}',",
        f"      shortLabel: '{a['short']}',",
        f"      description: '{a['desc']}',",
        f"      unlockLevel: {a['ul']},",
        f"      cooldown: {a['cd']},",
    ]
    if a.get("cost", 0):
        lines.append(f"      resourceCost: {a['cost']},")
    lines.append(f"      effect: AbilityEffectKind.{a['effect']},")
    lines.append(f"      tier: AbilityCastTier.{a['tier']},")
    if "coeff" in a:
        lines.append(f"      coeff: {a['coeff']},")
    if a.get("style"):
        lines.append(f"      boltStyle: SpellBoltStyle.{a['style']},")
        lines.append("      vfx: AbilityVfxSpec(")
        lines.append(f"        boltStyle: SpellBoltStyle.{a['style']},")
        if a.get("vfx"):
            lines.append(f"        castArgb: {a['vfx']},")
        if a.get("ground_disc"):
            lines.append("        groundDisc: true,")
            lines.append(f"        groundLife: {a.get('ground_life', 2.5)},")
            if a.get("ground_argb"):
                lines.append(f"        groundArgb: {a['ground_argb']},")
        lines.append("      ),")
    if a.get("shape"):
        lines.append(f"      aoeShape: AbilityAoeShape.{a['shape']},")
    if a.get("custom"):
        lines.append(f"      customId: AbilityCustomId.{a['custom']},")
    if a.get("fireMode"):
        lines.append(f"      fireMode: AbilityFireMode.{a['fireMode']},")
    if a.get("gate"):
        parts = a["gate"].split(",")
        gp = []
        for p in parts:
            k, v = p.split(":")
            if v in ("true", "false"):
                gp.append(f"{k}: {v}")
            else:
                try:
                    float(v)
                    gp.append(f"{k}: {v}")
                except ValueError:
                    gp.append(f"{k}: {v}")
        lines.append(f"      gate: AbilityGate({', '.join(gp)}),")
    if a.get("buff"):
        lines.append(f"      selfBuffKind: AbilitySelfBuffKind.{a['buff']},")
        if a.get("buff_dur"):
            lines.append(f"      selfBuffDuration: {a['buff_dur']},")
    if a.get("summon_c"):
        lines.append(f"      summonCount: {a['summon_c']},")
        lines.append(f"      summonDuration: {a['summon_d']},")
        lines.append(f"      summonAtkScale: {a['summon_atk']},")
        lines.append(f"      summonName: '{a['summon_name']}',")
        lines.append(f"      summonIdPrefix: '{a['summon_prefix']}',")
        if a.get("summon_haste"):
            lines.append(f"      summonHasteSeconds: {a['summon_haste']},")
    lines.append("    ),")
    return "\n".join(lines)


def main() -> None:
    enum_lines = ["  // —— abilities-61 batch ——"]
    for a in ABILITIES:
        enum_lines.append(f"  {a['id']},")

    enum_block = "\n".join(enum_lines)
    enum_path = ROOT / "lib/models/class_ability.dart"
    text = enum_path.read_text()
    needle = "  barkskinResto,\n}"
    if "colossusSmash" not in text:
        text = text.replace(needle, f"  barkskinResto,\n\n{enum_block}\n}}")
        enum_path.write_text(text)
        print(f"Added {len(ABILITIES)} enum entries")

    by_kit: dict[str, list[str]] = {}
    for a in ABILITIES:
        kit = SPEC_TO_KIT[a["spec"]]
        by_kit.setdefault(kit, []).append(render_def(a))

    for kit, blocks in by_kit.items():
        path = ROOT / f"lib/models/kits/{kit}.dart"
        content = path.read_text()
        if "colossusSmash" in content or "abilities-61" in content:
            print(f"Skip {kit} (already patched)")
            continue
        marker = "    // —— abilities-61 ——\n"
        insert = marker + "\n".join(blocks) + "\n"
        content = content.replace("];", insert + "];", 1)
        path.write_text(content)
        print(f"Patched {kit} (+{len(blocks)})")

    vfx_path = ROOT / "lib/spatial/spell_vfx.dart"
    vfx = vfx_path.read_text()
    if "colossusSmash" not in vfx:
        burst_lines = []
        ground_lines = []
        big_lines = []
        for a in ABILITIES:
            if a.get("burst"):
                bk = a["burst"]
                burst_lines.append(f"    AbilityId.{a['id']} => SpatialBurstKind.{bk},")
            if a.get("gkind"):
                gk = a["gkind"]
                ground_lines.append(f"    AbilityId.{a['id']} => SpatialGroundFxKind.{gk},")
            if a.get("big"):
                big_lines.append(f"    AbilityId.{a['id']} ||")
        burst_insert = "\n".join(burst_lines)
        vfx = vfx.replace(
            "    AbilityId.shockwave => SpatialBurstKind.cone,\n    _ => null,",
            f"    AbilityId.shockwave => SpatialBurstKind.cone,\n{burst_insert}\n    _ => null,",
        )
        ground_insert = "\n".join(ground_lines)
        vfx = vfx.replace(
            "    AbilityId.guardianThrash => SpatialGroundFxKind.steel,\n    _ => null,",
            f"    AbilityId.guardianThrash => SpatialGroundFxKind.steel,\n{ground_insert}\n    _ => null,",
        )
        if big_lines:
            vfx = vfx.replace(
                "    AbilityId.deathCoil => true,\n    _ => false,",
                "    AbilityId.deathCoil ||\n    " + "\n    ".join(big_lines).rstrip(" ||") + " => true,\n    _ => false,",
            )
        vfx_path.write_text(vfx)
        print("Patched spell_vfx.dart")

    look_path = ROOT / "lib/spatial/spell_look.dart"
    look = look_path.read_text()
    if "colossusSmash" not in look:
        buckets: dict[str, list[str]] = {}
        for a in ABILITIES:
            st = a.get("style")
            if not st:
                continue
            buckets.setdefault(st, []).append(f"AbilityId.{a['id']}")
        for st, ids in buckets.items():
            style_enum = f"SpellBoltStyle.{st}"
            block = " ||\n    ".join(ids)
            # Insert before _ => null in matching section is hard — append to weapon block tail
            if st == "weapon":
                look = look.replace(
                    "AbilityId.sweepingStrikes => SpellBoltStyle.weapon,\n    _ => null,",
                    f"AbilityId.sweepingStrikes ||\n    {block} => SpellBoltStyle.weapon,\n    _ => null,",
                )
            elif st == "holy":
                look = look.replace(
                    "AbilityId.layOnHands => SpellBoltStyle.holy,\n",
                    f"AbilityId.layOnHands ||\n    {block} => SpellBoltStyle.holy,\n",
                )
            elif st == "arrow":
                look = look.replace(
                    "AbilityId.bestialWrath => SpellBoltStyle.arrow,\n",
                    f"AbilityId.bestialWrath ||\n    {block} => SpellBoltStyle.arrow,\n",
                )
            elif st == "fire":
                look = look.replace(
                    "AbilityId.explosiveShot => SpellBoltStyle.fire,\n",
                    f"AbilityId.explosiveShot ||\n    {block} => SpellBoltStyle.fire,\n",
                )
            elif st == "frost":
                look = look.replace(
                    "AbilityId.iceBlock => SpellBoltStyle.frost,\n",
                    f"AbilityId.iceBlock ||\n    {block} => SpellBoltStyle.frost,\n",
                )
            elif st == "shadow":
                look = look.replace(
                    "AbilityId.psychicScream => SpellBoltStyle.shadow,\n",
                    f"AbilityId.psychicScream ||\n    {block} => SpellBoltStyle.shadow,\n",
                )
            elif st == "arcane":
                look = look.replace(
                    "AbilityId.presenceOfMind => SpellBoltStyle.arcane,\n",
                    f"AbilityId.presenceOfMind ||\n    {block} => SpellBoltStyle.arcane,\n",
                )
            elif st == "nature":
                look = look.replace(
                    "AbilityId.tranquility => SpellBoltStyle.nature,\n",
                    f"AbilityId.tranquility ||\n    {block} => SpellBoltStyle.nature,\n",
                )
            elif st == "lightning":
                look = look.replace(
                    "AbilityId.stormstrike => SpellBoltStyle.lightning,\n",
                    f"AbilityId.stormstrike ||\n    {block} => SpellBoltStyle.lightning,\n",
                )
            elif st == "demon":
                look = look.replace(
                    "AbilityId.handOfGuldan => SpellBoltStyle.demon,\n",
                    f"AbilityId.handOfGuldan ||\n    {block} => SpellBoltStyle.demon,\n",
                )
            elif st == "poison":
                look = look.replace(
                    "AbilityId.serpentSting => SpellBoltStyle.poison,\n",
                    f"AbilityId.serpentSting ||\n    {block} => SpellBoltStyle.poison,\n",
                )
        ground_disc = []
        for a in ABILITIES:
            if a.get("ground_disc"):
                life = a.get("ground_life", 2.5)
                ground_disc.append(f"    AbilityId.{a['id']} => {life},")
        if ground_disc:
            look = look.replace(
                "    _ => null,\n  };\n}",
                "\n".join(ground_disc) + "\n    _ => null,\n  };\n}",
                1,
            )
        look_path.write_text(look)
        print("Patched spell_look.dart")

    print(f"Total abilities in batch: {len(ABILITIES)}")


if __name__ == "__main__":
    main()