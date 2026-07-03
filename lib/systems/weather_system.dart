import '../core/dps_pipeline.dart';

/// Represents a loaded weather condition from JSON.
class WeatherCondition {
  final String id;
  final String name;
  final double dpsMult;       // multiplier added to 'weather' pipeline category
  final double rewardMult;
  final double duration;      // seconds this condition lasts

  const WeatherCondition({
    required this.id,
    required this.name,
    required this.dpsMult,
    required this.rewardMult,
    required this.duration,
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) =>
      WeatherCondition(
        id: json['id'] as String,
        name: json['name'] as String,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
        rewardMult: (json['rewardMult'] as num?)?.toDouble() ?? 1.0,
        duration: (json['duration'] as num?)?.toDouble() ?? 60.0,
      );
}

/// WeatherSystem manages the active weather condition and its pipeline effect.
///
/// Update order: step 1.
class WeatherSystem {
  final List<WeatherCondition> _conditions = [];
  WeatherCondition? _active;
  double _elapsed = 0.0;

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _conditions
      ..clear()
      ..addAll(data.map(WeatherCondition.fromJson));
    if (_conditions.isNotEmpty) _active = _conditions.first;
  }

  WeatherCondition? get activeCondition => _active;

  void update(double deltaTime, DpsPipeline pipeline) {
    // Clear previous weather contribution.
    pipeline.clearCategory('weather');

    if (_active == null) return;

    _elapsed += deltaTime;
    if (_elapsed >= _active!.duration) {
      _elapsed = 0.0;
      _cycleWeather();
    }

    if (_active != null) {
      pipeline.addMultiplier('weather', _active!.dpsMult);
    }
  }

  void _cycleWeather() {
    if (_conditions.isEmpty) {
      _active = null;
      return;
    }
    final idx = _active != null ? _conditions.indexOf(_active!) : -1;
    // If not found (idx == -1), start from index 0; otherwise advance.
    final nextIdx = (idx + 1) % _conditions.length;
    _active = _conditions[nextIdx];
  }

  /// Force a specific weather condition (useful for events/testing).
  void setWeather(String id) {
    _active = _conditions.firstWhere(
      (c) => c.id == id,
      orElse: () => _active ?? _conditions.first,
    );
    _elapsed = 0.0;
  }
}
