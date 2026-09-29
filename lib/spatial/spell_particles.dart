part of 'spatial_combat.dart';

/// Visual-only sparks. Combat never reads them. Offline stays on Minimal,
/// which spawns none, so DPS cannot move.
enum SpellSparkKind { ember, flake, mote, spark, leaf, smoke, rune }

class SpellSpark {
  SpellSpark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.argb,
    required this.size,
    required this.kind,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final int argb;
  final double size;
  final SpellSparkKind kind;
  double spin = 0;
}

/// Sparks behind spells. A private counter, never [GameLogic.random].
abstract final class SpellSparks {
  static const int capFull = 140;
  static const int capLite = 50;

  static int _noise = 1;

  static double _unit() {
    _noise = (_noise * 1103515245 + 12345) & 0x7fffffff;
    return (_noise % 1000) / 1000.0;
  }

  static SpellSparkKind kindFor(SpellBoltStyle style) => switch (style) {
    SpellBoltStyle.fire => SpellSparkKind.ember,
    SpellBoltStyle.frost => SpellSparkKind.flake,
    SpellBoltStyle.holy => SpellSparkKind.mote,
    SpellBoltStyle.shadow || SpellBoltStyle.demon => SpellSparkKind.smoke,
    SpellBoltStyle.nature || SpellBoltStyle.poison => SpellSparkKind.leaf,
    SpellBoltStyle.lightning ||
    SpellBoltStyle.arrow ||
    SpellBoltStyle.weapon => SpellSparkKind.spark,
    SpellBoltStyle.arcane => SpellSparkKind.rune,
  };

  /// True on Full and Lite. Minimal and offline (forced Minimal) stay still.
  static bool allow(SpatialWorld world) =>
      !world.reducedVfx || world.spawnPersistentVfx;

  static int capFor(SpatialWorld world) => world.reducedVfx ? capLite : capFull;

  static void puff(
    SpatialWorld world, {
    required double x,
    required double y,
    required SpellBoltStyle style,
    int count = 5,
  }) {
    if (!allow(world)) return;
    final lite = world.reducedVfx;
    final n = lite ? math.max(1, count ~/ 2) : count;
    final kind = kindFor(style);
    final argb = SpatialCombat.burstArgbForStyle(style);
    for (var i = 0; i < n; i++) {
      world.spellSparks.add(
        _spark(x: x, y: y, styleKind: kind, argb: argb, alongX: 0, alongY: 0),
      );
    }
    _trim(world);
  }

  /// One or two pips behind a flying bolt. Full only.
  static void trail(SpatialWorld world, SpatialProjectile bolt) {
    if (world.reducedVfx || !world.spawnPersistentVfx) return;
    final speed = math.sqrt(bolt.vx * bolt.vx + bolt.vy * bolt.vy);
    final backX = speed > 0.05 ? -bolt.vx / speed : 0.0;
    final backY = speed > 0.05 ? -bolt.vy / speed : 0.0;
    final magic =
        bolt.style != SpellBoltStyle.weapon &&
        bolt.style != SpellBoltStyle.arrow;
    final n = magic ? 2 : 1;
    final kind = kindFor(bolt.style);
    final argb = SpatialCombat.burstArgbForStyle(bolt.style);
    for (var i = 0; i < n; i++) {
      world.spellSparks.add(
        _spark(
          x: bolt.x + backX * (0.12 + i * 0.08),
          y: bolt.y + backY * (0.12 + i * 0.08),
          styleKind: kind,
          argb: argb,
          alongX: backX,
          alongY: backY,
          trail: true,
        ),
      );
    }
    _trim(world);
  }

  static SpellSpark _spark({
    required double x,
    required double y,
    required SpellSparkKind styleKind,
    required int argb,
    required double alongX,
    required double alongY,
    bool trail = false,
  }) {
    final a = _unit() * math.pi * 2;
    final speed = trail ? 0.35 + _unit() * 0.4 : 0.7 + _unit() * 1.6;
    var vx = math.cos(a) * speed;
    var vy = math.sin(a) * speed;
    var life = trail ? 0.18 + _unit() * 0.12 : 0.28 + _unit() * 0.26;
    var size = trail ? 0.045 + _unit() * 0.03 : 0.055 + _unit() * 0.05;
    switch (styleKind) {
      case SpellSparkKind.ember:
        vy = trail ? alongY * 0.8 - 0.4 : -1.1 - _unit() * 1.5;
        vx = trail ? alongX * 0.8 + (vx * 0.25) : vx * 0.4;
        life = trail ? life : 0.34 + _unit() * 0.22;
      case SpellSparkKind.flake:
        vy = trail ? alongY * 0.5 + 0.35 : 0.45 + _unit() * 0.7;
        vx *= 0.35;
      case SpellSparkKind.smoke:
        life = trail ? life : 0.4 + _unit() * 0.22;
        size *= 1.7;
      case SpellSparkKind.spark:
        vx = trail ? alongX * 1.2 : vx * 2.1;
        vy = trail ? alongY * 1.2 : vy * 2.1;
        life = 0.1 + _unit() * 0.1;
      case SpellSparkKind.leaf:
        vy = trail ? alongY * 0.4 - 0.2 : -0.25 - _unit() * 0.45;
      case SpellSparkKind.mote:
        life = trail ? life : 0.22 + _unit() * 0.16;
      case SpellSparkKind.rune:
        vx *= 0.35;
        vy *= 0.35;
        life = trail ? life : 0.32;
    }
    return SpellSpark(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      life: life,
      argb: argb,
      size: size,
      kind: styleKind,
    );
  }

  static void tick(SpatialWorld world, double dt) {
    final list = world.spellSparks;
    if (list.isEmpty) return;
    for (final s in list) {
      s.life -= dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.spin += dt * (s.kind == SpellSparkKind.smoke ? 5.5 : 2.2);
      if (s.kind == SpellSparkKind.ember) s.vy -= 1.5 * dt;
      if (s.kind == SpellSparkKind.flake) s.vy += 0.55 * dt;
      if (s.kind == SpellSparkKind.smoke) {
        s.vx += math.cos(s.spin) * 0.9 * dt;
        s.vy -= 0.35 * dt;
      }
      s.vx *= 0.96;
      s.vy *= 0.96;
    }
    list.removeWhere((s) => s.life <= 0);
  }

  static void _trim(SpatialWorld world) {
    final list = world.spellSparks;
    final extra = list.length - capFor(world);
    if (extra > 0) list.removeRange(0, extra);
  }
}
