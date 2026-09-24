import 'ability_vfx.dart';
import 'hero.dart';
import 'hero_spec.dart';
import 'spell_bolt_style.dart';

part 'kits/warrior.dart';
part 'kits/priest.dart';
part 'kits/mage.dart';
part 'kits/rogue.dart';
part 'kits/paladin.dart';
part 'kits/hunter.dart';
part 'kits/death_knight.dart';
part 'kits/shaman.dart';
part 'kits/warlock.dart';
part 'kits/druid.dart';

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

  /// Force loose enemies onto the caster (tank hard taunt).
  taunt,
}

/// Cast priority for auto-combat kits.
enum AbilityCastTier { passive, emergency, signature, filler }

/// How the ability actually fires. HUD ready-glow is only for [cast].
enum AbilityFireMode {
  cast,
  swingRider,
  onBlock,
  dotTick,
  onHitBounce,
  passive,
}

/// Typed self-buff — catalogs this instead of matching the name string.
enum AbilitySelfBuffKind { haste, absorb, amp, healAmp, cleave, block }

/// Typed AoE layout — catalogs this instead of matching the name string.
enum AbilityAoeShape { nova, fan, rain, ground, chain }

/// Rare casts with a named helper in SpatialCombat (not a second engine).
enum AbilityCustomId {
  none,
  charge,
  shieldBlock,
  shieldSlam,
  devastate,
  demoralizingShout,
  commandingShout,
  tauntPull,
  thunderClap,
  shockwave,
  lastStand,
  shieldWall,
  painSuppression,
  powerWordFortitude,
  powerWordShield,
  prayerOfMending,
  powerInfusion,
  penance,
  iceBlock,
  blink,
  livingBomb,
  frostNova,
  blastWave,
  fireball,
  pyroblast,
  vanish,
  shadowDance,
  killingSpree,
  sprint,
  bladeFlurry,
  sliceAndDice,
  kidneyShot,
  shamanisticRage,
}

/// Picker gates that used to live in AbilityId switches.
class AbilityGate {
  const AbilityGate({
    this.packMin = 0,
    this.executeHpFrac,
    this.comboMin = 0,
    this.minRange,
    this.maxRange,
    this.minRangeMul,
    this.maxRangeMul,
    this.maxRangePad,
    this.maintainDot = false,
    this.holdLongCdOnTrash,
    this.hotStreakOnly = false,
    this.hotStreakBlocks = false,
    this.casterHpMax,
    this.requireFocus = false,
    this.needClearCorridor = false,
    this.notQueued = false,
    this.peelRange,
    this.peelScanRange = 2.4,
    this.nearbyRadius,
    this.nearPackLeader = false,
    this.anyCombatWindow = false,
    this.needsPomTarget = false,
    this.needsPiTarget = false,
    this.needsPainTarget = false,
    this.needsPenance = false,
    this.arcaneChargesMin = 0,
    this.sliceAndDiceMin = 0,
    this.focusRootMax,
    this.skipIfBleedAbove,
    this.skipIfBeaconAbove,
    this.sunderRefresh = false,
    this.livingBombRefresh = false,
    this.sliceAndDiceRefresh = false,
    this.fortitudeRefresh = false,
    this.atkShoutRefresh = false,
  });

  static const none = AbilityGate();

  final int packMin;
  final double? executeHpFrac;
  final int comboMin;
  final double? minRange;
  final double? maxRange;

  /// Minimum distance as a multiple of the caster's attack range.
  final double? minRangeMul;

  /// Maximum distance as a multiple of preferred range (blink kite).
  final double? maxRangeMul;

  /// Maximum distance = attackRange + this pad.
  final double? maxRangePad;
  final bool maintainDot;

  /// `null` = auto-hold signature CDs ≥ 30s on healthy trash.
  final bool? holdLongCdOnTrash;
  final bool hotStreakOnly;
  final bool hotStreakBlocks;
  final double? casterHpMax;
  final bool requireFocus;
  final bool needClearCorridor;
  final bool notQueued;
  final double? peelRange;
  final double peelScanRange;
  final double? nearbyRadius;
  final bool nearPackLeader;

  /// Pack / elite / execute are OR'd (Killing Spree).
  final bool anyCombatWindow;
  final bool needsPomTarget;
  final bool needsPiTarget;
  final bool needsPainTarget;
  final bool needsPenance;
  final int arcaneChargesMin;
  final int sliceAndDiceMin;
  final double? focusRootMax;
  final double? skipIfBleedAbove;
  final double? skipIfBeaconAbove;
  final bool sunderRefresh;
  final bool livingBombRefresh;
  final bool sliceAndDiceRefresh;
  final bool fortitudeRefresh;
  final bool atkShoutRefresh;
}

