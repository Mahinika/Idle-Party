enum LootRarity { common, uncommon, rare, epic }

class LootDrop {
  const LootDrop({
    required this.name,
    required this.amount,
    required this.rarity,
  });

  final String name;
  final int amount;
  final LootRarity rarity;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'amount': amount,
    'rarity': rarity.name,
  };

  factory LootDrop.fromJson(Map<String, dynamic> json) {
    return LootDrop(
      name: json['name'] as String,
      amount: json['amount'] as int,
      rarity: LootRarity.values.byName(json['rarity'] as String),
    );
  }
}
