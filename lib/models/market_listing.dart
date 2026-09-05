import 'loot.dart';

/// One gear row on POWER → MARKET (refreshes over time; kept on Ascend).
class MarketListing {
  const MarketListing({
    required this.id,
    required this.item,
    required this.priceGold,
    required this.targetHeroIndex,
    required this.slot,
  });

  final String id;
  final EquipmentItem item;
  final int priceGold;

  /// -1 = filler listing; otherwise gap-targeted for that party index.
  final int targetHeroIndex;
  final EquipmentSlot slot;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'item': item.toJson(),
    'priceGold': priceGold,
    'targetHeroIndex': targetHeroIndex,
    'slot': slot.name,
  };

  factory MarketListing.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    return MarketListing(
      id: (json['id'] ?? '').toString(),
      item: EquipmentItem.fromJson(json['item'] as Map<String, dynamic>),
      priceGold: asInt(json['priceGold']),
      targetHeroIndex: asInt(json['targetHeroIndex'], -1),
      slot: EquipmentSlot.values.byName((json['slot'] ?? 'head').toString()),
    );
  }
}
