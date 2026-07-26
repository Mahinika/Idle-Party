import 'dart:math' as math;

import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/class_ability.dart';
import '../models/combat_ratings.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../ui/kenney_assets.dart';
import 'tile_map.dart';

enum SpatialTeam { hero, enemy }

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
    this.partyIndex,
    this.heroLevel = 1,
    this.fireCooldown = 0,
    this.pattern = ProjectilePattern.single,
    this.ranged = false,
    this.preferredRange,
    this.chamberIndex = 0,
    this.isPet = false,
    this.dormant = false,
    this.blockValue = 0,
    this.spiritRegenBonus = 0,
    this.mp5RegenBonus = 0,
  });

  final String id;
  final String name;
  final SpatialTeam team;
  double x;
  double y;
  int hp;
  final int maxHp;
  final int attack;
  final int defense;
  final double moveSpeed;
  final double attackRange;
  final double attackCooldown;
  final int assetIndex;
  final EnemyRole role;
  final EnemyArchetype archetype;
  final HeroRole? heroRole;

  /// Index into [GameState.heroes] when this is a party member.
  final int? partyIndex;

  /// Snapshot of hero level for ability unlock checks.
  final int heroLevel;

  double fireCooldown;
  final ProjectilePattern pattern;
  final bool ranged;
  final double? preferredRange;
  final int chamberIndex;
  final bool isPet;

  /// Flat damage blocked while Shield Block is active (Str/20).
  final int blockValue;

  /// Extra mana regen /s from Spirit (casters).
  final double spiritRegenBonus;

  /// Extra mana regen /s from Mp5 gear.
  final double mp5RegenBonus;

  /// Waiting for chamber unlock (gated rooms).
  bool dormant;

  /// Brief visual punch when the actor attacks (seconds remaining).
  double attackFlash = 0;

  /// Class resource 0â€“100 (rage / mana / energy).
  double rage = 0;

  /// Per-ability cooldown remaining (AbilityId.name â†’ seconds).
  final Map<String, double> abilityCd = <String, double>{};

  double shieldBlockTimer = 0;
  double shieldWallTimer = 0;
  double lastStandTimer = 0;
  int bonusMaxHp = 0;

  /// Next melee is Shield Slam / Revenge empowered.
  bool queuedShieldSlam = false;
  bool revengeReady = false;

  // â€”â€” Disc Priest â€”â€”
  int absorbShield = 0;
  double painSuppressionTimer = 0;
  double fortitudeTimer = 0;

  // â€”â€” Mage â€”â€”
  bool queuedFireball = false;
  bool queuedPyroblast = false;
  double combustionTimer = 0;
  double iceBlockTimer = 0;

  // â€”â€” Rogue â€”â€”
  int comboPoints = 0;
  double sliceAndDiceTimer = 0;
  double bladeFlurryTimer = 0;
  double sprintTimer = 0;
  double vanishTimer = 0;
  double adrenalineTimer = 0;

  /// Enemy: forced to attack [forcedTargetId] while timer > 0.
  String? forcedTargetId;
  double forcedTargetTimer = 0;

  /// Enemy: attack cadence slowed while > 0.
  double attackSlowTimer = 0;

  /// Sunder Armor stacks (max 5) while [sunderTimer] > 0.
  int sunderStacks = 0;
  double sunderTimer = 0;

  /// Demoralizing Shout: reduced attack while > 0.
  double demoShoutTimer = 0;

  /// Shadow Word: Pain DoT.
  double swPainTimer = 0;
  double swPainDps = 0;
  double swPainAcc = 0;

  /// Root / stun (Frost Nova, Kidney Shot).
  double rootTimer = 0;

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
    if (demoShoutTimer <= 0) return attack;
    return math.max(1, (attack * 0.8).round());
  }

  double get moveSpeedMul {
    var m = 1.0;
    if (sprintTimer > 0) m *= 1.55;
    if (rootTimer > 0) m = 0;
    if (iceBlockTimer > 0) m = 0;
    if (vanishTimer > 0) m *= 1.2;
    return m;
  }

  double get attackSpeedMul {
    var m = 1.0;
    if (sliceAndDiceTimer > 0) m *= 1.35;
    if (adrenalineTimer > 0) m *= 1.45;
    if (combustionTimer > 0) m *= 1.25;
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
      return drop.rarity == LootRarity.epic
          ? GroundLootKind.chest
          : GroundLootKind.gear;
    }
    final name = drop.name.toLowerCase();
    if (name.contains('gold') || name.contains('coin') || name.contains('pouch')) {
      return GroundLootKind.gold;
    }
    return GroundLootKind.essence;
  }
}

enum GroundLootKind { gold, essence, gear, chest }

class SpatialFloater {
  SpatialFloater({
    required this.x,
    required this.y,
    required this.text,
    required this.argb,
    this.life = 0.9,
    this.vy = -2.1,
  });

  double x;
  double y;
  double life;
  double vy;
  final String text;
  final int argb;
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
  });

  double x;
  double y;
  double life;
  final int argb;
  final double radius;
  /// Radians; used when [slash] is true (swing direction).
  final double? angle;
  final bool slash;
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
    List<SpatialFloater>? floaters,
    List<SpatialBurst>? bursts,
  })  : openGateIds = openGateIds ?? <int>{},
        clearedChambers = clearedChambers ?? <int>{},
        floaters = floaters ?? <SpatialFloater>[],
        bursts = bursts ?? <SpatialBurst>[];

  final TileMap map;
  final List<SpatialActor> heroes;
  final List<SpatialActor> enemies;
  final List<SpatialProjectile> projectiles;
  final List<GroundLoot> groundLoot;
  final List<SpatialActor> pets;
  final List<SpatialFloater> floaters;
  final List<SpatialBurst> bursts;
  final bool isTreasure;
  bool treasureOpen;
  double treasureTimer;
  bool awaitingExit;
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

  int get cols => map.cols;
  int get rows => map.rows;

  bool get allEnemiesDead =>
      enemies.isEmpty || enemies.every((e) => e.hp <= 0);

  bool get allHeroesDead => heroes.isEmpty || heroes.every((h) => h.hp <= 0);

  bool get allChambersCleared {
    if (map.chambers.isEmpty) return allEnemiesDead;
    return clearedChambers.length >= map.chambers.length ||
        (allEnemiesDead &&
            openGateIds.length >= map.gates.length);
  }

  SpatialActor? get leader {
    for (final h in heroes) {
      if (h.hp > 0 && h.heroRole == HeroRole.warrior) return h;
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
  });

  final SpatialWorld world;
  final GameState state;
  final bool roomCleared;
  final bool partyWiped;
  final int goldFromKills;
}

abstract final class SpatialCombat {
  static int get cols => 30;
  static int get rows => 22;

  static const int _floaterDamage = 0xFFFF6A4A;
  static const int _floaterCrit = 0xFFFFC14A;
  static const int _floaterGold = 0xFFFFE08A;
  static const int _floaterEssence = 0xFF7EC8FF;
  static const int _floaterGear = 0xFFB8E986;
  static const int _floaterHeal = 0xFF7AAB6E;
  static const int _floaterXp = 0xFF9AD0FF;

