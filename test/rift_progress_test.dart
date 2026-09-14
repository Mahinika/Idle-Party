import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/rift_progress.dart';

void main() {
  test('kill weights: elite fills faster; farm lighter than GR', () {
    expect(RiftProgress.weightForKill(elite: false, farm: true), 1.0);
    expect(RiftProgress.weightForKill(elite: true, farm: true), 1.5);
    expect(RiftProgress.weightForKill(elite: true, farm: false), 1.75);
  });

  test('killTarget normals fill the bar to 1.0', () {
    const target = 20;
    var p = 0.0;
    for (var i = 0; i < target; i++) {
      p = RiftProgress.add(
        current: p,
        killTarget: target,
        normalKills: 1,
        farm: true,
      );
    }
    expect(p, 1.0);
  });

  test('add clamps at 1.0 and elite overshoots less of the bar', () {
    final afterElite = RiftProgress.add(
      current: 0.9,
      killTarget: 10,
      normalKills: 0,
      eliteKills: 1,
      farm: true,
    );
    expect(afterElite, 1.0);
    final mid = RiftProgress.add(
      current: 0,
      killTarget: 10,
      normalKills: 0,
      eliteKills: 1,
      farm: false,
    );
    expect(mid, closeTo(0.175, 0.0001));
  });

  test('paceLabel AHEAD / BEHIND vs expected linear progress', () {
    expect(
      RiftProgress.paceLabel(progress01: 0.5, timerMs: 25_000, parMs: 100_000),
      'AHEAD',
    );
    expect(
      RiftProgress.paceLabel(progress01: 0.1, timerMs: 50_000, parMs: 100_000),
      'BEHIND',
    );
    expect(
      RiftProgress.paceLabel(progress01: 0.5, timerMs: 0, parMs: 0),
      '',
    );
  });

  test('percentLabel rounds', () {
    expect(RiftProgress.percentLabel(0), '0%');
    expect(RiftProgress.percentLabel(0.505), '51%');
    expect(RiftProgress.percentLabel(1), '100%');
  });
}
