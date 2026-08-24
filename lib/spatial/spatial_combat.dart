import 'dart:math' as math;

import '../core/blessing_constellation.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/keystone.dart';
import '../models/class_ability.dart';
import '../models/combat_ratings.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/gear_set.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/spec_mastery.dart';
import '../models/spell_bolt_style.dart';
import '../ui/kenney_assets.dart';
import 'combat_avoidance.dart';
import 'hideout_stash.dart';
import 'tile_map.dart';

export '../models/spell_bolt_style.dart';

part 'ability_effects.dart';
part 'kit_migrated_casts.dart';
part 'hero_focus.dart';
part 'combat_presence.dart';
part 'spell_vfx.dart';
part 'combat_pathing.dart';

enum SpatialTeam { hero, enemy }

bool _actorIsTank(SpatialActor h) {
  final id = h.heroSpecId;
  if (id == null) return false;
  return HeroSpecs.def(id).isTank;
}

bool _actorIsHealer(SpatialActor h) {
  final id = h.heroSpecId;
  if (id == null) return false;
  return HeroSpecs.def(id).isHealer;
}

bool _actorIsMeleeDps(SpatialActor h) {
  final id = h.heroSpecId;
  if (id == null) return false;
  return HeroSpecs.def(id).roleTag == SpecRoleTag.meleeDps;
}

/// Personal ATK fraction for BM / Demo / Unholy companions.
/// BM stays the pet-family leader; Unholy ghoul is a disease assist.
double _classCompanionAtkScale(HeroSpecId spec) {
  return switch (spec) {
    HeroSpecId.beastMastery => 0.51,
    HeroSpecId.unholy => 0.40,
    _ => 0.36,
  };
}

String _classCompanionLabel(HeroSpecId spec) {
  return switch (spec) {
    HeroSpecId.beastMastery => 'Hunter Pet',
    HeroSpecId.demonology => 'Felguard',
    HeroSpecId.unholy => 'Ghoul',
    _ => 'Pet',
  };
}

/// Resource return on a successful combat hit (melee direct or projectile).
/// [skipRageTank] when the caller already applied tank/rage-from-dealt.
void _grantCombatResource(
  SpatialActor hero, {
  required int dealt,
  bool skipRageTank = false,
}) {
  final resource = _actorResource(hero);
  if (!skipRageTank) {
    if (_actorIsTank(hero) || resource == SpecResource.rage) {
      SpatialCombat._gainRage(hero, 4 + dealt * 0.15);
    }
  }
  if (resource == SpecResource.mana && !_actorIsHealer(hero)) {
    SpatialCombat._gainRage(hero, 4);
  }
  if (resource == SpecResource.energy || resource == SpecResource.runic) {
    SpatialCombat._gainRage(hero, 5);
  }
}

SpecResource? _actorResource(SpatialActor h) {
  final id = h.heroSpecId;
  if (id != null) return HeroSpecs.def(id).resource;
  return switch (h.heroRole) {
    HeroRole.warrior => SpecResource.rage,
    HeroRole.rogue => SpecResource.energy,
    HeroRole.healer || HeroRole.mage => SpecResource.mana,
    null => null,
  };
}

bool _partyHeroIsTank(PartyHero hero) => hero.spec.isTank;

MasteryCombatant _masteryView(SpatialActor a) => MasteryCombatant(
  specId: a.heroSpecId,
  masteryPoints: a.masteryPoints,
  rage: a.rage,
  hp: a.hp,
  maxHp: a.effectiveMaxHp,
  rooted: a.rootTimer > 0,
  eclipseArcane: (a.buffTimers['eclipse_arcane'] ?? 0) > 0,
  eclipseNature: (a.buffTimers['eclipse_nature'] ?? 0) > 0,
);

void _applyEnemyRoot(SpatialActor enemy, double baseDuration) {
  final dr = enemy.ccRootDrLevel;
  final dur = CombatAvoidance.ccRootDuration(baseDuration, dr);
  if (dur <= 0) return;
  enemy.rootTimer = math.max(enemy.rootTimer, dur);
  enemy.ccRootDrLevel = math.min(3, dr + 1);
}

void _syncHeroCataStats(SpatialActor actor, PartyHero hero, GameState state) {
  final ratings = state.ratingsFor(hero);
  actor.attack = state.effectiveHeroAttack(hero);
  actor.physicalAttack = ratings.physicalAttack;
  actor.spellPower = ratings.spellPower;
  actor.dodgePercent = ratings.dodgePercent;
  actor.parryPercent = ratings.parryPercent;
  actor.masteryPoints = ratings.masteryPoints;
  actor.blockChance = SpecMastery.blockChance(
    MasteryCombatant(
      specId: hero.specId,
      masteryPoints: ratings.masteryPoints,
    ),
  ) + BlessingConstellation.blockChanceAdd(state);
  actor.uncrittable = hero.spec.isTank;
  actor.defense = state.effectiveHeroDefense(hero);
}

class SpatialActor {
  SpatialActor({
    required this.id,
    required this.name,
    required this.team,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.moveSpeed,
    required this.attackRange,
    required this.attackCooldown,
    this.assetIndex = 0,
    this.role = EnemyRole.normal,
    this.archetype = EnemyArchetype.brute,
    this.heroRole,
    this.heroSpecId,
    this.partyIndex,
    this.heroLevel = 1,
    this.fireCooldown = 0,
    this.pattern = ProjectilePattern.single,
    this.ranged = false,
    this.preferredRange,
    this.chamberIndex = 0,
    this.isPet = false,
    this.petOwnerId,
    this.petLifeTimer = 0,
    this.dormant = false,
    this.blockValue = 0,
    this.spiritRegenBonus = 0,
    this.mp5RegenBonus = 0,
    this.physicalAttack = 0,
    this.spellPower = 0,
    this.dodgePercent = 0,
    this.parryPercent = 0,
    this.blockChance = 0,
    this.masteryPoints = 0,
    this.uncrittable = false,
  });

  final String id;
  final String name;
  final SpatialTeam team;
  double x;
  double y;
  int hp;
  int maxHp;
  int attack;
  int defense;
  int physicalAttack;
  int spellPower;
  double dodgePercent;
  double parryPercent;
  double blockChance;
  double masteryPoints;
  bool uncrittable;
  double moveSpeed;
  final double attackRange;
  double attackCooldown;
  final int assetIndex;
  final EnemyRole role;
  final EnemyArchetype archetype;
  final HeroRole? heroRole;

  /// Talent-tree kit identity (party heroes).
  final HeroSpecId? heroSpecId;

  /// Index into [GameState.heroes] when this is a party member.
  final int? partyIndex;

  /// Snapshot of hero level for ability unlock checks.
  int heroLevel;

  double fireCooldown;
  final ProjectilePattern pattern;
  final bool ranged;
  final double? preferredRange;
  final int chamberIndex;
  final bool isPet;

  /// Hero id that owns a temporary summon (Army / Spirit Wolves).
  final String? petOwnerId;

  /// Seconds remaining for temporary pets; 0 = permanent companion.
  double petLifeTimer;

  /// Flat damage blocked while Shield Block is active (Str/20).
  final int blockValue;

  /// Extra mana regen /s from Spirit (casters).
  final double spiritRegenBonus;

  /// Extra mana regen /s from Mp5 gear.
  final double mp5RegenBonus;

  /// Seconds until Spirit regen recovers after taking damage (5SR).
  double spiritRegenPaused = 0;

  /// CC diminishing-return stack for roots/stuns.
  int ccRootDrLevel = 0;

  /// Cast-bar lockout for signature spells.
  double castingTimer = 0;
  String? pendingCastDef;

  /// Waiting for chamber unlock (gated rooms).
  bool dormant;

  /// Brief visual punch when the actor attacks (seconds remaining).
  double attackFlash = 0;

  /// World aim of the last attack (for lunge / facing during [attackFlash]).
  double attackAimX = 0;
  double attackAimY = 0;

  /// Smoothed facing aim (lerps toward attack / move target).
  double faceAimX = 0;
  double faceAimY = 0;

  /// Steering velocity in tiles/sec (soft inertia).
  double vx = 0;
  double vy = 0;

  /// 0–1 personality: higher breaks pack leash sooner / prefers nearer foes.
  double impatience = 0.5;

  /// Preferred-range multiplier (Fire panic kite >1, Arcane closer <1).
  double kiteMul = 1.0;

  /// Sidestep bias while kiting (−1 / +1).
  double kiteSide = 0;

  /// Seconds until another speech bark may fire.
  double barkCd = 0;

  /// One low-HP bark per distress streak.
  bool lowHpBarked = false;

  /// Class resource 0?100 (rage / mana / energy).
  double rage = 0;

  /// Per-ability cooldown remaining (AbilityId.name ? seconds).
  final Map<String, double> abilityCd = <String, double>{};

  double shieldBlockTimer = 0;
  double shieldWallTimer = 0;
  double lastStandTimer = 0;
  int bonusMaxHp = 0;

  /// Brief VFX/HUD flag after Shockwave.
  double shockwaveFlash = 0;

  /// Next melee is Shield Slam / Revenge empowered.
  bool queuedShieldSlam = false;
  bool revengeReady = false;

  // ?? Disc Priest (WotLK) ??
  int absorbShield = 0;
  double painSuppressionTimer = 0;
  double fortitudeTimer = 0;
  int pomCharges = 0;
  int pomHeal = 0;
  double powerInfusionTimer = 0;

  /// Inner Fire glow (always-on visual while unlocked & alive).
  bool innerFireActive = false;

  /// Always-on kit passive multipliers (refreshed each ability tick).
  double kitOutMul = 1.0;
  double kitInMul = 1.0;
  double kitHealMul = 1.0;
  double kitHasteMul = 1.0;
  double kitRootBonus = 0.0;

  /// Dungeon armor 4pc on-hit proc (from [GearSets.fourPieceProc]).
  double setProcChance = 0;
  String? setProcTag;
  int setProcArgb = 0xFFFFD070;

  // ?? Mage (Fire) ??
  /// Damage amp window (Fire Combustion, Assa Vendetta/Cold Blood, Arcane Power).
  double combustionTimer = 0;
  double iceBlockTimer = 0;

  /// While a Living Bomb you cast is still ticking on any foe.
  double livingBombArmed = 0;

  /// Fire Hot Streak: consecutive Fireball crits → free Pyroblast.
  int hotStreakStack = 0;
  bool hotStreakReady = false;

  /// Arcane Blast charges (0–4); Missiles dump spends them.
  int arcaneCharges = 0;

  /// Holy Paladin Beacon: heals peel onto this ally while [beaconTimer] > 0.
  String? beaconTargetId;
  double beaconTimer = 0;

  // ?? Rogue (Combat) ??
  int comboPoints = 0;
  double sliceAndDiceTimer = 0;
  double bladeFlurryTimer = 0;
  double sprintTimer = 0;
  double vanishTimer = 0;
  double killingSpreeTimer = 0;

  /// Enemy: forced to attack [forcedTargetId] while timer > 0.
  String? forcedTargetId;
  double forcedTargetTimer = 0;

  /// Hero: sticky combat focus (runtime only; not saved).
  String? focusEnemyId;

  /// Hero: soft lock after acquiring [focusEnemyId] (seconds).
  double focusLockTimer = 0;

  /// Enemy: attack cadence slowed while > 0.
  double attackSlowTimer = 0;

  /// Enemy enrage (tank low-HP / boss phase).
  double enrageTimer = 0;

  /// Periodic boss/elite special ability cooldown.
  double specialCd = 0;

  /// Sunder Armor stacks (max 5) while [sunderTimer] > 0.
  int sunderStacks = 0;
  double sunderTimer = 0;

  /// Demoralizing Shout: reduced attack while > 0.
  double demoShoutTimer = 0;

  /// Living Bomb DoT (Fire Mage).
  double livingBombTimer = 0;
  double livingBombDps = 0;
  double livingBombAcc = 0;
  String? livingBombCasterId;

  /// Generic bleed DoT (Rip / Rake / Rend / Affliction / Shadow).
  double bleedTimer = 0;
  double bleedDps = 0;
  double bleedAcc = 0;
  String? bleedCasterId;

  /// Last ability id that applied [bleedTimer] (maintain / stack checks).
  String? bleedAbilityId;

  /// Ally heal-over-time (Riptide / Renew / Rejuvenation).
  double hotHps = 0;
  double hotAcc = 0;

  /// Cumulative combat stats this floor (heroes only; for party meter).
  int damageDealt = 0;
  int healingDone = 0;
  int damageTaken = 0;

  /// Root / stun (Frost Nova, Kidney Shot).
  double rootTimer = 0;

  /// Generic buff timers for data-driven kits (haste / shield / …).
  final Map<String, double> buffTimers = <String, double>{};

  /// Dormancy prevents combat actions, not life-state checks or healing.
  bool get isAlive => hp > 0;

  int get effectiveMaxHp {
    var bonus = bonusMaxHp;
    if (fortitudeTimer > 0) bonus += math.max(6, (maxHp * 0.12).round());
    return maxHp + bonus;
  }

  int get effectiveDefense {
    if (sunderTimer <= 0 || sunderStacks <= 0) return defense;
    return math.max(0, defense - sunderStacks * 2);
  }

  int get effectiveAttack {
    var atk = attack;
    if (demoShoutTimer > 0) atk = (atk * 0.8).round();
    if (enrageTimer > 0) atk = (atk * 1.35).round();
    return math.max(1, atk);
  }

  double get moveSpeedMul {
    var m = 1.0;
    if (sprintTimer > 0) m *= 1.28;
    if (enrageTimer > 0 && team == SpatialTeam.enemy) m *= 1.25;
    if (rootTimer > 0) m = 0;
    if (iceBlockTimer > 0) m = 0;
    if (vanishTimer > 0) m *= 1.2;
    if ((buffTimers['haste'] ?? 0) > 0) m *= 1.12;
    return m;
  }

  double get attackSpeedMul {
    var m = kitHasteMul;
    if (sliceAndDiceTimer > 0) m *= 1.35;
    // Combat Spree: haste fantasy without turning pack whites into a blender.
    if (killingSpreeTimer > 0) m *= 1.18;
    if (powerInfusionTimer > 0) {
      final caster =
          heroSpecId != null &&
          HeroSpecs.def(heroSpecId!).roleTag == SpecRoleTag.caster;
      m *= caster ? 1.22 : 1.4;
    }
    // Combustion amps spell damage elsewhere — do not also haste whites.
    if (iceBlockTimer > 0) m = 0;
    return m;
  }
}

class SpatialProjectile {
  SpatialProjectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    required this.team,
    this.life = 1.6,
    this.pierce = false,
    this.hitsRemaining = 1,
    this.isCrit = false,
    this.style = SpellBoltStyle.weapon,
    this.label,
    this.labelArgb,
    this.radius = 0.12,
    this.delay = 0,
    this.onHitHealCaster = false,
    this.casterId,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final int damage;
  final SpatialTeam team;
  double life;
  final bool pierce;
  int hitsRemaining;
  final bool isCrit;
  final SpellBoltStyle style;
  final String? label;
  final int? labelArgb;
  final double radius;

  /// Seconds before the bolt starts moving (staggered casts like Penance).
  double delay;

  /// Disc: bolt damage lightly tops the party when it lands.
  final bool onHitHealCaster;
  final String? casterId;
}

class GroundLoot {
  GroundLoot({
    required this.x,
    required this.y,
    required this.drop,
    this.age = 0,
  });

  double x;
  double y;
  final LootDrop drop;
  double age;

  GroundLootKind get kind {
    if (drop.isEquipment) {
      return drop.rarity.index >= LootRarity.epic.index
          ? GroundLootKind.chest
          : GroundLootKind.gear;
    }
    final name = drop.name.toLowerCase();
    if (name.contains('gold') ||
        name.contains('coin') ||
        name.contains('pouch')) {
      return GroundLootKind.gold;
    }
    return GroundLootKind.essence;
  }
}

enum GroundLootKind { gold, essence, gear, chest }

enum SpatialFloaterKind {
  /// Damage / heal / loot numbers.
  combat,

  /// Short speech bark above a hero.
  speech,
}

class SpatialFloater {
  SpatialFloater({
    required this.x,
    required this.y,
    required this.text,
    required this.argb,
    this.life = 0.55,
    this.vx = 0,
    this.vy = -2.1,
    this.priority = 0,
    this.kind = SpatialFloaterKind.combat,
  });

  double x;
  double y;
  double life;
  double vx;
  double vy;
  final String text;
  final int argb;

  /// 0 = routine damage, 1 = heal/ability, 2 = crit/loot/wipe-critical.
  final int priority;

  final SpatialFloaterKind kind;
}

class SpatialBurst {
  SpatialBurst({
    required this.x,
    required this.y,
    this.life = 0.35,
    this.argb = 0xFFFFC14A,
    this.radius = 0.55,
    this.angle,
    this.slash = false,
    this.kind = SpatialBurstKind.blast,
    this.x2,
    this.y2,
  });

  double x;
  double y;
  double life;
  final int argb;
  final double radius;

  /// Radians; used when [slash] is true or [kind] is cone.
  final double? angle;
  final bool slash;
  final SpatialBurstKind kind;

  /// Optional beam end (Lightning Bolt, Chain Lightning, Holy Shock).
  final double? x2;
  final double? y2;
}

enum SpatialBurstKind {
  /// Soft filled disc (default impact).
  blast,

  /// Weapon swing arc.
  slash,

  /// Expanding hollow ring (Blast Wave, Nova, Shockwave).
  ring,

  /// Forward cone wedge (Shockwave).
  cone,

  /// Tiny spark ticks (PoM bounce, Living Bomb fuse).
  spark,

  /// Line / zigzag (lightning, holy shock, penance).
  beam,

  /// Falling streaks (Blizzard, Hurricane, Volley, Healing Rain).
  rain,

  /// Ice crystals (Frostbolt shatter, Howling Blast, Frost Nova).
  shards,

  /// Flame petals (Fireball, Immolate, Fire Nova).
  flame,

  /// Holy cross / rays (Holy Shock, Consecration pop, Divine Storm).
  cross,

  /// Poison / nature drips (Envenom, Wrath, Healing Wave).
  poison,

  /// Shadow swirl (Shadow Bolt, Death Coil, Mind Blast).
  skull,
}

enum SpatialGroundFxKind {
  disc,
  holy,
  frost,
  fire,
  rain,
  shadow,
  nature,
  steel,
}

/// Lasting ground disc (Consecration / Bladestorm / Shadowfury).
class SpatialGroundFx {
  SpatialGroundFx({
    required this.x,
    required this.y,
    required this.radius,
    required this.argb,
    required this.life,
    required this.maxLife,
    this.kind = SpatialGroundFxKind.disc,
  });

  double x;
  double y;
  double radius;
  int argb;
  double life;
  double maxLife;
  final SpatialGroundFxKind kind;
}

class SpatialWorld {
  SpatialWorld({
    required this.map,
    required this.heroes,
    required this.enemies,
    required this.projectiles,
    required this.groundLoot,
    required this.isTreasure,
    this.treasureOpen = false,
    this.treasureTimer = 0,
    this.awaitingExit = false,
    this.exitWaitTimer = 0,
    this.guideX,
    this.guideY,
    this.guideTimer = 0,
    this.godHandCooldown = 0,
    this.mendTimer = 0,
    this.activeChamber = 0,
    Set<int>? openGateIds,
    Set<int>? clearedChambers,
    this.pets = const <SpatialActor>[],
    this.pulseX,
    this.pulseY,
    this.pulseTimer = 0,
    this.bossBannerTimer = 0,
    this.bossBannerName = '',
    this.afkAssist = false,
    this.combatElapsed = 0,
    this.petMitigateFlat = 0,
    this.petHealBoost = 0,
    this.pendingAbilityCasts = 0,
    this.pendingFeelCrits = 0,
    this.pendingFeelLevelUps = 0,
    this.pendingFeelKills = 0,
    this.pendingFeelPickups = 0,
    this.pendingFeelStairs = 0,
    this.godHandRadius = 1.8,
    this.bagFullFloaterCooldown = 0,
    List<SpatialFloater>? floaters,
    List<SpatialBurst>? bursts,
    List<SpatialGroundFx>? groundFx,
  }) : openGateIds = openGateIds ?? <int>{},
       clearedChambers = clearedChambers ?? <int>{},
       floaters = floaters ?? <SpatialFloater>[],
       bursts = bursts ?? <SpatialBurst>[],
       groundFx = groundFx ?? <SpatialGroundFx>[];

  final TileMap map;
  final List<SpatialActor> heroes;
  final List<SpatialActor> enemies;
  final List<SpatialProjectile> projectiles;
  final List<GroundLoot> groundLoot;
  final List<SpatialActor> pets;
  final List<SpatialFloater> floaters;
  final List<SpatialBurst> bursts;
  final List<SpatialGroundFx> groundFx;
  final bool isTreasure;

  /// When true, enemy outgoing damage is softened (offline AFK sim).
  final bool afkAssist;
  bool treasureOpen;
  double treasureTimer;
  bool awaitingExit;

  /// Seconds spent in [awaitingExit] (anti soft-lock).
  double exitWaitTimer;
  double? guideX;
  double? guideY;
  double guideTimer;
  double godHandCooldown;
  double mendTimer;
  int activeChamber;
  final Set<int> openGateIds;
  final Set<int> clearedChambers;
  double? pulseX;
  double? pulseY;
  double pulseTimer;
  double bossBannerTimer;
  String bossBannerName;

  /// Seconds of active combat this floor (for DPS meter).
  double combatElapsed;

  /// Flat incoming damage reduction from mitigate pets.
  int petMitigateFlat;

  /// Extra heal potency from heal-boost pets.
  int petHealBoost;

  /// Ability casts this [SpatialCombat.step] (flushed into [SpatialStepResult]).
  int pendingAbilityCasts;

