import 'dart:math' as math;

import '../models/enemy.dart';
import '../models/loot.dart';
import '../ui/kenney_assets.dart';
import 'tile_map.dart';

/// One Hideout stash ambush spawn (built into [SpatialActor] by SpatialCombat).
class HideoutAmbushSpec {
  const HideoutAmbushSpec({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.moveSpeed,
    required this.attackCooldown,
    required this.archetype,
    required this.spritePath,
    required this.chamberIndex,
    required this.dormant,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final int hp;
  final int attack;
  final int defense;
  final double moveSpeed;
  final double attackCooldown;
  final EnemyArchetype archetype;
  final String spritePath;
  final int chamberIndex;
  final bool dormant;
}

/// Goblin's Hideout signature beat: room chests are stolen stashes.
///
/// Each chest socket can wake a nearby ambush (Stash Guard / Loot Snatcher)
/// so treasure rooms feel like raids, not free gold. AFK-safe — same dormant
/// + proximity wake rules as normal chamber packs.
abstract final class HideoutStash {
  static const String dungeonId = 'goblin';

  static bool isHideout(String id) => id == dungeonId;

  /// Extra gold multiplier for Hideout room chests (stolen pouches).
  static const double chestGoldMult = 1.55;

  /// Chance a Hideout chest also drops a second gold pouch.
  static const double stolenCoinChance = 0.38;

  /// Ambush specs next to [map.lootChestPoints]. Caller turns them into actors.
  static List<HideoutAmbushSpec> planAmbushes({
    required TileMap map,
    required int firstCombatChamber,
    required double threatScale,
    required math.Random rng,
    int templateHp = 40,
    int templateAtk = 6,
    int templateDef = 1,
  }) {
    if (map.lootChestPoints.isEmpty) return const [];

    final out = <HideoutAmbushSpec>[];
    var seq = 0;
    for (final cell in map.lootChestPoints) {
      final chamber = map.chamberIndexAt(cell.$1 + 0.5, cell.$2 + 0.5);
      final dormant = chamber > firstCombatChamber;
      final guards = 1 + (rng.nextDouble() < 0.45 ? 1 : 0);
      for (var g = 0; g < guards; g++) {
        final glass = g > 0 || rng.nextDouble() < 0.35;
        final ox = (g == 0 ? -0.55 : 0.55) + (rng.nextDouble() - 0.5) * 0.2;
        final oy = (rng.nextDouble() - 0.5) * 0.35;
        final hpMult = glass ? 0.45 : 0.62;
        final atkMult = glass ? 1.15 : 0.9;
        final name = glass ? 'Loot Snatcher' : 'Stash Guard';
        final archetype = glass ? EnemyArchetype.glass : EnemyArchetype.swarm;
        out.add(
          HideoutAmbushSpec(
            id: 'stash_${seq++}_${cell.$1}_${cell.$2}',
            name: name,
            x: cell.$1 + 0.5 + ox,
            y: cell.$2 + 0.5 + oy,
            hp: math.max(1, (templateHp * hpMult * threatScale).round()),
            attack: math.max(1, (templateAtk * atkMult * threatScale).round()),
            defense: glass ? 0 : templateDef,
            moveSpeed: glass ? 3.5 : 3.05,
            attackCooldown: glass ? 0.72 : 0.88,
            archetype: archetype,
            spritePath: KenneyAssets.enemySpriteForCodexName(name),
            chamberIndex: chamber,
            dormant: dormant,
          ),
        );
      }
    }
    return out;
  }

  /// Apply Hideout chest loot bonuses (stolen pouches).
  static List<LootDrop> enrichChestLoot(
    List<LootDrop> drops, {
    required math.Random rng,
    required int baseGold,
  }) {
    final next = <LootDrop>[];
    for (final d in drops) {
      if (d.name == 'Gold Pouch' && !d.isEquipment) {
        next.add(
          LootDrop(
            name: d.name,
            amount: math.max(d.amount, (d.amount * chestGoldMult).round()),
            rarity: d.rarity,
          ),
        );
      } else {
        next.add(d);
      }
    }
    if (rng.nextDouble() < stolenCoinChance) {
      final stolen = math.max(3, (baseGold * 0.35).round());
      next.add(
        LootDrop(
          name: 'Stolen Coin',
          amount: stolen,
          rarity: LootRarity.uncommon,
        ),
      );
    }
    return next;
  }
}