/// Combat abilities unlocked by hero level (WotLK-inspired kits).
enum AbilityId {
  // Warrior — Protection
  defensiveStance,
  charge,
  shieldBlock,
  thunderClap,
  devastate,
  taunt,
  demoralizingShout,
  shieldSlam,
  commandingShout,
  revenge,
  shockwave,
  lastStand,
  shieldWall,

  // Healer — Discipline Priest
  innerFire,
  powerWordShield,
  prayerOfMending,
  penance,
  powerWordFortitude,
  flashHeal,
  painSuppression,
  powerInfusion,

  // Mage — Fire
  arcaneIntellect,
  fireball,
  livingBomb,
  frostNova,
  blastWave,
  flamestrike,
  blink,
  combustion,
  pyroblast,
  iceBlock,

  // Rogue — Combat
  sinisterStrike,
  sliceAndDice,
  eviscerate,
  kidneyShot,
  bladeFlurry,
  sprint,
  vanish,
  killingSpree,
  fanOfKnivesCombat,

  // arms
  armsStance,
  mortalStrike,
  overpower,
  rend,
  sweepingStrikes,
  bladestorm,
  armsExecute,
  armsRally,

  // fury
  berserkerStance,
  bloodthirst,
  whirlwind,
  ragingBlow,
  enrageBuff,
  deathWish,
  furyExecute,
  furyRecklessness,
  enragedRegeneration,

  // holyPaladin
  holyLightAura,
  holyShock,
  flashOfLight,
  sacredShield,
  holyLight,
  beaconOfLight,
  consecrationHoly,
  divineFavor,
  layOnHands,

  // protPaladin
  righteousFury,
  avengersShield,
  holyShield,
  hammerOfTheRighteous,
  consecration,
  shieldOfRighteousness,
  holyWrath,
  divineProtection,
  handOfReckoning,

  // retribution
  sealOfCommand,
  crusaderStrike,
  judgment,
  divineStorm,
  hammerOfWrath,
  zealotry,
  templarsVerdict,
  divineShield,

  // beastMastery
  aspectOfHawk,
  arcaneShot,
  killCommand,
  multiShot,
  bestialWrath,
  intimidation,
  beastWithin,
  feignDeath,

  // marksmanship
  trueshotAura,
  steadyShot,
  aimedShot,
  chimeraShot,
  volley,
  multiShotMm,
  rapidFire,
  trueshot,
  deterrence,

  // survival
  trapMastery,
  explosiveShot,
  serpentSting,
  explosiveTrap,
  freezingTrap,
  mongooseBite,
  blackArrow,
  multiShotSurv,
  disengage,

  // assassination
  improvedPoisons,
  mutilate,
  envenom,
  garrote,
  rupture,
  coldBlood,
  fanOfKnives,
  vendetta,
  cloakOfShadows,

  // subtlety
  masterOfSubtlety,
  hemorrhage,
  backstab,
  shadowstep,
  premeditation,
  shadowDance,
  fanOfKnivesSub,
  cheapShot,
  preparation,
  eviscerateSub,

  // holyPriest
  spiritOfRedemption,
  renew,
  holyPriestFlash,
  circleOfHealing,
  guardianSpirit,
  holyPriestNova,
  divineHymn,
  desperatePrayer,

  // shadow
  shadowform,
  mindFlay,
  vampiricTouch,
  devouringPlague,
  shadowWordPain,
  mindSear,
  psychicScream,
  mindBlast,
  dispersion,

  // blood
  bloodPresence,
  deathStrike,
  heartStrike,
  runeTap,
  bloodBoil,
  deathAndDecayBlood,
  vampiricBlood,
  boneShield,
  dancingRuneWeapon,
  iceboundFortitude,
  darkCommand,

  // frostDk
  frostPresence,
  obliterate,
  frostStrike,
  howlingBlast,
  chainsOfIce,
  pillarOfFrost,
  hungeringCold,
  frostDkIbf,

  // unholy
  unholyPresence,
  scourgeStrike,
  deathCoil,
  bloodBoilUnholy,
  deathAndDecayUnholy,
  gargoyle,
  antiMagicShell,
  armyOfDead,
  unholyIbf,

  // elemental
  elementalFocus,
  lightningBolt,
  lavaBurst,
  chainLightning,
  thunderstorm,
  earthquake,
  elementalMastery,
  flameShock,
  earthShock,
  astralShift,

  // enhancement
  enhancementWeapons,
  stormstrike,
  lavaLash,
  fireNova,
  magmaTotem,
  feralSpirit,
  frostShock,
  shamanisticRage,
  enhancementAstral,

  // restorationShaman
  ancestralAwakening,
  riptide,
  healingWave,
  chainHeal,
  earthShield,
  healingRain,
  spiritLink,
  natureSwiftness,

  // arcane
  arcanePowerPassive,
  arcaneBlast,
  arcaneMissiles,
  arcaneExplosion,
  slow,
  presenceOfMind,
  arcanePower,
  arcaneIceBlock,

