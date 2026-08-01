/// A saved gear preset: per-hero equipped slot → item id.
///
/// When [heroIds] is non-empty, index `i` maps to the roster hero with that
/// id (preferred). Otherwise [heroSlotItemIds] index `i` corresponds to
/// `state.heroes[i]` (legacy party-index layout).
/// Each entry maps `EquipmentSlot.name` → `EquipmentItem.id`.
class GearLoadout {
  const GearLoadout({
    required this.id,
    required this.name,
    required this.heroSlotItemIds,
    this.heroIds = const <String>[],
  });

  final String id;
  final String name;
  final List<Map<String, String>> heroSlotItemIds;

  /// Parallel to [heroSlotItemIds]; empty on pre-roster saves.
  final List<String> heroIds;

  GearLoadout copyWith({
    String? id,
    String? name,
    List<Map<String, String>>? heroSlotItemIds,
    List<String>? heroIds,
  }) {
    return GearLoadout(
      id: id ?? this.id,
      name: name ?? this.name,
      heroSlotItemIds: heroSlotItemIds ?? this.heroSlotItemIds,
      heroIds: heroIds ?? this.heroIds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'heroSlotItemIds': heroSlotItemIds
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
        'heroIds': heroIds,
      };

  factory GearLoadout.fromJson(Map<String, dynamic> json) {
    final raw = json['heroSlotItemIds'] as List<dynamic>? ?? const [];
    final idsRaw = json['heroIds'] as List<dynamic>?;
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
      heroIds: idsRaw?.map((e) => e.toString()).toList() ?? const <String>[],
    );
  }
}
