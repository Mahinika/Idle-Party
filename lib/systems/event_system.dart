import '../core/dps_pipeline.dart';

/// A game event loaded from JSON.
class GameEvent {
  final String id;
  final String name;
  final double dpsMult;
  final double rewardMult;
  final double cooldown;   // minimum seconds between activations

  const GameEvent({
    required this.id,
    required this.name,
    required this.dpsMult,
    required this.rewardMult,
    required this.cooldown,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
        rewardMult: (json['rewardMult'] as num?)?.toDouble() ?? 1.0,
        cooldown: (json['cooldown'] as num?)?.toDouble() ?? 300.0,
      );
}

/// EventSystem manages timed/triggered game events and their pipeline effects.
///
/// Update order: step 2.
class EventSystem {
  final List<GameEvent> _events = [];
  final Map<String, double> _cooldownTimers = {};
  final List<GameEvent> _activeEvents = [];

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _events
      ..clear()
      ..addAll(data.map(GameEvent.fromJson));
  }

  void update(double deltaTime, DpsPipeline pipeline) {
    pipeline.clearCategory('event');

    // Advance cooldowns.
    for (final id in _cooldownTimers.keys.toList()) {
      final remaining = (_cooldownTimers[id]! - deltaTime);
      if (remaining <= 0) {
        _cooldownTimers.remove(id);
      } else {
        _cooldownTimers[id] = remaining;
      }
    }

    for (final event in _activeEvents) {
      pipeline.addMultiplier('event', event.dpsMult);
    }
  }

  /// Trigger an event by id; ignored if on cooldown.
  bool triggerEvent(String eventId) {
    if (_cooldownTimers.containsKey(eventId)) return false;
    final event = _events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => throw ArgumentError('Unknown event: $eventId'),
    );
    _activeEvents.add(event);
    _cooldownTimers[eventId] = event.cooldown;
    return true;
  }

  void clearEvent(String eventId) =>
      _activeEvents.removeWhere((e) => e.id == eventId);

  List<GameEvent> get activeEvents => List.unmodifiable(_activeEvents);
}
