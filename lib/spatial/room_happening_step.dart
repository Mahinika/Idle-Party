part of 'spatial_combat.dart';

/// Fires the floor's chest, trap, or altar once, when a hero walks onto it.
GameState roomHappeningTick(SpatialWorld world, GameState state) {
  if (world.happeningSpent) return state;
  if (RoomHappening.alreadyClaimed(state)) {
    world.happeningSpent = true;
    return state;
  }
  MapProp? prop;
  for (final p in world.map.props) {
    if (!p.happening) continue;
    prop = p;
    break;
  }
  if (prop == null) return state;

  final px = prop.x + 0.5;
  final py = prop.y + 0.5;
  var near = false;
  for (final hero in world.heroes) {
    if (hero.hp <= 0) continue;
    if (SpatialCombat.distPoint(hero.x, hero.y, px, py) <=
        RoomHappening.reach) {
      near = true;
      break;
    }
  }
  if (!near) return state;

  world.happeningSpent = true;
  var next = state.copyWith(roomHappeningClaim: RoomHappening.claimKey(state));
  switch (prop.kind) {
    case MapPropKind.chest:
      final gold = RoomHappening.chestGold(next);
      final granted = GameLogic.grantLoot(next, [
        LootDrop(name: 'Gold Pouch', amount: gold, rarity: LootRarity.common),
      ]);
      next = granted.state;
      SpatialCombat.spawnFloater(
        world,
        x: px,
        y: py - 0.45,
        text: 'CHEST',
        argb: SpatialCombat._floaterGold,
        life: 1.15,
        priority: 2,
      );
      final gained = granted.receipt.goldGained;
      if (gained > 0) {
        SpatialCombat.spawnFloater(
          world,
          x: px,
          y: py - 0.9,
          text: '+${gained}g',
          argb: SpatialCombat._floaterGold,
          life: 1.05,
          priority: 2,
        );
      }
      break;
    case MapPropKind.trap:
      for (final hero in world.heroes) {
        if (hero.hp <= 1) continue;
        final chip = math.max(1, (hero.effectiveMaxHp * 0.08).round());
        final left = hero.hp - chip;
        hero.hp = left < 1 ? 1 : left;
      }
      SpatialCombat.spawnFloater(
        world,
        x: px,
        y: py - 0.45,
        text: 'TRAP',
        argb: SpatialCombat.floaterDamage,
        life: 1.15,
        priority: 2,
      );
      break;
    case MapPropKind.altar:
      for (final hero in world.heroes) {
        if (hero.hp <= 0 || hero.hp >= hero.effectiveMaxHp) continue;
        final heal = math.max(1, (hero.effectiveMaxHp * 0.12).round());
        hero.hp = math.min(hero.effectiveMaxHp, hero.hp + heal);
      }
      SpatialCombat.spawnFloater(
        world,
        x: px,
        y: py - 0.45,
        text: 'ALTAR',
        argb: SpatialCombat.floaterHeal,
        life: 1.15,
        priority: 2,
      );
      break;
    default:
      break;
  }
  SpatialCombat.spawnRing(
    world,
    x: px,
    y: py,
    argb: prop.kind == MapPropKind.trap
        ? SpatialCombat.floaterDamage
        : prop.kind == MapPropKind.altar
        ? SpatialCombat.floaterHeal
        : SpatialCombat._floaterGold,
    radius: 1.05,
    life: 0.45,
  );
  return next;
}