  // frostMage
  frostArmor,
  frostbolt,
  iceLance,
  coneOfCold,
  blizzard,
  frostNovaMage,
  icyVeins,
  summonWaterElemental,
  frostMageIceBlock,

  // affliction
  soulSiphon,
  corruption,
  unstableAffliction,
  haunt,
  drainLife,
  curseOfAgony,
  seedOfCorruption,
  hauntBurst,
  soulburn,

  // demonology
  demonicKnowledge,
  shadowBolt,
  handOfGuldan,
  hellfire,
  immolateDemo,
  metamorphosis,
  demonCharge,
  chaosBoltDemo,
  sacrifice,

  // destruction
  cataclysm,
  incinerate,
  conflagrate,
  immolateDestro,
  shadowfury,
  rainOfFire,
  backdraft,
  chaosBolt,
  shadowWard,

  // balance
  moonkinForm,
  wrath,
  starfire,
  moonfire,
  insectSwarm,
  hurricane,
  typhoon,
  starfall,
  barkskinBal,

  // feral
  catForm,
  shred,
  rake,
  ferociousBite,
  tigersFury,
  feralSwipe,
  feralThrash,
  berserk,
  rip,
  survivalInstincts,

  // guardian
  bearForm,
  mangleBear,
  swipe,
  guardianThrash,
  lacerate,
  maul,
  frenziedRegen,
  barkskinGuard,
  berserkGuard,
  survivalInstinctsGuard,
  growl,

  // restorationDruid
  treeOfLife,
  rejuvenation,
  regrowth,
  wildGrowth,
  lifebloom,
  nourish,
  tranquility,
  barkskinResto,
}

class ClassAbilityDef {
  const ClassAbilityDef({
    required this.id,
    required this.gearAffinity,
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
    this.boltStyle,
    this.vfx,
    this.fireMode = AbilityFireMode.cast,
    this.gate = AbilityGate.none,
    this.customId = AbilityCustomId.none,
    this.selfBuffKind,
    this.selfBuffDuration = 0,
    this.aoeShape,
    this.usesSpellPower,
    this.castDelaySeconds = 0,
    this.passiveOutMul = 1.0,
    this.passiveInMul = 1.0,
    this.passiveHealMul = 1.0,
    this.passiveHasteMul = 1.0,
    this.passiveRootBonus = 0.0,
    this.innerFire = false,
    this.summonCount = 0,
    this.summonDuration = 0,
    this.summonAtkScale = 0,
    this.summonName = '',
    this.summonIdPrefix = '',
    this.summonHasteSeconds = 0,
  });

  final AbilityId id;

  /// Gear/ratings affinity bucket (not SpecRoleTag).
  final HeroRole gearAffinity;
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

  /// Prefer this bolt theme when set (overrides id/keyword maps).
  final SpellBoltStyle? boltStyle;

  /// Optional cast / ground / aura VFX overrides.
  final AbilityVfxSpec? vfx;

  final AbilityFireMode fireMode;
  final AbilityGate gate;
  final AbilityCustomId customId;
  final AbilitySelfBuffKind? selfBuffKind;

  /// Seconds; 0 = kind default (haste 6 / amp 5 / others 3–6).
  final double selfBuffDuration;
  final AbilityAoeShape? aoeShape;

  /// When true, ability damage/heal scales from spell power instead of physical attack.
  final bool? usesSpellPower;

  /// Signature cast delay before damage resolves (haste reduces in combat).
  final double castDelaySeconds;

  /// Always-on kit multipliers for [AbilityEffectKind.passive] rows.
  final double passiveOutMul;
  final double passiveInMul;
  final double passiveHealMul;
  final double passiveHasteMul;
  final double passiveRootBonus;

  /// Disc Inner Fire — enables shield/heal amp in named casts.
  final bool innerFire;

  /// Temp pets via [SpatialCombat.spawnTempPets]. [summonCount] 0 = none.
  final int summonCount;
  final double summonDuration;
  final double summonAtkScale;
  final String summonName;
  final String summonIdPrefix;

  /// Optional haste window on the caster (Gargoyle reuses powerInfusionTimer).
  final double summonHasteSeconds;

  /// Infer spell vs physical scaling when [usesSpellPower] is null.
  static bool inferUsesSpellPower(ClassAbilityDef d) {
    if (d.usesSpellPower != null) return d.usesSpellPower!;
    if (d.effect == AbilityEffectKind.heal ||
        d.effect == AbilityEffectKind.emergencyHeal ||
        d.effect == AbilityEffectKind.absorb) {
      return d.gearAffinity == HeroRole.mage ||
          d.gearAffinity == HeroRole.healer;
    }
    if (d.effect != AbilityEffectKind.damage &&
        d.effect != AbilityEffectKind.aoe) {
      return false;
    }
    return d.gearAffinity == HeroRole.mage ||
        d.gearAffinity == HeroRole.healer ||
        d.boltStyle != null;
  }