  static void _spawnFloater(
    SpatialWorld world, {
    required double x,
    required double y,
    required String text,
    required int argb,
    double life = 0.9,
  }) {
    world.floaters.add(
      SpatialFloater(x: x, y: y, text: text, argb: argb, life: life),
    );
    if (world.floaters.length > 36) {
      world.floaters.removeRange(0, world.floaters.length - 36);
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
  }) {
    if (world.bursts.length > 18) {
      world.bursts.removeAt(0);
    }
    world.bursts.add(
      SpatialBurst(
        x: x,
        y: y,
        argb: argb,
        radius: radius,
        angle: angle,
        slash: slash,
        life: life,
      ),
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
    _spawnBurst(
      world,
      x: from.x + dx * 0.45,
      y: from.y + dy * 0.45,
      argb: isCrit ? _floaterCrit : 0xFFFFE8A0,
      radius: isCrit ? 0.85 : 0.65,
      angle: angle,
      slash: true,
      life: isCrit ? 0.28 : 0.2,
    );
  }

  static void _tickCombatBuffs(SpatialWorld world, double dt) {
    for (final a in [...world.heroes, ...world.enemies, ...world.pets]) {
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
      if (a.attackSlowTimer > 0) {
        a.attackSlowTimer = math.max(0, a.attackSlowTimer - dt);
      }
      if (a.sunderTimer > 0) {
        a.sunderTimer = math.max(0, a.sunderTimer - dt);
        if (a.sunderTimer <= 0) a.sunderStacks = 0;
      }
      if (a.demoShoutTimer > 0) {
        a.demoShoutTimer = math.max(0, a.demoShoutTimer - dt);
      }
      if (a.swPainTimer > 0) {
        a.swPainTimer = math.max(0, a.swPainTimer - dt);
        if (a.swPainTimer <= 0) a.swPainDps = 0;
      }
      if (a.rootTimer > 0) {
        a.rootTimer = math.max(0, a.rootTimer - dt);
      }
      if (a.painSuppressionTimer > 0) {
        a.painSuppressionTimer = math.max(0, a.painSuppressionTimer - dt);
      }
      if (a.fortitudeTimer > 0) {
        a.fortitudeTimer = math.max(0, a.fortitudeTimer - dt);
      }
      if (a.combustionTimer > 0) {
        a.combustionTimer = math.max(0, a.combustionTimer - dt);
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
      if (a.adrenalineTimer > 0) {
        a.adrenalineTimer = math.max(0, a.adrenalineTimer - dt);
      }
      if (a.abilityCd.isNotEmpty) {
        final keys = a.abilityCd.keys.toList(growable: false);
        for (final key in keys) {
          final left = (a.abilityCd[key] ?? 0) - dt;
          if (left <= 0) {
            a.abilityCd.remove(key);
          } else {
            a.abilityCd[key] = left;
          }
        }
      }
    }
  }

  static double _abilityCdLeft(SpatialActor a, AbilityId id) =>
      a.abilityCd[id.name] ?? 0;

  static void _startAbilityCd(SpatialActor a, AbilityId id, double cd) {
    if (cd > 0) a.abilityCd[id.name] = cd;
  }

  static bool _canCast(
    SpatialActor a,
    AbilityId id, {
    bool hasShield = true,
  }) {
    final def = WarriorAbilities.defFor(id);
    if (def == null) return false;
    if (!WarriorAbilities.isUnlocked(id, a.heroLevel)) return false;
    if (def.requiresShield && !hasShield) return false;
    if (_abilityCdLeft(a, id) > 0) return false;
    if (a.rage + 0.001 < def.resourceCost) return false;
    return true;
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
    var mul = 1.0;
    var blocked = false;
    if (hero.shieldWallTimer > 0) {
      mul *= 0.45;
    }
    if (hero.painSuppressionTimer > 0) {
      mul *= 0.55;
    }
    if (hero.shieldBlockTimer > 0) {
      mul *= 0.55;
      blocked = true;
      if (WarriorAbilities.isUnlocked(AbilityId.revenge, hero.heroLevel)) {
        hero.revengeReady = true;
      }
    }
    var dealt = math.max(1, (rawDamage * mul).round());
    if (blocked && hero.blockValue > 0) {
      dealt = math.max(1, dealt - hero.blockValue);
    }
    if (hero.absorbShield > 0) {
      final absorbed = math.min(hero.absorbShield, dealt);
      hero.absorbShield -= absorbed;
      dealt -= absorbed;
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
      if (dealt <= 0) return absorbed;
    }
    hero.hp = math.max(0, hero.hp - dealt);
    if (hero.heroRole == HeroRole.warrior) {
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
    return dealt;
  }

  static void _atonementHeal(
    SpatialWorld world,
    SpatialActor priest,
    int damageDealt, {
    required bool reducedVfx,
  }) {
    if (!ClassKits.isUnlocked(AbilityId.atonement, priest.heroLevel)) return;
    final heal = math.max(1, (damageDealt * 0.45).round());
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
    if (gained > 0 && !reducedVfx) {
      _spawnFloater(
        world,
        x: lowest.x,
        y: lowest.y - 0.4,
        text: '+$gained',
        argb: _floaterHeal,
        life: 0.5,
      );
    }
  }

  /// Protection Warrior auto-cast priority (idle-friendly).
  static ({GameState state, int gold}) _tickWarriorAbilities(
    SpatialWorld world,
    GameState state,
    SpatialActor warrior,
    SpatialActor? focusEnemy,
    double dt,
    math.Random rng, {
    required bool reducedVfx,
    required bool hasShield,
  }) {
    var nextState = state;
    var gold = 0;
    if (warrior.heroRole != HeroRole.warrior || !warrior.isAlive) {
      return (state: nextState, gold: gold);
    }

    // Passive rage while in combat near enemies.
    if (focusEnemy != null) {
      _gainRage(warrior, 6 * dt);
    }

    final hpFrac = warrior.effectiveMaxHp <= 0
        ? 0.0
        : warrior.hp / warrior.effectiveMaxHp;

    bool can(AbilityId id) => _canCast(warrior, id, hasShield: hasShield);

    // Shield Wall â€” emergency DR.
    if (hpFrac <= 0.28 && can(AbilityId.shieldWall)) {
      final def = WarriorAbilities.defFor(AbilityId.shieldWall)!;
      _spendRage(warrior, def.resourceCost);
      _startAbilityCd(warrior, AbilityId.shieldWall, def.cooldown);
      warrior.shieldWallTimer = 5.0;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: warrior.x,
          y: warrior.y - 0.55,
          text: 'SHIELD WALL',
          argb: 0xFFB8D4FF,
          life: 1.1,
        );
        _spawnBurst(
          world,
          x: warrior.x,
          y: warrior.y,
          argb: 0xFF88AADD,
          radius: 1.1,
          life: 0.45,
        );
      }
    }

    // Last Stand â€” emergency HP.
    if (hpFrac <= 0.4 && can(AbilityId.lastStand)) {
      final def = WarriorAbilities.defFor(AbilityId.lastStand)!;
      _spendRage(warrior, def.resourceCost);
      _startAbilityCd(warrior, AbilityId.lastStand, def.cooldown);
      final bonus = math.max(8, (warrior.maxHp * 0.3).round());
      warrior.bonusMaxHp = bonus;
      warrior.lastStandTimer = 6.0;
      warrior.hp = math.min(warrior.effectiveMaxHp, warrior.hp + bonus);
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: warrior.x,
          y: warrior.y - 0.55,
          text: 'LAST STAND',
          argb: 0xFFFF7070,
          life: 1.0,
        );
      }
    }

