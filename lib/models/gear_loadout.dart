/// A saved gear preset: per-hero equipped slot → item id.
///
/// [heroSlotItemIds] index `i` corresponds to `state.heroes[i]`; each entry
/// maps `EquipmentSlot.name` → `EquipmentItem.id` for whatever was equipped
/// on that hero when the loadout was saved.
class GearLoadout {
  const GearLoadout({
    required this.id,
    required this.name,
    required this.heroSlotItemIds,
  });

  final String id;
  final String name;
  final List<Map<String, String>> heroSlotItemIds;

  GearLoadout copyWith({
    String? id,
    String? name,
    List<Map<String, String>>? heroSlotItemIds,
  }) {
    return GearLoadout(
      id: id ?? this.id,
      name: name ?? this.name,
      heroSlotItemIds: heroSlotItemIds ?? this.heroSlotItemIds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'heroSlotItemIds': heroSlotItemIds
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
      };

  factory GearLoadout.fromJson(Map<String, dynamic> json) {
    final raw = json['heroSlotItemIds'] as List<dynamic>? ?? const [];
    return GearLoadout(
      id: json['id'] as String,
      name: json['name'] as String,
      heroSlotItemIds: raw
          .map(
            (entry) => (entry as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          )
          .toList(),
    );
  }
}
