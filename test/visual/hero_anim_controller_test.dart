import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/visual/hero_anim_controller.dart';
import 'package:idle_party/visual/hero_anim_state.dart';

void main() {
  test('idle when nothing is happening', () {
    final pose = HeroAnimController.snapshot(const HeroAnimSignals());
    expect(pose.kind, HeroAnimKind.idle);
    expect(pose.locked, isFalse);
  });

  test('moving walks and cycles frames with the phase', () {
    final early = HeroAnimController.snapshot(
      const HeroAnimSignals(moving: true),
      walkPhase: 0.1,
    );
    final late = HeroAnimController.snapshot(
      const HeroAnimSignals(moving: true),
      walkPhase: 0.8,
    );
    expect(early.kind, HeroAnimKind.walk);
    expect(late.kind, HeroAnimKind.walk);
    expect(early.frame, isNot(late.frame));
    expect(early.progress, isNot(late.progress));
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

  test('priority: hit beats attack and walk', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(moving: true, attackFlash: 0.2, hitFlash: 0.1),
    );
    expect(pose.kind, HeroAnimKind.hit);
  });
}