  /// Crit hits this step (audio/haptics; counted even when VFX is reduced).
  int pendingFeelCrits;

  /// Hero level-ups this step (audio/haptics; counted even when VFX is reduced).
  int pendingFeelLevelUps;

  /// Enemies slain this step (audio/haptics; counted even when VFX is reduced).
  int pendingFeelKills;

  /// Ground-loot pickups this step (audio/haptics).
  int pendingFeelPickups;

  /// Stairs just opened this step (GO juice).
  int pendingFeelStairs;

  /// Cached God Hand radius for guide ring paint (set on cast).
  double godHandRadius;

  /// Suppress stacked "BAG FULL +Ne" floaters while salvage spam is high.
  double bagFullFloaterCooldown;

  int get cols => map.cols;
  int get rows => map.rows;

  bool get allEnemiesDead => enemies.isEmpty || enemies.every((e) => e.hp <= 0);

  bool get allHeroesDead => heroes.isEmpty || heroes.every((h) => h.hp <= 0);

  bool get allChambersCleared {
    if (map.chambers.isEmpty) return allEnemiesDead;
    return clearedChambers.length >= map.chambers.length ||
        (allEnemiesDead && openGateIds.length >= map.gates.length);
  }

  SpatialActor? get leader {
    for (final h in heroes) {
      if (h.hp > 0 && _actorIsTank(h)) return h;
    }
    for (final h in heroes) {
      if (h.hp > 0) return h;
    }
    return null;
  }

  bool canWalk(double x, double y) =>
      map.isWalkableWorld(x, y, openGateIds: openGateIds);

  bool canWalkTile(int x, int y) =>
      map.isWalkable(x, y, openGateIds: openGateIds);
}

class SpatialStepResult {
  const SpatialStepResult({
    required this.world,
    required this.state,
    this.roomCleared = false,
    this.partyWiped = false,
    this.goldFromKills = 0,
    this.kills = 0,
    this.abilityCasts = 0,
    this.critHits = 0,
    this.heroLevelUps = 0,
    this.lootPickups = 0,
    this.stairsOpened = false,
  });

  final SpatialWorld world;
  final GameState state;
  final bool roomCleared;
  final bool partyWiped;
  final int goldFromKills;

  /// Enemies slain this result (God Hand / step kill bank).
  final int kills;
  final int abilityCasts;

  /// Crits landed this result — live juice only (offline ignores).
  final int critHits;

  /// Party members who gained a level this result.
  final int heroLevelUps;

  /// Ground loot collected this result (audio/haptics).
  final int lootPickups;

  /// Floor is cleared and the stairs just opened this result.
  final bool stairsOpened;
}

abstract final class SpatialCombat {
  static int get cols => 30;
  static int get rows => 22;

  /// Accessibility: swaps combat floaters to an Okabe-Ito colorblind-safe
  /// palette (avoids relying on red/green hue alone to distinguish types).
  static bool colorblindMode = false;

  static int get _floaterDamage => colorblindMode ? 0xFFD55E00 : 0xFFFF6A4A;
  static int get _floaterCrit => colorblindMode ? 0xFFF0E442 : 0xFFFFC14A;
  static int get _floaterGold => colorblindMode ? 0xFFE69F00 : 0xFFFFE08A;
  static int get _floaterEssence => colorblindMode ? 0xFF56B4E9 : 0xFF7EC8FF;
  static int get _floaterGear => colorblindMode ? 0xFF0072B2 : 0xFFB8E986;
  static int get _floaterHeal => colorblindMode ? 0xFFCC79A7 : 0xFF7AAB6E;
  static int get _floaterXp => colorblindMode ? 0xFF009E73 : 0xFF9AD0FF;
  static int get _floaterPet => colorblindMode ? 0xFF56B4E9 : 0xFF7CE8FF;

  static const int _maxFloaters = 12;
  static const int _maxBursts = 22;
  static const int _maxProjectiles = 36;
  static const int _maxGroundFx = 6;

  static void _spawnFloater(
    SpatialWorld world, {
    required double x,
    required double y,
    required String text,
    required int argb,
    double life = 0.55,
    int priority = 0,
    SpatialFloaterKind kind = SpatialFloaterKind.combat,
  }) {
    // Skip empty / whitespace-only.
    if (text.isEmpty) return;
    // Combat spam: at most a few routine hit numbers on screen.
    if (priority <= 0) {
      var routine = 0;
      for (final f in world.floaters) {
        if (f.priority <= 0) routine++;
      }
      if (routine >= 4) return;
    }
    // One shoutout of the same word nearby (stops stacked OPEN / GO).
    if (priority >= 2) {
      for (final f in world.floaters) {
        if (f.text == text &&
            f.priority >= 2 &&
            (f.x - x).abs() < 3.5 &&
            (f.y - y).abs() < 3.5) {
          return;
        }
      }
    }
    // Stagger stack at the same tile so gold/XP/loot don't fully overlap.
    var nearby = 0;
    for (final f in world.floaters) {
      if ((f.x - x).abs() < 0.7 && (f.y - y).abs() < 1.0) nearby++;
    }
    final lane = nearby % 5;
    final jx = (lane - 2) * 0.22;
    final jy = (lane % 3) * 0.12;
    final speech = kind == SpatialFloaterKind.speech;
    world.floaters.add(
      SpatialFloater(
        x: x + (speech ? 0 : jx),
        y: y - (speech ? 0 : jy),
        text: text,
        argb: argb,
        life: life,
        vx: speech ? 0 : jx * 0.35,
        vy: speech ? -0.55 : (-2.1 - lane * 0.08),
        priority: priority,
        kind: kind,
      ),
    );
    _trimFloaters(world);
  }

  /// Melee / bolt hit numbers — crits always, routine hits throttled.
  static void _spawnHitFloater(
    SpatialWorld world, {
    required double x,
    required double y,
    required int dealt,
    required bool isCrit,
    int? abilityArgb,
    math.Random? rng,
  }) {
    if (dealt <= 0) return;
    final ability = abilityArgb != null;
    // Skip most white hits so a 5-man pack doesn't wallpaper the phone.
    if (!isCrit && !ability) {
      final r = rng ?? math.Random();
      if (r.nextDouble() > 0.28) return;
    }
    _spawnFloater(
      world,
      x: x,
      y: y,
      text: '$dealt',
      argb: isCrit
          ? _floaterCrit
          : (abilityArgb ?? _floaterDamage),
      life: isCrit ? 0.55 : (ability ? 0.45 : 0.32),
      priority: isCrit ? 2 : (ability ? 1 : 0),
    );
  }

  /// Prefer a word-boundary cut so loot names stay readable.
  static String _shortFloaterLabel(String text, {int max = 20}) {
    final t = text.trim();
    if (t.length <= max) return t;
    final cut = t.substring(0, max - 1);
    final sp = cut.lastIndexOf(' ');
    if (sp >= 6) return '${cut.substring(0, sp)}…';
    return '$cut…';
  }

  static void _trimFloaters(SpatialWorld world) {
    while (world.floaters.length > _maxFloaters) {
      var dropAt = 0;
      var best = world.floaters[0];
      for (var i = 1; i < world.floaters.length; i++) {
        final f = world.floaters[i];
        if (f.priority < best.priority ||
            (f.priority == best.priority && f.life < best.life)) {
          best = f;
          dropAt = i;
        }
      }
      world.floaters.removeAt(dropAt);
    }
  }

  static void _addProjectile(SpatialWorld world, SpatialProjectile p) {
    world.projectiles.add(p);
    if (world.projectiles.length > _maxProjectiles) {
      world.projectiles.removeRange(
        0,
        world.projectiles.length - _maxProjectiles,
      );
    }
  }

  static void _addProjectiles(
    SpatialWorld world,
    Iterable<SpatialProjectile> list,
  ) {
    for (final p in list) {
      _addProjectile(world, p);
    }
  }

  static void _spawnBurst(
    SpatialWorld world, {
    required double x,
    required double y,
    int argb = 0xFFFFC14A,
    double radius = 0.55,
    double? angle,
    bool slash = false,
    double life = 0.35,
    SpatialBurstKind kind = SpatialBurstKind.blast,
    double? x2,
    double? y2,
  }) {
    if (world.bursts.length >= _maxBursts) {
      world.bursts.removeAt(0);
    }
    world.bursts.add(
      SpatialBurst(
        x: x,
        y: y,
        argb: argb,
        radius: radius,
        angle: angle,
        slash: slash || kind == SpatialBurstKind.slash,
        life: life,
        kind: slash ? SpatialBurstKind.slash : kind,
        x2: x2,
        y2: y2,
      ),
    );
  }

  static void _spawnRing(
    SpatialWorld world, {
    required double x,
    required double y,
    required int argb,
    double radius = 1.2,
    double life = 0.4,
  }) {
    _spawnBurst(
      world,
      x: x,
      y: y,
      argb: argb,
      radius: radius,
      life: life,
      kind: SpatialBurstKind.ring,
    );
  }

  static void _spawnGroundFx(
    SpatialWorld world, {
    required double x,
    required double y,
    required int argb,
    double radius = 2.7,
    double life = 4.5,
    SpatialGroundFxKind kind = SpatialGroundFxKind.disc,
  }) {
    if (world.groundFx.length >= _maxGroundFx) {
      world.groundFx.removeAt(0);
    }
    world.groundFx.add(
      SpatialGroundFx(
        x: x,
        y: y,
        radius: radius,
        argb: argb,
        life: life,
        maxLife: life,
        kind: kind,
      ),
    );
  }

