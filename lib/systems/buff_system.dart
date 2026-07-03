import '../managers/buff_manager.dart';

/// BuffSystem owns the lifecycle of buffs each tick.
///
/// It delegates storage and stacking rules to BuffManager.
/// Update order: step 4.
class BuffSystem {
  final BuffManager buffManager;

  BuffSystem({required this.buffManager});

  /// Advance all buff timers; expired buffs are removed by the manager.
  void update(double deltaTime) {
    buffManager.tick(deltaTime);
  }

  /// Apply a buff via the manager; convenience wrapper.
  void applyBuff(String targetId, BuffInstance buff) {
    buffManager.apply(targetId, buff);
  }
}
