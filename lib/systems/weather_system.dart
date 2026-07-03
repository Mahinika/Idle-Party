import 'dart:math';

class WeatherCondition {
  final String id;
  final String name;
  final double dpsMultiplier;
  final double defenseMultiplier;
  final String description;

  WeatherCondition({
    required this.id,
    required this.name,
    required this.dpsMultiplier,
    required this.defenseMultiplier,
    required this.description,
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    return WeatherCondition(
      id: json['id'] as String,
      name: json['name'] as String,
      dpsMultiplier: (json['dps_multiplier'] as num).toDouble(),
      defenseMultiplier: (json['defense_multiplier'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}

class WeatherSystem {
  final List<WeatherCondition> _conditions = [];
  WeatherCondition? _currentWeather;
  double _timeUntilChange = 0.0;
  final Random _random = Random();

  WeatherSystem();

  void loadConditions(List<dynamic> jsonData) {
    _conditions.clear();
    for (var item in jsonData) {
      _conditions.add(WeatherCondition.fromJson(item as Map<String, dynamic>));
    }
    if (_conditions.isNotEmpty) {
      _currentWeather = _conditions.first;
      _timeUntilChange = 60.0; // Change every 60s
    }
  }

  WeatherCondition? get currentWeather => _currentWeather;

  void update(double deltaTime) {
    if (_conditions.isEmpty) return;
    
    _timeUntilChange -= deltaTime;
    if (_timeUntilChange <= 0) {
      // Pick a random weather condition that is different from current if possible
      final oldWeather = _currentWeather;
      int retries = 0;
      do {
        _currentWeather = _conditions[_random.nextInt(_conditions.length)];
        retries++;
      } while (_conditions.length > 1 && 
               _currentWeather?.id == oldWeather?.id && 
               retries < 10);
      
      _timeUntilChange = 60.0;
    }
  }

  double get dpsMultiplier => _currentWeather?.dpsMultiplier ?? 1.0;
  double get defenseMultiplier => _currentWeather?.defenseMultiplier ?? 1.0;
}
