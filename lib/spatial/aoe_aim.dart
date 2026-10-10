part of 'spatial_combat.dart';

/// Where a ground, rain, nova, or chain spell should go.
///
/// The center is the clump the disc can actually cover. A lone focus beside
/// that clump does not pull the spell into the empty gap.
class AoeSpot {
  const AoeSpot({required this.x, required this.y, required this.hits});

  final double x;
  final double y;
  final int hits;
}

abstract final class AoeAim {
  /// Densest disc of [radius] this hero can drop right now.
  static AoeSpot? bestDisc({
    required SpatialWorld world,
    required SpatialActor hero,
    SpatialActor? focus,
    required double radius,
  }) {
    if (radius <= 0) return null;
    final pool = _inReach(world, hero, focus, radius);
    if (pool.isEmpty) return null;

    final melee = _melee(hero);
    final anchor = melee
        ? hero
        : (focus != null && focus.hp > 0 && !focus.dormant ? focus : hero);

    // Enemy feet and the midpoint of every pair inside the diameter. A pair
    // three tiles apart is still one disc; the gap between two clumps is not.
    final points = <(double, double)>[for (final e in pool) (e.x, e.y)];
    for (var i = 0; i < pool.length; i++) {
      for (var j = i + 1; j < pool.length; j++) {
        final gap = SpatialCombat.actorDist(pool[i], pool[j]);
        if (gap < 0.2 || gap > radius * 2) continue;
        points.add(((pool[i].x + pool[j].x) / 2, (pool[i].y + pool[j].y) / 2));
      }
    }

    var bestX = pool.first.x;
    var bestY = pool.first.y;
    var bestHits = -1;
    var bestSpread = double.infinity;
    var bestDist = double.infinity;
    List<SpatialActor> bestCovered = const [];
    for (final (x, y) in points) {
      final covered = _hittable(world, hero, pool, x, y, radius);
      final hits = covered.length;
      if (hits <= 0) continue;
      final spread = _spread(x, y, covered);
      final dist = SpatialCombat.distPoint(anchor.x, anchor.y, x, y);
      final better =
          hits > bestHits ||
          (hits == bestHits && spread < bestSpread - 0.05) ||
          (hits == bestHits &&
              (spread - bestSpread).abs() <= 0.05 &&
              dist < bestDist);
      if (!better) continue;
      bestX = x;
      bestY = y;
      bestHits = hits;
      bestSpread = spread;
      bestDist = dist;
      bestCovered = covered;
    }
    if (bestHits <= 0) return null;

    var sx = 0.0;
    var sy = 0.0;
    for (final e in bestCovered) {
      sx += e.x;
      sy += e.y;
    }
    final cx = sx / bestCovered.length;
    final cy = sy / bestCovered.length;
    final tightened = _hittable(world, hero, pool, cx, cy, radius);
    if (tightened.length >= bestCovered.length && world.canWalk(cx, cy)) {
      return AoeSpot(x: cx, y: cy, hits: tightened.length);
    }
    return AoeSpot(x: bestX, y: bestY, hits: bestCovered.length);
  }

  /// Living enemies inside a self-nova that the hero can see.
  static int novaHits(SpatialWorld world, SpatialActor hero, double radius) {
    var n = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat.actorDist(hero, e) > radius) continue;
      if (!SpatialCombat.canShoot(world, hero.x, hero.y, e.x, e.y)) continue;
      n++;
    }
    return n;
  }

  /// Chain path that reaches the most bodies. Equal paths keep [focus].
  static List<SpatialActor> chainTargets({
    required SpatialWorld world,
    required SpatialActor hero,
    SpatialActor? focus,
    double hopRange = 3.6,
    int cap = 6,
  }) {
    final alive = <SpatialActor>[
      for (final e in world.enemies)
        if (e.hp > 0 && !e.dormant) e,
    ];
    if (alive.isEmpty) return const [];

    List<SpatialActor>? best;
    var bestWasFocus = false;
    var bestDist = double.infinity;
    for (final start in alive) {
      if (!_chainReachable(hero, focus, start)) continue;
      final path = _chainFrom(start, alive, hopRange, cap);
      if (path.isEmpty) continue;
      final isFocus = focus != null && start.id == focus.id;
      final dist = SpatialCombat.actorDist(hero, start);
      final better =
          best == null ||
          path.length > best.length ||
          (path.length == best.length && isFocus && !bestWasFocus) ||
          (path.length == best.length &&
              isFocus == bestWasFocus &&
              dist < bestDist);
      if (!better) continue;
      best = path;
      bestWasFocus = isFocus;
      bestDist = dist;
    }
    return best ?? const [];
  }

  static bool _melee(SpatialActor hero) =>
      (hero.preferredRange ?? hero.attackRange) < 3.2;

  static List<SpatialActor> _inReach(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    double radius,
  ) {
    final melee = _melee(hero);
    final reach = melee
        ? radius + 1.15
        : math.max(hero.attackRange, hero.preferredRange ?? 0) + 1.8;
    final focusBubble = radius + 1.5;
    final out = <SpatialActor>[];
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat.actorDist(hero, e) <= reach) {
        out.add(e);
        continue;
      }
      // Ground and rain have no max range. A ranged hero still aims at the
      // pack around the focus while walking up. Melee stays with its own reach.
      if (!melee &&
          focus != null &&
          focus.hp > 0 &&
          !focus.dormant &&
          SpatialCombat.actorDist(focus, e) <= focusBubble) {
        out.add(e);
      }
    }
    return out;
  }

  /// Lower means the bodies sit tighter on the candidate.
  static double _spread(double x, double y, List<SpatialActor> covered) {
    if (covered.length <= 1) return 0;
    var sum = 0.0;
    for (final e in covered) {
      sum += SpatialCombat.distPoint(x, y, e.x, e.y);
    }
    return sum / covered.length;
  }

  /// Bodies inside the disc that this cast can actually shoot, matching
  /// [AbilityEffectRunner]'s ground hit test.
  static List<SpatialActor> _hittable(
    SpatialWorld world,
    SpatialActor hero,
    List<SpatialActor> pool,
    double x,
    double y,
    double radius,
  ) {
    final fromX = world.canWalk(x, y) ? x : hero.x;
    final fromY = world.canWalk(x, y) ? y : hero.y;
    return [
      for (final e in pool)
        if (SpatialCombat.distPoint(x, y, e.x, e.y) <= radius &&
            SpatialCombat.canShoot(world, fromX, fromY, e.x, e.y))
          e,
    ];
  }

  static bool _chainReachable(
    SpatialActor hero,
    SpatialActor? focus,
    SpatialActor enemy,
  ) {
    final reach = math.max(hero.attackRange, hero.preferredRange ?? 0) + 2.4;
    if (SpatialCombat.actorDist(hero, enemy) <= reach) return true;
    return focus != null && enemy.id == focus.id;
  }

  static List<SpatialActor> _chainFrom(
    SpatialActor start,
    List<SpatialActor> alive,
    double hopRange,
    int cap,
  ) {
    final targets = <SpatialActor>[];
    final used = <String>{};
    SpatialActor? cursor = start;
    while (cursor != null && targets.length < cap) {
      targets.add(cursor);
      used.add(cursor.id);
      SpatialActor? next;
      var best = hopRange;
      for (final e in alive) {
        if (used.contains(e.id)) continue;
        final d = SpatialCombat.actorDist(cursor, e);
        if (d < best) {
          best = d;
          next = e;
        }
      }
      cursor = next;
    }
    return targets;
  }
}