    // Shield Block on CD while fighting.
    if (focusEnemy != null &&
        _dist(warrior, focusEnemy) <= 3.2 &&
        can(AbilityId.shieldBlock)) {
      final def = WarriorAbilities.defFor(AbilityId.shieldBlock)!;
      _spendRage(warrior, def.resourceCost);
      _startAbilityCd(warrior, AbilityId.shieldBlock, def.cooldown);
      warrior.shieldBlockTimer = 2.5;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: warrior.x,
          y: warrior.y - 0.5,
          text: 'SHIELD BLOCK',
          argb: 0xFF9AD0FF,
          life: 0.55,
        );
      }
    }

    // Taunt a loose enemy attacking an ally.
    if (can(AbilityId.taunt)) {
      SpatialActor? loose;
      var best = double.infinity;
      for (final e in world.enemies) {
        if (e.hp <= 0 || e.dormant) continue;
        if (e.forcedTargetTimer > 0) continue;
        final focus = _focusHero(e, world.heroes);
        if (focus == null || focus.id == warrior.id) continue;
        final d = _dist(warrior, e);
        if (d < best && d <= 5.5) {
          best = d;
          loose = e;
        }
      }
      if (loose != null) {
        final def = WarriorAbilities.defFor(AbilityId.taunt)!;
        _spendRage(warrior, def.resourceCost);
        _startAbilityCd(warrior, AbilityId.taunt, def.cooldown);
        loose.forcedTargetId = warrior.id;
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
        }
      }
    }

    // Demoralizing Shout â€” AoE attack down.
    if (can(AbilityId.demoralizingShout)) {
      final nearby = <SpatialActor>[
        for (final e in world.enemies)
          if (e.hp > 0 && !e.dormant && _dist(warrior, e) <= 3.4) e,
      ];
      if (nearby.isNotEmpty) {
        final def = WarriorAbilities.defFor(AbilityId.demoralizingShout)!;
        _spendRage(warrior, def.resourceCost);
        _startAbilityCd(warrior, AbilityId.demoralizingShout, def.cooldown);
        for (final e in nearby) {
          e.demoShoutTimer = math.max(e.demoShoutTimer, 6.5);
        }
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: warrior.x,
            y: warrior.y - 0.55,
            text: 'DEMO SHOUT',
            argb: 0xFFFF8866,
            life: 0.7,
          );
          _spawnBurst(
            world,
            x: warrior.x,
            y: warrior.y,
            argb: 0xFFFF7040,
            radius: 1.5,
            life: 0.28,
          );
        }
      }
    }

    // Thunder Clap when packing enemies.
    if (can(AbilityId.thunderClap)) {
      final nearby = <SpatialActor>[
        for (final e in world.enemies)
          if (e.hp > 0 && !e.dormant && _dist(warrior, e) <= 2.6) e,
      ];
      if (nearby.length >= 2 ||
          (nearby.length == 1 && nearby.first.role == EnemyRole.boss)) {
        final def = WarriorAbilities.defFor(AbilityId.thunderClap)!;
        _spendRage(warrior, def.resourceCost);
        _startAbilityCd(warrior, AbilityId.thunderClap, def.cooldown);
        warrior.attackFlash = 0.18;
        final clapDmg = math.max(2, (warrior.attack * 0.55).round());
        for (final e in nearby) {
          final wasAlive = e.hp > 0;
          final dealt = math.max(1, clapDmg - e.effectiveDefense);
          e.hp = math.max(0, e.hp - dealt);
          e.attackSlowTimer = math.max(e.attackSlowTimer, 3.2);
          _spawnFloater(
            world,
            x: e.x,
            y: e.y - 0.25,
            text: '$dealt',
            argb: _floaterDamage,
            life: 0.55,
          );
          if (wasAlive && e.hp <= 0) {
            final killed = _onEnemyKilled(world, nextState, e, rng);
            gold += killed.gold;
            nextState = killed.state;
          }
        }
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: warrior.x,
            y: warrior.y - 0.55,
            text: 'THUNDER CLAP',
            argb: 0xFFFFE08A,
            life: 0.6,
          );
          _spawnBurst(
            world,
            x: warrior.x,
            y: warrior.y,
            argb: 0xFFFFC14A,
            radius: 1.35,
            life: 0.3,
          );
        }
        _gainRage(warrior, 8);
      }
    }

    // Sunder Armor on focus target (keep stacks up).
    if (focusEnemy != null &&
        focusEnemy.hp > 0 &&
        !focusEnemy.dormant &&
        _dist(warrior, focusEnemy) <= warrior.attackRange + 0.35 &&
        can(AbilityId.sunderArmor) &&
        (focusEnemy.sunderStacks < 5 || focusEnemy.sunderTimer < 4)) {
      final def = WarriorAbilities.defFor(AbilityId.sunderArmor)!;
      _spendRage(warrior, def.resourceCost);
      _startAbilityCd(warrior, AbilityId.sunderArmor, def.cooldown);
      focusEnemy.sunderStacks = math.min(5, focusEnemy.sunderStacks + 1);
      focusEnemy.sunderTimer = 14;
      warrior.attackFlash = 0.12;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: focusEnemy.x,
          y: focusEnemy.y - 0.4,
          text: 'SUNDER ${focusEnemy.sunderStacks}',
          argb: 0xFFC0A070,
          life: 0.55,
        );
      }
    }

    // Queue Shield Slam for next swing.
    if (focusEnemy != null &&
        !warrior.queuedShieldSlam &&
        can(AbilityId.shieldSlam)) {
      final def = WarriorAbilities.defFor(AbilityId.shieldSlam)!;
      _spendRage(warrior, def.resourceCost);
      _startAbilityCd(warrior, AbilityId.shieldSlam, def.cooldown);
      warrior.queuedShieldSlam = true;
    }

    return (state: nextState, gold: gold);
  }

  /// Warrior attack modifiers: Defensive Stance, Shield Slam, Revenge.
  static ({int damage, String? tag, int tagArgb}) _warriorAttackMods(
    SpatialActor warrior,
    int baseDamage,
  ) {
    var damage = baseDamage;
    String? tag;
    var tagArgb = _floaterDamage;

    // Defensive Stance: slightly less damage dealt.
    if (WarriorAbilities.isUnlocked(AbilityId.defensiveStance, warrior.heroLevel)) {
      damage = math.max(1, (damage * 0.9).round());
    }

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

  static void _tickPriestAbilities(
    SpatialWorld world,
    SpatialActor priest,
    SpatialActor? focusEnemy,
    double dt, {
    required bool reducedVfx,
  }) {
    if (priest.heroRole != HeroRole.healer || !priest.isAlive) return;
    if (focusEnemy != null) _gainRage(priest, 7 * dt);
    _gainRage(priest, (priest.spiritRegenBonus + priest.mp5RegenBonus) * dt);
    bool can(AbilityId id) => _canCast(priest, id);

    // Rapture — party-wide shields.
    if (can(AbilityId.rapture)) {
      final injured = world.heroes.any(
        (h) => h.isAlive && h.hp < h.effectiveMaxHp * 0.7,
      );
      if (injured) {
        final def = ClassKits.defFor(AbilityId.rapture)!;
        _spendRage(priest, def.resourceCost);
        _startAbilityCd(priest, AbilityId.rapture, def.cooldown);
        final shield = math.max(12, (priest.attack * 2.2).round());
        for (final h in world.heroes) {
          if (!h.isAlive) continue;
          h.absorbShield = math.max(h.absorbShield, shield);
        }
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: priest.x,
            y: priest.y - 0.55,
            text: 'RAPTURE',
            argb: 0xFFB0E0FF,
            life: 0.9,
          );
        }
      }
    }

    // Pain Suppression on critically low ally.
    if (can(AbilityId.painSuppression)) {
      SpatialActor? target;
      var worst = 1.0;
      for (final h in world.heroes) {
        if (!h.isAlive || h.painSuppressionTimer > 0) continue;
        final frac = h.hp / math.max(1, h.effectiveMaxHp);
        if (frac < 0.32 && frac < worst) {
          worst = frac;
          target = h;
        }
      }
      if (target != null) {
        final def = ClassKits.defFor(AbilityId.painSuppression)!;
        _spendRage(priest, def.resourceCost);
        _startAbilityCd(priest, AbilityId.painSuppression, def.cooldown);
        target.painSuppressionTimer = 5.5;
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: target.x,
            y: target.y - 0.5,
            text: 'PAIN SUPP',
            argb: 0xFFFF9090,
            life: 0.7,
          );
        }
      }
    }

    // Power Word: Fortitude
    if (can(AbilityId.powerWordFortitude) &&
        world.heroes.any((h) => h.isAlive && h.fortitudeTimer < 2)) {
      final def = ClassKits.defFor(AbilityId.powerWordFortitude)!;
      _spendRage(priest, def.resourceCost);
      _startAbilityCd(priest, AbilityId.powerWordFortitude, def.cooldown);
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        h.fortitudeTimer = 20;
        h.hp = math.min(h.effectiveMaxHp, h.hp + 4);
      }
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: priest.x,
          y: priest.y - 0.5,
          text: 'FORTITUDE',
          argb: 0xFFFFE8A0,
          life: 0.65,
        );
      }
    }

    // Power Word: Shield
    if (can(AbilityId.powerWordShield)) {
      SpatialActor? target;
      var worst = 1.0;
      for (final h in world.heroes) {
        if (!h.isAlive || h.absorbShield > 4) continue;
        final frac = h.hp / math.max(1, h.effectiveMaxHp);
        if (frac < worst) {
          worst = frac;
          target = h;
        }
      }
      if (target != null && worst < 0.92) {
        final def = ClassKits.defFor(AbilityId.powerWordShield)!;
        _spendRage(priest, def.resourceCost);
        _startAbilityCd(priest, AbilityId.powerWordShield, def.cooldown);
        final shield = math.max(8, (priest.attack * 1.6).round());
        target.absorbShield = math.max(target.absorbShield, shield);
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: target.x,
            y: target.y - 0.45,
            text: 'PW:S',
            argb: 0xFF80C0FF,
            life: 0.55,
          );
        }
      }
    }

    // Flash Heal
    if (can(AbilityId.flashHeal)) {
      SpatialActor? target;
      var worst = 1.0;
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        final frac = h.hp / math.max(1, h.effectiveMaxHp);
        if (frac < worst) {
          worst = frac;
          target = h;
        }
      }
      if (target != null && worst < 0.75) {
        final def = ClassKits.defFor(AbilityId.flashHeal)!;
        _spendRage(priest, def.resourceCost);
        _startAbilityCd(priest, AbilityId.flashHeal, def.cooldown);
        final heal = math.max(6, (priest.attack * 1.4).round());
        final before = target.hp;
        target.hp = math.min(target.effectiveMaxHp, target.hp + heal);
        final gained = target.hp - before;
        if (gained > 0) {
          _spawnFloater(
            world,
            x: target.x,
            y: target.y - 0.4,
            text: '+$gained',
            argb: _floaterHeal,
            life: 0.6,
          );
        }
      }
    }

    // Shadow Word: Pain
    if (focusEnemy != null &&
        focusEnemy.hp > 0 &&
        can(AbilityId.shadowWordPain) &&
        focusEnemy.swPainTimer < 3) {
      final def = ClassKits.defFor(AbilityId.shadowWordPain)!;
      _spendRage(priest, def.resourceCost);
      _startAbilityCd(priest, AbilityId.shadowWordPain, def.cooldown);
      focusEnemy.swPainTimer = 10;
      focusEnemy.swPainDps = math.max(2.0, priest.attack * 0.35);
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: focusEnemy.x,
          y: focusEnemy.y - 0.4,
          text: 'SW:P',
          argb: 0xFFB060E0,
          life: 0.5,
        );
      }
    }

    // Penance — burst bolts
    if (focusEnemy != null &&
        focusEnemy.hp > 0 &&
        _dist(priest, focusEnemy) <= priest.attackRange &&
        can(AbilityId.penance)) {
      final def = ClassKits.defFor(AbilityId.penance)!;
      _spendRage(priest, def.resourceCost);
      _startAbilityCd(priest, AbilityId.penance, def.cooldown);
      priest.attackFlash = 0.2;
      var total = 0;
      for (var i = 0; i < 3; i++) {
        final bolt = math.max(2, (priest.attack * 0.75).round());
        final dealt = math.max(1, bolt - focusEnemy.effectiveDefense);
        focusEnemy.hp = math.max(0, focusEnemy.hp - dealt);
        total += dealt;
      }
      _atonementHeal(world, priest, total, reducedVfx: reducedVfx);
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: focusEnemy.x,
          y: focusEnemy.y - 0.35,
          text: 'PENANCE $total',
          argb: 0xFFFFF0A0,
          life: 0.75,
        );
      }
    }
  }

  static void _tickMageAbilities(
    SpatialWorld world,
    SpatialActor mage,
    SpatialActor? focusEnemy,
    double dt, {
    required bool reducedVfx,
  }) {
    if (mage.heroRole != HeroRole.mage || !mage.isAlive) return;
    if (focusEnemy != null) _gainRage(mage, 8 * dt);
    _gainRage(mage, (mage.spiritRegenBonus + mage.mp5RegenBonus) * dt);
    bool can(AbilityId id) => _canCast(mage, id);

    if (mage.hp / math.max(1, mage.effectiveMaxHp) <= 0.28 &&
        can(AbilityId.iceBlock)) {
      final def = ClassKits.defFor(AbilityId.iceBlock)!;
      _spendRage(mage, def.resourceCost);
      _startAbilityCd(mage, AbilityId.iceBlock, def.cooldown);
      mage.iceBlockTimer = 4.0;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: mage.x,
          y: mage.y - 0.55,
          text: 'ICE BLOCK',
          argb: 0xFFA0E8FF,
          life: 0.9,
        );
      }
    }

    if (can(AbilityId.combustion) && focusEnemy != null) {
      final def = ClassKits.defFor(AbilityId.combustion)!;
      _spendRage(mage, def.resourceCost);
      _startAbilityCd(mage, AbilityId.combustion, def.cooldown);
      mage.combustionTimer = 8;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: mage.x,
          y: mage.y - 0.5,
          text: 'COMBUSTION',
          argb: 0xFFFF6030,
          life: 0.7,
        );
      }
    }

    if (focusEnemy != null &&
        can(AbilityId.blink) &&
        _dist(mage, focusEnemy) < (mage.preferredRange ?? 3) * 0.55) {
      final def = ClassKits.defFor(AbilityId.blink)!;
      _spendRage(mage, def.resourceCost);
      _startAbilityCd(mage, AbilityId.blink, def.cooldown);
      final dx = mage.x - focusEnemy.x;
      final dy = mage.y - focusEnemy.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 0.1) {
        mage.x += (dx / len) * 2.2;
        mage.y += (dy / len) * 2.2;
      }
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: mage.x,
          y: mage.y - 0.4,
          text: 'BLINK',
          argb: 0xFFC0A0FF,
          life: 0.45,
        );
      }
    }

    if (can(AbilityId.frostNova)) {
      final nearby = [
        for (final e in world.enemies)
          if (e.hp > 0 && !e.dormant && _dist(mage, e) <= 2.4) e,
      ];
      if (nearby.isNotEmpty) {
        final def = ClassKits.defFor(AbilityId.frostNova)!;
        _spendRage(mage, def.resourceCost);
        _startAbilityCd(mage, AbilityId.frostNova, def.cooldown);
        for (final e in nearby) {
          e.rootTimer = math.max(e.rootTimer, 2.4);
          e.attackSlowTimer = math.max(e.attackSlowTimer, 3);
        }
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: mage.x,
            y: mage.y - 0.5,
            text: 'FROST NOVA',
            argb: 0xFF80D0FF,
            life: 0.55,
          );
        }
      }
    }

    if (can(AbilityId.arcaneExplosion)) {
      final nearby = [
        for (final e in world.enemies)
          if (e.hp > 0 && !e.dormant && _dist(mage, e) <= 2.8) e,
      ];
      if (nearby.length >= 2) {
        final def = ClassKits.defFor(AbilityId.arcaneExplosion)!;
        _spendRage(mage, def.resourceCost);
        _startAbilityCd(mage, AbilityId.arcaneExplosion, def.cooldown);
        final dmg = math.max(2, (mage.attack * 0.7).round());
        for (final e in nearby) {
          final dealt = math.max(1, dmg - e.effectiveDefense);
          e.hp = math.max(0, e.hp - dealt);
          _spawnFloater(
            world,
            x: e.x,
            y: e.y - 0.25,
            text: '$dealt',
            argb: 0xFFC070FF,
            life: 0.45,
          );
        }
        if (!reducedVfx) {
          _spawnBurst(
            world,
            x: mage.x,
            y: mage.y,
            argb: 0xFFA050FF,
            radius: 1.4,
            life: 0.28,
          );
        }
      }
    }

    if (focusEnemy != null &&
        !mage.queuedPyroblast &&
        can(AbilityId.pyroblast)) {
      final def = ClassKits.defFor(AbilityId.pyroblast)!;
      _spendRage(mage, def.resourceCost);
      _startAbilityCd(mage, AbilityId.pyroblast, def.cooldown);
      mage.queuedPyroblast = true;
    }

    if (focusEnemy != null &&
        !mage.queuedFireball &&
        !mage.queuedPyroblast &&
        can(AbilityId.fireball)) {
      final def = ClassKits.defFor(AbilityId.fireball)!;
      _spendRage(mage, def.resourceCost);
      _startAbilityCd(mage, AbilityId.fireball, def.cooldown);
      mage.queuedFireball = true;
    }
  }

  static void _tickRogueAbilities(
    SpatialWorld world,
    SpatialActor rogue,
    SpatialActor? focusEnemy,
    double dt, {
    required bool reducedVfx,
  }) {
    if (rogue.heroRole != HeroRole.rogue || !rogue.isAlive) return;
    if (focusEnemy != null) {
      _gainRage(rogue, 10 * dt);
      if (rogue.adrenalineTimer > 0) _gainRage(rogue, 12 * dt);
    }
    bool can(AbilityId id) => _canCast(rogue, id);

    if (rogue.hp / math.max(1, rogue.effectiveMaxHp) <= 0.3 &&
        can(AbilityId.vanish)) {
      final def = ClassKits.defFor(AbilityId.vanish)!;
      _spendRage(rogue, def.resourceCost);
      _startAbilityCd(rogue, AbilityId.vanish, def.cooldown);
      rogue.vanishTimer = 3.5;
      for (final e in world.enemies) {
        if (e.forcedTargetId == rogue.id) {
          e.forcedTargetId = null;
          e.forcedTargetTimer = 0;
        }
      }
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: rogue.x,
          y: rogue.y - 0.5,
          text: 'VANISH',
          argb: 0xFF909090,
          life: 0.6,
        );
      }
    }

    if (can(AbilityId.adrenalineRush) && focusEnemy != null) {
      final def = ClassKits.defFor(AbilityId.adrenalineRush)!;
      _spendRage(rogue, def.resourceCost);
      _startAbilityCd(rogue, AbilityId.adrenalineRush, def.cooldown);
      rogue.adrenalineTimer = 8;
      rogue.rage = math.min(100, rogue.rage + 40);
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: rogue.x,
          y: rogue.y - 0.5,
          text: 'ADRENALINE',
          argb: 0xFFFFE060,
          life: 0.7,
        );
      }
    }

    if (can(AbilityId.sprint) &&
        focusEnemy != null &&
        _dist(rogue, focusEnemy) > rogue.attackRange * 1.1) {
      final def = ClassKits.defFor(AbilityId.sprint)!;
      _spendRage(rogue, def.resourceCost);
      _startAbilityCd(rogue, AbilityId.sprint, def.cooldown);
      rogue.sprintTimer = 4;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: rogue.x,
          y: rogue.y - 0.45,
          text: 'SPRINT',
          argb: 0xFF90FF90,
          life: 0.45,
        );
      }
    }

    if (can(AbilityId.bladeFlurry)) {
      final nearby = [
        for (final e in world.enemies)
          if (e.hp > 0 && !e.dormant && _dist(rogue, e) <= 2.5) e,
      ];
      if (nearby.length >= 2) {
        final def = ClassKits.defFor(AbilityId.bladeFlurry)!;
        _spendRage(rogue, def.resourceCost);
        _startAbilityCd(rogue, AbilityId.bladeFlurry, def.cooldown);
        rogue.bladeFlurryTimer = 6;
        if (!reducedVfx) {
          _spawnFloater(
            world,
            x: rogue.x,
            y: rogue.y - 0.5,
            text: 'FLURRY',
            argb: 0xFFFFAA40,
            life: 0.55,
          );
        }
      }
    }

    if (focusEnemy != null &&
        focusEnemy.hp > 0 &&
        rogue.comboPoints >= 3 &&
        can(AbilityId.kidneyShot) &&
        focusEnemy.rootTimer < 0.5) {
      final def = ClassKits.defFor(AbilityId.kidneyShot)!;
      _spendRage(rogue, def.resourceCost);
      _startAbilityCd(rogue, AbilityId.kidneyShot, def.cooldown);
      focusEnemy.rootTimer = 2.0 + rogue.comboPoints * 0.25;
      rogue.comboPoints = 0;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: focusEnemy.x,
          y: focusEnemy.y - 0.4,
          text: 'KIDNEY',
          argb: 0xFFFF7070,
          life: 0.55,
        );
      }
    }

    if (rogue.comboPoints >= 3 &&
        rogue.sliceAndDiceTimer < 2 &&
        can(AbilityId.sliceAndDice)) {
      final def = ClassKits.defFor(AbilityId.sliceAndDice)!;
      _spendRage(rogue, def.resourceCost);
      _startAbilityCd(rogue, AbilityId.sliceAndDice, def.cooldown);
      rogue.sliceAndDiceTimer = 6 + rogue.comboPoints * 1.5;
      rogue.comboPoints = 0;
      if (!reducedVfx) {
        _spawnFloater(
          world,
          x: rogue.x,
          y: rogue.y - 0.45,
          text: 'SnD',
          argb: 0xFFFFD070,
          life: 0.5,
        );
      }
    }
  }

  static ({int damage, String? tag, int tagArgb}) _classAttackMods(
    SpatialActor hero,
    int baseDamage,
  ) {
    if (hero.heroRole == HeroRole.warrior) {
      return _warriorAttackMods(hero, baseDamage);
    }
    var damage = baseDamage;
    String? tag;
    var tagArgb = _floaterDamage;

    if (hero.heroRole == HeroRole.mage) {
      if (hero.combustionTimer > 0) {
        damage = (damage * 1.45).round();
      }
      if (hero.queuedPyroblast) {
        hero.queuedPyroblast = false;
        damage = (damage * 2.4).round();
        tag = 'PYRO';
        tagArgb = 0xFFFF5020;
      } else if (hero.queuedFireball) {
        hero.queuedFireball = false;
        damage = (damage * 1.7).round();
        tag = 'FIREBALL';
        tagArgb = 0xFFFF8040;
      }
    }

    if (hero.heroRole == HeroRole.rogue) {
      if (ClassKits.isUnlocked(AbilityId.sinisterStrike, hero.heroLevel)) {
        hero.comboPoints = math.min(5, hero.comboPoints + 1);
      }
      if (hero.comboPoints >= 4 &&
          ClassKits.isUnlocked(AbilityId.eviscerate, hero.heroLevel) &&
          hero.rage + 0.001 >=
              (ClassKits.defFor(AbilityId.eviscerate)?.resourceCost ?? 25)) {
        final cost =
            ClassKits.defFor(AbilityId.eviscerate)?.resourceCost ?? 25;
        if (_abilityCdLeft(hero, AbilityId.eviscerate) <= 0) {
          _spendRage(hero, cost);
          _startAbilityCd(
            hero,
            AbilityId.eviscerate,
            ClassKits.defFor(AbilityId.eviscerate)?.cooldown ?? 1.2,
          );
          final pts = hero.comboPoints;
          hero.comboPoints = 0;
          damage = (damage * (1.2 + pts * 0.35)).round();
          tag = 'EVIS';
          tagArgb = 0xFFFF4060;
        }
      }
    }

    return (damage: damage, tag: tag, tagArgb: tagArgb);
  }

  static void _tickFloaters(SpatialWorld world, double dt) {
    for (final f in world.floaters) {
      f.life -= dt;
      f.y += f.vy * dt;
      f.vy *= 0.94;
    }
    world.floaters.removeWhere((f) => f.life <= 0);
    for (final b in world.bursts) {
      b.life -= dt;
    }
    world.bursts.removeWhere((b) => b.life <= 0);
    for (final a in [...world.heroes, ...world.enemies, ...world.pets]) {
      if (a.attackFlash > 0) {
        a.attackFlash = (a.attackFlash - dt).clamp(0, 1);
      }
    }
    if (world.bossBannerTimer > 0) {
      world.bossBannerTimer = math.max(0, world.bossBannerTimer - dt);
    }
  }

  static SpatialWorld build(GameState state) {
    final room = state.currentRoom;
    final map = RoomLayouts.forFloor(
      floorNumber: room.floorNumber,
      room: room,
      dungeonId: state.dungeonId,
      layoutSeed: state.layoutSeed,
    );
    final isTreasure =
        room.type == RoomType.treasure || state.enemies.isEmpty;

    final heroes = <SpatialActor>[];
    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      final spawn = i < map.spawnPoints.length
          ? map.spawnPoints[i]
          : map.spawnPoints[i % map.spawnPoints.length];
      final pattern = _patternForHero(hero, state);
      final ranged = hero.role != HeroRole.warrior;
      // Tank leads up front; casters hang at preferred range.
      final preferred = switch (hero.role) {
        HeroRole.warrior => 1.15,
        HeroRole.healer => 3.2,
        HeroRole.mage => 4.0,
        HeroRole.rogue => 1.6,
      };
      // Spread party so 4 heroes don't stack on one cell.
      final ox = switch (i) {
        0 => 0.0,
        1 => 0.35,
        2 => -0.35,
        _ => 0.15,
      };
      final oy = switch (i) {
        0 => 0.0,
        1 => -0.35,
        2 => 0.35,
        _ => 0.45,
      };
      heroes.add(
        SpatialActor(
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
          attackRange: switch (hero.role) {
            HeroRole.mage => 5.0,
            HeroRole.healer => 4.0,
            HeroRole.rogue => 2.4,
            HeroRole.warrior => 1.7,
          },
          attackCooldown: 1.0 / state.effectiveHeroAttackSpeed(hero),
          assetIndex: i,
          heroRole: hero.role,
          partyIndex: i,
          heroLevel: hero.level,
          fireCooldown: i * 0.12,
          pattern: pattern,
          ranged: ranged,
          preferredRange: preferred,
          blockValue: hero.role == HeroRole.warrior
              ? state.effectiveHeroStrength(hero) ~/ 20
              : 0,
          spiritRegenBonus:
              (hero.role == HeroRole.healer || hero.role == HeroRole.mage)
                  ? spiritManaRegenPerSec(state.effectiveHeroSpirit(hero))
                  : 0,
          mp5RegenBonus: mp5ManaRegenPerSec(hero.gearMp5Bonus),
        ),
      );
    }

    final firstCombat = map.chambers.length <= 1 ? 0 : 1;
    final enemies = <SpatialActor>[];
    for (var i = 0; i < state.enemies.length; i++) {
      final enemy = state.enemies[i];
      final spawn = i < map.enemySpawns.length
          ? map.enemySpawns[i]
          : (
              map.cols - 3,
              2 + (i % (map.rows - 4)),
            );
      final ranged = enemy.archetype == EnemyArchetype.ranged ||
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
          hp: enemy.currentHp,
          maxHp: enemy.maxHp,
          attack: enemy.attack,
          defense: enemy.defense,
          moveSpeed: enemy.role == EnemyRole.boss ? moveSpeed * 0.85 : moveSpeed,
          attackRange: attackRange,
          attackCooldown: enemy.role == EnemyRole.boss
              ? 1.05
              : (enemy.archetype == EnemyArchetype.glass ? 0.7 : 0.9),
          assetIndex: KenneyAssets.enemySpriteCatalogIndex(
            KenneyAssets.enemySpriteFor(
              enemy,
              dungeonId: state.dungeonId,
            ),
          ),
          role: enemy.role,
          archetype: enemy.archetype,
          fireCooldown: 0.35 + i * 0.15,
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
          fireCooldown: 0.25,
        ),
      );
    }

    return SpatialWorld(
      map: map,
      heroes: heroes,
      enemies: enemies,
      projectiles: <SpatialProjectile>[],
      groundLoot: <GroundLoot>[],
      isTreasure: isTreasure,
      treasureTimer: isTreasure ? 1.2 : 0,
      activeChamber: firstCombat,
      clearedChambers: <int>{0},
      pets: pets,
      bossBannerTimer: room.type == RoomType.boss ? 2.4 : 0,
      bossBannerName: room.type == RoomType.boss
          ? (enemies.isNotEmpty ? enemies.first.name : 'BOSS')
          : '',
    );
  }

  static ProjectilePattern _patternForHero(PartyHero hero, GameState state) {
    if (hero.role == HeroRole.mage) {
      return ProjectilePattern.arc;
    }
    if (hero.role == HeroRole.healer) {
      return ProjectilePattern.single;
    }
    return hero.weaponPattern;
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
    world.pulseTimer = math.max(0, world.pulseTimer - dt);
    world.guideTimer = math.max(0, world.guideTimer - dt);
    _updateChambers(world);

    if (world.isTreasure) {
      world.treasureTimer -= dt;
      if (world.treasureTimer <= 0) {
        world.treasureOpen = true;
        return SpatialStepResult(
          world: world,
          state: nextState,
          roomCleared: true,
          goldFromKills: GameLogic.roomCombatBudget(state.currentRoom).gold,
        );
      }
      return SpatialStepResult(world: world, state: nextState);
    }

    // Cleared: walk to exit. Stairs need only ONE hero; party clusters nearby.
    // (Requiring all 4 inside r=1.1 of one tile soft-locks with separation.)
    if (world.awaitingExit) {
      // Ensure every gate is open so the exit path can't soft-lock.
      for (final gate in world.map.gates) {
        world.openGateIds.add(gate.id);
      }
      final exitX = world.map.exitPoint.$1 + 0.5;
      final exitY = world.map.exitPoint.$2 + 0.5;
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
      var clustered = 0;
      final livingHeroes = <SpatialActor>[
        for (final h in world.heroes)
          if (h.isAlive) h,
      ];
      for (final hero in livingHeroes) {
        final offset = approachSlots[slot % approachSlots.length];
        slot++;
        _steerActor(
          hero,
          exitX + offset.$1,
          exitY + offset.$2,
          hero.moveSpeed * 1.25 * dt,
          world,
          holdDistance: 0.28,
          separateFrom: livingHeroes,
          separationRadius: 0.55,
          separationWeight: 0.55,
        );
        final d = _distPoint(hero.x, hero.y, exitX, exitY);
        if (d < 1.35) anyOnStairs = true;
        if (d < 3.4) clustered++;
      }
      final living = livingHeroes.length;
      if (living > 0 && anyOnStairs && clustered >= living) {
        final gold = goldFromKills > 0
            ? goldFromKills
            : state.enemies.fold<int>(0, (s, e) => s + e.rewardGold);
        return SpatialStepResult(
          world: world,
          state: nextState,
          roomCleared: true,
          goldFromKills: gold,
        );
      }
      nextState = _syncHp(nextState, world);
      return SpatialStepResult(world: world, state: nextState);
    }

    final guiding = world.guideTimer > 0 &&
        world.guideX != null &&
        world.guideY != null;

    _tickCombatBuffs(world, dt);

    // The healer's mend is independent of attacks and only runs while alive.
    world.mendTimer -= dt;
    while (world.mendTimer <= 0) {
      final healerAlive = world.heroes.any(
        (h) => h.hp > 0 && h.heroRole == HeroRole.healer,
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

    // Heroes: formation + role ranges + optional God Hand steering.
    final leader = world.leader;
    for (var i = 0; i < world.heroes.length; i++) {
      final hero = world.heroes[i];
      if (!hero.isAlive) continue;
      final target = _nearestActiveEnemy(hero, world.enemies);
      var tx = hero.x;
      var ty = hero.y;
      var hold = 0.0;

      if (guiding) {
        // God Hand: tap pulls the party toward the point.
        tx = world.guideX!;
        ty = world.guideY!;
        hold = 0.35;
      } else if (target != null) {
        final dist = _dist(hero, target);
        final preferred = hero.preferredRange ?? (hero.attackRange * 0.7);
        final hasLos = _hasClearCorridor(
          world.map,
          world.openGateIds,
          hero.x.floor(),
          hero.y.floor(),
          target.x.floor(),
          target.y.floor(),
        );
        if (hero.ranged && dist < preferred * 0.72 && hasLos) {
          // Kite away while keeping LOS toward target.
          tx = hero.x - (target.x - hero.x);
          ty = hero.y - (target.y - hero.y);
          hold = 0;
        } else {
          tx = target.x;
          ty = target.y;
          // No LOS at hold range â†’ close in so shots/melee aren't wall-blocked.
          hold = hasLos ? preferred : 0;
        }
      } else if (leader != null && hero.id != leader.id) {
        // Idle pack: trail the warrior/leader with light formation offsets.
        final ox = switch (hero.heroRole) {
          HeroRole.mage => -0.9,
          HeroRole.healer => -0.55,
          HeroRole.rogue => 0.35,
          _ => -0.4,
        };
        final oy = (i - 1) * 0.55;
        tx = leader.x + ox;
        ty = leader.y + oy;
        hold = 0.45;
      }

      _steerActor(
        hero,
        tx,
        ty,
        hero.moveSpeed * hero.moveSpeedMul * dt,
        world,
        holdDistance: hold,
        separateFrom: world.heroes,
      );

      if (hero.heroRole == HeroRole.warrior) {
        final partyHero = hero.assetIndex >= 0 &&
                hero.assetIndex < nextState.heroes.length
            ? nextState.heroes[hero.assetIndex]
            : null;
        final offHand = partyHero?.itemIn(EquipmentSlot.offHand);
        final hasShield = offHand?.offHandKind == OffHandKind.shield;
        final cast = _tickWarriorAbilities(
          world,
          nextState,
          hero,
          target,
          dt,
          rng,
          reducedVfx: state.reducedVfx,
          hasShield: hasShield,
        );
        nextState = cast.state;
        goldFromKills += cast.gold;
      } else if (hero.heroRole == HeroRole.healer) {
        _tickPriestAbilities(
          world,
          hero,
          target,
          dt,
          reducedVfx: state.reducedVfx,
        );
      } else if (hero.heroRole == HeroRole.mage) {
        _tickMageAbilities(
          world,
          hero,
          target,
          dt,
          reducedVfx: state.reducedVfx,
        );
      } else if (hero.heroRole == HeroRole.rogue) {
        _tickRogueAbilities(
          world,
          hero,
          target,
          dt,
          reducedVfx: state.reducedVfx,
        );
      }

      if (target == null) continue;
      final dist = _dist(hero, target);
      hero.fireCooldown -= dt * hero.attackSpeedMul;
      if (hero.fireCooldown <= 0 && dist <= hero.attackRange) {
        hero.fireCooldown = hero.attackCooldown;
        final partyHero = hero.assetIndex >= 0 &&
                hero.assetIndex < nextState.heroes.length
            ? nextState.heroes[hero.assetIndex]
            : null;
        final executeBonus = hero.heroRole == HeroRole.rogue &&
            target.hp / target.maxHp < 0.35;
        final critChance = partyHero == null
            ? 5
            : nextState.effectiveHeroCrit(partyHero);
        final isCrit = rng.nextInt(100) < critChance;
        var damage = executeBonus ? (hero.attack * 1.4).round() : hero.attack;
        String? abilityTag;
        var abilityTagArgb = _floaterDamage;
        final mods = _classAttackMods(hero, damage);
        damage = mods.damage;
        abilityTag = mods.tag;
        abilityTagArgb = mods.tagArgb;
        if (isCrit) {
          damage = (damage * 1.75).round();
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
          final dealt = math.max(1, damage - target.effectiveDefense);
          target.hp = math.max(0, target.hp - dealt);
          if (hero.heroRole == HeroRole.warrior) {
            _gainRage(hero, 4 + dealt * 0.15);
            // Soft threat: briefly pull this target onto the tank.
            if (target.forcedTargetTimer < 1.2) {
              target.forcedTargetId = hero.id;
              target.forcedTargetTimer = math.max(target.forcedTargetTimer, 1.4);
            }
          }
          if (hero.heroRole == HeroRole.healer) {
            _atonementHeal(world, hero, dealt, reducedVfx: state.reducedVfx);
            _gainRage(hero, 3);
          }
          if (hero.heroRole == HeroRole.mage) {
            _gainRage(hero, 4);
          }
          if (hero.heroRole == HeroRole.rogue) {
            _gainRage(hero, 5);
            if (hero.bladeFlurryTimer > 0) {
              for (final e in world.enemies) {
                if (e.id == target.id || e.hp <= 0 || e.dormant) continue;
                if (_dist(hero, e) > 2.2) continue;
                final cleave = math.max(1, (dealt * 0.55).round());
                e.hp = math.max(0, e.hp - cleave);
              }
            }
          }
          hero.attackFlash = 0.16;
          if (!state.reducedVfx) {
            _spawnSlash(
              world,
              from: hero,
              to: target,
              isCrit: isCrit || abilityTag != null,
            );
          }
          _spawnFloater(
            world,
            x: target.x + (rng.nextDouble() - 0.5) * 0.25,
            y: target.y - 0.3,
            text: isCrit
                ? 'CRIT $dealt'
                : (abilityTag != null ? '$abilityTag $dealt' : '$dealt'),
            argb: isCrit
                ? _floaterCrit
                : (abilityTag != null ? abilityTagArgb : _floaterDamage),
            life: isCrit || abilityTag != null ? 0.95 : 0.7,
          );
          if (wasAlive && target.hp <= 0) {
            final killed = _onEnemyKilled(world, nextState, target, rng);
            goldFromKills += killed.gold;
            nextState = killed.state;
            if (!state.reducedVfx) {
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
          world.projectiles.addAll(
            _firePattern(
              from: hero,
              to: target,
              damage: damage,
              pattern: hero.pattern,
              forcePierce: partyHero?.gearHasPierce ?? false,
              isCrit: isCrit,
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

    // Pets follow the leader and chip at the nearest unlocked enemy.
    final petLeader = world.leader;
    for (final pet in world.pets) {
      if (petLeader == null) break;
      final target = _nearestActiveEnemy(pet, world.enemies);
      if (target == null) {
        _steerActor(
          pet,
          petLeader.x - 0.55,
          petLeader.y + 0.45,
          pet.moveSpeed * dt,
          world,
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
          pet.moveSpeed * dt,
          world,
          holdDistance: pet.attackRange * 0.7,
          separateFrom: <SpatialActor>[...world.heroes, ...world.pets],
        );
      }
      pet.fireCooldown -= dt;
      if (pet.fireCooldown <= 0 && _dist(pet, target) <= pet.attackRange) {
        pet.fireCooldown = pet.attackCooldown;
        final wasAlive = target.hp > 0;
        final petHit = math.max(1, pet.attack - target.effectiveDefense);
        target.hp = math.max(0, target.hp - petHit);
        pet.attackFlash = 0.14;
        if (!state.reducedVfx) {
          _spawnSlash(world, from: pet, to: target, isCrit: false);
        }
        _spawnFloater(
          world,
          x: target.x,
          y: target.y - 0.25,
          text: '$petHit',
          argb: _floaterDamage,
          life: 0.6,
        );
        if (wasAlive && target.hp <= 0) {
          final killed = _onEnemyKilled(world, nextState, target, rng);
          goldFromKills += killed.gold;
          nextState = killed.state;
        }
      }
    }

    // Enemies: prefer the tank, kite if ranged, path around walls.
    for (final enemy in world.enemies) {
      if (enemy.hp <= 0 || enemy.dormant) continue;
      // Shadow Word: Pain ticks.
      if (enemy.swPainTimer > 0 && enemy.swPainDps > 0) {
        enemy.swPainAcc += enemy.swPainDps * dt;
        if (enemy.swPainAcc >= 1) {
          final tick = enemy.swPainAcc.floor();
          enemy.swPainAcc -= tick;
          final wasAlive = enemy.hp > 0;
          enemy.hp = math.max(0, enemy.hp - tick);
          for (final h in world.heroes) {
            if (h.heroRole == HeroRole.healer && h.isAlive) {
              _atonementHeal(world, h, tick, reducedVfx: state.reducedVfx);
              break;
            }
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
        enemy.moveSpeed * enemy.moveSpeedMul * dt,
        world,
        holdDistance: hold,
        separateFrom: world.enemies,
      );

      final slowRate = enemy.attackSlowTimer > 0 ? 0.8 : 1.0;
      enemy.fireCooldown -= dt * slowRate;
      final afterDist = _dist(enemy, target);
      if (enemy.fireCooldown <= 0 && afterDist <= enemy.attackRange) {
        enemy.fireCooldown = enemy.attackCooldown;
        final raw = math.max(1, enemy.effectiveAttack - target.defense);
        if (enemy.ranged) {
          enemy.attackFlash = 0.12;
          world.projectiles.addAll(
            _firePattern(
              from: enemy,
              to: target,
              damage: raw,
              pattern: ProjectilePattern.single,
            ),
          );
        } else {
          enemy.attackFlash = 0.16;
          final dmg = _applyHeroIncomingDamage(
            world,
            target,
            raw,
            reducedVfx: state.reducedVfx,
          );
          if (!state.reducedVfx) {
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
        }
      }
    }

    // Projectiles
    final remaining = <SpatialProjectile>[];
    for (final p in world.projectiles) {
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

      final victims = p.team == SpatialTeam.hero ? world.enemies : world.heroes;
      var hit = false;
      for (final v in victims) {
        if (v.hp <= 0 || (v.team == SpatialTeam.enemy && v.dormant)) continue;
        if (_distPoint(p.x, p.y, v.x, v.y) < 0.55) {
          final wasAlive = v.hp > 0;
          final int dealt;
          if (v.team == SpatialTeam.hero) {
            // Enemy shots already bake DEF at fire time.
            dealt = _applyHeroIncomingDamage(
              world,
              v,
              p.damage,
              reducedVfx: state.reducedVfx,
            );
          } else {
            dealt = math.max(1, p.damage - v.effectiveDefense);
            v.hp = math.max(0, v.hp - dealt);
          }
          _spawnFloater(
            world,
            x: v.x + (rng.nextDouble() - 0.5) * 0.25,
            y: v.y - 0.3,
            text: p.isCrit ? 'CRIT $dealt' : '$dealt',
            argb: p.isCrit ? _floaterCrit : _floaterDamage,
            life: p.isCrit ? 0.95 : 0.7,
          );
          if (p.isCrit && !state.reducedVfx) {
            _spawnBurst(world, x: v.x, y: v.y, argb: _floaterCrit, radius: 0.7);
          } else if (!state.reducedVfx) {
            _spawnBurst(
              world,
              x: v.x,
              y: v.y,
              argb: p.team == SpatialTeam.hero ? 0xFFFFE08A : 0xFFFF6A4A,
              radius: 0.35,
              life: 0.18,
            );
          }
          hit = true;
          p.hitsRemaining -= 1;
          if (wasAlive && v.hp <= 0 && v.team == SpatialTeam.enemy) {
            final killed = _onEnemyKilled(world, nextState, v, rng);
            goldFromKills += killed.gold;
            nextState = killed.state;
            if (!state.reducedVfx) {
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
      if (!hit || (p.pierce && p.hitsRemaining > 0)) {
        if (!(hit && (!p.pierce || p.hitsRemaining <= 0))) {
          remaining.add(p);
        }
      }
    }
    world.projectiles
      ..clear()
      ..addAll(remaining);

    // Loot becomes real state only when collected (or after its grace period).
    final stillOnGround = <GroundLoot>[];
    for (final loot in world.groundLoot) {
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
        final applied =
            GameLogic.applyLootDrops(nextState, [loot.drop]).state;
        nextState = applied;
        final label = loot.drop.isEquipment
            ? loot.drop.name
            : (loot.kind == GroundLootKind.gold
                ? '+${loot.drop.amount}g'
                : '+essence');
        _spawnFloater(
          world,
          x: loot.x,
          y: loot.y - 0.2,
          text: label.length > 14 ? '${label.substring(0, 12)}â€¦' : label,
          argb: loot.drop.isEquipment
              ? _floaterGear
              : (loot.kind == GroundLootKind.gold
                    ? _floaterGold
                    : _floaterEssence),
          life: 1.05,
        );
      } else {
        stillOnGround.add(loot);
      }
    }
    world.groundLoot
      ..clear()
      ..addAll(stillOnGround);

    _tickFloaters(world, dt);

    nextState = _syncHp(nextState, world);

    if (world.allHeroesDead) {
      return SpatialStepResult(
        world: world,
        state: nextState,
        partyWiped: true,
        goldFromKills: goldFromKills,
      );
    }

    _updateChambers(world);
    // Proximity wake: don't leave later chambers forever dormant.
    for (final enemy in world.enemies) {
      if (!enemy.dormant || enemy.hp <= 0) continue;
      for (final hero in world.heroes) {
        if (!hero.isAlive) continue;
        if (_dist(hero, enemy) < 7.5) {
          enemy.dormant = false;
          break;
        }
      }
    }
    if (world.allEnemiesDead &&
        (world.groundLoot.isEmpty ||
            world.groundLoot.every((loot) => loot.age > 4.5))) {
      world.awaitingExit = true;
    }

    return SpatialStepResult(
      world: world,
      state: nextState,
      goldFromKills: goldFromKills,
    );
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
    world.godHandCooldown = math.max(
      0.55,
      1.1 - state.godHandLevel * 0.05,
    );
    world.pulseX = tileX;
    world.pulseY = tileY;
    world.pulseTimer = 0.35;

    final damage = (baseDamage ?? state.godHandBaseDamage) +
        state.ascensionLevel +
        (state.totalAttack ~/ 8);
    final radius = state.godHandRadius;
    var gold = 0;
    var nextState = state;
    final rng = GameLogic.random;
    for (final enemy in world.enemies) {
      if (enemy.hp <= 0 || enemy.dormant) continue;
      if (_distPoint(tileX, tileY, enemy.x, enemy.y) <= radius) {
        final wasAlive = enemy.hp > 0;
        enemy.hp = math.max(0, enemy.hp - damage);
        _spawnFloater(
          world,
          x: enemy.x,
          y: enemy.y - 0.35,
          text: '$damage',
          argb: _floaterDamage,
          life: 0.75,
        );
        if (wasAlive && enemy.hp <= 0) {
          final killed = _onEnemyKilled(world, nextState, enemy, rng);
          gold += killed.gold;
          nextState = killed.state;
        }
      }
    }
    _updateChambers(world);
    final synced = _syncHp(nextState, world);
    return SpatialStepResult(
      world: world,
      state: synced,
      goldFromKills: gold,
    );
  }

  static GameState _syncHp(GameState state, SpatialWorld world) {
    final heroes = <PartyHero>[];
    for (var i = 0; i < state.heroes.length; i++) {
      final h = state.heroes[i];
      final spatial = i < world.heroes.length ? world.heroes[i] : null;
      heroes.add(
        h.copyWith(currentHp: spatial?.hp.clamp(0, spatial.effectiveMaxHp) ?? 0),
      );
    }
    final enemies = <EnemyUnit>[];
    for (var i = 0; i < state.enemies.length; i++) {
      final e = state.enemies[i];
      final spatial = i < world.enemies.length ? world.enemies[i] : null;
      enemies.add(
        e.copyWith(currentHp: spatial?.hp.clamp(0, e.maxHp) ?? 0),
      );
    }
    return state.copyWith(heroes: heroes, enemies: enemies);
  }

  static void _updateChambers(SpatialWorld world) {
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
    }

    for (final gate in world.map.gates) {
      if (world.clearedChambers.contains(gate.opensAfterChamber)) {
        world.openGateIds.add(gate.id);
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

    // Path soft-lock: living enemies exist but no hero can BFS to them.
    _unlockIfEnemiesUnreachable(world);
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
  static void _unlockIfEnemiesUnreachable(SpatialWorld world) {
    final living = world.enemies.where((e) => e.hp > 0 && !e.dormant).toList();
    if (living.isEmpty) return;
    final heroes = world.heroes.where((h) => h.isAlive).toList();
    if (heroes.isEmpty) return;

    final blocked = living.any((enemy) {
      return !heroes.any(
        (hero) => _hasPath(
          world.map,
          world.openGateIds,
          hero.x,
          hero.y,
          enemy.x,
          enemy.y,
        ),
      );
    });
    if (!blocked) return;
    _openAllGatesAndWake(world);
  }

  static bool _hasPath(
    TileMap map,
    Set<int> openGateIds,
    double fx,
    double fy,
    double tx,
    double ty,
  ) {
    final sx = fx.floor().clamp(0, map.cols - 1);
    final sy = fy.floor().clamp(0, map.rows - 1);
    final gx = tx.floor().clamp(0, map.cols - 1);
    final gy = ty.floor().clamp(0, map.rows - 1);
    if (sx == gx && sy == gy) return true;
    if (_hasClearCorridor(map, openGateIds, sx, sy, gx, gy)) return true;

    final came = <int>{_key(sx, sy, map.cols)};
    final q = <(int, int)>[(sx, sy)];
    const dirs = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];
    while (q.isNotEmpty) {
      final cur = q.removeAt(0);
      if (cur.$1 == gx && cur.$2 == gy) return true;
      for (final d in dirs) {
        final nx = cur.$1 + d.$1;
        final ny = cur.$2 + d.$2;
        final k = _key(nx, ny, map.cols);
        if (came.contains(k)) continue;
        if (!map.isWalkable(nx, ny, openGateIds: openGateIds)) continue;
        came.add(k);
        q.add((nx, ny));
      }
      if (came.length > map.cols * map.rows) break;
    }
    return false;
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

  static ({int gold, GameState state}) _onEnemyKilled(
    SpatialWorld world,
    GameState state,
    SpatialActor enemy,
    math.Random rng,
  ) {
    final index = world.enemies.indexOf(enemy);
    final unit = index >= 0 && index < state.enemies.length
        ? state.enemies[index]
        : null;
    final rewardGold = unit?.rewardGold ?? 0;
    final drops = GameLogic.rollLoot(
      state.battleNumber,
      ascensionLevel: state.ascensionLevel,
    );
    final drop = drops.isEmpty
        ? const LootDrop(
            name: 'Gold Pouch',
            amount: 1,
            rarity: LootRarity.common,
          )
        : drops.first;
    world.groundLoot.add(
      GroundLoot(
        x: enemy.x + (rng.nextDouble() - 0.5) * 0.4,
        y: enemy.y + (rng.nextDouble() - 0.5) * 0.4,
        drop: drop,
      ),
    );
    if (rewardGold > 0) {
      _spawnFloater(
        world,
        x: enemy.x,
        y: enemy.y - 0.55,
        text: '+${rewardGold}g',
        argb: _floaterGold,
        life: 1.0,
      );
    }
    if (drop.isEquipment) {
      _spawnFloater(
        world,
        x: enemy.x + 0.2,
        y: enemy.y - 0.15,
        text: 'LOOT!',
        argb: _floaterGear,
        life: 0.7,
      );
    }
    var next = state;
    if (unit != null) {
      final beforeLevels = [
        for (final h in next.heroes) h.level,
      ];
      next = GameLogic.awardEnemyKillXp(next, unit);
      final xp = GameLogic.xpForEnemy(unit);
      _spawnFloater(
        world,
        x: enemy.x - 0.15,
        y: enemy.y - 0.75,
        text: '+${xp}XP',
        argb: _floaterXp,
        life: 0.9,
      );
      for (var i = 0; i < next.heroes.length; i++) {
        if (next.heroes[i].level > beforeLevels[i]) {
          _spawnFloater(
            world,
            x: world.heroes.length > i ? world.heroes[i].x : enemy.x,
            y: (world.heroes.length > i ? world.heroes[i].y : enemy.y) - 0.9,
            text: 'LEVEL UP!',
            argb: _floaterXp,
            life: 1.2,
          );
        }
      }
    }
    return (gold: rewardGold, state: next);
  }

  static SpatialActor? _nearestActiveEnemy(
    SpatialActor self,
    List<SpatialActor> enemies,
  ) {
    SpatialActor? best;
    var bestD = double.infinity;
    for (final enemy in enemies) {
      if (enemy.hp <= 0 || enemy.dormant) continue;
      final distance = _dist(self, enemy);
      if (distance < bestD) {
        bestD = distance;
        best = enemy;
      }
    }
    if (best != null) return best;
    // Next chamber still dormant: path toward them so floors don't soft-lock.
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      final distance = _dist(self, enemy);
      if (distance < bestD) {
        bestD = distance;
        best = enemy;
      }
    }
    return best;
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
      if (h.heroRole == HeroRole.warrior) tank = h;
      if (d < bestD) {
        bestD = d;
        nearest = h;
      }
    }
    // Defensive Stance: wider soft-taunt leash.
    final leash = tank != null &&
            WarriorAbilities.isUnlocked(
              AbilityId.defensiveStance,
              tank.heroLevel,
            )
        ? 4.0
        : 2.5;
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
  static void _steerActor(
    SpatialActor a,
    double tx,
    double ty,
    double step,
    SpatialWorld world, {
    double holdDistance = 0,
    List<SpatialActor>? separateFrom,
    double separationRadius = 0.95,
    double separationWeight = 1.4,
  }) {
    if (step <= 0) return;
    final dist = _distPoint(a.x, a.y, tx, ty);
    if (holdDistance > 0 && dist <= holdDistance) {
      // Soft orbit / idle â€” only apply separation.
      _applySeparation(
        a,
        world,
        separateFrom,
        step * 0.55,
        radius: separationRadius,
        weight: separationWeight,
      );
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
    if (len < 0.001) return;
    final move = math.min(step, dist > 0 ? dist : step);
    final nx = a.x + dx / len * move;
    final ny = a.y + dy / len * move;

    // Try diagonal, then slide on axes (corner-friendly).
    if (world.canWalk(nx, ny)) {
      a.x = nx;
      a.y = ny;
      return;
    }
    if (world.canWalk(nx, a.y)) {
      a.x = nx;
    }
    if (world.canWalk(a.x, ny)) {
      a.y = ny;
    }
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
    final gx = tx.floor().clamp(0, map.cols - 1);
    final gy = ty.floor().clamp(0, map.rows - 1);
    if (sx == gx && sy == gy) return (tx, ty);

    if (_hasClearCorridor(map, openGateIds, sx, sy, gx, gy)) {
      return (tx, ty);
    }

    final came = <int, int>{};
    final q = <(int, int)>[(sx, sy)];
    came[_key(sx, sy, map.cols)] = _key(sx, sy, map.cols);
    const dirs = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];
    var found = false;
    while (q.isNotEmpty) {
      final cur = q.removeAt(0);
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
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, 999);
    final ux = dx / len;
    final uy = dy / len;
    const speed = 7.5;
    final pierce =
        forcePierce || pattern == ProjectilePattern.pierce;

    SpatialProjectile shot(double angleOffset, {double life = 1.6}) {
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
        life: life,
        pierce: pierce,
        hitsRemaining: pierce ? 3 : 1,
        isCrit: isCrit,
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
}
