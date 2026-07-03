import 'dart:math';

class GameEvent {
  final String id;
  final String name;
  final double goldMultiplier;
  final double xpMultiplier;
  final double duration;
  final String description;

  GameEvent({
    required this.id,
    required this.name,
    required this.goldMultiplier,
    required this.xpMultiplier,
    required this.duration,
    required this.description,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      goldMultiplier: (json['gold_multiplier'] as num).toDouble(),
      xpMultiplier: (json['xp_multiplier'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}

class EventSystem {
  final List<GameEvent> _events = [];
  GameEvent? _activeEvent;
  double _remainingDuration = 0.0;
  final Random _random = Random();

  EventSystem();

  void loadEvents(List<dynamic> jsonData) {
    _events.clear();
    for (var item in jsonData) {
      _events.add(GameEvent.fromJson(item as Map<String, dynamic>));
    }
    // Set standard/default event first
    _activeEvent = _events.firstWhere((e) => e.id == 'event_none', orElse: () => _events.first);
    _remainingDuration = _activeEvent?.duration ?? 3600.0;
  }

  GameEvent? get activeEvent => _activeEvent;
  double get remainingDuration => _remainingDuration;

  void triggerEvent(String eventId) {
    final ev = _events.firstWhere((e) => e.id == eventId, orElse: () => _events.first);
    _activeEvent = ev;
    _remainingDuration = ev.duration;
  }

  void update(double deltaTime) {
    if (_activeEvent == null || _events.isEmpty) return;

    _remainingDuration -= deltaTime;
    if (_remainingDuration <= 0) {
      if (_activeEvent?.id != 'event_none') {
        // Return to standard day
        triggerEvent('event_none');
      } else {
        // Trigger a random active event (not event_none)
        final nonNoneEvents = _events.where((e) => e.id != 'event_none').toList();
        if (nonNoneEvents.isNotEmpty) {
          final chosen = nonNoneEvents[_random.nextInt(nonNoneEvents.length)];
          triggerEvent(chosen.id);
        } else {
          _remainingDuration = 3600.0;
        }
      }
    }
  }

  double get goldMultiplier => _activeEvent?.goldMultiplier ?? 1.0;
  double get xpMultiplier => _activeEvent?.xpMultiplier ?? 1.0;
}