  /// Mid-fight flask heal feedback on living heroes.
  static void spawnFlaskHealFx(SpatialWorld world, {required bool reducedVfx}) {
    if (reducedVfx) return;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      _spawnRing(
        world,
        x: h.x,
        y: h.y,
        argb: 0xFF60E080,
        radius: 0.95,
        life: 0.45,
      );
      _spawnSpark(world, x: h.x, y: h.y - 0.15, argb: 0xFFA0FFB0, radius: 0.4);
      _spawnFloater(
        world,
        x: h.x,
        y: h.y - 0.45,
        text: 'FLASK',
        argb: 0xFF70F090,
        life: 1.2,
        priority: 2,
      );
    }
  }

  static void _spawnCone(
    SpatialWorld world, {
    required double x,
    required double y,
    required double angle,
    required int argb,
    double radius = 1.6,
    double life = 0.38,
  }) {
    _spawnBurst(
      world,
      x: x,
      y: y,
      argb: argb,
      radius: radius,
      angle: angle,
      life: life,
      kind: SpatialBurstKind.cone,
    );
  }

  static void _spawnSpark(
    SpatialWorld world, {
    required double x,
    required double y,
    required int argb,
    double radius = 0.35,
    double life = 0.28,
  }) {
    _spawnBurst(
      world,
      x: x,
      y: y,
      argb: argb,
      radius: radius,
      life: life,
      kind: SpatialBurstKind.spark,
    );
  }

  static void _spawnSlash(
    SpatialWorld world, {
    required SpatialActor from,
    required SpatialActor to,
    required bool isCrit,
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final angle = math.atan2(dy, dx);
    final warrior = from.heroRole == HeroRole.warrior;
    final rogue = from.heroRole == HeroRole.rogue;
    // WoW-like weapon swing: wide arc near the attacker, impact spark on target.
    _spawnBurst(
      world,
      x: from.x + dx * 0.35,
      y: from.y + dy * 0.35,
      argb: isCrit
          ? _floaterCrit
          : (warrior ? 0xFFFFD070 : (rogue ? 0xFFFFB0C0 : 0xFFFFE8A0)),
      radius: warrior ? (isCrit ? 1.35 : 1.15) : (isCrit ? 1.0 : 0.8),
      angle: angle,
      slash: true,
      life: warrior ? (isCrit ? 0.42 : 0.34) : (isCrit ? 0.32 : 0.24),
    );
    // Second trailing arc (heavier weapons).
    if (warrior || isCrit) {
      _spawnBurst(
        world,
        x: from.x + dx * 0.55,
        y: from.y + dy * 0.55,
        argb: 0x88FFF8E0,
        radius: warrior ? 0.95 : 0.7,
        angle: angle + 0.25,
        slash: true,
        life: 0.22,
      );
    }
    _spawnBurst(
      world,
      x: to.x,
      y: to.y,
      argb: isCrit ? _floaterCrit : 0xFFFFC14A,
      radius: warrior ? 0.55 : 0.35,
      life: 0.18,
    );
  }

  static void _setAttackAnim(SpatialActor from, SpatialActor to, double life) {
    from.attackFlash = life;
    from.attackAimX = to.x;
    from.attackAimY = to.y;
    // Facing catches up smoothly; punch aim snaps for the lunge.
    CombatPresence.updateFacing(from, to.x, to.y, 0.08);
  }

  static void _tickCombatBuffs(SpatialWorld world, double dt) {
    for (final a in world.heroes) {
      _tickActorBuffs(world, a, dt);
    }
    for (final a in world.enemies) {
      _tickActorBuffs(world, a, dt);
    }
    for (final a in world.pets) {
      _tickActorBuffs(world, a, dt);
    }
  }

  static void _tickActorBuffs(SpatialWorld world, SpatialActor a, double dt) {
    if (a.shieldBlockTimer > 0) {
      a.shieldBlockTimer = math.max(0, a.shieldBlockTimer - dt);
    }
    if (a.shieldWallTimer > 0) {
      a.shieldWallTimer = math.max(0, a.shieldWallTimer - dt);
    }
    if (a.lastStandTimer > 0) {
      a.lastStandTimer = math.max(0, a.lastStandTimer - dt);
      if (a.lastStandTimer <= 0 && a.bonusMaxHp > 0) {
        a.bonusMaxHp = 0;
        if (a.hp > a.effectiveMaxHp) a.hp = a.effectiveMaxHp;
      }
    }
    if (a.forcedTargetTimer > 0) {
      a.forcedTargetTimer = math.max(0, a.forcedTargetTimer - dt);
      if (a.forcedTargetTimer <= 0) a.forcedTargetId = null;
    }
    if (a.focusLockTimer > 0) {
      a.focusLockTimer = math.max(0, a.focusLockTimer - dt);
    }
    if (a.attackSlowTimer > 0) {
      a.attackSlowTimer = math.max(0, a.attackSlowTimer - dt);
    }
    if (a.enrageTimer > 0) {
      a.enrageTimer = math.max(0, a.enrageTimer - dt);
    }
    if (a.specialCd > 0) {
      a.specialCd = math.max(0, a.specialCd - dt);
    }
    if (a.sunderTimer > 0) {
      a.sunderTimer = math.max(0, a.sunderTimer - dt);
      if (a.sunderTimer <= 0) a.sunderStacks = 0;
    }
    if (a.demoShoutTimer > 0) {
      a.demoShoutTimer = math.max(0, a.demoShoutTimer - dt);
    }
    if (a.livingBombTimer > 0) {
      a.livingBombTimer = math.max(0, a.livingBombTimer - dt);
      if (a.livingBombTimer <= 0) {
        a.livingBombDps = 0;
        a.livingBombCasterId = null;
      }
    }
    if (a.bleedTimer > 0) {
      a.bleedTimer = math.max(0, a.bleedTimer - dt);
      if (a.bleedTimer <= 0) {
        a.bleedDps = 0;
        a.bleedAcc = 0;
        a.bleedCasterId = null;
        a.bleedAbilityId = null;
      }
    }
    if (a.rootTimer > 0) {
      a.rootTimer = math.max(0, a.rootTimer - dt);
    } else if (a.ccRootDrLevel > 0) {
      a.ccRootDrLevel = math.max(0, a.ccRootDrLevel - 1);
    }
    if (a.castingTimer > 0) {
      a.castingTimer = math.max(0, a.castingTimer - dt);
      if (a.castingTimer <= 0) a.pendingCastDef = null;
    }
    if (a.spiritRegenPaused > 0) {
      a.spiritRegenPaused = math.max(0, a.spiritRegenPaused - dt);
    }
    if (a.painSuppressionTimer > 0) {
      a.painSuppressionTimer = math.max(0, a.painSuppressionTimer - dt);
    }
    if (a.fortitudeTimer > 0) {
      a.fortitudeTimer = math.max(0, a.fortitudeTimer - dt);
      if (a.fortitudeTimer <= 0 && a.hp > a.effectiveMaxHp) {
        a.hp = a.effectiveMaxHp;
      }
    }
    if (a.powerInfusionTimer > 0) {
      a.powerInfusionTimer = math.max(0, a.powerInfusionTimer - dt);
    }
    if (a.combustionTimer > 0) {
      a.combustionTimer = math.max(0, a.combustionTimer - dt);
    }
    if (a.beaconTimer > 0) {
      a.beaconTimer = math.max(0, a.beaconTimer - dt);
      if (a.beaconTimer <= 0) a.beaconTargetId = null;
    }
    if (a.iceBlockTimer > 0) {
      a.iceBlockTimer = math.max(0, a.iceBlockTimer - dt);
    }
    if (a.sliceAndDiceTimer > 0) {
      a.sliceAndDiceTimer = math.max(0, a.sliceAndDiceTimer - dt);
    }
    if (a.bladeFlurryTimer > 0) {
      a.bladeFlurryTimer = math.max(0, a.bladeFlurryTimer - dt);
    }
    if (a.sprintTimer > 0) {
      a.sprintTimer = math.max(0, a.sprintTimer - dt);
    }
    if (a.vanishTimer > 0) {
      a.vanishTimer = math.max(0, a.vanishTimer - dt);
    }
    if (a.killingSpreeTimer > 0) {
      a.killingSpreeTimer = math.max(0, a.killingSpreeTimer - dt);
    }
    if (a.shockwaveFlash > 0) {
      a.shockwaveFlash = math.max(0, a.shockwaveFlash - dt);
    }
    if (a.livingBombArmed > 0) {
      a.livingBombArmed = math.max(0, a.livingBombArmed - dt);
      // Desync guard: no live bomb on any foe → clear armed chip.
      if (a.livingBombArmed > 0 &&
          !world.enemies.any(
            (e) =>
                e.hp > 0 &&
                e.livingBombTimer > 0 &&
                e.livingBombCasterId == a.id,
          )) {
        a.livingBombArmed = 0;
      }
    }
    _CombatPathing.tickStringTimers(a.abilityCd, dt);
    _CombatPathing.tickStringTimers(
      a.buffTimers,
      dt,
      onExpire: (key) {
        if (key == 'hot') {
          a.hotHps = 0;
          a.hotAcc = 0;
        }
      },
    );
    // Ally HoT ticks (Riptide / Renew / Rejuv).
    if (a.team == SpatialTeam.hero &&
        a.hp > 0 &&
        (a.buffTimers['hot'] ?? 0) > 0 &&
        a.hotHps > 0) {
      a.hotAcc += a.hotHps * dt;
      if (a.hotAcc >= 1) {
        final tick = a.hotAcc.floor();
        a.hotAcc -= tick;
        final before = a.hp;
        a.hp = math.min(a.effectiveMaxHp, a.hp + tick);
        final gained = a.hp - before;
        if (gained > 0) a.healingDone += gained;
      }
    }
    CombatPresence.tick(a, dt);
  }

  static double _abilityCdLeft(SpatialActor a, AbilityId id) =>
      a.abilityCd[id.name] ?? 0;

  static void _startAbilityCd(
    SpatialWorld world,
    SpatialActor a,
    AbilityId id,
    double cd,
  ) {
    if (cd > 0) a.abilityCd[id.name] = cd;
    world.pendingAbilityCasts++;
  }

  static void _spendRage(SpatialActor a, int cost) {
    a.rage = math.max(0, a.rage - cost);
  }

  static void _gainRage(SpatialActor a, double amount) {
    a.rage = math.min(100, a.rage + amount);
  }

  /// Incoming damage to a hero after mitigation / absorbs.
  static int _applyHeroIncomingDamage(
    SpatialWorld world,
    SpatialActor hero,
    int rawDamage, {
    required bool reducedVfx,
    required math.Random rng,
    bool isMelee = true,
  }) {
    if (hero.iceBlockTimer > 0 || hero.vanishTimer > 0) {
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: hero.x,
          y: hero.y - 0.45,
          text: hero.iceBlockTimer > 0 ? 'ICE BLOCK' : 'MISS',
          argb: 0xFFA0D8FF,
          life: 0.35,
        );
      }
      return 0;
    }

    var dealt = rawDamage;
    var blocked = false;

    if (isMelee && dealt > 0) {
      final avoid = CombatAvoidance.resolveIncomingMelee(
        rawDamage: dealt,
        dodgePercent: hero.dodgePercent,
        parryPercent: hero.parryPercent,
        blockChance: hero.blockChance,
        blockValue: hero.blockValue,
        shieldBlockActive: hero.shieldBlockTimer > 0,
        rng: rng,
      );
      dealt = avoid.damage;
      blocked = avoid.blocked;
      if (avoid.avoided && !reducedVfx) {
        _spawnFloater(
          world,
          x: hero.x,
          y: hero.y - 0.45,
          text: avoid.dodged ? 'DODGE' : 'PARRY',
          argb: 0xFF90E0A0,
          life: 0.35,
        );
      }
      if (blocked &&
          hero.shieldBlockTimer > 0 &&
          WarriorAbilities.isUnlocked(AbilityId.revenge, hero.heroLevel)) {
        hero.revengeReady = true;
      }
    }

    if (dealt <= 0) return 0;

    var mul = hero.kitInMul;
    if (hero.shieldWallTimer > 0) {
      mul *= 0.45;
    }
    if (hero.painSuppressionTimer > 0) {
      mul *= 0.55;
    }
    // Active Shield Block window stacks DR on top of mastery block (−30%).
    if (hero.shieldBlockTimer > 0 && !blocked) {
      mul *= 0.55;
      blocked = true;
      if (WarriorAbilities.isUnlocked(AbilityId.revenge, hero.heroLevel)) {
        hero.revengeReady = true;
      }
    }
    dealt = math.max(1, (dealt * mul).round());
    if (world.petMitigateFlat > 0) {
      dealt = math.max(1, dealt - world.petMitigateFlat);
    }
    var held = 0;
    if (hero.absorbShield > 0) {
      final absorbed = math.min(hero.absorbShield, dealt);
      hero.absorbShield -= absorbed;
      dealt -= absorbed;
      held += absorbed;
      if (!reducedVfx && absorbed > 0) {
        _spawnFloater(
          world,
          x: hero.x,
          y: hero.y - 0.5,
          text: 'ABSORB $absorbed',
          argb: 0xFF80C0FF,
          life: 0.4,
        );
      }
      if (dealt <= 0) {
        _recordHeroTaken(hero, held);
        return absorbed;
      }
    }
    hero.hp = math.max(0, hero.hp - dealt);
    held += dealt;
    _recordHeroTaken(hero, held);
    hero.spiritRegenPaused = 5.0;
    if (dealt > 0) {
      _triggerPrayerOfMending(world, hero);
    }
    if (_actorIsTank(hero) || _actorResource(hero) == SpecResource.rage) {
      _gainRage(hero, 2.5 + dealt * 0.35);
    }
    if (blocked && !reducedVfx) {
      _spawnFloater(
        world,
        x: hero.x,
        y: hero.y - 0.45,
        text: 'BLOCK',
        argb: 0xFF9AD0FF,
        life: 0.4,
      );
    }
    if (dealt > 0) {
      CombatPresence.onLowHp(world, hero, reducedVfx: reducedVfx);
    }
    return dealt;
  }

  /// Direct heal to the lowest ally (used by Penance side-heal in WotLK kit).
  static void _healLowestAlly(
    SpatialWorld world,
    int amount, {
    required bool reducedVfx,
    SpatialActor? healer,
  }) {
    final heal = math.max(1, amount + world.petHealBoost);
    SpatialActor? lowest;
    var worst = 2.0;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      final frac = h.hp / math.max(1, h.effectiveMaxHp);
      if (frac < worst) {
        worst = frac;
        lowest = h;
      }
    }
    if (lowest == null || heal <= 0) return;
    final before = lowest.hp;
    lowest.hp = math.min(lowest.effectiveMaxHp, lowest.hp + heal);
    final gained = lowest.hp - before;
    _recordHeroHeal(healer, gained);
    if (gained > 0 && !reducedVfx && gained >= 8) {
      _spawnFloater(
        world,
        x: lowest.x,
        y: lowest.y - 0.4,
        text: '+$gained',
        argb: _floaterHeal,
        life: 0.4,
        priority: 1,
      );
    }
  }

  static void _triggerPrayerOfMending(SpatialWorld world, SpatialActor hit) {
    if (hit.pomCharges <= 0 || hit.pomHeal <= 0) return;
    final heal = hit.pomHeal;
    hit.pomCharges -= 1;
    final before = hit.hp;
    hit.hp = math.min(hit.effectiveMaxHp, hit.hp + heal);
    final gained = hit.hp - before;
    if (gained > 0) {
      _spawnFloater(
        world,
        x: hit.x,
        y: hit.y - 0.35,
        text: '+$gained',
        argb: _floaterHeal,
        life: 0.45,
      );
      _spawnSpark(
        world,
        x: hit.x,
        y: hit.y,
        argb: 0xFFFFF0A0,
        radius: 0.5,
        life: 0.3,
      );
    }
    if (hit.pomCharges <= 0) {
      hit.pomHeal = 0;
      return;
    }
    // Bounce to another injured ally.
    SpatialActor? next;
    var worst = 1.0;
    for (final h in world.heroes) {
      if (!h.isAlive || h.id == hit.id || h.pomCharges > 0) continue;
      final frac = h.hp / math.max(1, h.effectiveMaxHp);
      if (frac < worst) {
        worst = frac;
        next = h;
      }
    }
    if (next == null) {
      hit.pomCharges = 0;
      hit.pomHeal = 0;
      return;
    }
    next.pomCharges = hit.pomCharges;
    next.pomHeal = heal;
    hit.pomCharges = 0;
    hit.pomHeal = 0;
  }

  /// Warrior attack modifiers: Defensive Stance, Shield Slam, Revenge.
  static ({int damage, String? tag, int tagArgb}) _warriorAttackMods(
    SpatialActor warrior,
    int baseDamage,
  ) {
    var damage = baseDamage;
    String? tag;
    var tagArgb = _floaterDamage;

    // Defensive Stance itself is a kit passive (kitOutMul / kitInMul); the
    // caller folds kitOutMul in, so only the swing riders live here.
    if (warrior.revengeReady &&
        WarriorAbilities.isUnlocked(AbilityId.revenge, warrior.heroLevel)) {
      final def = WarriorAbilities.defFor(AbilityId.revenge)!;
      if (warrior.rage + 0.001 >= def.resourceCost) {
        _spendRage(warrior, def.resourceCost);
        warrior.revengeReady = false;
        damage = (damage * 1.85).round();
        tag = 'REVENGE';
        tagArgb = 0xFFFF9060;
        return (damage: damage, tag: tag, tagArgb: tagArgb);
      }
    }

    if (warrior.queuedShieldSlam) {
      warrior.queuedShieldSlam = false;
      damage = (damage * 1.65).round();
      tag = 'SLAM';
      tagArgb = 0xFFFFD070;
      _gainRage(warrior, 10);
    }

    return (damage: damage, tag: tag, tagArgb: tagArgb);
  }

  /// Softens caster kit casts vs white hits so spam kits don't eclipse melee.
  /// Raised toward parity after AL20 dense-pack boards left casters soft.
  static const double casterAbilityTax = 0.92;

  static ({int damage, String? tag, int tagArgb}) _classAttackMods(
    SpatialWorld world,
    SpatialActor hero,
    int baseDamage,
  ) {
    // Protection-only auto mods (Revenge / Shield Slam / Defensive Stance).
    // Other warrior-legacy DPS use ClassKits + kitOutMul only.
    if (hero.heroSpecId == HeroSpecId.protection) {
      final w = _warriorAttackMods(hero, baseDamage);
      var scaled = math.max(1, (w.damage * hero.kitOutMul).round());
      if ((hero.buffTimers['atkShout'] ?? 0) > 0) {
        scaled = math.max(1, (scaled * 1.08).round());
      }
      return (damage: scaled, tag: w.tag, tagArgb: w.tagArgb);
    }
    var damage = math.max(1, (baseDamage * hero.kitOutMul).round());
    String? tag;
    var tagArgb = _floaterDamage;

    if ((hero.buffTimers['atkShout'] ?? 0) > 0) {
      damage = math.max(1, (damage * 1.08).round());
    }
    // Vendetta / Cold Blood / Arcane Power / Combustion amp whites + kit AA.
    if (hero.combustionTimer > 0 && hero.heroSpecId != HeroSpecId.fire) {
      damage = math.max(1, (damage * 1.25).round());
      tag ??= 'AMP';
      tagArgb = 0xFFFF6060;
    }

    if (hero.heroSpecId == HeroSpecId.combat ||
        hero.heroSpecId == HeroSpecId.subtlety) {
      final buildsCombo = hero.heroSpecId == HeroSpecId.combat
          ? ClassKits.isUnlocked(AbilityId.sinisterStrike, hero.heroLevel)
          : ClassKits.isUnlocked(AbilityId.masterOfSubtlety, hero.heroLevel);
      if (buildsCombo) {
        hero.comboPoints = math.min(5, hero.comboPoints + 1);
      }
      final evisId = hero.heroSpecId == HeroSpecId.subtlety
          ? AbilityId.eviscerateSub
          : AbilityId.eviscerate;
      final evisDef = ClassKits.defFor(evisId);
      if (hero.comboPoints >= 4 &&
          evisDef != null &&
          hero.heroLevel >= evisDef.unlockLevel &&
          hero.rage + 0.001 >= evisDef.resourceCost &&
          _abilityCdLeft(hero, evisId) <= 0) {
        _spendRage(hero, evisDef.resourceCost);
        _startAbilityCd(world, hero, evisId, evisDef.cooldown);
        final pts = hero.comboPoints;
        hero.comboPoints = 0;
        damage = (damage * (1.2 + pts * 0.35)).round();
        tag = 'EVIS';
        tagArgb = 0xFFFF4060;
      }
    }

    if (hero.setProcChance > 0 &&
        GameLogic.random.nextDouble() < hero.setProcChance) {
      damage = math.max(1, (damage * 1.35).round());
      tag = hero.setProcTag ?? 'SET';
      tagArgb = hero.setProcArgb;
    }

    // Spec mastery white-hit procs (Arms / MM / Combat). Skip finishers.
    if (tag != 'EVIS') {
      final mastery = _masteryView(hero);
      final roll = GameLogic.random.nextDouble();
      switch (hero.heroSpecId) {
        case HeroSpecId.arms:
          final chance = SpecMastery.extraSwingProcChance(mastery);
          if (chance > 0 && roll < chance) {
            damage = math.max(1, (damage * 2.0).round());
            tag = 'SWING';
            tagArgb = 0xFFFFC060;
          }
        case HeroSpecId.marksmanship:
          final chance = SpecMastery.extraAutoShotProcChance(mastery);
          if (chance > 0 && roll < chance) {
            damage = math.max(1, (damage * 2.0).round());
            tag = 'WILD QUIVER';
            tagArgb = 0xFF80E080;
          }
        case HeroSpecId.combat:
          final chance = SpecMastery.mainGaucheProcChance(mastery);
          if (chance > 0 && roll < chance) {
            damage = math.max(1, (damage * 1.55).round());
            tag ??= 'MAIN GAUCHE';
            tagArgb = 0xFFFF9060;
          }
        default:
          break;
      }
    }

    return (damage: damage, tag: tag, tagArgb: tagArgb);
  }

  static void _tickFloaters(SpatialWorld world, double dt) {
    for (final f in world.floaters) {
      f.life -= dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.vx *= 0.92;
      f.vy *= 0.94;
    }
    world.floaters.removeWhere((f) => f.life <= 0);
    for (final b in world.bursts) {
      b.life -= dt;
    }
    world.bursts.removeWhere((b) => b.life <= 0);
    for (final g in world.groundFx) {
      g.life -= dt;
    }
    world.groundFx.removeWhere((g) => g.life <= 0);
    void tickFlash(SpatialActor a) {
      if (a.attackFlash > 0) {
        a.attackFlash = (a.attackFlash - dt).clamp(0, 1);
      }
    }

    for (final a in world.heroes) {
      tickFlash(a);
    }
    for (final a in world.enemies) {
      tickFlash(a);
    }
    for (final a in world.pets) {
      tickFlash(a);
    }
    if (world.bossBannerTimer > 0) {
      world.bossBannerTimer = math.max(0, world.bossBannerTimer - dt);
    }
  }

  /// Fresh-floor mana so a healer's first spell is not a 10s wait from 0.
  static const double healerOpeningMana = 55;

  static SpatialWorld build(
    GameState state, {
    double threatScale = 1.0,
    bool? afkAssist,
  }) {
    final room = state.currentRoom;
    final map = RoomLayouts.forFloor(
      floorNumber: room.floorNumber,
      room: room,
      dungeonId: state.dungeonId,
      layoutSeed: state.layoutSeed,
      enemyCountOverride: state.enemies.length,
    );
    final isTreasure = room.type == RoomType.treasure || state.enemies.isEmpty;

    final heroes = <SpatialActor>[];
    final party = state.combatHeroes;
    for (var i = 0; i < party.length; i++) {
      final hero = party[i];
      final spawn = i < map.spawnPoints.length
          ? map.spawnPoints[i]
          : map.spawnPoints[i % map.spawnPoints.length];
      final pattern = _patternForHero(hero, state);
      final ranged = hero.spec.ranged;
      final preferred = hero.spec.preferredRange;
      // Spread party so up to 5 heroes don't stack on one cell.
      final ox = switch (i) {
        0 => 0.0,
        1 => 0.35,
        2 => -0.35,
        3 => 0.15,
        _ => -0.15,
      };
      final oy = switch (i) {
        0 => 0.0,
        1 => -0.35,
        2 => 0.35,
        3 => 0.45,
        _ => -0.45,
      };
      final actor = SpatialActor(
        id: 'hero_$i',
        name: hero.name,
        team: SpatialTeam.hero,
        x: spawn.$1 + 0.5 + ox,
        y: spawn.$2 + 0.5 + oy,
        hp: hero.currentHp,
        maxHp: state.effectiveHeroMaxHp(hero),
        attack: state.effectiveHeroAttack(hero),
        defense: state.effectiveHeroDefense(hero),
        moveSpeed: state.effectiveHeroMoveSpeed(hero),
        attackRange: hero.spec.attackRange,
        attackCooldown: 1.0 / state.effectiveHeroAttackSpeed(hero),
        assetIndex: i,
        heroRole: hero.gearAffinity,
        heroSpecId: hero.specId,
        partyIndex: i,
        heroLevel: hero.level,
        fireCooldown: i * 0.12,
        pattern: pattern,
        ranged: ranged,
        preferredRange: preferred,
        blockValue: _partyHeroIsTank(hero)
            ? state.effectiveHeroStrength(hero) ~/ 20
            : 0,
        spiritRegenBonus: (hero.spec.resource == SpecResource.mana)
            ? spiritManaRegenPerSec(state.effectiveHeroSpirit(hero))
            : 0,
        mp5RegenBonus: mp5ManaRegenPerSec(hero.gearMp5Bonus),
      );
      if (hero.spec.isHealer) {
        actor.rage = healerOpeningMana;
      }
      CombatPresence.seed(actor);
      _syncHeroCataStats(actor, hero, state);
      heroes.add(actor);
    }

    final firstCombat = map.chambers.length <= 1 ? 0 : 1;
    final floorPool = map.spawnableCells(combatOnly: map.chambers.length > 1);
    final overflowSpawns = List<(int, int)>.from(floorPool);
    // Stable shuffle from layout seed so overflow doesn't jitter every rebuild.
    overflowSpawns.shuffle(math.Random(state.layoutSeed ^ 0xE2E2));
    var overflowIdx = 0;
    final used = <String>{};

    (int, int) placeEnemy(int i) {
      (int, int) candidate;
      if (i < map.enemySpawns.length) {
        candidate = map.enemySpawns[i];
      } else if (overflowSpawns.isNotEmpty) {
        candidate = overflowSpawns[overflowIdx % overflowSpawns.length];
        overflowIdx++;
      } else {
        candidate = ((map.cols / 2).floor(), (map.rows / 2).floor());
      }
      var snapped = map.snapToSpawnable(candidate.$1, candidate.$2);
      // Prefer unique cells when the map has room.
      final key = '${snapped.$1},${snapped.$2}';
      if (used.contains(key) && overflowSpawns.isNotEmpty) {
        for (var k = 0; k < overflowSpawns.length; k++) {
          final alt = overflowSpawns[(overflowIdx + k) % overflowSpawns.length];
          final altSnap = map.snapToSpawnable(alt.$1, alt.$2);
          final altKey = '${altSnap.$1},${altSnap.$2}';
          if (!used.contains(altKey)) {
            snapped = altSnap;
            break;
          }
        }
      }
      used.add('${snapped.$1},${snapped.$2}');
      return snapped;
    }

    final enemies = <SpatialActor>[];
    for (var i = 0; i < state.enemies.length; i++) {
      final enemy = state.enemies[i];
      final spawn = placeEnemy(i);
      final ranged =
          enemy.archetype == EnemyArchetype.ranged ||
          enemy.archetype == EnemyArchetype.support ||
          (enemy.role == EnemyRole.elite &&
              enemy.archetype != EnemyArchetype.tank &&
              enemy.archetype != EnemyArchetype.brute);
      final chamberIndex = i < map.enemyChamberIndices.length
          ? map.enemyChamberIndices[i]
          : map.chamberIndexAt(spawn.$1 + 0.5, spawn.$2 + 0.5);
      final moveSpeed = switch (enemy.archetype) {
        EnemyArchetype.swarm => 3.1,
        EnemyArchetype.brute => 2.55,
        EnemyArchetype.tank => 1.85,
        EnemyArchetype.ranged => 2.35,
        EnemyArchetype.glass => 3.4,
        EnemyArchetype.support => 2.2,
      };
      final attackRange = ranged
          ? (enemy.archetype == EnemyArchetype.support ? 4.2 : 3.9)
          : (enemy.role == EnemyRole.boss ? 2.2 : 1.45);
      enemies.add(
        SpatialActor(
          id: 'enemy_$i',
          name: enemy.name,
          team: SpatialTeam.enemy,
          x: spawn.$1 + 0.5,
          y: spawn.$2 + 0.5,
          hp: math.max(1, (enemy.currentHp * threatScale).round()),
          maxHp: math.max(1, (enemy.maxHp * threatScale).round()),
          attack: math.max(1, (enemy.attack * threatScale).round()),
          defense: enemy.defense,
          moveSpeed: enemy.role == EnemyRole.boss
              ? moveSpeed * 0.85
              : moveSpeed,
          attackRange: attackRange,
          attackCooldown: enemy.role == EnemyRole.boss
              ? 1.05
              : (enemy.archetype == EnemyArchetype.glass
                    ? 0.78
                    : (enemy.archetype == EnemyArchetype.swarm ? 0.85 : 0.95)),
          assetIndex: KenneyAssets.enemySpriteCatalogIndex(
            KenneyAssets.enemySpriteFor(enemy, dungeonId: state.dungeonId),
          ),
          role: enemy.role,
          archetype: enemy.archetype,
          fireCooldown: 0.35 + i * 0.12,
          pattern: ProjectilePattern.single,
          ranged: ranged,
          preferredRange: ranged ? 3.2 : 1.2,
          chamberIndex: chamberIndex,
          dormant: chamberIndex > firstCombat,
        ),
      );
    }

    final pets = <SpatialActor>[];
    final pet = state.activePet;
    if (pet != null && heroes.isNotEmpty) {
      final leader = heroes.first;
      pets.add(
        SpatialActor(
          id: 'pet_${pet.id}',
          name: pet.name,
          team: SpatialTeam.hero,
          x: leader.x - 0.55,
          y: leader.y + 0.45,
          hp: 1,
          maxHp: 1,
          attack: math.max(1, pet.totalAttackBonus),
          defense: 0,
          moveSpeed: 3.8,
          attackRange: 1.35,
          attackCooldown: 0.8,
          isPet: true,
          petOwnerId: leader.id,
          fireCooldown: 0.25,
        ),
      );
    }
    // Class companions (BM / Demo / Unholy) — reuse pet combat AI.
    for (final h in heroes) {
      final spec = h.heroSpecId;
      if (spec != HeroSpecId.beastMastery &&
          spec != HeroSpecId.demonology &&
          spec != HeroSpecId.unholy) {
        continue;
      }
      final label = _classCompanionLabel(spec!);
      final atkScale = _classCompanionAtkScale(spec);
      pets.add(
        SpatialActor(
          id: 'classpet_${h.id}',
          name: label,
          team: SpatialTeam.hero,
          x: h.x - 0.45,
          y: h.y + 0.4,
          hp: 1,
          maxHp: 1,
          attack: math.max(2, (h.attack * atkScale).round()),
          defense: 0,
          moveSpeed: 3.6,
          attackRange: 1.4,
          attackCooldown: 0.85,
          isPet: true,
          petOwnerId: h.id,
          fireCooldown: 0.2,
        ),
      );
    }

    final groundLoot = <GroundLoot>[];
    final chestRng = math.Random(state.layoutSeed ^ 0xC7E57);
    for (final cell in map.lootChestPoints) {
      final drops = GameLogic.rollRoomChestLoot(state, random: chestRng);
      for (var i = 0; i < drops.length; i++) {
        final ang = (i / math.max(1, drops.length)) * math.pi * 2;
        groundLoot.add(
          GroundLoot(
            x: cell.$1 + 0.5 + math.cos(ang) * 0.2,
            y: cell.$2 + 0.5 + math.sin(ang) * 0.2,
            drop: drops[i],
          ),
        );
      }
    }

    // Goblin Hideout: chests are stolen stashes — ambush guards wake nearby.
    if (HideoutStash.isHideout(state.dungeonId)) {
      var templateHp = 40;
      var templateAtk = 6;
      var templateDef = 1;
      for (final e in enemies) {
        if (e.role != EnemyRole.boss) {
          templateHp = e.maxHp;
          templateAtk = e.attack;
          templateDef = e.defense;
          break;
        }
      }
      final ambushes = HideoutStash.planAmbushes(
        map: map,
        firstCombatChamber: firstCombat,
        threatScale: threatScale,
        rng: math.Random(state.layoutSeed ^ 0x57A5A),
        templateHp: templateHp,
        templateAtk: templateAtk,
        templateDef: templateDef,
      );
      for (final a in ambushes) {
        enemies.add(
          SpatialActor(
            id: a.id,
            name: a.name,
            team: SpatialTeam.enemy,
            x: a.x,
            y: a.y,
            hp: a.hp,
            maxHp: a.hp,
            attack: a.attack,
            defense: a.defense,
            moveSpeed: a.moveSpeed,
            attackRange: 1.4,
            attackCooldown: a.attackCooldown,
            assetIndex: KenneyAssets.enemySpriteCatalogIndex(a.spritePath),
            role: EnemyRole.normal,
            archetype: a.archetype,
            fireCooldown: 0.25,
            pattern: ProjectilePattern.single,
            ranged: false,
            preferredRange: 1.15,
            chamberIndex: a.chamberIndex,
            dormant: a.dormant,
          ),
        );
      }
    }

    return SpatialWorld(
      map: map,
      heroes: heroes,
      enemies: enemies,
      projectiles: <SpatialProjectile>[],
      groundLoot: groundLoot,
      isTreasure: isTreasure,
      treasureTimer: isTreasure ? 1.2 : 0,
      activeChamber: firstCombat,
      clearedChambers: <int>{0},
      pets: pets,
      afkAssist: afkAssist ?? false,
      petMitigateFlat: state.petMitigateFlat,
      petHealBoost: state.petHealBoost,
      bossBannerTimer: room.type == RoomType.boss ? 2.4 : 0,
      bossBannerName: room.type == RoomType.boss
          ? (enemies.isNotEmpty ? enemies.first.name : 'BOSS')
          : '',
    );
  }

  /// Temporary summons (Army of the Dead / Feral Spirit). Caps per owner.
  static void spawnTempPets(
    SpatialWorld world, {
    required SpatialActor owner,
    required int count,
    required double duration,
    required double atkScale,
    required String namePrefix,
    required String idPrefix,
  }) {
    world.pets.removeWhere(
      (p) =>
          p.petOwnerId == owner.id &&
          p.petLifeTimer > 0 &&
          p.id.startsWith('temppet_${idPrefix}_'),
    );
    final softCap = math.min(count, 5);
    for (var i = 0; i < softCap; i++) {
      final ox = (i % 3) * 0.35 - 0.35;
      final oy = (i ~/ 3) * 0.35 + 0.35;
      world.pets.add(
        SpatialActor(
          id: 'temppet_${idPrefix}_${owner.id}_$i',
          name: softCap == 1 ? namePrefix : '$namePrefix ${i + 1}',
          team: SpatialTeam.hero,
          x: owner.x - 0.4 + ox,
          y: owner.y + 0.35 + oy,
          hp: 1,
          maxHp: 1,
          attack: math.max(1, (owner.attack * atkScale).round()),
          defense: 0,
          moveSpeed: 3.7,
          attackRange: 1.35,
          attackCooldown: 0.75,
          isPet: true,
          petOwnerId: owner.id,
          petLifeTimer: duration,
          fireCooldown: 0.1 + i * 0.05,
        ),
      );
    }
  }

  /// Refresh party combat stats after gear/forge/train without resetting the floor.
  static SpatialWorld syncPartyFromState(SpatialWorld world, GameState state) {
    final heroes = <SpatialActor>[];
    final party = state.combatHeroes;
    for (var i = 0; i < party.length; i++) {
      final hero = party[i];
      SpatialActor? prev;
      for (final h in world.heroes) {
        if (h.partyIndex == i) {
          prev = h;
          break;
        }
      }
      final pattern = _patternForHero(hero, state);
      final ranged = hero.spec.ranged;
      final preferred = hero.spec.preferredRange;
      final spawn = i < world.map.spawnPoints.length
          ? world.map.spawnPoints[i]
          : (world.map.spawnPoints.isNotEmpty
                ? world.map.spawnPoints.first
                : (1, 1));
      final ox = switch (i) {
        0 => 0.0,
        1 => 0.35,
        2 => -0.35,
        3 => 0.15,
        _ => -0.15,
      };
      final oy = switch (i) {
        0 => 0.0,
        1 => -0.35,
        2 => 0.35,
        3 => 0.45,
        _ => -0.45,
      };
      final maxHp = state.effectiveHeroMaxHp(hero);
      final actor = SpatialActor(
        id: prev?.id ?? 'hero_$i',
        name: hero.name,
        team: SpatialTeam.hero,
        x: prev?.x ?? (spawn.$1 + 0.5 + ox),
        y: prev?.y ?? (spawn.$2 + 0.5 + oy),
        // Prefer live spatial HP (keeps fortitude surplus), but take state HP
        // when higher so flask / hub heals are not overwritten on sync.
        hp: hero.isAlive
            ? (prev != null
                  ? (hero.currentHp > prev.hp ? hero.currentHp : prev.hp).clamp(
                      0,
                      math.max(prev.effectiveMaxHp, maxHp),
                    )
                  : hero.currentHp.clamp(0, maxHp))
            : 0,
        maxHp: maxHp,
        attack: state.effectiveHeroAttack(hero),
        defense: state.effectiveHeroDefense(hero),
        moveSpeed: state.effectiveHeroMoveSpeed(hero),
        attackRange: hero.spec.attackRange,
        attackCooldown: 1.0 / state.effectiveHeroAttackSpeed(hero),
        assetIndex: i,
        heroRole: hero.gearAffinity,
        heroSpecId: hero.specId,
        partyIndex: i,
        heroLevel: hero.level,
        fireCooldown: prev?.fireCooldown ?? (i * 0.12),
        pattern: pattern,
        ranged: ranged,
        preferredRange: preferred,
        blockValue: _partyHeroIsTank(hero)
            ? state.effectiveHeroStrength(hero) ~/ 20
            : 0,
        spiritRegenBonus: hero.spec.resource == SpecResource.mana
            ? spiritManaRegenPerSec(state.effectiveHeroSpirit(hero))
            : 0,
        mp5RegenBonus: mp5ManaRegenPerSec(hero.gearMp5Bonus),
      );
      if (prev != null) {
        _copyHeroRuntime(prev, actor);
      } else {
        CombatPresence.seed(actor);
        if (hero.spec.isHealer) {
          actor.rage = healerOpeningMana;
        }
      }
      _syncHeroCataStats(actor, hero, state);
      final setProc = GearSets.fourPieceProc(hero.equipped);
      if (setProc != null) {
        actor.setProcChance = setProc.chance;
        actor.setProcTag = setProc.tag;
        actor.setProcArgb = setProc.argb;
      } else {
        actor.setProcChance = 0;
        actor.setProcTag = null;
      }
      heroes.add(actor);
    }

    final pets = <SpatialActor>[];
    final pet = state.activePet;
    if (pet != null && heroes.isNotEmpty) {
      SpatialActor? prevPet;
      for (final p in world.pets) {
        if (p.id.startsWith('pet_')) {
          prevPet = p;
          break;
        }
      }
      final leader = heroes.firstWhere(
        (h) => h.isAlive,
        orElse: () => heroes.first,
      );
      pets.add(
        SpatialActor(
          id: 'pet_${pet.id}',
          name: pet.name,
          team: SpatialTeam.hero,
          x: prevPet?.x ?? (leader.x - 0.55),
          y: prevPet?.y ?? (leader.y + 0.45),
          hp: 1,
          maxHp: 1,
          attack: math.max(1, pet.totalAttackBonus),
          defense: 0,
          moveSpeed: 3.8,
          attackRange: 1.35,
          attackCooldown: 0.8,
          isPet: true,
          petOwnerId: leader.id,
          fireCooldown: prevPet?.fireCooldown ?? 0.25,
        ),
      );
    }
    // Rebuild class companions after gear sync.
    for (final h in heroes) {
      final spec = h.heroSpecId;
      if (spec != HeroSpecId.beastMastery &&
          spec != HeroSpecId.demonology &&
          spec != HeroSpecId.unholy) {
        continue;
      }
      SpatialActor? prevClass;
      for (final p in world.pets) {
        if (p.id == 'classpet_${h.id}') {
          prevClass = p;
          break;
        }
      }
      final label = _classCompanionLabel(spec!);
      final atkScale = _classCompanionAtkScale(spec);
      pets.add(
        SpatialActor(
          id: 'classpet_${h.id}',
          name: label,
          team: SpatialTeam.hero,
          x: prevClass?.x ?? (h.x - 0.45),
          y: prevClass?.y ?? (h.y + 0.4),
          hp: 1,
          maxHp: 1,
          attack: math.max(2, (h.attack * atkScale).round()),
          defense: 0,
          moveSpeed: 3.6,
          attackRange: 1.4,
          attackCooldown: 0.85,
          isPet: true,
          petOwnerId: h.id,
          fireCooldown: prevClass?.fireCooldown ?? 0.2,
        ),
      );
    }
    // Preserve temporary summons across sync.
    for (final p in world.pets) {
      if (p.petLifeTimer > 0 && p.id.startsWith('temppet_')) {
        pets.add(p);
      }
    }

    return SpatialWorld(
      map: world.map,
      heroes: heroes,
      enemies: world.enemies,
      projectiles: world.projectiles,
      groundLoot: world.groundLoot,
      isTreasure: world.isTreasure,
      treasureOpen: world.treasureOpen,
      treasureTimer: world.treasureTimer,
      awaitingExit: world.awaitingExit,
      exitWaitTimer: world.exitWaitTimer,
      guideX: world.guideX,
      guideY: world.guideY,
      guideTimer: world.guideTimer,
      godHandCooldown: world.godHandCooldown,
      mendTimer: world.mendTimer,
      activeChamber: world.activeChamber,
      openGateIds: world.openGateIds,
      clearedChambers: world.clearedChambers,
      pets: pets,
      pulseX: world.pulseX,
      pulseY: world.pulseY,
      pulseTimer: world.pulseTimer,
      bossBannerTimer: world.bossBannerTimer,
      bossBannerName: world.bossBannerName,
      afkAssist: world.afkAssist,
      combatElapsed: world.combatElapsed,
      petMitigateFlat: state.petMitigateFlat,
      petHealBoost: state.petHealBoost,
      pendingAbilityCasts: world.pendingAbilityCasts,
      pendingFeelCrits: world.pendingFeelCrits,
      pendingFeelLevelUps: world.pendingFeelLevelUps,
      pendingFeelKills: world.pendingFeelKills,
      pendingFeelPickups: world.pendingFeelPickups,
      pendingFeelStairs: world.pendingFeelStairs,
      floaters: world.floaters,
      bursts: world.bursts,
      groundFx: world.groundFx,
      godHandRadius: world.godHandRadius,
    );
  }

  static void _copyHeroRuntime(SpatialActor from, SpatialActor to) {
    to.attackFlash = from.attackFlash;
    to.attackAimX = from.attackAimX;
    to.attackAimY = from.attackAimY;
    to.faceAimX = from.faceAimX;
    to.faceAimY = from.faceAimY;
    to.vx = from.vx;
    to.vy = from.vy;
    to.impatience = from.impatience;
    to.kiteMul = from.kiteMul;
    to.kiteSide = from.kiteSide;
    to.barkCd = from.barkCd;
    to.lowHpBarked = from.lowHpBarked;
    to.rage = from.rage;
    to.abilityCd
      ..clear()
      ..addAll(from.abilityCd);
    to.shieldBlockTimer = from.shieldBlockTimer;
    to.shieldWallTimer = from.shieldWallTimer;
    to.lastStandTimer = from.lastStandTimer;
    to.bonusMaxHp = from.bonusMaxHp;
    to.queuedShieldSlam = from.queuedShieldSlam;
    to.revengeReady = from.revengeReady;
    to.shockwaveFlash = from.shockwaveFlash;
    to.absorbShield = from.absorbShield;
    to.painSuppressionTimer = from.painSuppressionTimer;
    to.fortitudeTimer = from.fortitudeTimer;
    to.pomCharges = from.pomCharges;
    to.pomHeal = from.pomHeal;
    to.powerInfusionTimer = from.powerInfusionTimer;
    to.innerFireActive = from.innerFireActive;
    to.kitOutMul = from.kitOutMul;
    to.kitInMul = from.kitInMul;
    to.kitHealMul = from.kitHealMul;
    to.kitHasteMul = from.kitHasteMul;
    to.kitRootBonus = from.kitRootBonus;
    to.setProcChance = from.setProcChance;
    to.setProcTag = from.setProcTag;
    to.setProcArgb = from.setProcArgb;
    to.combustionTimer = from.combustionTimer;
    to.iceBlockTimer = from.iceBlockTimer;
    to.livingBombArmed = from.livingBombArmed;
    to.hotStreakStack = from.hotStreakStack;
    to.hotStreakReady = from.hotStreakReady;
    to.arcaneCharges = from.arcaneCharges;
    to.beaconTargetId = from.beaconTargetId;
    to.beaconTimer = from.beaconTimer;
    to.comboPoints = from.comboPoints;
    to.sliceAndDiceTimer = from.sliceAndDiceTimer;
    to.bladeFlurryTimer = from.bladeFlurryTimer;
    to.sprintTimer = from.sprintTimer;
    to.vanishTimer = from.vanishTimer;
    to.killingSpreeTimer = from.killingSpreeTimer;
    to.forcedTargetId = from.forcedTargetId;
    to.forcedTargetTimer = from.forcedTargetTimer;
    to.focusEnemyId = from.focusEnemyId;
    to.focusLockTimer = from.focusLockTimer;
    to.attackSlowTimer = from.attackSlowTimer;
    to.sunderStacks = from.sunderStacks;
    to.sunderTimer = from.sunderTimer;
    to.demoShoutTimer = from.demoShoutTimer;
    to.livingBombTimer = from.livingBombTimer;
    to.livingBombDps = from.livingBombDps;
    to.livingBombAcc = from.livingBombAcc;
    to.livingBombCasterId = from.livingBombCasterId;
    to.bleedTimer = from.bleedTimer;
    to.bleedDps = from.bleedDps;
    to.bleedAcc = from.bleedAcc;
    to.bleedCasterId = from.bleedCasterId;
    to.bleedAbilityId = from.bleedAbilityId;
    to.hotHps = from.hotHps;
    to.hotAcc = from.hotAcc;
    to.rootTimer = from.rootTimer;
    to.ccRootDrLevel = from.ccRootDrLevel;
    to.castingTimer = from.castingTimer;
    to.pendingCastDef = from.pendingCastDef;
    to.spiritRegenPaused = from.spiritRegenPaused;
    to.physicalAttack = from.physicalAttack;
    to.spellPower = from.spellPower;
    to.dodgePercent = from.dodgePercent;
    to.parryPercent = from.parryPercent;
    to.blockChance = from.blockChance;
    to.masteryPoints = from.masteryPoints;
    to.uncrittable = from.uncrittable;
    to.damageDealt = from.damageDealt;
    to.healingDone = from.healingDone;
    to.damageTaken = from.damageTaken;
    to.buffTimers
      ..clear()
      ..addAll(from.buffTimers);
  }

  static ProjectilePattern _patternForHero(PartyHero hero, GameState state) {
    // Casters / ranged kits: one bolt per auto.
    if (hero.spec.ranged) {
      return ProjectilePattern.single;
    }
    return hero.weaponPattern;
  }

  /// Visual bolt style for a hero's auto-attack / default spell look.
  static SpellBoltStyle boltStyleForHero(SpatialActor hero) {
    final id = hero.heroSpecId;
    if (id == null) {
      return switch (hero.heroRole) {
        HeroRole.mage => SpellBoltStyle.fire,
        HeroRole.healer => SpellBoltStyle.holy,
        HeroRole.rogue =>
          hero.ranged ? SpellBoltStyle.arrow : SpellBoltStyle.weapon,
        _ => SpellBoltStyle.weapon,
      };
    }
    return boltStyleForSpec(id);
  }

  static SpellBoltStyle boltStyleForSpec(HeroSpecId id) {
    final def = HeroSpecs.def(id);
    return switch (def.classId) {
      HeroClassId.hunter => SpellBoltStyle.arrow,
      HeroClassId.warlock => SpellBoltStyle.shadow,
      HeroClassId.mage => switch (id) {
        HeroSpecId.frostMage => SpellBoltStyle.frost,
        HeroSpecId.arcane => SpellBoltStyle.arcane,
        _ => SpellBoltStyle.fire,
      },
      HeroClassId.shaman => SpellBoltStyle.lightning,
      HeroClassId.druid => SpellBoltStyle.nature,
      HeroClassId.priest => switch (id) {
        HeroSpecId.shadow => SpellBoltStyle.shadow,
        _ => SpellBoltStyle.holy,
      },
      HeroClassId.paladin => SpellBoltStyle.holy,
      _ => SpellBoltStyle.weapon,
    };
  }

  /// Visual style for a cast. Prefer [def] (id + full name); [label] is fallback
  /// for auto-attack tags. Truncated shortLabels alone are not enough.
  static SpellBoltStyle boltStyleForAbility(
    SpatialActor hero, {
    String? label,
    ClassAbilityDef? def,
  }) {
    final fromVfx = def?.vfx?.boltStyle ?? def?.boltStyle;
    if (fromVfx != null) return fromVfx;

    final classId = hero.heroSpecId != null
        ? HeroSpecs.def(hero.heroSpecId!).classId
        : null;
    final byId = def == null ? null : _boltStyleForAbilityId(def.id);
    if (byId != null) return byId;

    final key = [
      ?def?.id.name,
      ?def?.name,
      ?def?.shortLabel,
      ?label,
    ].join(' ').toLowerCase();

    // Abbreviated shortLabels + full names.
    if (_keyHasAny(key, const [
          'lava',
          'fire',
          'pyro',
          'immolate',
          'immo',
          'incinerate',
          'incin',
          'chaos',
          'conflag',
          'scorch',
          'blast wave',
          'flamestrike',
          'combust',
        ]) ||
        (key.contains('nova') &&
            (key.contains('fire') || classId == HeroClassId.shaman))) {
      return SpellBoltStyle.fire;
    }
    if (_keyHasAny(key, const [
          'frost',
          'fshock',
          'ice',
          'rime',
          'glace',
          'howl',
          'cone of cold',
          'icy',
        ]) ||
        (key.contains('nova') &&
            (classId == HeroClassId.mage ||
                key.contains('frost') ||
                key.contains('ice')))) {
      return SpellBoltStyle.frost;
    }
    if (_keyHasAny(key, const ['arcane', 'prism']) &&
        !key.contains('arcane shot')) {
      return SpellBoltStyle.arcane;
    }
    if (_keyHasAny(key, const [
      'shadow',
      'haunt',
      'drain',
      'corrupt',
      'afflict',
      'umbral',
      'mind',
      'guldan',
      'shadowfury',
    ])) {
      return SpellBoltStyle.shadow;
    }
    if (_keyHasAny(key, const [
          'holy',
          'smite',
          'penance',
          'flash',
          'light',
          'consecrat',
          'exorcism',
          'divine',
          'hammer of wrath',
        ]) ||
        // 'heal' → holy only for priest/paladin (shaman/druid stay nature).
        (_keyHasAny(key, const ['heal']) &&
            (classId == HeroClassId.priest ||
                classId == HeroClassId.paladin)) ||
        (key.contains('nova') && classId == HeroClassId.priest) ||
        (key.contains('wrath') && classId == HeroClassId.paladin) ||
        (key.contains('storm') && classId == HeroClassId.paladin)) {
      return SpellBoltStyle.holy;
    }
    if (_keyHasAny(key, const [
          'star',
          'insect',
          'moon',
          'hurricane',
          'typhoon',
          'rejuve',
          'regrowth',
          'nourish',
          'riptide',
          'chain heal',
          'healing rain',
          'wild growth',
          'tranquility',
          'lifebloom',
        ]) ||
        (key.contains('wrath') && classId == HeroClassId.druid) ||
        (key.contains('heal') &&
            (classId == HeroClassId.shaman || classId == HeroClassId.druid))) {
      return SpellBoltStyle.nature;
    }
    // Hunter shots / traps — avoid matching rogue *Shot / killingSpree.
    if (classId == HeroClassId.hunter ||
        _keyHasAny(key, const [
          'arrow',
          'aimed',
          'multi',
          'steady',
          'chimera',
          'chim',
          'serpent',
          'kill command',
          'black arrow',
        ]) ||
        (key.contains('shot') &&
            !key.contains('cheap') &&
            !key.contains('kidney') &&
            (classId == HeroClassId.hunter ||
                key.contains('arcane shot') ||
                key.contains('aimed') ||
                key.contains('multi') ||
                key.contains('steady') ||
                key.contains('chimera') ||
                key.contains('scatter') ||
                key.contains('explosive')))) {
      return SpellBoltStyle.arrow;
    }
    if (_keyHasAny(key, const [
          'lightning',
          'chain',
          'thunder',
          'stormstrike',
          'earth shock',
        ]) ||
        (key.contains('storm') && classId == HeroClassId.shaman) ||
        (key.contains('clap') && key.contains('thunder')) ||
        (key.contains('bolt') && classId == HeroClassId.shaman)) {
      return SpellBoltStyle.lightning;
    }
    // Melee "storm" (Bladestorm) and generic bolt → class default.
    if (key.contains('bolt') && classId == HeroClassId.hunter) {
      return SpellBoltStyle.arrow;
    }
    return boltStyleForHero(hero);
  }

  static SpellBoltStyle? _boltStyleForAbilityId(AbilityId id) {
    return switch (id) {
      // —— Fire ——
      AbilityId.immolateDemo ||
      AbilityId.immolateDestro ||
      AbilityId.incinerate ||
      AbilityId.conflagrate ||
      AbilityId.chaosBolt ||
      AbilityId.chaosBoltDemo ||
      AbilityId.lavaBurst ||
      AbilityId.flameShock ||
      AbilityId.rainOfFire ||
      AbilityId.lavaLash ||
      AbilityId.fireNova ||
      AbilityId.blastWave ||
      AbilityId.livingBomb ||
      AbilityId.fireball ||
      AbilityId.pyroblast ||
      AbilityId.combustion ||
      AbilityId.explosiveTrap ||
      AbilityId.explosiveShot => SpellBoltStyle.fire,

      // —— Frost ——
      AbilityId.frostShock ||
      AbilityId.howlingBlast ||
      AbilityId.frostbolt ||
      AbilityId.iceLance ||
      AbilityId.coneOfCold ||
      AbilityId.blizzard ||
      AbilityId.frostNova ||
      AbilityId.frostNovaMage ||
      AbilityId.hungeringCold ||
      AbilityId.chainsOfIce ||
      AbilityId.frostStrike ||
      AbilityId.freezingTrap ||
      AbilityId.iceBlock => SpellBoltStyle.frost,

      // —— Lightning ——
      AbilityId.thunderClap ||
      AbilityId.chainLightning ||
      AbilityId.lightningBolt ||
      AbilityId.thunderstorm ||
      AbilityId.earthShock ||
      AbilityId.stormstrike => SpellBoltStyle.lightning,

      // —— Holy ——
      AbilityId.holyPriestNova ||
      AbilityId.holyWrath ||
      AbilityId.divineStorm ||
      AbilityId.consecration ||
      AbilityId.consecrationHoly ||
      AbilityId.hammerOfWrath ||
      AbilityId.holyShock ||
      AbilityId.hammerOfTheRighteous ||
      AbilityId.judgment ||
      AbilityId.crusaderStrike ||
      AbilityId.templarsVerdict ||
      AbilityId.avengersShield ||
      AbilityId.shieldOfRighteousness ||
      AbilityId.penance ||
      AbilityId.flashHeal ||
      AbilityId.flashOfLight ||
      AbilityId.holyLight ||
      AbilityId.divineHymn ||
      AbilityId.circleOfHealing ||
      AbilityId.powerWordShield ||
      AbilityId.prayerOfMending ||
      AbilityId.renew ||
      AbilityId.guardianSpirit ||
      AbilityId.beaconOfLight ||
      AbilityId.layOnHands => SpellBoltStyle.holy,

      // —— Nature (resto sham / balance / resto druid / poisons) ——
      AbilityId.hurricane ||
      AbilityId.starfall ||
      AbilityId.starfire ||
      AbilityId.wrath ||
      AbilityId.moonfire ||
      AbilityId.typhoon ||
      AbilityId.riptide ||
      AbilityId.healingWave ||
      AbilityId.chainHeal ||
      AbilityId.earthShield ||
      AbilityId.healingRain ||
      AbilityId.spiritLink ||
      AbilityId.natureSwiftness ||
      AbilityId.rejuvenation ||
      AbilityId.regrowth ||
      AbilityId.wildGrowth ||
      AbilityId.lifebloom ||
      AbilityId.nourish ||
      AbilityId.tranquility ||
      AbilityId.envenom ||
      AbilityId.garrote => SpellBoltStyle.nature,

      // —— Arcane ——
      AbilityId.arcaneBlast ||
      AbilityId.arcaneMissiles ||
      AbilityId.arcaneExplosion ||
      AbilityId.arcanePower ||
      AbilityId.slow ||
      AbilityId.antiMagicShell ||
      AbilityId.boneShield ||
      AbilityId.presenceOfMind => SpellBoltStyle.arcane,

      // —— Arrow (hunter ranged) ——
      AbilityId.arcaneShot ||
      AbilityId.multiShot ||
      AbilityId.multiShotSurv ||
      AbilityId.aimedShot ||
      AbilityId.steadyShot ||
      AbilityId.chimeraShot ||
      AbilityId.volley ||
      AbilityId.killCommand ||
      AbilityId.serpentSting ||
      AbilityId.blackArrow ||
      AbilityId.bestialWrath => SpellBoltStyle.arrow,

      // —— Shadow ——
      AbilityId.shadowBolt ||
      AbilityId.haunt ||
      AbilityId.hauntBurst ||
      AbilityId.corruption ||
      AbilityId.unstableAffliction ||
      AbilityId.drainLife ||
      AbilityId.mindBlast ||
      AbilityId.mindFlay ||
      AbilityId.mindSear ||
      AbilityId.devouringPlague ||
      AbilityId.shadowWordPain ||
      AbilityId.handOfGuldan ||
      AbilityId.shadowfury ||
      AbilityId.seedOfCorruption ||
      AbilityId.fanOfKnivesSub ||
      AbilityId.deathCoil ||
      AbilityId.vampiricTouch ||
      AbilityId.curseOfAgony ||
      AbilityId.armyOfDead ||
      AbilityId.gargoyle ||
      AbilityId.runeTap ||
      AbilityId.psychicScream => SpellBoltStyle.shadow,

      // —— Weapon / physical ——
      AbilityId.bladestorm ||
      AbilityId.whirlwind ||
      AbilityId.mortalStrike ||
      AbilityId.bloodthirst ||
      AbilityId.obliterate ||
      AbilityId.heartStrike ||
      AbilityId.deathStrike ||
      AbilityId.scourgeStrike ||
      AbilityId.bloodBoil ||
      AbilityId.bloodBoilUnholy ||
      AbilityId.cheapShot ||
      AbilityId.kidneyShot ||
      AbilityId.killingSpree ||
      AbilityId.mongooseBite ||
      AbilityId.fanOfKnives ||
      AbilityId.shred ||
      AbilityId.rake ||
      AbilityId.ferociousBite ||
      AbilityId.rip ||
      AbilityId.mangleBear ||
      AbilityId.swipe ||
      AbilityId.feralSwipe ||
      AbilityId.lacerate ||
      AbilityId.maul ||
      AbilityId.overpower ||
      AbilityId.rend ||
      AbilityId.armsExecute ||
      AbilityId.ragingBlow ||
      AbilityId.furyExecute ||
      AbilityId.devastate ||
      AbilityId.shieldSlam ||
      AbilityId.revenge ||
      AbilityId.shockwave ||
      AbilityId.eviscerate ||
      AbilityId.sinisterStrike ||
      AbilityId.bladeFlurry ||
      AbilityId.hemorrhage ||
      AbilityId.backstab ||
      AbilityId.sweepingStrikes => SpellBoltStyle.weapon,
      _ => null,
    };
  }

  /// Lasting ground disc defaults for signature AOEs (life seconds).
  static double? groundDiscLifeFor(AbilityId id) {
    return switch (id) {
      AbilityId.consecration || AbilityId.consecrationHoly => 6.0,
      AbilityId.healingRain || AbilityId.tranquility => 5.5,
      AbilityId.explosiveTrap => 4.0,
      AbilityId.handOfGuldan || AbilityId.wildGrowth => 3.5,
      AbilityId.bladestorm ||
      AbilityId.bladeFlurry ||
      AbilityId.divineStorm => 3.2,
      AbilityId.spiritLink || AbilityId.mindSear => 3.0,
      AbilityId.bloodBoil ||
      AbilityId.bloodBoilUnholy ||
      AbilityId.whirlwind ||
      AbilityId.holyPriestNova ||
      AbilityId.circleOfHealing => 2.5,
      AbilityId.armyOfDead => 2.5,
      AbilityId.holyWrath || AbilityId.hungeringCold => 2.2,
      AbilityId.fireNova ||
      AbilityId.frostNova ||
      AbilityId.frostNovaMage ||
      AbilityId.thunderClap => 2.2,
      AbilityId.seedOfCorruption => 2.0,
      AbilityId.killingSpree => 2.0,
      AbilityId.blastWave ||
      AbilityId.shockwave ||
      AbilityId.arcaneExplosion ||
      AbilityId.shadowfury => 1.6,
      AbilityId.swipe ||
      AbilityId.feralSwipe ||
      AbilityId.fanOfKnives ||
      AbilityId.fanOfKnivesSub => 1.5,
      _ => null,
    };
  }

  static bool _keyHasAny(String key, List<String> parts) {
    for (final p in parts) {
      if (key.contains(p)) return true;
    }
    return false;
  }

  static void _recordHeroDamage(SpatialActor hero, int dealt) {
    if (dealt <= 0 || hero.isPet || hero.team != SpatialTeam.hero) return;
    hero.damageDealt += dealt;
  }

  static void _recordHeroHeal(SpatialActor? healer, int gained) {
    if (healer == null ||
        gained <= 0 ||
        healer.isPet ||
        healer.team != SpatialTeam.hero) {
      return;
    }
    healer.healingDone += gained;
  }

  static void _recordHeroTaken(SpatialActor hero, int taken) {
    if (taken <= 0 || hero.isPet || hero.team != SpatialTeam.hero) return;
    hero.damageTaken += taken;
  }

  static SpatialActor? _heroById(SpatialWorld world, String? id) {
    if (id == null) return null;
    for (final h in world.heroes) {
      if (h.id == id) return h;
    }
    return null;
  }

  static SpatialStepResult _stepResult(
    SpatialWorld world,
    GameState state, {
    bool roomCleared = false,
    bool partyWiped = false,
    int goldFromKills = 0,
  }) {
    final casts = world.pendingAbilityCasts;
    world.pendingAbilityCasts = 0;
    final crits = world.pendingFeelCrits;
    world.pendingFeelCrits = 0;
    final levels = world.pendingFeelLevelUps;
    world.pendingFeelLevelUps = 0;
    final kills = world.pendingFeelKills;
    world.pendingFeelKills = 0;
    final pickups = world.pendingFeelPickups;
    world.pendingFeelPickups = 0;
    final stairs = world.pendingFeelStairs;
    world.pendingFeelStairs = 0;
    return SpatialStepResult(
      world: world,
      state: state,
      roomCleared: roomCleared,
      partyWiped: partyWiped,
      goldFromKills: goldFromKills,
      kills: kills,
      abilityCasts: casts,
      critHits: crits,
      heroLevelUps: levels,
      lootPickups: pickups,
      stairsOpened: stairs > 0,
    );
  }

  static void _noteFeelCrit(SpatialWorld world) {
    world.pendingFeelCrits++;
  }

  static void _noteFeelLevelUp(SpatialWorld world) {
    world.pendingFeelLevelUps++;
  }

  static void _noteFeelKill(SpatialWorld world) {
    world.pendingFeelKills++;
  }

  static void _noteFeelPickup(SpatialWorld world) {
    world.pendingFeelPickups++;
  }

  /// Phone combat text: loot / level-up / gold read larger than damage ticks.
  static double floaterReadScale(int priority) {
    if (priority >= 2) return 1.75;
    if (priority >= 1) return 1.35;
    return 1.0;
  }

  /// Advances spatial combat by [dt] seconds and syncs HP into [state].
  static SpatialStepResult step(
    SpatialWorld world,
    GameState state, {
    required double dt,
  }) {
    var nextState = state;
    var goldFromKills = 0;
    final rng = GameLogic.random;

    world.godHandCooldown = math.max(0, world.godHandCooldown - dt);
    world.bagFullFloaterCooldown = math.max(0, world.bagFullFloaterCooldown - dt);
    world.pulseTimer = math.max(0, world.pulseTimer - dt);
    world.guideTimer = math.max(0, world.guideTimer - dt);
    _updateChambers(world, reducedVfx: state.reducedVfx, softLock: false);

    final inFight =
        !world.awaitingExit &&
        !world.isTreasure &&
        world.enemies.any((e) => e.hp > 0 && !e.dormant);
    if (inFight) {
      world.combatElapsed += dt;
    }

    if (world.isTreasure) {
      world.treasureTimer -= dt;
      if (world.treasureTimer <= 0) {
        world.treasureOpen = true;
        // Chest gold paid once in completeCurrentRoom via treasureGoldBudget.
        return _stepResult(
          world,
          nextState,
          roomCleared: true,
          goldFromKills: 0,
        );
      }
      return _stepResult(world, nextState);
    }

    // Cleared: walk to exit. ONE living hero on the stairs clears the floor.
    // (Requiring the full party in a tight cluster soft-locks when someone jams.)
    if (world.awaitingExit) {
      world.exitWaitTimer += dt;
      // Ensure every gate is open so the exit path can't soft-lock.
      for (final gate in world.map.gates) {
        world.openGateIds.add(gate.id);
      }
      final exitX = world.map.exitPoint.$1 + 0.5;
      final exitY = world.map.exitPoint.$2 + 0.5;
      final guiding =
          world.guideTimer > 0 && world.guideX != null && world.guideY != null;
      const approachSlots = <(double, double)>[
        (0.0, 0.0),
        (-0.85, 0.35),
        (0.85, 0.35),
        (0.0, -0.85),
        (-0.7, -0.55),
        (0.7, -0.55),
      ];
      var slot = 0;
      var anyOnStairs = false;
      final livingHeroes = <SpatialActor>[
        for (final h in world.heroes)
          if (h.isAlive) h,
      ];
      for (final hero in livingHeroes) {
        late final double tx;
        late final double ty;
        if (guiding) {
          tx = world.guideX!;
          ty = world.guideY!;
        } else {
          final dNow = _distPoint(hero.x, hero.y, exitX, exitY);
          if (dNow > 3.8) {
            // Far stragglers head straight to the stairs (not a side slot).
            tx = exitX;
            ty = exitY;
          } else {
            final offset = approachSlots[slot % approachSlots.length];
            slot++;
            tx = exitX + offset.$1;
            ty = exitY + offset.$2;
          }
        }
        final snapped = _snapToWalkable(world.map, world.openGateIds, tx, ty);
        _steerActor(
          hero,
          snapped.$1,
          snapped.$2,
          hero.moveSpeed * 1.35,
          world,
          dt: dt,
          holdDistance: guiding ? 0.35 : 0.22,
          separateFrom: livingHeroes,
          separationRadius: 0.5,
          separationWeight: 0.35,
        );
        if (_distPoint(hero.x, hero.y, exitX, exitY) < 1.35) {
          anyOnStairs = true;
        }
      }

      // Failsafe: if pathing totally fails, warp stragglers after a few seconds
      // once someone is already on the stairs ? then clear.
      if (anyOnStairs && world.exitWaitTimer > 2.5) {
        for (final hero in livingHeroes) {
          if (_distPoint(hero.x, hero.y, exitX, exitY) > 3.4) {
            final pad = _snapToWalkable(
              world.map,
              world.openGateIds,
              exitX,
              exitY,
            );
            hero.x = pad.$1;
            hero.y = pad.$2;
          }
        }
      }

      final living = livingHeroes.length;
      // Live play soft-locks feel bad if pathing jams; keep AFK snappy.
      final forceClear =
          living > 0 && world.exitWaitTimer > (world.afkAssist ? 2.8 : 5.0);
      if (living > 0 && (anyOnStairs || forceClear)) {
        if (forceClear && !anyOnStairs) {
          for (final hero in livingHeroes) {
            final pad = _snapToWalkable(
              world.map,
              world.openGateIds,
              exitX,
              exitY,
            );
            hero.x = pad.$1;
            hero.y = pad.$2;
          }
        }
        nextState = _vacuumGroundLoot(world, nextState);
        final gold = goldFromKills;
        return _stepResult(
          world,
          nextState,
          roomCleared: true,
          goldFromKills: gold,
        );
      }
      nextState = _syncHp(nextState, world);
      return _stepResult(world, nextState);
    }

    final guiding =
        world.guideTimer > 0 && world.guideX != null && world.guideY != null;

    _tickCombatBuffs(world, dt);

    // The healer's mend is independent of attacks and only runs while alive.
    world.mendTimer -= dt;
    while (world.mendTimer <= 0) {
      final healerAlive = world.heroes.any(
        (h) => h.hp > 0 && _actorIsHealer(h),
      );
      if (healerAlive) {
        final mend = nextState.healerMendAmount;
        for (final hero in world.heroes) {
          if (hero.hp > 0) {
            final before = hero.hp;
            hero.hp = math.min(hero.effectiveMaxHp, hero.hp + mend);
            final gained = hero.hp - before;
            if (gained > 0) {
              _spawnFloater(
                world,
                x: hero.x,
                y: hero.y - 0.35,
                text: '+$gained',
                argb: _floaterHeal,
                life: 0.5,
              );
            }
          }
        }
      }
      world.mendTimer += 1.0;
    }

    final party = _stepHeroes(
      world,
      nextState,
      dt: dt,
      rng: rng,
      guiding: guiding,
      reducedVfx: state.reducedVfx,
    );
    nextState = party.state;
    goldFromKills += party.gold;

    // Pets follow their owner (meta pet / class pet) when set, else party leader.
    final pets = _stepPets(
      world,
      nextState,
      dt: dt,
      rng: rng,
      reducedVfx: state.reducedVfx,
    );
    nextState = pets.state;
    goldFromKills += pets.gold;

    final foes = _stepEnemies(
      world,
      nextState,
      dt: dt,
      rng: rng,
      reducedVfx: state.reducedVfx,
    );
    nextState = foes.state;
    goldFromKills += foes.gold;

    // Projectiles
    final shots = _stepProjectiles(
      world,
      nextState,
      dt: dt,
      rng: rng,
      reducedVfx: state.reducedVfx,
    );
    nextState = shots.state;
    goldFromKills += shots.gold;

    // Loot becomes real state only when collected (or after its grace period).
    nextState = _stepGroundLoot(world, nextState, dt);

    _tickFloaters(world, dt);

    nextState = _syncHp(nextState, world);

    if (world.allHeroesDead) {
      return _stepResult(
        world,
        nextState,
        partyWiped: true,
        goldFromKills: goldFromKills,
      );
    }

    _updateChambers(world, reducedVfx: state.reducedVfx, softLock: true);
    nextState = _wakeAndFinishFloor(
      world,
      nextState,
      reducedVfx: state.reducedVfx,
    );

    return _stepResult(world, nextState, goldFromKills: goldFromKills);
  }

  /// Enemies: prefer the tank, kite if ranged, path around walls.
  static ({GameState state, int gold}) _stepEnemies(
    SpatialWorld world,
    GameState state, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
  }) {
    var nextState = state;
    var goldFromKills = 0;
    // Enemies: prefer the tank, kite if ranged, path around walls.
    for (final enemy in world.enemies) {
      if (enemy.hp <= 0 || enemy.dormant) continue;
      // Living Bomb ticks + splash explode when the fuse ends.
      if (enemy.livingBombTimer > 0 && enemy.livingBombDps > 0) {
        enemy.livingBombAcc += enemy.livingBombDps * dt;
        if (enemy.livingBombAcc >= 1) {
          final tick = enemy.livingBombAcc.floor();
          enemy.livingBombAcc -= tick;
          final caster = _heroById(world, enemy.livingBombCasterId);
          var tickDmg = tick;
          if (caster != null) {
            tickDmg = math.max(
              1,
              (tick * SpecMastery.dotTickMul(_masteryView(caster))).round(),
            );
          }
          final wasAlive = enemy.hp > 0;
          enemy.hp = math.max(0, enemy.hp - tickDmg);
          if (caster != null) _recordHeroDamage(caster, tickDmg);
          if (!reducedVfx) {
            _spawnFloater(
              world,
              x: enemy.x,
              y: enemy.y - 0.25,
              text: '$tickDmg',
              argb: 0xFFFF6030,
              life: 0.4,
            );
          }
          if (wasAlive && enemy.hp <= 0) {
            final killed = _onEnemyKilled(world, nextState, enemy, rng);
            goldFromKills += killed.gold;
            nextState = killed.state;
          }
        }
        if (enemy.livingBombTimer <= dt && enemy.hp > 0) {
          // Explode for splash.
          final boom = math.max(4, (enemy.livingBombDps * 3).round());
          final caster = _heroById(world, enemy.livingBombCasterId);
          for (final e in world.enemies) {
            if (e.hp <= 0 || e.dormant) continue;
            if (_dist(enemy, e) > 2.2) continue;
            final wasAlive = e.hp > 0;
            final dealt = CombatRatings.mitigateByArmor(
              rawDamage: boom,
              defense: e.effectiveDefense,
              attackerAttack: caster?.attack ?? boom,
            );
            e.hp = math.max(0, e.hp - dealt);
            if (caster != null) _recordHeroDamage(caster, dealt);
            if (!reducedVfx) {
              _spawnFloater(
                world,
                x: e.x,
                y: e.y - 0.2,
                text: '$dealt',
                argb: 0xFFFF5020,
                life: 0.45,
              );
            }
            if (wasAlive && e.hp <= 0) {
              final killed = _onEnemyKilled(world, nextState, e, rng);
              goldFromKills += killed.gold;
              nextState = killed.state;
            }
          }
          if (!reducedVfx) {
            _spawnBurst(
              world,
              x: enemy.x,
              y: enemy.y,
              argb: 0xFFFF4010,
              radius: 1.4,
              life: 0.35,
            );
            _spawnRing(
              world,
              x: enemy.x,
              y: enemy.y,
              argb: 0xFFFF6020,
              radius: 1.8,
              life: 0.45,
            );
          }
        }
      }
      // Bleed DoT ticks (Rip / Rake / Rend).
      if (enemy.bleedTimer > 0 && enemy.bleedDps > 0 && enemy.hp > 0) {
        enemy.bleedAcc += enemy.bleedDps * dt;
        if (enemy.bleedAcc >= 1) {
          final tick = enemy.bleedAcc.floor();
          enemy.bleedAcc -= tick;
          final caster = _heroById(world, enemy.bleedCasterId);
          var tickDmg = tick;
          if (caster != null) {
            tickDmg = math.max(
              1,
              (tick * SpecMastery.dotTickMul(_masteryView(caster))).round(),
            );
          }
          final wasAlive = enemy.hp > 0;
          enemy.hp = math.max(0, enemy.hp - tickDmg);
          if (caster != null) _recordHeroDamage(caster, tickDmg);
          if (!reducedVfx) {
            _spawnFloater(
              world,
              x: enemy.x,
              y: enemy.y - 0.2,
              text: '$tickDmg',
              argb: 0xFFC05050,
              life: 0.4,
            );
          }
          if (wasAlive && enemy.hp <= 0) {
            final killed = _onEnemyKilled(world, nextState, enemy, rng);
            goldFromKills += killed.gold;
            nextState = killed.state;
          }
        }
      }
      final target = _focusHero(enemy, world.heroes);
      if (target == null) continue;
      final dist = _dist(enemy, target);
      final preferred = enemy.preferredRange ?? (enemy.attackRange * 0.75);
      var tx = target.x;
      var ty = target.y;
      var hold = preferred;
      if (enemy.ranged && dist < preferred * 0.65) {
        tx = enemy.x - (target.x - enemy.x);
        ty = enemy.y - (target.y - enemy.y);
        hold = 0;
      }
      _steerActor(
        enemy,
        tx,
        ty,
        enemy.moveSpeed * enemy.moveSpeedMul,
        world,
        dt: dt,
        holdDistance: hold,
        separateFrom: world.enemies,
      );

      final slowRate = enemy.attackSlowTimer > 0 ? 0.8 : 1.0;
      enemy.fireCooldown -= dt * slowRate;

      // ?? Enemy specials (heal / enrage / slow / execute / boss pulse) ??
      _tickEnemySpecials(world, enemy, target, dt, rng: rng, reducedVfx: reducedVfx);

      final afterDist = _dist(enemy, target);
      if (enemy.fireCooldown <= 0 && afterDist <= enemy.attackRange) {
        enemy.fireCooldown = enemy.attackCooldown;
        // Armor matters as a percent — more DEF always helps, never immune.
        var raw = CombatRatings.mitigateByArmor(
          rawDamage: enemy.effectiveAttack,
          defense: target.effectiveDefense,
          attackerAttack: enemy.effectiveAttack,
        );
        // Glass execute: bonus damage vs low-HP heroes.
        if (enemy.archetype == EnemyArchetype.glass &&
            target.hp < target.effectiveMaxHp * 0.3) {
          raw = math.max(1, (raw * 1.35).round());
        }
        if (world.afkAssist) {
          raw = math.max(1, (raw * 0.45).round());
        }
        if (enemy.ranged) {
          enemy.attackFlash = 0.12;
          SpatialCombat._addProjectiles(
            world,
            _firePattern(
              from: enemy,
              to: target,
              damage: raw,
              pattern: ProjectilePattern.single,
            ),
          );
          // Ranged hits apply attack-speed slow.
          target.attackSlowTimer = math.max(target.attackSlowTimer, 1.6);
        } else {
          enemy.attackFlash = 0.16;
          final dmg = _applyHeroIncomingDamage(
            world,
            target,
            raw,
            reducedVfx: reducedVfx,
            rng: rng,
            isMelee: true,
          );
          if (!reducedVfx) {
            _spawnSlash(world, from: enemy, to: target, isCrit: false);
          }
          _spawnFloater(
            world,
            x: target.x,
            y: target.y - 0.25,
            text: '$dmg',
            argb: _floaterDamage,
            life: 0.65,
          );
          if (dmg > 0) {
            CombatPresence.onPulledAggro(
              world,
              target,
              reducedVfx: reducedVfx,
            );
          }
        }
      }
    }
    return (state: nextState, gold: goldFromKills);
  }

  /// Heroes: formation + role ranges + optional God Hand steering.
  static ({GameState state, int gold}) _stepHeroes(
    SpatialWorld world,
    GameState state, {
    required double dt,
    required math.Random rng,
    required bool guiding,
    required bool reducedVfx,
  }) {
    var nextState = state;
    var goldFromKills = 0;
    // Heroes: formation + role ranges + optional God Hand steering.
    final leader = world.leader;
    SpatialActor? tankAnchor;
    for (final h in world.heroes) {
      if (h.isAlive && _actorIsTank(h)) {
        tankAnchor = h;
        break;
      }
    }
    final packAnchor = tankAnchor ?? leader;
    final focusCache = _FocusTickCache.build(world);

    for (var i = 0; i < world.heroes.length; i++) {
      final hero = world.heroes[i];
      if (!hero.isAlive) continue;
      final target = _pickSmartFocus(hero, world, focusCache);
      var tx = hero.x;
      var ty = hero.y;
      var hold = 0.0;
      final roleTag = hero.heroSpecId != null
          ? HeroSpecs.def(hero.heroSpecId!).roleTag
          : null;
      final isHealer = _actorIsHealer(hero) || roleTag == SpecRoleTag.healer;
      final isBackliner =
          isHealer ||
          hero.ranged ||
          roleTag == SpecRoleTag.caster ||
          roleTag == SpecRoleTag.rangedDps;

      if (guiding) {
        // God Hand: tap pulls the party toward the point.
        tx = world.guideX!;
        ty = world.guideY!;
        hold = 0.35;
      } else if (target != null) {
        final dist = _dist(hero, target);
        var preferred = CombatPresence.preferredFightRange(
          hero,
          hero.preferredRange ?? (hero.attackRange * 0.7),
        );
        if (isHealer) {
          preferred = math.max(preferred, hero.attackRange * 0.92);
        }
        final hasLos = _hasClearCorridor(
          world.map,
          world.openGateIds,
          hero.x.floor(),
          hero.y.floor(),
          target.x.floor(),
          target.y.floor(),
        );

        if (isHealer && packAnchor != null && packAnchor.id != hero.id) {
          // Stay slightly behind the tank, not deep in the pack.
          final dx = packAnchor.x - target.x;
          final dy = packAnchor.y - target.y;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len > 0.15) {
            tx = packAnchor.x + (dx / len) * 0.75;
            ty = packAnchor.y + (dy / len) * 0.75;
          } else {
            tx = packAnchor.x - 0.7;
            ty = packAnchor.y;
          }
          hold = 0.3;
        } else if (isBackliner &&
            dist < preferred * (isHealer ? 0.88 : 0.72) &&
            hasLos) {
          // Kite away — Fire panics straight back, Arcane sidesteps.
          final kite = CombatPresence.kiteTarget(hero, target);
          tx = kite.$1;
          ty = kite.$2;
          hold = 0;
        } else {
          tx = target.x;
          ty = target.y;
          // No LOS at hold range ? close in so shots/melee aren't wall-blocked.
          hold = hasLos ? preferred : 0;
        }
      } else if (packAnchor != null && hero.id != packAnchor.id) {
        // Idle pack: trail the tank/leader with light formation offsets.
        final ox = switch (roleTag) {
          SpecRoleTag.caster || SpecRoleTag.rangedDps => -1.05,
          SpecRoleTag.healer => -1.15,
          SpecRoleTag.meleeDps => -0.25,
          SpecRoleTag.tank => -0.4,
          null => switch (hero.heroRole) {
            HeroRole.mage => -1.05,
            HeroRole.healer => -1.15,
            HeroRole.rogue => -0.25,
            _ => -0.4,
          },
        };
        final oy = (i - 1) * 0.55;
        tx = packAnchor.x + ox;
        ty = packAnchor.y + oy;
        hold = 0.45;
      }

      var speedMul = hero.moveSpeedMul;
      // Low HP: limp toward healer / behind the tank instead of holding the line.
      if (!guiding) {
        CombatPresence.tryEmergencyRetreat(
          hero,
          world,
          packAnchor: packAnchor,
          setGoal: (rtx, rty, rhold, limp) {
            tx = rtx;
            ty = rty;
            hold = rhold;
            speedMul *= limp;
          },
        );
      }

      // Keep melee DPS from racing a chamber ahead of the tank.
      // Impatient kits get a longer leash before the snap-back.
      if (packAnchor != null &&
          hero.id != packAnchor.id &&
          _actorIsMeleeDps(hero) &&
          _dist(hero, packAnchor) > CombatPresence.packLeash(hero)) {
        tx = packAnchor.x;
        ty = packAnchor.y;
        hold = 0.45;
      }

      // Healers that drifted into the pack: snap back toward tank.
      if (packAnchor != null &&
          isHealer &&
          hero.id != packAnchor.id &&
          _dist(hero, packAnchor) > 3.2) {
        tx = packAnchor.x;
        ty = packAnchor.y;
        hold = 0.75;
      }

      _steerActor(
        hero,
        tx,
        ty,
        hero.moveSpeed * speedMul,
        world,
        dt: dt,
        holdDistance: hold,
        separateFrom: world.heroes,
      );

      if (hero.heroRole != null) {
        final partyHero =
            hero.assetIndex >= 0 && hero.assetIndex < nextState.heroes.length
            ? nextState.heroes[hero.assetIndex]
            : null;
        final offHand = partyHero?.itemIn(EquipmentSlot.offHand);
        final hasShield = offHand?.offHandKind == OffHandKind.shield;
        AbilityEffectRunner.tick(
          world,
          hero,
          nextState,
          dt: dt,
          rng: rng,
          reducedVfx: reducedVfx,
          hasShield: hasShield,
        );
        nextState = AbilityEffectRunner.takeState(nextState);
        goldFromKills += AbilityEffectRunner.takeGold();
      }

      if (target == null) continue;
      final dist = _dist(hero, target);
      hero.fireCooldown -=
          dt * hero.attackSpeedMul * (hero.attackSlowTimer > 0 ? 0.65 : 1.0);
      if (hero.fireCooldown <= 0 && dist <= hero.attackRange) {
        hero.fireCooldown = hero.attackCooldown;
        final partyHero =
            hero.assetIndex >= 0 && hero.assetIndex < nextState.heroes.length
            ? nextState.heroes[hero.assetIndex]
            : null;
        final executeBonus =
            hero.heroSpecId == HeroSpecId.combat &&
            target.hp / target.maxHp < 0.35;
        final critChance = partyHero == null
            ? 5
            : nextState.effectiveHeroCrit(partyHero);
        final isCrit = rng.nextInt(100) < critChance;
        var damage = executeBonus ? (hero.attack * 1.15).round() : hero.attack;
        String? abilityTag;
        var abilityTagArgb = _floaterDamage;
        final mods = _classAttackMods(world, hero, damage);
        damage = mods.damage;
        abilityTag = mods.tag;
        abilityTagArgb = mods.tagArgb;
        if (isCrit) {
          damage = (damage * 1.75).round();
        }
        if (target.role == EnemyRole.boss) {
          damage = (damage * BlessingConstellation.bossAtkMul(nextState)).round();
        }
        if (!reducedVfx &&
            (abilityTag == 'SWING' ||
                abilityTag == 'WILD QUIVER' ||
                abilityTag == 'MAIN GAUCHE')) {
          _spawnFloater(
            world,
            x: target.x,
            y: target.y - 0.55,
            text: abilityTag!,
            argb: abilityTagArgb,
            life: 0.55,
            priority: 1,
          );
        }
        final hasLos = _hasClearCorridor(
          world.map,
          world.openGateIds,
          hero.x.floor(),
          hero.y.floor(),
          target.x.floor(),
          target.y.floor(),
        );
        // Melee and point-blank / blocked LOS: resolve instantly so corner
        // walls can't soft-lock a floor.
        final useDirect = !hero.ranged || dist <= 1.35 || !hasLos;
        if (useDirect) {
          final wasAlive = target.hp > 0;
          var hitDmg = damage;
          if (world.afkAssist) hitDmg = (hitDmg * 2.4).round();
          final dealt = CombatRatings.mitigateByArmor(
            rawDamage: hitDmg,
            defense: target.effectiveDefense,
            attackerAttack: hero.attack,
          );
          target.hp = math.max(0, target.hp - dealt);
          _recordHeroDamage(hero, dealt);
          if (isCrit && dealt > 0) {
            _noteFeelCrit(world);
            CombatPresence.onCrit(
              world,
              hero,
              reducedVfx: reducedVfx,
              rng: rng,
            );
          }
          final resource = _actorResource(hero);
          if (_actorIsTank(hero)) {
            _gainRage(hero, 4 + dealt * 0.15);
            _applyTankSoftThreat(hero, target);
          } else if (resource == SpecResource.rage) {
            _gainRage(hero, 4 + dealt * 0.15);
          }
          if (_actorIsHealer(hero)) {
            _healLowestAlly(
              world,
              math.max(1, (dealt * 0.35).round()),
              reducedVfx: reducedVfx,
              healer: hero,
            );
            _gainRage(hero, 3);
          }
          _grantCombatResource(hero, dealt: dealt, skipRageTank: true);
          if (hero.bladeFlurryTimer > 0) {
            for (final e in world.enemies) {
              if (e.id == target.id || e.hp <= 0 || e.dormant) continue;
              if (_dist(hero, e) > 2.2) continue;
              // Dense packs: Arms Sweeping was 40% AA → blender; Combat stays lower.
              final frac = switch (hero.heroSpecId) {
                HeroSpecId.combat => 0.14,
                HeroSpecId.arms => 0.20,
                _ => 0.30,
              };
              final cleave = math.max(1, (dealt * frac).round());
              e.hp = math.max(0, e.hp - cleave);
              _recordHeroDamage(hero, cleave);
              // No per-cleave number — pack swings already shout on the main hit.
            }
          }
          _setAttackAnim(
            hero,
            target,
            _actorIsTank(hero)
                ? (isCrit || abilityTag != null ? 0.32 : 0.26)
                : 0.18,
          );
          if (!reducedVfx) {
            _spawnSlash(
              world,
              from: hero,
              to: target,
              isCrit: isCrit || abilityTag != null,
            );
            _spawnHitFloater(
              world,
              x: target.x + (rng.nextDouble() - 0.5) * 0.25,
              y: target.y - 0.3,
              dealt: dealt,
              isCrit: isCrit,
              abilityArgb: abilityTag != null ? abilityTagArgb : null,
              rng: rng,
            );
          }
          if (wasAlive && target.hp <= 0) {
            final killed = _onEnemyKilled(world, nextState, target, rng);
            goldFromKills += killed.gold;
            nextState = killed.state;
            if (!reducedVfx) {
              _spawnBurst(
                world,
                x: target.x,
                y: target.y,
                argb: _floaterGold,
                radius: 0.75,
              );
            }
          }
        } else {
          hero.attackFlash = 0.12;
          SpatialCombat._addProjectiles(
            world,
            _firePattern(
              from: hero,
              to: target,
              damage: damage,
              pattern: hero.pattern,
              forcePierce: partyHero?.gearHasPierce ?? false,
              isCrit: isCrit,
              style: abilityTag != null
                  ? boltStyleForAbility(hero, label: abilityTag)
                  : boltStyleForHero(hero),
              label: abilityTag,
              labelArgb: abilityTagArgb,
            ),
          );
        }
        final ls = partyHero?.gearLifestealPercent ?? 0;
        if (ls > 0) {
          final heal = math.max(1, (damage * ls) ~/ 100);
          final before = hero.hp;
          hero.hp = math.min(hero.effectiveMaxHp, hero.hp + heal);
          final gained = hero.hp - before;
          if (gained > 0) {
            _spawnFloater(
              world,
              x: hero.x,
              y: hero.y - 0.4,
              text: '+$gained',
              argb: _floaterHeal,
              life: 0.55,
            );
          }
        }
      }
    }
    return (state: nextState, gold: goldFromKills);
  }

  /// Proximity wake + floor-clear gate: nothing may stay dormant forever.
  /// When the pack is dead, bank ground loot immediately and open the exit.
  static GameState _wakeAndFinishFloor(
    SpatialWorld world,
    GameState state, {
    required bool reducedVfx,
  }) {
    var nextState = state;
    // Proximity wake: don't leave later chambers forever dormant.
    for (final enemy in world.enemies) {
      if (!enemy.dormant || enemy.hp <= 0) continue;
      for (final hero in world.heroes) {
        if (!hero.isAlive) continue;
        if (_dist(hero, enemy) < 11.0) {
          enemy.dormant = false;
          break;
        }
      }
    }
    if (world.allEnemiesDead && !world.awaitingExit) {
      // Instant vacuum — no idle shuffle while loot ages out on the floor.
      nextState = _vacuumGroundLoot(world, nextState);
      world.awaitingExit = true;
      world.exitWaitTimer = 0;
      world.pendingFeelStairs++;
      if (!reducedVfx) {
        final ex = world.map.exitPoint.$1 + 0.5;
        final ey = world.map.exitPoint.$2 + 0.5;
        _spawnRing(
          world,
          x: ex,
          y: ey,
          argb: 0xFF70E0A0,
          radius: 1.4,
          life: 0.65,
        );
        _spawnBurst(
          world,
          x: ex,
          y: ey,
          argb: 0x88A0FFC0,
          radius: 0.7,
          life: 0.4,
        );
        _spawnFloater(
          world,
          x: ex,
          y: ey - 0.55,
          text: 'GO',
          argb: _floaterHeal,
          life: 1.55,
          priority: 2,
        );
      }
    }
    return nextState;
  }

  /// Loot on the floor: magnet toward heroes, then bank it.
  ///
  /// Mid-fight pickups still use proximity / a short grace period. Once the
  /// pack is dead, [_wakeAndFinishFloor] vacuums everything immediately.
  static GameState _stepGroundLoot(
    SpatialWorld world,
    GameState state,
    double dt,
  ) {
    var nextState = state;
    var write = 0;
    final lootList = world.groundLoot;
    for (var i = 0; i < lootList.length; i++) {
      final loot = lootList[i];
      loot.age += dt;
      final nearHero = world.heroes.any(
        (h) => h.hp > 0 && _distPoint(loot.x, loot.y, h.x, h.y) < 2.35,
      );
      // Magnet: pull loot toward nearest living hero.
      if (!nearHero && loot.age > 0.35) {
        SpatialActor? closest;
        var best = 9.0;
        for (final h in world.heroes) {
          if (h.hp <= 0) continue;
          final d = _distPoint(loot.x, loot.y, h.x, h.y);
          if (d < best) {
            best = d;
            closest = h;
          }
        }
        if (closest != null && best < 4.5) {
          final pull = math.min(4.2 * dt, best);
          final dx = closest.x - loot.x;
          final dy = closest.y - loot.y;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len > 0.01) {
            loot.x += dx / len * pull;
            loot.y += dy / len * pull;
          }
        }
      }
      if (nearHero || loot.age > 4.5) {
        final applied = GameLogic.applyLootDrops(nextState, [loot.drop]);
        nextState = applied.state;
        final resolved = applied.resolved.isEmpty
            ? null
            : applied.resolved.first;
        final salvaged =
            resolved != null &&
            resolved.outcome == LootOutcome.stashed &&
            resolved.essenceGained > 0;
        final goldPickup = resolved?.outcome == LootOutcome.gold;
        final label = salvaged
            ? 'FULL +${resolved.essenceGained}e'
            : (loot.drop.isEquipment
                  ? loot.drop.name
                  : (goldPickup || loot.kind == GroundLootKind.gold
                        ? '+${loot.drop.amount}g'
                        : '+essence'));
        _noteFeelPickup(world);
        if (!nextState.reducedVfx) {
          _spawnSpark(
            world,
            x: loot.x,
            y: loot.y,
            argb: salvaged
                ? _floaterEssence
                : (loot.drop.isEquipment ? _floaterGear : _floaterGold),
            radius: loot.drop.isEquipment ? 0.42 : 0.28,
          );
        }
        final showFloater =
            !salvaged || world.bagFullFloaterCooldown <= 0;
        if (salvaged) {
          world.bagFullFloaterCooldown = 2.0;
        }
        if (showFloater) {
          _spawnFloater(
            world,
            x: loot.x,
            y: loot.y - 0.2,
            text: _shortFloaterLabel(label),
            argb: salvaged
                ? _floaterEssence
                : (loot.drop.isEquipment
                      ? _floaterGear
                      : (goldPickup || loot.kind == GroundLootKind.gold
                            ? _floaterGold
                            : _floaterEssence)),
            life: salvaged || loot.drop.isEquipment ? 1.4 : 1.15,
            priority: salvaged || loot.drop.isEquipment ? 2 : 1,
          );
        }
      } else {
        lootList[write++] = loot;
      }
    }
    if (write < lootList.length) {
      lootList.removeRange(write, lootList.length);
    }
    return nextState;
  }

  /// Every bolt, arrow and thrown weapon in flight this frame.
  static ({GameState state, int gold}) _stepProjectiles(
    SpatialWorld world,
    GameState state, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
  }) {
    var nextState = state;
    var goldFromKills = 0;
    final cols = world.map.cols;
    // Bin living actors by tile so bolts don't scan every foe.
    _CombatPathing.clearActorCells();
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      _CombatPathing.binActor(e, cols);
    }
    for (final h in world.heroes) {
      if (h.hp <= 0) continue;
      _CombatPathing.binActor(h, cols);
    }

    final remaining = <SpatialProjectile>[];
    for (final p in world.projectiles) {
      if (p.delay > 0) {
        p.delay -= dt;
        remaining.add(p);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0 ||
          p.x < -1 ||
          p.y < -1 ||
          p.x > world.cols + 1 ||
          p.y > world.rows + 1 ||
          !_projectileCanTravel(world, p.x, p.y)) {
        continue;
      }

      final hitR = 0.55 + p.radius;
      final hitR2 = hitR * hitR;
      final cx = p.x.floor();
      final cy = p.y.floor();
      var hit = false;
      for (var oy = -1; oy <= 1 && !hit; oy++) {
        for (var ox = -1; ox <= 1 && !hit; ox++) {
          final cell = _CombatPathing.actorsInCell(cx + ox, cy + oy, cols);
          if (cell == null) continue;
          for (final v in cell) {
            if (v.team == p.team) continue;
            if (v.hp <= 0 || (v.team == SpatialTeam.enemy && v.dormant)) {
              continue;
            }
            final dx = p.x - v.x;
            final dy = p.y - v.y;
            if (dx * dx + dy * dy >= hitR2) continue;
            final wasAlive = v.hp > 0;
            final int dealt;
            if (v.team == SpatialTeam.hero) {
              // Enemy shots already bake DEF at fire time.
              dealt = _applyHeroIncomingDamage(
                world,
                v,
                p.damage,
                reducedVfx: reducedVfx,
                rng: rng,
                isMelee: false,
              );
            } else {
              var hitDmg = p.damage;
              if (world.afkAssist) hitDmg = (hitDmg * 2.4).round();
              final caster = _heroById(world, p.casterId);
              dealt = CombatRatings.mitigateByArmor(
                rawDamage: hitDmg,
                defense: v.effectiveDefense,
                attackerAttack: caster?.attack ?? hitDmg,
              );
              v.hp = math.max(0, v.hp - dealt);
              if (caster != null) {
                _recordHeroDamage(caster, dealt);
                _applyTankSoftThreat(caster, v);
                // Ranged autos/abilities use projectiles — grant resource like
                // melee direct hits so casters/hunters aren't passive-only.
                if (dealt > 0) {
                  _grantCombatResource(caster, dealt: dealt);
                }
              }
            }
            if (dealt > 0 && p.isCrit) {
              _noteFeelCrit(world);
              final caster = _heroById(world, p.casterId);
              if (caster != null) {
                CombatPresence.onCrit(
                  world,
                  caster,
                  reducedVfx: reducedVfx,
                  rng: rng,
                );
              }
            }
            if (dealt > 0 && !reducedVfx) {
              _spawnHitFloater(
                world,
                x: v.x + (rng.nextDouble() - 0.5) * 0.25,
                y: v.y - 0.3,
                dealt: dealt,
                isCrit: p.isCrit,
                abilityArgb: p.labelArgb,
                rng: rng,
              );
            }
            if (p.onHitHealCaster && p.casterId != null && dealt > 0) {
              for (final h in world.heroes) {
                if (h.id == p.casterId && h.isAlive) {
                  _healLowestAlly(
                    world,
                    math.max(1, (dealt * 0.4).round()),
                    reducedVfx: reducedVfx,
                    healer: h,
                  );
                  _gainRage(h, 2);
                  break;
                }
              }
            }
            if (p.isCrit && !reducedVfx) {
              _spawnBurst(
                world,
                x: v.x,
                y: v.y,
                argb: _floaterCrit,
                radius: 0.7,
              );
            } else if (!reducedVfx) {
              final hitArgb = switch (p.style) {
                SpellBoltStyle.fire => 0xFFFF6030,
                SpellBoltStyle.holy => 0xFFFFE080,
                SpellBoltStyle.frost => 0xFF80D0FF,
                SpellBoltStyle.arcane => 0xFFC070FF,
                SpellBoltStyle.shadow => 0xFFB060E0,
                SpellBoltStyle.nature => 0xFF70D070,
                SpellBoltStyle.lightning => 0xFFA0E8FF,
                SpellBoltStyle.arrow => 0xFFE8D080,
                SpellBoltStyle.weapon =>
                  p.team == SpatialTeam.hero ? 0xFFFFE08A : 0xFFFF6A4A,
              };
              _spawnBurst(
                world,
                x: v.x,
                y: v.y,
                argb: hitArgb,
                radius: p.style == SpellBoltStyle.fire
                    ? 0.65
                    : (p.style == SpellBoltStyle.arrow ? 0.28 : 0.35),
                life: 0.2,
              );
            }
            hit = true;
            p.hitsRemaining -= 1;
            if (wasAlive && v.hp <= 0 && v.team == SpatialTeam.enemy) {
              final killed = _onEnemyKilled(world, nextState, v, rng);
              goldFromKills += killed.gold;
              nextState = killed.state;
              if (!reducedVfx) {
                _spawnBurst(
                  world,
                  x: v.x,
                  y: v.y,
                  argb: _floaterGold,
                  radius: 0.85,
                );
              }
            }
            if (!p.pierce || p.hitsRemaining <= 0) {
              break;
            }
          }
        }
      }
      if (!hit || (p.pierce && p.hitsRemaining > 0)) {
        if (!(hit && (!p.pierce || p.hitsRemaining <= 0))) {
          remaining.add(p);
        }
      }
    }
    world.projectiles
      ..clear()
      ..addAll(remaining);
    return (state: nextState, gold: goldFromKills);
  }

  /// Pets: follow their owner, then hit whatever the party is hitting.
  static ({GameState state, int gold}) _stepPets(
    SpatialWorld world,
    GameState state, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
  }) {
    var nextState = state;
    var goldFromKills = 0;
    final petLeader = world.leader;
    world.pets.removeWhere((p) {
      if (p.petLifeTimer <= 0) return false;
      p.petLifeTimer -= dt;
      return p.petLifeTimer <= 0;
    });
    for (final pet in world.pets) {
      if (petLeader == null) break;
      final leashOwner = _heroById(world, pet.petOwnerId) ?? petLeader;
      final ownerFocus = HeroFocus.stickyEnemy(leashOwner, world);
      final target =
          ownerFocus ?? _nearestActiveEnemy(pet, world.enemies);
      if (target == null) {
        _steerActor(
          pet,
          leashOwner.x - 0.55,
          leashOwner.y + 0.45,
          pet.moveSpeed,
          world,
          dt: dt,
          holdDistance: 0.35,
          separateFrom: <SpatialActor>[...world.heroes, ...world.pets],
        );
        continue;
      }
      final distance = _dist(pet, target);
      if (distance > pet.attackRange) {
        _steerActor(
          pet,
          target.x,
          target.y,
          pet.moveSpeed,
          world,
          dt: dt,
          holdDistance: pet.attackRange * 0.7,
          separateFrom: <SpatialActor>[...world.heroes, ...world.pets],
        );
      }
      pet.fireCooldown -= dt;
      if (pet.fireCooldown <= 0 && _dist(pet, target) <= pet.attackRange) {
        pet.fireCooldown = pet.attackCooldown;
        final wasAlive = target.hp > 0;
        final petHit = CombatRatings.mitigateByArmor(
          rawDamage: pet.attack,
          defense: target.effectiveDefense,
          attackerAttack: pet.attack,
        );
        target.hp = math.max(0, target.hp - petHit);
        pet.attackFlash = 0.14;
        final owner =
            _heroById(world, pet.petOwnerId) ??
            (pet.id.startsWith('classpet_')
                ? _heroById(world, pet.id.replaceFirst('classpet_', ''))
                : null);
        if (owner != null) {
          _recordHeroDamage(owner, petHit);
        }
        if (!reducedVfx) {
          _spawnSlash(world, from: pet, to: target, isCrit: false);
        }
        _spawnFloater(
          world,
          x: target.x,
          y: target.y - 0.25,
          text: '$petHit',
          argb: _floaterPet,
          life: 0.6,
        );
        if (wasAlive && target.hp <= 0) {
          final killed = _onEnemyKilled(world, nextState, target, rng);
          goldFromKills += killed.gold;
          nextState = killed.state;
        }
      }
    }
    return (state: nextState, gold: goldFromKills);
  }

  /// God Hand: AOE damage + brief party guidance toward the tap.
  static SpatialStepResult godHand(
    SpatialWorld world,
    GameState state, {
    required double tileX,
    required double tileY,
    int? baseDamage,
  }) {
    if (world.godHandCooldown > 0) {
      return SpatialStepResult(world: world, state: state);
    }
    world.guideX = tileX;
    world.guideY = tileY;
    world.guideTimer = 1.35;
    world.godHandCooldown = state.godHandCooldownSeconds;
    world.pulseX = tileX;
    world.pulseY = tileY;
    world.pulseTimer = 0.35;
    final damage = state.godHandSmashDamage(baseDamage: baseDamage);
    final radius = state.godHandSmashRadius;
    world.godHandRadius = radius;
    final reduced = state.reducedVfx;
    if (!reduced) {
      _spawnRing(
        world,
        x: tileX,
        y: tileY,
        argb: 0xFFFFE080,
        radius: radius * 0.55,
        life: 0.42,
      );
      _spawnBurst(
        world,
        x: tileX,
        y: tileY,
        argb: 0xAAFFF0A0,
        radius: radius * 0.35,
        life: 0.28,
      );
    }
    var gold = 0;
    var nextState = state;
    final rng = GameLogic.random;
    for (final enemy in world.enemies) {
      if (enemy.hp <= 0 || enemy.dormant) continue;
      if (_distPoint(tileX, tileY, enemy.x, enemy.y) <= radius) {
        final wasAlive = enemy.hp > 0;
        enemy.hp = math.max(0, enemy.hp - damage);
        if (!reduced) {
          _spawnFloater(
            world,
            x: enemy.x,
            y: enemy.y - 0.35,
            text: '$damage',
            argb: _floaterDamage,
            life: 0.75,
          );
        }
        if (wasAlive && enemy.hp <= 0) {
          final killed = _onEnemyKilled(world, nextState, enemy, rng);
          gold += killed.gold;
          nextState = killed.state;
        }
      }
    }
    _updateChambers(world, reducedVfx: reduced, softLock: true);
    final synced = _syncHp(nextState, world);
    return _stepResult(
      world,
      synced,
      goldFromKills: gold,
    );
  }

  static GameState _syncHp(GameState state, SpatialWorld world) {
    final fighting = state.combatHeroes;
    final hpById = <String, int>{};
    var heroesDirty = false;
    for (var i = 0; i < fighting.length; i++) {
      final h = fighting[i];
      final spatial = i < world.heroes.length ? world.heroes[i] : null;
      final baseMax = state.effectiveHeroMaxHp(h);
      final nextHp = spatial?.hp.clamp(0, baseMax) ?? 0;
      hpById[h.id] = nextHp;
      if (nextHp != h.currentHp) heroesDirty = true;
    }
    var enemiesDirty = false;
    for (var i = 0; i < state.enemies.length; i++) {
      final e = state.enemies[i];
      final spatial = i < world.enemies.length ? world.enemies[i] : null;
      final nextHp = spatial?.hp.clamp(0, e.maxHp) ?? 0;
      if (nextHp != e.currentHp) {
        enemiesDirty = true;
        break;
      }
    }
    if (!heroesDirty && !enemiesDirty) return state;

    List<PartyHero>? heroes;
    if (heroesDirty) {
      // Keep full active party membership; Tiny only fights a subset.
      heroes = [
        for (final h in state.heroes)
          if (hpById.containsKey(h.id))
            h.copyWith(currentHp: hpById[h.id])
          else
            h,
      ];
    }
    List<EnemyUnit>? enemies;
    if (enemiesDirty) {
      enemies = <EnemyUnit>[];
      for (var i = 0; i < state.enemies.length; i++) {
        final e = state.enemies[i];
        final spatial = i < world.enemies.length ? world.enemies[i] : null;
        enemies.add(e.copyWith(currentHp: spatial?.hp.clamp(0, e.maxHp) ?? 0));
      }
    }
    return state.copyWith(heroes: heroes, enemies: enemies);
  }

  static void _updateChambers(
    SpatialWorld world, {
    bool reducedVfx = false,
    bool softLock = true,
  }) {
    if (world.map.chambers.isEmpty) return;

    final chamberCount = world.map.chambers.length;
    // Chambers unlock in order, while empty chambers are safely skipped.
    while (world.clearedChambers.length < chamberCount) {
      var maxCleared = -1;
      for (final chamber in world.clearedChambers) {
        if (chamber > maxCleared) maxCleared = chamber;
      }
      final next = maxCleared + 1;
      if (next >= chamberCount) break;
      final hasLivingEnemy = world.enemies.any(
        (enemy) => enemy.chamberIndex == next && enemy.hp > 0,
      );
      if (hasLivingEnemy) break;
      world.clearedChambers.add(next);
      if (!reducedVfx) {
        for (final chamber in world.map.chambers) {
          if (chamber.index != next) continue;
          _spawnRing(
            world,
            x: chamber.x + chamber.w * 0.5,
            y: chamber.y + chamber.h * 0.5,
            argb: 0xFF50C070,
            radius: math.min(chamber.w, chamber.h) * 0.35,
            life: 0.55,
          );
          break;
        }
      }
    }

    for (final gate in world.map.gates) {
      if (!world.clearedChambers.contains(gate.opensAfterChamber)) continue;
      final wasOpen = world.openGateIds.contains(gate.id);
      world.openGateIds.add(gate.id);
      if (!wasOpen && !reducedVfx) {
        // One shout per door strip — multi-tile gates used to spam OPEN×3.
        var alreadyShouted = false;
        for (final f in world.floaters) {
          if (f.text == 'OPEN' && f.priority >= 2) {
            alreadyShouted = true;
            break;
          }
        }
        _spawnRing(
          world,
          x: gate.x + 0.5,
          y: gate.y + 0.5,
          argb: 0xFFFFD070,
          radius: 1.0,
          life: 0.4,
        );
        if (!alreadyShouted) {
          _spawnSpark(
            world,
            x: gate.x + 0.5,
            y: gate.y + 0.5,
            argb: 0xFFFFF0A0,
            radius: 0.55,
          );
          _spawnFloater(
            world,
            x: gate.x + 0.5,
            y: gate.y - 0.45,
            text: 'OPEN',
            argb: _floaterGold,
            life: 0.7,
            priority: 2,
          );
        }
      }
    }

    var maxCleared = -1;
    for (final chamber in world.clearedChambers) {
      if (chamber > maxCleared) maxCleared = chamber;
    }
    final nextChamber = math.min(chamberCount - 1, maxCleared + 1);
    world.activeChamber = nextChamber;
    for (final enemy in world.enemies) {
      if (enemy.chamberIndex <= maxCleared + 1 ||
          enemy.chamberIndex == nextChamber) {
        enemy.dormant = false;
      }
    }

    // Idle-safe: if nothing active remains but dormant packs do, open the
    // road and wake them so the party isn't soft-locked behind gates.
    final hasActive = world.enemies.any((e) => e.hp > 0 && !e.dormant);
    final hasDormant = world.enemies.any((e) => e.hp > 0 && e.dormant);
    if (!hasActive && hasDormant) {
      _openAllGatesAndWake(world);
    }

    // Path soft-lock once per step (not on the early chamber pass).
    if (softLock) {
      _unlockIfEnemiesUnreachable(world);
    }
  }

  static void _openAllGatesAndWake(SpatialWorld world) {
    for (final gate in world.map.gates) {
      world.openGateIds.add(gate.id);
    }
    for (final enemy in world.enemies) {
      if (enemy.hp > 0) enemy.dormant = false;
    }
  }

  /// Opens remaining gates when any *active* living enemy is unreachable.
  /// One flood-fill from the party — not heroes×enemies BFS.
  static void _unlockIfEnemiesUnreachable(SpatialWorld world) {
    if (!_CombatPathing.anyActiveEnemyUnreachable(world)) return;
    _openAllGatesAndWake(world);
  }

  /// Projectiles die on solid walls, but graze open corners so diagonal
  /// point-blank shots aren't eaten by tile floors.
  static bool _projectileCanTravel(SpatialWorld world, double x, double y) {
    if (world.canWalk(x, y)) return true;
    final fx = x.floor();
    final fy = y.floor();
    final lx = x - fx;
    final ly = y - fy;
    // Near a corner: allow if both adjacent cardinals are walkable.
    if (lx < 0.2 || lx > 0.8 || ly < 0.2 || ly > 0.8) {
      final ox = lx < 0.5 ? fx - 1 : fx + 1;
      final oy = ly < 0.5 ? fy - 1 : fy + 1;
      final sideX = world.canWalkTile(ox, fy);
      final sideY = world.canWalkTile(fx, oy);
      if (sideX && sideY) return true;
      if (sideX && world.canWalkTile(fx, fy + (ly < 0.5 ? -1 : 1))) {
        return true;
      }
      if (sideY && world.canWalkTile(fx + (lx < 0.5 ? -1 : 1), fy)) {
        return true;
      }
    }
    return false;
  }

  /// Apply any remaining ground loot into state and clear the pile.
  /// Used when exit starts early (AFK) or right before roomCleared.
  static GameState _vacuumGroundLoot(SpatialWorld world, GameState state) {
    if (world.groundLoot.isEmpty) return state;
    final drops = <LootDrop>[for (final loot in world.groundLoot) loot.drop];
    world.groundLoot.clear();
    return GameLogic.applyLootDrops(state, drops).state;
  }

  static ({int gold, GameState state}) _onEnemyKilled(
    SpatialWorld world,
    GameState state,
    SpatialActor enemy,
    math.Random rng,
  ) {
    // Clear Living Bomb HUD if this was the armed target.
    final bombCasterId = enemy.livingBombCasterId;
    if (enemy.livingBombTimer > 0 || bombCasterId != null) {
      enemy.livingBombTimer = 0;
      enemy.livingBombDps = 0;
      enemy.livingBombAcc = 0;
      enemy.livingBombCasterId = null;
      if (bombCasterId != null) {
        final caster = _heroById(world, bombCasterId);
        if (caster != null) caster.livingBombArmed = 0;
      }
    }
    final index = world.enemies.indexOf(enemy);
    final unit = index >= 0 && index < state.enemies.length
        ? state.enemies[index]
        : null;
    final rewardGold = unit?.rewardGold ?? 0;
    _noteFeelKill(world);
    if (!state.reducedVfx) {
      if (enemy.role == EnemyRole.boss) {
        _spawnRing(
          world,
          x: enemy.x,
          y: enemy.y,
          argb: _floaterCrit,
          radius: 1.35,
          life: 0.48,
        );
        _spawnBurst(
          world,
          x: enemy.x,
          y: enemy.y,
          argb: 0xAAFFF0A0,
          radius: 0.85,
          life: 0.38,
        );
        _spawnFloater(
          world,
          x: enemy.x,
          y: enemy.y - 0.85,
          text: 'BOSS DOWN',
          argb: _floaterCrit,
          life: 1.55,
          priority: 2,
        );
      } else if (enemy.role == EnemyRole.elite) {
        _spawnRing(
          world,
          x: enemy.x,
          y: enemy.y,
          argb: _floaterGold,
          radius: 0.95,
          life: 0.36,
        );
      } else {
        _spawnBurst(
          world,
          x: enemy.x,
          y: enemy.y,
          argb: 0xAAFFE8A0,
          radius: 0.55,
          life: 0.28,
        );
      }
    }
    final drops = state.inGreaterRift
        ? const <LootDrop>[]
        : GameLogic.rollKillLoot(
            state.battleNumber,
            ascensionLevel: state.ascensionLevel,
            lootFindPercent: state.petLootFindPercent,
            hardmodeLevel: Keystone.combatLevel(state),
            party: state.heroes,
            dungeonId: state.dungeonId,
            enemyRole: enemy.role,
          );
    for (var i = 0; i < drops.length; i++) {
      final drop = drops[i];
      final angle = (i / math.max(1, drops.length)) * math.pi * 2;
      world.groundLoot.add(
        GroundLoot(
          x: enemy.x + math.cos(angle) * 0.35 * (0.6 + i * 0.15),
          y: enemy.y + math.sin(angle) * 0.35 * (0.6 + i * 0.15),
          drop: drop,
        ),
      );
      if (drop.isEquipment) {
        // One LOOT! per kill pack — skip extras when the screen is already busy.
        final busyLoot = world.floaters
            .where((f) => f.text == 'LOOT!' || f.priority >= 2)
            .length;
        if (busyLoot < 2) {
          _spawnFloater(
            world,
            x: enemy.x + 0.2 + i * 0.05,
            y: enemy.y - 0.15,
            text: 'LOOT!',
            argb: _floaterGear,
            life: 0.95,
            priority: 2,
          );
        }
      }
    }
    if (rewardGold > 0) {
      _spawnFloater(
        world,
        x: enemy.x,
        y: enemy.y - 0.55,
        text: '+${rewardGold}g',
        argb: _floaterGold,
        life: 1.15,
        priority: 1,
      );
    }
    var next = state;
    if (unit != null) {
      final beforeLevels = [for (final h in next.heroes) h.level];
      next = GameLogic.awardEnemyKillXp(next, unit);
      final xp = GameLogic.xpForEnemy(unit);
      _spawnFloater(
        world,
        x: enemy.x - 0.15,
        y: enemy.y - 0.75,
        text: '+${xp}XP',
        argb: _floaterXp,
        life: 0.85,
        priority: 0,
      );
      var leveledFloater = false;
      for (var i = 0; i < next.heroes.length; i++) {
        if (next.heroes[i].level > beforeLevels[i]) {
          if (!leveledFloater) {
            leveledFloater = true;
            _noteFeelLevelUp(world);
            _spawnFloater(
              world,
              x: world.heroes.length > i ? world.heroes[i].x : enemy.x,
              y: (world.heroes.length > i ? world.heroes[i].y : enemy.y) - 0.9,
              text: 'LEVEL UP!',
              argb: _floaterXp,
              life: 1.45,
              priority: 2,
            );
          }
          if (i < world.heroes.length) {
            final h = next.heroes[i];
            final a = world.heroes[i];
            final newMax = next.effectiveHeroMaxHp(h);
            final delta = newMax - a.maxHp;
            a.maxHp = newMax;
            if (a.hp > 0 && delta > 0) {
              a.hp = math.min(a.effectiveMaxHp, a.hp + delta);
            }
            a.attack = next.effectiveHeroAttack(h);
            a.defense = next.effectiveHeroDefense(h);
            a.heroLevel = h.level;
            a.moveSpeed = next.effectiveHeroMoveSpeed(h);
            a.attackCooldown = 1.0 / next.effectiveHeroAttackSpeed(h);
          }
        }
      }
    }
    return (gold: rewardGold, state: next);
  }

  static SpatialActor? _nearestActiveEnemy(
    SpatialActor self,
    List<SpatialActor> enemies,
  ) => HeroFocus.nearestActiveEnemy(self, enemies);

  /// Role-aware focus: peel extras off tank, sticky lock, boss/execute bias.
  /// Optional [cache] kept for call sites that build [_FocusTickCache].
  static SpatialActor? _pickSmartFocus(
    SpatialActor self,
    SpatialWorld world, [
    _FocusTickCache? cache,
  ]) {
    return HeroFocus.pickSmartFocus(self, world);
  }

  /// Test hook for peel / sticky focus scoring.
  static SpatialActor? pickSmartFocusForTest(
    SpatialActor self,
    SpatialWorld world,
  ) => HeroFocus.pickSmartFocus(self, world);

  /// Test hook: tank taunt + CombatPresence bark path.
  static bool testTauntForPresence(SpatialWorld world, SpatialActor tank) {
    return _tauntLooseEnemies(world, tank, reducedVfx: false);
  }

  static int _countNearbyEnemies(
    SpatialActor self,
    SpatialWorld world, {
    double radius = 3.2,
  }) {
    var n = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (_dist(self, e) <= radius) n++;
    }
    return n;
  }

  static void _applyTankSoftThreat(SpatialActor tank, SpatialActor enemy) {
    if (!_actorIsTank(tank) || enemy.hp <= 0) return;
    if (enemy.forcedTargetTimer < 1.2) {
      enemy.forcedTargetId = tank.id;
      enemy.forcedTargetTimer = math.max(enemy.forcedTargetTimer, 1.4);
    }
  }

  /// Pull the nearest loose enemy (attacking an ally) onto [tank].
  /// Returns true when at least one enemy was taunted.
  static bool _tauntLooseEnemies(
    SpatialWorld world,
    SpatialActor tank, {
    required bool reducedVfx,
  }) {
    SpatialActor? loose;
    var best = double.infinity;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (e.forcedTargetTimer > 0) continue;
      final focus = _focusHero(e, world.heroes);
      if (focus == null || focus.id == tank.id) continue;
      final d = _dist(tank, e);
      if (d < best && d <= 5.5) {
        best = d;
        loose = e;
      }
    }
    if (loose == null) return false;
    loose.forcedTargetId = tank.id;
    loose.forcedTargetTimer = 4.0;
    if (!reducedVfx) {
      _spawnFloater(
        world,
        x: loose.x,
        y: loose.y - 0.45,
        text: 'TAUNT',
        argb: 0xFFFFAA55,
        life: 0.7,
      );
      CombatPresence.onTaunt(world, tank, reducedVfx: reducedVfx);
    }
    return true;
  }

  /// Enemies focus the tank when possible (aggro toward frontliner).
  static SpatialActor? _focusHero(
    SpatialActor enemy,
    List<SpatialActor> heroes,
  ) {
    if (enemy.forcedTargetTimer > 0 && enemy.forcedTargetId != null) {
      for (final h in heroes) {
        if (h.isAlive && h.id == enemy.forcedTargetId) return h;
      }
    }
    SpatialActor? tank;
    SpatialActor? nearest;
    var bestD = double.infinity;
    for (final h in heroes) {
      if (!h.isAlive || h.vanishTimer > 0) continue;
      final d = _dist(enemy, h);
      if (_actorIsTank(h)) tank = h;
      if (d < bestD) {
        bestD = d;
        nearest = h;
      }
    }
    // Tanks hold a wider soft-taunt leash so packs stick to them.
    final leash = tank != null ? 4.0 : 2.5;
    if (tank != null && _dist(enemy, tank) < bestD + leash) {
      return tank;
    }
    return nearest;
  }

  static double _dist(SpatialActor a, SpatialActor b) =>
      _distPoint(a.x, a.y, b.x, b.y);

  static double _distPoint(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Steering: path around walls, hold preferred range, separate from allies.
  /// Soft inertia + idle jitter so holds don't look robotic.
  static void _steerActor(
    SpatialActor a,
    double tx,
    double ty,
    double speed,
    SpatialWorld world, {
    required double dt,
    double holdDistance = 0,
    List<SpatialActor>? separateFrom,
    double separationRadius = 0.95,
    double separationWeight = 1.4,
  }) {
    if (speed <= 0 || dt <= 0) return;
    final dist = _distPoint(a.x, a.y, tx, ty);
    if (holdDistance > 0 && dist <= holdDistance) {
      CombatPresence.applyIdlePresence(
        a,
        world,
        dt,
        separateFrom: separateFrom,
        separationRadius: separationRadius,
        separationWeight: separationWeight,
        stepBudget: speed * dt * 0.55,
      );
      CombatPresence.updateFacing(a, tx, ty, dt);
      return;
    }

    final waypoint = _nextWaypoint(
      world.map,
      world.openGateIds,
      a.x,
      a.y,
      tx,
      ty,
    );
    // No full path (closed gate / disconnected): still greedy-slide so God Hand
    // and corridor approaches make progress instead of freezing.
    final wx = waypoint?.$1 ?? tx;
    final wy = waypoint?.$2 ?? ty;
    var dx = wx - a.x;
    var dy = wy - a.y;

    if (separateFrom != null) {
      var sx = 0.0;
      var sy = 0.0;
      for (final o in separateFrom) {
        if (identical(o, a) || !o.isAlive) continue;
        final d = _distPoint(a.x, a.y, o.x, o.y);
        if (d < 0.01 || d > separationRadius) continue;
        final push = (separationRadius - d) / separationRadius;
        sx += (a.x - o.x) / d * push;
        sy += (a.y - o.y) / d * push;
      }
      dx += sx * separationWeight;
      dy += sy * separationWeight;
    }

    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) {
      CombatPresence.applyIdlePresence(
        a,
        world,
        dt,
        separateFrom: separateFrom,
        separationRadius: separationRadius,
        separationWeight: separationWeight,
        stepBudget: speed * dt * 0.4,
      );
      return;
    }
    var desiredVx = dx / len * speed;
    var desiredVy = dy / len * speed;
    // Short remaining distance: ease so we don't overshoot the hold ring.
    if (dist < speed * 0.2) {
      final ease = (dist / math.max(0.05, speed * 0.2)).clamp(0.15, 1.0);
      desiredVx *= ease;
      desiredVy *= ease;
    }
    CombatPresence.applyVelocityMove(
      a,
      world,
      desiredVx: desiredVx,
      desiredVy: desiredVy,
      dt: dt,
      maxSpeed: speed,
    );
    CombatPresence.updateFacing(a, tx, ty, dt);
  }

  static void _applySeparation(
    SpatialActor a,
    SpatialWorld world,
    List<SpatialActor>? others,
    double step, {
    double radius = 0.95,
    double weight = 1.0,
  }) {
    if (others == null || step <= 0) return;
    var sx = 0.0;
    var sy = 0.0;
    for (final o in others) {
      if (identical(o, a) || !o.isAlive) continue;
      final d = _distPoint(a.x, a.y, o.x, o.y);
      if (d < 0.01 || d > radius) continue;
      final push = (radius - d) / radius;
      sx += (a.x - o.x) / d * push * weight;
      sy += (a.y - o.y) / d * push * weight;
    }
    final len = math.sqrt(sx * sx + sy * sy);
    if (len < 0.001) return;
    final nx = a.x + sx / len * step;
    final ny = a.y + sy / len * step;
    if (world.canWalk(nx, a.y)) a.x = nx;
    if (world.canWalk(a.x, ny)) a.y = ny;
  }

  /// Snap a world point onto the nearest walkable tile center.
  static (double, double) _snapToWalkable(
    TileMap map,
    Set<int> openGateIds,
    double tx,
    double ty,
  ) {
    final tile = _nearestWalkableTile(
      map,
      openGateIds,
      tx.floor().clamp(0, map.cols - 1),
      ty.floor().clamp(0, map.rows - 1),
    );
    return (tile.$1 + 0.5, tile.$2 + 0.5);
  }

  static (int, int) _nearestWalkableTile(
    TileMap map,
    Set<int> openGateIds,
    int gx,
    int gy,
  ) {
    if (map.isWalkable(gx, gy, openGateIds: openGateIds)) return (gx, gy);
    const dirs = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];
    final q = <(int, int)>[(gx, gy)];
    final seen = <int>{_key(gx, gy, map.cols)};
    var head = 0;
    while (head < q.length) {
      final cur = q[head++];
      for (final d in dirs) {
        final nx = cur.$1 + d.$1;
        final ny = cur.$2 + d.$2;
        if (!map.inBounds(nx, ny)) continue;
        final k = _key(nx, ny, map.cols);
        if (!seen.add(k)) continue;
        if (map.isWalkable(nx, ny, openGateIds: openGateIds)) {
          return (nx, ny);
        }
        q.add((nx, ny));
      }
      if (seen.length > 64) break;
    }
    // Last resort: exit / spawn.
    final ex = map.exitPoint;
    if (map.isWalkable(ex.$1, ex.$2, openGateIds: openGateIds)) {
      return ex;
    }
    if (map.spawnPoints.isNotEmpty) return map.spawnPoints.first;
    return (gx.clamp(0, map.cols - 1), gy.clamp(0, map.rows - 1));
  }

  static void _tickEnemySpecials(
    SpatialWorld world,
    SpatialActor enemy,
    SpatialActor focus,
    double dt, {
    required math.Random rng,
    required bool reducedVfx,
  }) {
    // Tank / boss: enrage under 40% HP.
    if ((enemy.archetype == EnemyArchetype.tank ||
            enemy.role == EnemyRole.boss) &&
        enemy.hp < enemy.effectiveMaxHp * 0.4 &&
        enemy.enrageTimer <= 0) {
      enemy.enrageTimer = 5.0;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: enemy.x,
          y: enemy.y - 0.45,
          text: 'ENRAGE',
          argb: 0xFFFF4040,
          life: 0.9,
        );
      }
    }

    if (enemy.specialCd > 0) return;

    if (enemy.archetype == EnemyArchetype.support) {
      SpatialActor? lowest;
      for (final ally in world.enemies) {
        if (!ally.isAlive || ally.dormant) continue;
        if (_dist(enemy, ally) > 5.0) continue;
        if (lowest == null ||
            ally.hp / ally.effectiveMaxHp < lowest.hp / lowest.effectiveMaxHp) {
          lowest = ally;
        }
      }
      if (lowest != null && lowest.hp < lowest.effectiveMaxHp) {
        final healMul = world.afkAssist ? 0.4 : 1.0;
        final heal = math.max(8, (enemy.attack * 1.4 * healMul).round());
        lowest.hp = math.min(lowest.effectiveMaxHp, lowest.hp + heal);
        enemy.specialCd = world.afkAssist ? 6.0 : 5.0;
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: lowest.x,
            y: lowest.y - 0.35,
            text: '+$heal',
            argb: _floaterHeal,
            life: 0.7,
          );
        }
      }
    } else if (enemy.archetype == EnemyArchetype.ranged) {
      if (_dist(enemy, focus) <= 5.5) {
        focus.attackSlowTimer = math.max(focus.attackSlowTimer, 2.2);
        focus.demoShoutTimer = math.max(focus.demoShoutTimer, 2.0);
        enemy.specialCd = 6.0;
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: focus.x,
            y: focus.y - 0.5,
            text: 'HEX',
            argb: 0xFFB060FF,
            life: 0.75,
          );
        }
      }
    } else if (enemy.archetype == EnemyArchetype.brute &&
        (enemy.role == EnemyRole.elite || enemy.role == EnemyRole.boss)) {
      var hit = false;
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        if (_dist(enemy, h) > 2.6) continue;
        var chip = math.max(2, (enemy.effectiveAttack * 0.35).round());
        if (world.afkAssist) chip = math.max(1, (chip * 0.4).round());
        _applyHeroIncomingDamage(
          world,
          h,
          chip,
          reducedVfx: reducedVfx,
          rng: rng,
          isMelee: true,
        );
        hit = true;
      }
      if (hit) {
        enemy.specialCd = world.afkAssist ? 7.0 : 6.5;
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: enemy.x,
            y: enemy.y - 0.4,
            text: 'CLEAVE',
            argb: 0xFFFF8040,
            life: 0.7,
          );
        }
      }
    } else if (enemy.archetype == EnemyArchetype.tank &&
        enemy.hp < enemy.effectiveMaxHp * 0.55 &&
        enemy.bonusMaxHp <= 0) {
      enemy.bonusMaxHp = math.max(20, (enemy.maxHp * 0.15).round());
      enemy.hp = math.min(enemy.effectiveMaxHp, enemy.hp + enemy.bonusMaxHp);
      enemy.specialCd = 8.0;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: enemy.x,
          y: enemy.y - 0.4,
          text: 'FORTIFY',
          argb: 0xFF80C0FF,
          life: 0.7,
        );
      }
    }

    // Boss pulse AoE.
    if (enemy.role == EnemyRole.boss && enemy.specialCd <= 0) {
      var hit = false;
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        if (_dist(enemy, h) > 3.4) continue;
        var pulse = math.max(4, (enemy.effectiveAttack * 0.55).round());
        if (world.afkAssist) pulse = math.max(1, (pulse * 0.35).round());
        _applyHeroIncomingDamage(
          world,
          h,
          pulse,
          reducedVfx: reducedVfx,
          rng: rng,
          isMelee: true,
        );
        hit = true;
      }
      if (hit) {
        enemy.specialCd = world.afkAssist ? 9.0 : 8.0;
        if (!reducedVfx) {
          _spawnBurst(
            world,
            x: enemy.x,
            y: enemy.y,
            argb: 0xAAFF3030,
            radius: 1.4,
          );
          _spawnFloater(
            world,
            x: enemy.x,
            y: enemy.y - 0.55,
            text: 'PULSE',
            argb: 0xFFFF5050,
            life: 0.85,
          );
        }
      }
    }
  }

  /// First step toward goal via BFS when walls block a straight line.
  /// Returns null when the goal is unreachable with current open gates.
  static (double, double)? _nextWaypoint(
    TileMap map,
    Set<int> openGateIds,
    double fx,
    double fy,
    double tx,
    double ty,
  ) {
    final sx = fx.floor().clamp(0, map.cols - 1);
    final sy = fy.floor().clamp(0, map.rows - 1);
    var gx = tx.floor().clamp(0, map.cols - 1);
    var gy = ty.floor().clamp(0, map.rows - 1);
    // Approach offsets can land on walls ? path to nearest walkable instead.
    final goal = _nearestWalkableTile(map, openGateIds, gx, gy);
    gx = goal.$1;
    gy = goal.$2;
    if (sx == gx && sy == gy) return (gx + 0.5, gy + 0.5);

    if (_hasClearCorridor(map, openGateIds, sx, sy, gx, gy)) {
      return (gx + 0.5, gy + 0.5);
    }

    final came = <int, int>{};
    final q = <(int, int)>[(sx, sy)];
    var head = 0;
    came[_key(sx, sy, map.cols)] = _key(sx, sy, map.cols);
    const dirs = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];
    var found = false;
    while (head < q.length) {
      final cur = q[head++];
      if (cur.$1 == gx && cur.$2 == gy) {
        found = true;
        break;
      }
      for (final d in dirs) {
        final nx = cur.$1 + d.$1;
        final ny = cur.$2 + d.$2;
        final k = _key(nx, ny, map.cols);
        if (came.containsKey(k)) continue;
        if (!map.isWalkable(nx, ny, openGateIds: openGateIds)) continue;
        came[k] = _key(cur.$1, cur.$2, map.cols);
        q.add((nx, ny));
      }
      if (came.length > map.cols * map.rows) break;
    }
    if (!found) return null;

    // Walk back one step from goal toward start; return next tile from start.
    var ck = _key(gx, gy, map.cols);
    final startKey = _key(sx, sy, map.cols);
    var guard = 0;
    while (came[ck] != startKey && came[ck] != null && guard++ < 400) {
      ck = came[ck]!;
    }
    final nextX = ck % map.cols;
    final nextY = ck ~/ map.cols;
    return (nextX + 0.5, nextY + 0.5);
  }

  static int _key(int x, int y, int cols) => y * cols + x;

  static bool _hasClearCorridor(
    TileMap map,
    Set<int> openGateIds,
    int x0,
    int y0,
    int x1,
    int y1,
  ) {
    var x = x0;
    var y = y0;
    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx - dy;
    while (true) {
      if (!map.isWalkable(x, y, openGateIds: openGateIds)) return false;
      if (x == x1 && y == y1) return true;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }

  static List<SpatialProjectile> _firePattern({
    required SpatialActor from,
    required SpatialActor to,
    required int damage,
    required ProjectilePattern pattern,
    bool forcePierce = false,
    bool isCrit = false,
    SpellBoltStyle style = SpellBoltStyle.weapon,
    String? label,
    int? labelArgb,
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, 999);
    final ux = dx / len;
    final uy = dy / len;
    final speed = switch (style) {
      SpellBoltStyle.fire => 6.2,
      SpellBoltStyle.holy => 8.5,
      SpellBoltStyle.frost => 7.0,
      SpellBoltStyle.arcane => 8.0,
      SpellBoltStyle.shadow => 6.8,
      SpellBoltStyle.nature => 7.2,
      SpellBoltStyle.lightning => 9.0,
      SpellBoltStyle.arrow => 11.0,
      SpellBoltStyle.weapon => 7.5,
    };
    final pierce = forcePierce || pattern == ProjectilePattern.pierce;
    final radius = switch (style) {
      SpellBoltStyle.fire => label == 'PYRO' ? 0.28 : 0.2,
      SpellBoltStyle.holy => 0.14,
      SpellBoltStyle.arcane => 0.16,
      SpellBoltStyle.frost => 0.18,
      SpellBoltStyle.shadow => 0.16,
      SpellBoltStyle.nature => 0.17,
      SpellBoltStyle.lightning => 0.13,
      SpellBoltStyle.arrow => 0.1,
      _ => 0.12,
    };

    SpatialProjectile shot(
      double angleOffset, {
      double life = 1.6,
      double delay = 0,
    }) {
      final cos = math.cos(angleOffset);
      final sin = math.sin(angleOffset);
      final vx = (ux * cos - uy * sin) * speed;
      final vy = (ux * sin + uy * cos) * speed;
      return SpatialProjectile(
        x: from.x,
        y: from.y,
        vx: vx,
        vy: vy,
        damage: damage,
        team: from.team,
        life: life + delay,
        pierce: pierce,
        hitsRemaining: pierce ? 3 : 1,
        isCrit: isCrit,
        style: style,
        label: label,
        labelArgb: labelArgb,
        radius: radius,
        delay: delay,
        onHitHealCaster: from.heroRole == HeroRole.healer,
        casterId: from.id,
      );
    }

    return switch (pattern) {
      ProjectilePattern.single || ProjectilePattern.pierce => [shot(0)],
      ProjectilePattern.spread => [shot(-0.28), shot(0), shot(0.28)],
      ProjectilePattern.arc => [
        shot(-0.45, life: 1.3),
        shot(-0.15, life: 1.4),
        shot(0.15, life: 1.4),
        shot(0.45, life: 1.3),
      ],
    };
  }

  /// WoW-style single spell bolt (Fireball, Penance tick, etc.).
  static SpatialProjectile _spellBolt({
    required SpatialActor from,
    required SpatialActor to,
    required int damage,
    required SpellBoltStyle style,
    String? label,
    int? labelArgb,
    double delay = 0,
    bool isCrit = false,
  }) {
    final bolt = _firePattern(
      from: from,
      to: to,
      damage: damage,
      pattern: ProjectilePattern.single,
      isCrit: isCrit,
      style: style,
      label: label,
      labelArgb: labelArgb,
    ).first;
    bolt.delay = delay;
    return bolt;
  }

  /// Bolt between arbitrary points (chain lightning hops, etc.).
  static SpatialProjectile spellBoltBetween({
    required double x0,
    required double y0,
    required double x1,
    required double y1,
    required int damage,
    required SpellBoltStyle style,
    required SpatialTeam team,
    String? casterId,
    String? label,
    int? labelArgb,
    double delay = 0,
    bool isCrit = false,
  }) {
    final dx = x1 - x0;
    final dy = y1 - y0;
    final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, 999);
    final speed = switch (style) {
      SpellBoltStyle.fire => 6.2,
      SpellBoltStyle.holy => 8.5,
      SpellBoltStyle.frost => 7.0,
      SpellBoltStyle.arcane => 8.0,
      SpellBoltStyle.shadow => 6.8,
      SpellBoltStyle.nature => 7.2,
      SpellBoltStyle.lightning => 10.5,
      SpellBoltStyle.arrow => 11.0,
      SpellBoltStyle.weapon => 7.5,
    };
    final radius = switch (style) {
      SpellBoltStyle.fire => 0.2,
      SpellBoltStyle.lightning => 0.14,
      SpellBoltStyle.arrow => 0.1,
      SpellBoltStyle.frost => 0.18,
      _ => 0.14,
    };
    return SpatialProjectile(
      x: x0,
      y: y0,
      vx: (dx / len) * speed,
      vy: (dy / len) * speed,
      damage: damage,
      team: team,
      life: 1.4 + delay,
      pierce: false,
      hitsRemaining: 1,
      isCrit: isCrit,
      style: style,
      label: label,
      labelArgb: labelArgb,
      radius: radius,
      delay: delay,
      casterId: casterId,
    );
  }

  static int burstArgbForStyle(SpellBoltStyle style) => switch (style) {
    SpellBoltStyle.fire => 0xFFFF6030,
    SpellBoltStyle.holy => 0xFFFFE080,
    SpellBoltStyle.frost => 0xFF80D0FF,
    SpellBoltStyle.arcane => 0xFFC070FF,
    SpellBoltStyle.shadow => 0xFFB060E0,
    SpellBoltStyle.nature => 0xFF70D070,
    SpellBoltStyle.lightning => 0xFFA0E8FF,
    SpellBoltStyle.arrow => 0xFFE8D080,
    SpellBoltStyle.weapon => 0xFFFFE08A,
  };

  static void _announceCast(
    SpatialWorld world,
    SpatialActor caster, {
    required String text,
    required int argb,
    bool reducedVfx = false,
    int? burstArgb,
    double burstRadius = 0.7,
    bool showText = false,
  }) {
    final tint = burstArgb ?? argb;
    if (reducedVfx) {
      // Tiny cast pulse so legacy kits aren't fully silent offline.
      _spawnBurst(
        world,
        x: caster.x,
        y: caster.y,
        argb: (tint & 0x00FFFFFF) | 0x66000000,
        radius: burstRadius * 0.55,
        life: 0.18,
      );
      return;
    }
    // Ability-name floaters clutter the stage — default to burst-only.
    if (showText) {
      _spawnFloater(
        world,
        x: caster.x,
        y: caster.y - 0.55,
        text: text,
        argb: argb,
        life: 0.5,
        priority: 1,
      );
    }
    _spawnBurst(
      world,
      x: caster.x,
      y: caster.y,
      argb: tint,
      radius: burstRadius,
      life: 0.28,
    );
  }
}
