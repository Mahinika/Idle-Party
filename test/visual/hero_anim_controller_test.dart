import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/visual/hero_anim_controller.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/rig/rig_sampler.dart';

void main() {
  test('idle when nothing is happening', () {
    final pose = HeroAnimController.snapshot(const HeroAnimSignals());
    expect(pose.kind, HeroAnimKind.idle);
    expect(pose.locked, isFalse);
  });

  test('walk phase only steps forward', () {
    final a = HeroAnimController.walkPhase(40, offset: 0.2);
    final b = HeroAnimController.walkPhase(41, offset: 0.2);
    final step = (b - a + 1) % 1;
    expect(step, closeTo(HeroAnimController.walkCyclesPerFrame, 0.0001));
    expect(
      HeroAnimController.walkPhase(10, offset: 0.1),
      isNot(HeroAnimController.walkPhase(10, offset: 0.5)),
    );
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
    expect(pose.progress, 0, reason: 'the fall starts on the first paint');
    final mid = HeroAnimController.snapshot(
      const HeroAnimSignals(dead: true, deathProgress: 0.4),
    );
    expect(mid.frame, 0);
    final down = HeroAnimController.snapshot(
      const HeroAnimSignals(dead: true, deathProgress: 0.8),
    );
    expect(down.frame, 1);
  });

  test('a named pose plays through while the hero is still moving', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(
        moving: true,
        abilityName: 'mortalStrike',
        poseTime: 0.2,
        poseHold: 0.8,
      ),
    );
    expect(pose.kind, HeroAnimKind.attack);
    expect(pose.abilityName, 'mortalStrike');
    expect(pose.progress, closeTo(0.25, 0.02));
  });

  test('a finished pose lets the walk return', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(
        moving: true,
        abilityName: 'mortalStrike',
        poseTime: 0.8,
        poseHold: 0.8,
      ),
      walkPhase: 0.2,
    );
    expect(pose.kind, HeroAnimKind.walk);
  });

  test('a hit still beats a named pose', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(
        hit: true,
        abilityName: 'mortalStrike',
        poseTime: 0.2,
        poseHold: 0.8,
      ),
    );
    expect(pose.kind, HeroAnimKind.hit);
  });

  test('priority: hit beats attack and walk', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(moving: true, attackFlash: 0.2, hitFlash: 0.1),
    );
    expect(pose.kind, HeroAnimKind.hit);
  });

  test('pose time stays put across a flinch', () {
    final before = HeroAnimController.snapshot(
      const HeroAnimSignals(
        abilityName: 'mortalStrike',
        poseTime: 0.2,
        poseHold: 0.8,
      ),
    );
    final during = HeroAnimController.snapshot(
      const HeroAnimSignals(
        abilityName: 'mortalStrike',
        poseTime: 0.34,
        poseHold: 0.8,
      ),
      flinchPause: 0.14,
    );
    expect(before.progress, closeTo(0.25, 0.02));
    expect(during.progress, closeTo(before.progress, 0.02));
  });

  test('2× walks the feet twice as far per paint', () {
    final slow = HeroAnimController.walkPhase(40, pace: 1);
    final fast = HeroAnimController.walkPhase(40, pace: 2);
    expect(fast, closeTo((slow * 2) % 1, 0.0001));
  });

  test('the hit clip is a flinch, not the walk', () {
    final pose = HeroAnimController.snapshot(
      const HeroAnimSignals(hit: true, hitFlash: 0.12),
    );
    final sample = RigSampler.sample(pose);
    expect(sample.clip, 'hit');
    expect(sample.pose.angles['torso'] ?? 0, isNot(0));
    expect((sample.pose.angles['thigh_l'] ?? 0).abs(), lessThan(8));
  });
}
