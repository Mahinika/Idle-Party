import '../managers/debuff_manager.dart';

/// DebuffSystem owns the lifecycle of debuffs each tick.
///
/// Update order: step 5.
class DebuffSystem {
  final DebuffManager debuffManager;

  DebuffSystem({required this.debuffManager});

  void update(double deltaTime) {
    debuffManager.tick(deltaTime);
  }

  void applyDebuff(String targetId, DebuffInstance debuff) {
    debuffManager.apply(targetId, debuff);
  }
}
