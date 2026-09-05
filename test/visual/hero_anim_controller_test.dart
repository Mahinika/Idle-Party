import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/visual/hero_anim_controller.dart';
import 'package:idle_party/visual/hero_anim_state.dart';

void main() {
  test('idle → walk → attack → idle', () {
    final c = HeroAnimController();
    var pose = c.tick(0.05, const HeroAnimSignals());
    expect(pose.kind, HeroAnimKind.idle);

    pose = c.tick(0.05, const HeroAnimSignals(moving: true));
    expect(pose.kind, HeroAnimKind.walk);

    pose = c.tick(0.02, const HeroAnimSignals(attackFlash: 0.2));
    expect(pose.kind, HeroAnimKind.attack);

    // Drain attack clip then return to idle.
    for (var i = 0; i < 20; i++) {
      pose = c.tick(0.05, const HeroAnimSignals());
    }
    expect(pose.kind, HeroAnimKind.idle);
  });

  test('death locks pose', () {
    final c = HeroAnimController();
    c.tick(0.01, const HeroAnimSignals(dead: true));
    final locked = c.tick(0.2, const HeroAnimSignals(moving: true, attacking: true));
    expect(locked.kind, HeroAnimKind.death);
    expect(locked.locked, isTrue);
    expect(c.locked, isTrue);
  });

  test('snapshot mirrors flash-driven attack', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(attackFlash: 0.15),
    );
    expect(pose.kind, HeroAnimKind.attack);
    expect(pose.frame, anyOf(0, 1));
  });

  test('priority: death beats attack', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(dead: true, attackFlash: 0.2),
    );
    expect(pose.kind, HeroAnimKind.death);
    expect(pose.locked, isTrue);
  });
}
