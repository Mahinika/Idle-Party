import 'dart:math';

import '../models/hero_spec.dart';
import '../models/spec_mastery.dart';

/// Cataclysm-style avoidance + CC diminishing returns (idle-tuned).
class CombatAvoidance {
  CombatAvoidance._();

  /// Rating → % with diminishing returns vs level.
  static double ratingToPercent(int rating, int level, {double scale = 130}) {
    if (rating <= 0) return 0;
    final lvl = level.clamp(1, 60);
    return 100.0 * rating / (rating + scale * lvl);
  }

  /// Sheet dodge/parry from Agi (+ optional mastery rating crumb).
  static ({double dodgePercent, double parryPercent}) sheetAvoidance({
    required int agility,
    required int masteryRating,
    required int level,
    required bool isTank,
  }) {
    final dodgeRating = max(0, agility * 4 + masteryRating ~/ 3);
    final dodge = ratingToPercent(dodgeRating, level, scale: 115);
    final parryRating = isTank ? max(0, agility * 2 + level * 6) : 0;
    final parry = isTank ? ratingToPercent(parryRating, level, scale: 95) : 0.0;
    return (dodgePercent: dodge.clamp(0, 75), parryPercent: parry.clamp(0, 60));
  }

  /// CC root/stun duration after diminishing returns stacks.
  static double ccRootDuration(double baseSeconds, int drStacks) {
    return baseSeconds *
        switch (drStacks.clamp(0, 4)) {
          0 => 1.0,
          1 => 0.5,
          2 => 0.25,
          _ => 0.0,
        };
  }

  /// Result of melee avoidance roll (armor + DR CDs applied by caller).
  static AvoidanceResult resolveIncomingMelee({
    required int rawDamage,
    required double dodgePercent,
    required double parryPercent,
    required double blockChance,
    required int blockValue,
    required bool shieldBlockActive,
    required Random rng,
  }) {
    if (rawDamage <= 0) {
      return const AvoidanceResult(damage: 0);
    }

    final dodgeRoll = rng.nextDouble() * 100;
    if (dodgeRoll < dodgePercent) {
      return const AvoidanceResult(damage: 0, dodged: true);
    }

    final parryRoll = rng.nextDouble() * 100;
    if (parryRoll < parryPercent) {
      return const AvoidanceResult(damage: 0, parried: true);
    }

    var damage = rawDamage;
    var blocked = false;

    // Mastery passive block or active Shield Block / Holy Shield window.
    final blockRoll = rng.nextDouble();
    if (blockChance > 0 && blockRoll < blockChance) {
      blocked = true;
    } else if (shieldBlockActive) {
      blocked = true;
    }

    if (blocked) {
      // Cata: blocked hits take −30% damage, then flat block value.
      damage = max(1, (damage * 0.70).round());
      if (blockValue > 0) {
        damage = max(1, damage - blockValue);
      }
    }

    return AvoidanceResult(damage: damage, blocked: blocked);
  }
}

class AvoidanceResult {
  const AvoidanceResult({
    required this.damage,
    this.dodged = false,
    this.parried = false,
    this.blocked = false,
  });

  final int damage;
  final bool dodged;
  final bool parried;
  final bool blocked;

  bool get avoided => dodged || parried;
}

/// Populate mastery-derived block chance on a hero view.
double masteryBlockChance({
  required HeroSpecId? specId,
  required double masteryPoints,
}) {
  return SpecMastery.blockChance(
    MasteryCombatant(specId: specId, masteryPoints: masteryPoints),
  );
}
