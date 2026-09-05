enum MissionType {
  defeatEnemies,
  clearBosses,
  earnGold,
  clearFloors,
  defeatElites,
}

class Mission {
  const Mission({
    required this.id,
    required this.type,
    required this.title,
    required this.target,
    required this.progress,
    required this.goldReward,
    required this.essenceReward,
    this.tier = 0,
    this.claimed = false,
  });

  final String id;
  final MissionType type;
  final String title;
  final int target;
  final int progress;
  final int goldReward;
  final int essenceReward;

  /// 0 normal · 1 hard · 2 brutal (affects targets + rewards).
  final int tier;

  /// True after claim when the slot should not pay out again (Daily).
  final bool claimed;

  bool get isComplete => progress >= target;

  /// Ready to claim on the board (complete and not already claimed).
  bool get canClaim => isComplete && !claimed;

  double get progressFraction =>
      target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  Mission copyWith({
    String? id,
    MissionType? type,
    String? title,
    int? target,
    int? progress,
    int? goldReward,
    int? essenceReward,
    int? tier,
    bool? claimed,
  }) {
    return Mission(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      goldReward: goldReward ?? this.goldReward,
      essenceReward: essenceReward ?? this.essenceReward,
      tier: tier ?? this.tier,
      claimed: claimed ?? this.claimed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'title': title,
    'target': target,
    'progress': progress,
    'goldReward': goldReward,
    'essenceReward': essenceReward,
    'tier': tier,
    'claimed': claimed,
  };

  factory Mission.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    final typeName = json['type'] as String? ?? MissionType.defeatEnemies.name;
    final type = MissionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => MissionType.defeatEnemies,
    );

    return Mission(
      id: json['id'] as String? ?? type.name,
      type: type,
      title: json['title'] as String? ?? type.name,
      target: asInt(json['target'], 1),
      progress: asInt(json['progress']),
      goldReward: asInt(json['goldReward']),
      essenceReward: asInt(json['essenceReward']),
      tier: asInt(json['tier']).clamp(0, 2),
      claimed: json['claimed'] as bool? ?? false,
    );
  }
}
