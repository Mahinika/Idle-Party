/// Repeated boss-tell shape: chip and/or a status after the wind-up.
///
/// Unique tells (Sandy knock, Storm chain, Crystal scale, Goblin rally,
/// Dead heal, Ashen) stay as named functions in enemy specials.
enum BossTellShape { radius, focus, party }

class BossTellDef {
  const BossTellDef({
    required this.shape,
    required this.argb,
    required this.ringRadius,
    required this.cdLive,
    required this.cdAfk,
    this.radius = 0,
    this.maxRange = 0,
    this.atkMul = 0,
    this.slowSeconds = 0,
    this.rootSeconds = 0,
    this.shoutSeconds = 0,
    this.meleeChip = true,
    this.scaleCooldown = false,
    this.tellOnFocus = false,
  });

  final BossTellShape shape;
  final double radius;
  final double maxRange;
  final double atkMul;
  final double slowSeconds;
  final double rootSeconds;
  final double shoutSeconds;
  final double cdLive;
  final double cdAfk;
  final int argb;
  final double ringRadius;
  final bool meleeChip;
  final bool scaleCooldown;
  final bool tellOnFocus;
}

/// Numbers copied from the old per-cave resolve switch.
abstract final class BossTells {
  static const Map<String, BossTellDef> byDungeon = {
    'veil': BossTellDef(
      shape: BossTellShape.radius,
      radius: 3.6,
      atkMul: 0.32,
      slowSeconds: 2.8,
      cdLive: 8,
      cdAfk: 9,
      argb: 0xFFE8D0FF,
      ringRadius: 1.45,
    ),
    'hell': BossTellDef(
      shape: BossTellShape.radius,
      radius: 2.2,
      atkMul: 0.5,
      rootSeconds: 1.15,
      cdLive: 8,
      cdAfk: 9,
      argb: 0xFFFF6030,
      ringRadius: 1.15,
      scaleCooldown: true,
    ),
    'tide': BossTellDef(
      shape: BossTellShape.radius,
      radius: 4.0,
      atkMul: 0.4,
      slowSeconds: 2.6,
      cdLive: 8,
      cdAfk: 9,
      argb: 0xFF40A0E0,
      ringRadius: 1.7,
    ),
    'fen': BossTellDef(
      shape: BossTellShape.radius,
      radius: 4.2,
      atkMul: 0.28,
      slowSeconds: 2.4,
      cdLive: 7,
      cdAfk: 8,
      argb: 0xFF80C040,
      ringRadius: 1.35,
      meleeChip: false,
    ),
    'grove': BossTellDef(
      shape: BossTellShape.focus,
      maxRange: 4.8,
      rootSeconds: 2.0,
      cdLive: 8,
      cdAfk: 9,
      argb: 0xFF70C060,
      ringRadius: 1.0,
      tellOnFocus: true,
    ),
    'ember': BossTellDef(
      shape: BossTellShape.focus,
      maxRange: 5.2,
      atkMul: 0.4,
      slowSeconds: 3.4,
      cdLive: 7,
      cdAfk: 8,
      argb: 0xFFFF7030,
      ringRadius: 0.95,
      meleeChip: false,
      tellOnFocus: true,
    ),
    'underworld': BossTellDef(
      shape: BossTellShape.focus,
      maxRange: 6.2,
      atkMul: 0.85,
      shoutSeconds: 2.8,
      cdLive: 7,
      cdAfk: 8,
      argb: 0xFF80FFA0,
      ringRadius: 0.9,
      meleeChip: false,
      tellOnFocus: true,
    ),
    'king': BossTellDef(
      shape: BossTellShape.party,
      slowSeconds: 3.0,
      shoutSeconds: 2.4,
      cdLive: 8,
      cdAfk: 9,
      argb: 0xFFE0C060,
      ringRadius: 1.6,
    ),
    'rime': BossTellDef(
      shape: BossTellShape.party,
      atkMul: 0.28,
      slowSeconds: 2.8,
      cdLive: 8,
      cdAfk: 9,
      argb: 0xFFA0E0FF,
      ringRadius: 1.55,
    ),
  };

  static BossTellDef? forId(String id) => byDungeon[id];
}
