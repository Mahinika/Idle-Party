part of 'spatial_combat.dart';

/// Per-tick focus facts so every hero doesn't re-scan tank / threats.
final class _FocusTickCache {
  _FocusTickCache({
    required this.tank,
    required this.tankFocus,
    required this.anyActive,
    required this.threatBonusByEnemyId,
  });

  final SpatialActor? tank;
  final SpatialActor? tankFocus;
  final bool anyActive;

  /// Precomputed peel score for enemies currently beating on backline.
  final Map<String, double> threatBonusByEnemyId;

  static _FocusTickCache build(SpatialWorld world) {
    SpatialActor? tank;
    SpatialActor? tankFocus;
    for (final h in world.heroes) {
      if (!h.isAlive || !_actorIsTank(h)) continue;
      tank = h;
      tankFocus = SpatialCombat._nearestActiveEnemy(h, world.enemies);
      break;
    }

    var anyActive = false;
    final threat = <String, double>{};
    for (final e in world.enemies) {
      if (e.hp <= 0) continue;
      if (!e.dormant) anyActive = true;
      if (e.forcedTargetTimer <= 0 || e.forcedTargetId == null) continue;
      for (final h in world.heroes) {
        if (!h.isAlive || h.id != e.forcedTargetId) continue;
        if (_actorIsHealer(h)) {
          threat[e.id] = 50;
        } else if (h.ranged ||
            (h.heroSpecId != null &&
                HeroSpecs.def(h.heroSpecId!).roleTag == SpecRoleTag.caster)) {
          threat[e.id] = 28;
        }
        break;
      }
    }
    return _FocusTickCache(
      tank: tank,
      tankFocus: tankFocus,
      anyActive: anyActive,
      threatBonusByEnemyId: threat,
    );
  }
}

/// Pathing / soft-lock helpers (indexed BFS — no queue removeAt(0)).
abstract final class _CombatPathing {
  /// Reusable key buffer for cooldown / buff maps (single-threaded combat).
  static final List<String> scratchKeys = <String>[];

  static final Map<int, List<SpatialActor>> _actorCells =
      <int, List<SpatialActor>>{};
  static final List<int> _actorCellKeys = <int>[];

  static void clearActorCells() {
    for (final k in _actorCellKeys) {
      _actorCells[k]?.clear();
    }
    _actorCellKeys.clear();
  }

  static void binActor(SpatialActor a, int cols) {
    final k = SpatialCombat._key(a.x.floor(), a.y.floor(), cols);
    final list = _actorCells.putIfAbsent(k, () => <SpatialActor>[]);
    if (list.isEmpty) _actorCellKeys.add(k);
    list.add(a);
  }

  static List<SpatialActor>? actorsInCell(int x, int y, int cols) {
    return _actorCells[SpatialCombat._key(x, y, cols)];
  }

  static void tickStringTimers(
    Map<String, double> timers,
    double dt, {
    void Function(String key)? onExpire,
  }) {
    if (timers.isEmpty) return;
    scratchKeys
      ..clear()
      ..addAll(timers.keys);
    for (final key in scratchKeys) {
      final left = (timers[key] ?? 0) - dt;
      if (left <= 0) {
        timers.remove(key);
        onExpire?.call(key);
      } else {
        timers[key] = left;
      }
    }
  }

  /// Flood-fill walkable tiles reachable by any living hero.
  /// Returns true when some active enemy tile is outside that set.
  static bool anyActiveEnemyUnreachable(SpatialWorld world) {
    final map = world.map;
    final open = world.openGateIds;
    final cols = map.cols;

    var hasLivingHero = false;
    var hasLivingEnemy = false;
    for (final h in world.heroes) {
      if (h.isAlive) {
        hasLivingHero = true;
        break;
      }
    }
    if (!hasLivingHero) return false;
    for (final e in world.enemies) {
      if (e.hp > 0 && !e.dormant) {
        hasLivingEnemy = true;
        break;
      }
    }
    if (!hasLivingEnemy) return false;

    final reached = <int>{};
    final q = <(int, int)>[];
    var head = 0;
    const dirs = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];

    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      final sx = h.x.floor().clamp(0, map.cols - 1);
      final sy = h.y.floor().clamp(0, map.rows - 1);
      // Snap onto walkable if standing on a gate edge / corner.
      final start = SpatialCombat._nearestWalkableTile(map, open, sx, sy);
      final k = SpatialCombat._key(start.$1, start.$2, cols);
      if (reached.add(k)) q.add(start);
    }

    while (head < q.length) {
      final cur = q[head++];
      for (final d in dirs) {
        final nx = cur.$1 + d.$1;
        final ny = cur.$2 + d.$2;
        if (!map.inBounds(nx, ny)) continue;
        final k = SpatialCombat._key(nx, ny, cols);
        if (reached.contains(k)) continue;
        if (!map.isWalkable(nx, ny, openGateIds: open)) continue;
        reached.add(k);
        q.add((nx, ny));
      }
      if (reached.length > map.cols * map.rows) break;
    }

    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final ex = e.x.floor().clamp(0, map.cols - 1);
      final ey = e.y.floor().clamp(0, map.rows - 1);
      final ek = SpatialCombat._key(ex, ey, cols);
      if (reached.contains(ek)) continue;
      // Enemy may sit slightly off-tile — accept adjacent walkable reach.
      var near = false;
      for (final d in dirs) {
        final ax = ex + d.$1;
        final ay = ey + d.$2;
        if (!map.inBounds(ax, ay)) continue;
        if (reached.contains(SpatialCombat._key(ax, ay, cols))) {
          near = true;
          break;
        }
      }
      if (!near) return true;
    }
    return false;
  }
}