  AbilityFireMode get resolvedFireMode {
    if (fireMode != AbilityFireMode.cast) return fireMode;
    if (effect == AbilityEffectKind.passive) return AbilityFireMode.passive;
    return AbilityFireMode.cast;
  }

  /// Picker may try this row (white-hit riders without a queue-cast stay out).
  bool get runnerMayCast {
    if (effect == AbilityEffectKind.passive) return false;
    return switch (resolvedFireMode) {
      AbilityFireMode.passive || AbilityFireMode.onBlock => false,
      AbilityFireMode.swingRider => customId != AbilityCustomId.none,
      _ => true,
    };
  }

  bool get showsInHud => showInHud;

  /// Hover / long-press chip text for the party HUD.
  String get tooltipMessage {
    final cd = cooldown <= 0
        ? 'Passive'
        : cooldown == cooldown.roundToDouble()
        ? 'CD ${cooldown.round()}s'
        : 'CD ${cooldown.toStringAsFixed(1)}s';
    final cost = resourceCost > 0 ? ' · Cost $resourceCost' : '';
    final shield = requiresShield ? ' · Needs shield' : '';
    final mode = switch (resolvedFireMode) {
      AbilityFireMode.swingRider => ' · Next auto',
      AbilityFireMode.onBlock => ' · After block',
      AbilityFireMode.dotTick => ' · DoT tick',
      AbilityFireMode.onHitBounce => ' · On hit',
      _ => '',
    };
    return '$name\n$description\n$cd$cost$shield$mode';
  }

  /// Party HUD: gold flash for the first beat after a dump/panic fires.
  bool justFiredHud(double cdLeft) {
    if (tier != AbilityCastTier.signature &&
        tier != AbilityCastTier.emergency) {
      return false;
    }
    if (cooldown <= 0.4) return false;
    return cdLeft > 0.05 && cdLeft >= cooldown - 0.42;
  }
}

/// Class kits adapted for Idle Party auto-combat (Wrath of the Lich King).
class ClassKits {
  ClassKits._();

  static const List<ClassAbilityDef> all = <ClassAbilityDef>[
    ..._warriorKit,
    ..._priestKit,
    ..._mageKit,
    ..._rogueKit,
    ..._paladinKit,
    ..._hunterKit,
    ..._deathKnightKit,
    ..._shamanKit,
    ..._warlockKit,
    ..._druidKit,
  ];


  static ClassAbilityDef? defFor(AbilityId id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Legacy role kits (original four specs only).
  static List<ClassAbilityDef> forRole(HeroRole role) {
    final legacySpec = HeroSpecs.fromGearAffinity(role);
    return all
        .where(
          (d) =>
              d.specId == legacySpec ||
              (d.specId == null && d.gearAffinity == role),
        )
        .toList(growable: false);
  }

  /// Abilities for a talent-tree kit. Never silently falls back to a legacy
  /// role kit — missing rows would cast the wrong class's spells.
  static List<ClassAbilityDef> forSpec(HeroSpecId specId) {
    return all.where((d) => d.specId == specId).toList(growable: false);
  }

  static bool isUnlocked(AbilityId id, int level) {
    final d = defFor(id);
    return d != null && level >= d.unlockLevel;
  }

  static List<ClassAbilityDef> unlockedAt(HeroRole role, int level) => forRole(
    role,
  ).where((d) => level >= d.unlockLevel).toList(growable: false);

  static List<ClassAbilityDef> unlockedAtSpec(HeroSpecId specId, int level) =>
      forSpec(
        specId,
      ).where((d) => level >= d.unlockLevel).toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAt(HeroRole role, int level) =>
      forRole(role)
          .where((d) => d.showsInHud && level >= d.unlockLevel)
          .toList(growable: false);

  static List<ClassAbilityDef> hudAbilitiesAtSpec(
    HeroSpecId specId,
    int level,
  ) => forSpec(specId)
      .where((d) => d.showsInHud && level >= d.unlockLevel)
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

  static String resourceLabelForSpec(HeroSpecId specId) =>
      switch (HeroSpecs.def(specId).resource) {
        SpecResource.rage => 'RAGE',
        SpecResource.mana => 'MANA',
        SpecResource.energy => 'ENERGY',
        SpecResource.runic => 'RUNIC',
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
  static List<ClassAbilityDef> get all => ClassKits.forRole(HeroRole.warrior);
  static List<ClassAbilityDef> forHero(PartyHero hero) =>
      hero.gearAffinity == HeroRole.warrior
      ? ClassKits.unlockedAtSpec(hero.specId, hero.level)
      : const [];
}
