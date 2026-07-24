enum LootRarity { common, uncommon, rare, epic }

enum EquipmentSlot { weapon, armor }

enum LootOutcome { essence, equipped, replaced, stashed }

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    required this.attackBonus,
    required this.defenseBonus,
    required this.vitalityBonus,
  });

  final String id;
  final String name;
  final EquipmentSlot slot;
  final LootRarity rarity;
  final int attackBonus;
  final int defenseBonus;
  final int vitalityBonus;

  /// Higher score wins auto-equip comparisons.
  int get powerScore =>
      (attackBonus * 3) + (defenseBonus * 2) + vitalityBonus;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'slot': slot.name,
    'rarity': rarity.name,
    'attackBonus': attackBonus,
    'defenseBonus': defenseBonus,
    'vitalityBonus': vitalityBonus,
  };

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      slot: EquipmentSlot.values.byName(json['slot'] as String),
      rarity: LootRarity.values.byName(json['rarity'] as String),
      attackBonus: json['attackBonus'] as int,
      defenseBonus: json['defenseBonus'] as int,
      vitalityBonus: json['vitalityBonus'] as int,
    );
  }
}

class LootDrop {
  const LootDrop({
    required this.name,
    required this.amount,
    required this.rarity,
    this.equipment,
    this.outcome = LootOutcome.essence,
    this.essenceGained = 0,
  });

  final String name;
  final int amount;
  final LootRarity rarity;

  /// When set, this drop is gear rather than a pure currency token.
  final EquipmentItem? equipment;
  final LootOutcome outcome;
  final int essenceGained;

  bool get isEquipment => equipment != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'amount': amount,
    'rarity': rarity.name,
    if (equipment != null) 'equipment': equipment!.toJson(),
    'outcome': outcome.name,
    'essenceGained': essenceGained,
  };

  factory LootDrop.fromJson(Map<String, dynamic> json) {
    final equipmentJson = json['equipment'] as Map<String, dynamic>?;
    final outcomeRaw = json['outcome'] as String?;
    return LootDrop(
      name: json['name'] as String,
      amount: json['amount'] as int,
      rarity: LootRarity.values.byName(json['rarity'] as String),
      equipment: equipmentJson == null
          ? null
          : EquipmentItem.fromJson(equipmentJson),
      outcome: outcomeRaw == null
          ? LootOutcome.essence
          : LootOutcome.values.byName(outcomeRaw),
      essenceGained: (json['essenceGained'] as int?) ?? 0,
    );
  }

  LootDrop copyWith({
    String? name,
    int? amount,
    LootRarity? rarity,
    EquipmentItem? equipment,
    LootOutcome? outcome,
    int? essenceGained,
  }) {
    return LootDrop(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      rarity: rarity ?? this.rarity,
      equipment: equipment ?? this.equipment,
      outcome: outcome ?? this.outcome,
      essenceGained: essenceGained ?? this.essenceGained,
    );
  }
}
