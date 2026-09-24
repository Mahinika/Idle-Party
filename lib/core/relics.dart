import 'relic_ids.dart';

/// What a relic does. One effect per relic.
enum RelicEffect {
  bossDamage,
  lowHpDr,
  stairHeal,
  godHandCd,
  lootFind,
  mitigate,
  treasureGold,
  offlineGold,
  bossEssence,
  moveSpeed,
  flaskHeal,
  manaRegen,
}

class RelicDef {
  const RelicDef({
    required this.id,
    required this.name,
    required this.blurb,
    required this.effect,
    required this.perTier,
  });

  final String id;
  final String name;
  final String blurb;
  final RelicEffect effect;

  /// Flat amount added per owned tier (percent points, or a small integer).
  final int perTier;

  String payoutAt(int tier) {
    final n = perTier * tier;
    return switch (effect) {
      RelicEffect.bossDamage => '+$n% boss damage',
      RelicEffect.lowHpDr => '-$n% damage under 40% HP',
      RelicEffect.stairHeal => '+$n% HP at the stairs',
      RelicEffect.godHandCd => '-${(n / 100).toStringAsFixed(2)}s God Hand',
      RelicEffect.lootFind => '+$n% loot',
      RelicEffect.mitigate => '+$n mitigate',
      RelicEffect.treasureGold => '+$n% treasure gold',
      RelicEffect.offlineGold => '+$n% offline gold',
      RelicEffect.bossEssence => '+$n essence on boss',
      RelicEffect.moveSpeed => '+$n% walk',
      RelicEffect.flaskHeal => '+$n% flask',
      RelicEffect.manaRegen => '+$n mana / s',
    };
  }
}

/// Fixed discover order. Old ids stay so saves keep their tier.
abstract final class RelicCatalog {
  static const int maxTier = 6;

  static const List<RelicDef> all = <RelicDef>[
    RelicDef(
      id: RelicIds.warBanner,
      name: 'Crownbreaker',
      blurb: 'The party hits bosses harder.',
      effect: RelicEffect.bossDamage,
      perTier: 4,
    ),
    RelicDef(
      id: RelicIds.ironWard,
      name: 'Cracked Aegis',
      blurb: 'Heroes under 40% HP take less damage.',
      effect: RelicEffect.lowHpDr,
      perTier: 4,
    ),
    RelicDef(
      id: RelicIds.phoenixEmber,
      name: 'Hearth at the Stairs',
      blurb: 'The party heals when the stairs open.',
      effect: RelicEffect.stairHeal,
      perTier: 4,
    ),
    RelicDef(
      id: RelicIds.godHandFocus,
      name: 'Short Prayer',
      blurb: 'God Hand comes back sooner.',
      effect: RelicEffect.godHandCd,
      perTier: 4,
    ),
    RelicDef(
      id: RelicIds.chamberLuck,
      name: "Finder's Knot",
      blurb: 'More gear from kills and chests.',
      effect: RelicEffect.lootFind,
      perTier: 5,
    ),
    RelicDef(
      id: RelicIds.ironWill,
      name: 'Stone Stomach',
      blurb: 'A flat bite taken off every hit.',
      effect: RelicEffect.mitigate,
      perTier: 8,
    ),
    RelicDef(
      id: RelicIds.hoardJar,
      name: 'Hoard Jar',
      blurb: 'Treasure rooms pay more gold.',
      effect: RelicEffect.treasureGold,
      perTier: 8,
    ),
    RelicDef(
      id: RelicIds.porchLantern,
      name: 'Porch Lantern',
      blurb: 'More gold while you are away.',
      effect: RelicEffect.offlineGold,
      perTier: 6,
    ),
    RelicDef(
      id: RelicIds.ashTithe,
      name: 'Ash Tithe',
      blurb: 'Boss clears pay extra essence.',
      effect: RelicEffect.bossEssence,
      perTier: 1,
    ),
    RelicDef(
      id: RelicIds.dustyBoots,
      name: 'Dusty Boots',
      blurb: 'The party walks faster.',
      effect: RelicEffect.moveSpeed,
      perTier: 3,
    ),
    RelicDef(
      id: RelicIds.deepSip,
      name: 'Deep Sip',
      blurb: 'The flask heals more.',
      effect: RelicEffect.flaskHeal,
      perTier: 8,
    ),
    RelicDef(
      id: RelicIds.secondBreath,
      name: 'Second Breath',
      blurb: 'Casters gain mana over time.',
      effect: RelicEffect.manaRegen,
      perTier: 1,
    ),
  ];

  static RelicDef? byId(String id) {
    for (final def in all) {
      if (def.id == id) return def;
    }
    return null;
  }

  static int discoverCost(int ownedCount) => 8 + ownedCount * 6;

  static int tierCost(int nextTier) => 4 + nextTier * 3;

  /// Embers spent to own [tier] (discover slot [index] plus upgrades).
  static int embersSpent(int index, int tier) {
    var sum = discoverCost(index);
    for (var t = 2; t <= tier; t++) {
      sum += tierCost(t);
    }
    return sum;
  }
}
