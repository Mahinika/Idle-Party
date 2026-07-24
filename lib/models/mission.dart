enum MissionType { defeatEnemies, clearBosses, earnGold }

class Mission {
  const Mission({
    required this.id,
    required this.type,
    required this.title,
    required this.target,
    required this.progress,
    required this.goldReward,
    required this.essenceReward,
  });

  final String id;
  final MissionType type;
  final String title;
  final int target;
  final int progress;
  final int goldReward;
  final int essenceReward;

  bool get isComplete => progress >= target;

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
  }) {
    return Mission(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      goldReward: goldReward ?? this.goldReward,
      essenceReward: essenceReward ?? this.essenceReward,
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
  };

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      type: MissionType.values.byName(json['type'] as String),
      title: json['title'] as String,
      target: json['target'] as int,
      progress: json['progress'] as int,
      goldReward: json['goldReward'] as int,
      essenceReward: json['essenceReward'] as int,
    );
  }
}
