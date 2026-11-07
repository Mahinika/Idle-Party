import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/dungeon_camera.dart';

/// The pre-fix ease: a gap of 0.35 tiles or less snapped, and anything
/// between that and 10 tiles moved 12% of the gap per sample. A late frame
/// at high speed and 2× left the snap band, and the 12% catch could not
/// rejoin a hero who was still walking.
({double x, double y}) _legacyFrameEase({
  required double? prevX,
  required double? prevY,
  required double targetX,
  required double targetY,
}) {
  if (prevX == null || prevY == null) return (x: targetX, y: targetY);
  final dx = targetX - prevX;
  final dy = targetY - prevY;
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist <= 0.35 || dist >= 10) return (x: targetX, y: targetY);
  final step = dist * 0.12;
  return (x: prevX + dx / dist * step, y: prevY + dy / dist * step);
}

class _Follow {
  double? x;
  double? y;
  double? aimX;
  double? aimY;

  void sample(double tx, double ty, double dt, {required bool legacy}) {
    if (legacy) {
      final next = _legacyFrameEase(
        prevX: x,
        prevY: y,
        targetX: tx,
        targetY: ty,
      );
      x = next.x;
      y = next.y;
      return;
    }
    final next = dungeonCamEase(
      prevX: x,
      prevY: y,
      prevTargetX: aimX,
      prevTargetY: aimY,
      targetX: tx,
      targetY: ty,
      newWorld: false,
      dt: dt,
    );
    x = next.x;
    y = next.y;
    aimX = tx;
    aimY = ty;
  }
}

double _straightLag({
  required double speed,
  required int steps,
  required int samples,
  required bool legacy,
  int? hitchAt,
}) {
  final cam = _Follow();
  var hero = 0.0;
  for (var i = 0; i < samples; i++) {
    final n = steps + ((hitchAt != null && i == hitchAt) ? 1 : 0);
    hero += speed * n / 60;
    cam.sample(hero, 0, n / 60, legacy: legacy);
  }
  return hero - cam.x!;
}

void main() {
  test('camera origin keeps focus at viewport center without map clamp', () {
    final cam = dungeonCamOrigin(
      focusX: 4,
      focusY: 3,
      visibleCols: 20,
      visibleRows: 36,
    );
    expect(cam.camX, 4 - 10);
    expect(cam.camY, 3 - 18);
    expect(
      cam.camY,
      lessThan(0),
      reason: 'short floor: camera looks above y=0',
    );
  });

  test('party focus is centroid of living heroes', () {
    final f = dungeonPartyFocus(
      heroes: [
        (x: 2.0, y: 2.0, alive: true, index: 0),
        (x: 6.0, y: 4.0, alive: true, index: 1),
        (x: 99.0, y: 99.0, alive: false, index: 2),
      ],
      mapCenterX: 10,
      mapCenterY: 10,
      pinIndex: null,
    );
    expect(f.x, 4);
    expect(f.y, 3);
  });

  test('pinned hero stays at camera center', () {
    final heroes = [
      (x: 2.0, y: 2.0, alive: true, index: 0),
      (x: 6.0, y: 4.0, alive: true, index: 1),
      (x: 99.0, y: 99.0, alive: false, index: 2),
    ];
    final pinned = dungeonPartyFocus(
      heroes: heroes,
      mapCenterX: 10,
      mapCenterY: 10,
      pinIndex: 1,
    );
    expect(pinned.x, 6);
    expect(pinned.y, 4);
    final missing = dungeonPartyFocus(
      heroes: heroes,
      mapCenterX: 10,
      mapCenterY: 10,
      pinIndex: 9,
    );
    expect(missing.x, 4);
    expect(missing.y, 3);
  });

  test('far awake enemies do not pull the camera off the party', () {
    final heroes = [
      (x: 6.0, y: 28.0, alive: true, index: 0),
      (x: 7.0, y: 29.0, alive: true, index: 1),
    ];
    final focus = dungeonCombatFocus(
      heroes: heroes,
      awakeEnemies: [
        (x: 40.0, y: 8.0, alive: true),
        (x: 42.0, y: 10.0, alive: true),
      ],
      mapCenterX: 27,
      mapCenterY: 19,
      pinIndex: null,
    );
    expect(focus.x, closeTo(6.5, 0.01));
    expect(focus.y, closeTo(28.5, 0.01));
  });

  test(
    'cleared floor pulls north stairs under the HUD and keeps the party',
    () {
      final focus = dungeonStairsFocus(
        partyX: 20,
        partyY: 40,
        exitX: 22,
        exitY: 26,
        visibleCols: 20,
        visibleRows: 36,
      );
      final halfY = 18.0;
      expect(focus.y - 26, lessThanOrEqualTo(halfY - 8));
      expect(40 - focus.y, lessThanOrEqualTo(halfY - 6));
      expect(focus.y, lessThan(40));
    },
  );

  test('stairs stay in frame when the exit is farther than the phone', () {
    final focus = dungeonStairsFocus(
      partyX: 10,
      partyY: 50,
      exitX: 10,
      exitY: 4,
      visibleCols: 20,
      visibleRows: 36,
    );
    expect(focus.y - 4, lessThanOrEqualTo(18 - 8));
  });

  test('nearby pack nudges focus but stays within the shift cap', () {
    final focus = dungeonCombatFocus(
      heroes: [(x: 10.0, y: 10.0, alive: true, index: 0)],
      awakeEnemies: [
        (x: 18.0, y: 10.0, alive: true),
        (x: 50.0, y: 10.0, alive: true),
      ],
      mapCenterX: 27,
      mapCenterY: 19,
      pinIndex: null,
      packBias: 0.38,
      nearbyTiles: 9,
      maxShiftX: 2,
      maxShiftY: 2,
    );
    expect(focus.x, 12);
    expect(focus.y, 10);
  });

  test('ease snaps on a new floor and on a huge jump', () {
    final fresh = dungeonCamEase(
      prevX: 0,
      prevY: 0,
      targetX: 5,
      targetY: 4,
      newWorld: true,
    );
    expect(fresh.x, 5);
    expect(fresh.y, 4);
    final first = dungeonCamEase(
      prevX: null,
      prevY: null,
      targetX: 2,
      targetY: 3,
      newWorld: false,
    );
    expect(first.x, 2);
    expect(first.y, 3);
    final far = dungeonCamEase(
      prevX: 0,
      prevY: 0,
      targetX: 40,
      targetY: 0,
      newWorld: false,
    );
    expect(far.x, 40);
  });

  test('ease copies a one-step walk instead of lagging behind it', () {
    final eased = dungeonCamEase(
      prevX: 1,
      prevY: 1,
      prevTargetX: 1,
      prevTargetY: 1,
      targetX: 1.1,
      targetY: 1.05,
      newWorld: false,
      dt: dungeonCamSimStep,
    );
    expect(eased.x, closeTo(1.1, 1e-9));
    expect(eased.y, closeTo(1.05, 1e-9));
  });

  test('ease glides toward a pack shift, never past it, and arrives', () {
    var x = 0.0;
    var y = 0.0;
    for (var i = 0; i < 8; i++) {
      final eased = dungeonCamEase(
        prevX: x,
        prevY: y,
        targetX: 4,
        targetY: 0,
        newWorld: false,
      );
      expect(eased.x, lessThanOrEqualTo(4));
      expect(eased.x, greaterThan(x));
      x = eased.x;
      y = eased.y;
    }
    expect(x, greaterThan(1));
    expect(x, lessThan(4));
    for (var i = 0; i < 90; i++) {
      final eased = dungeonCamEase(
        prevX: x,
        prevY: y,
        targetX: 3,
        targetY: -2,
        newWorld: false,
      );
      x = eased.x;
      y = eased.y;
    }
    expect(x, closeTo(3, 0.01));
    expect(y, closeTo(-2, 0.01));
  });

  test('high speed at 1× and 2× stays with the hero', () {
    // Source simulation of the ease. Not a device capture.
    const speeds = [3.2, 8.0, 12.0];
    const paces = [1, 2];
    for (final speed in speeds) {
      for (final pace in paces) {
        final now = _straightLag(
          speed: speed,
          steps: pace,
          samples: 120,
          legacy: false,
        );
        expect(now.abs(), lessThan(1e-6), reason: 'speed $speed pace $pace');
      }
    }
    final legacyFast = _straightLag(
      speed: 12,
      steps: 2,
      samples: 120,
      legacy: true,
    );
    expect(legacyFast, greaterThan(2.5));
    final legacyOrdinary = _straightLag(
      speed: 3.2,
      steps: 1,
      samples: 120,
      legacy: true,
    );
    expect(legacyOrdinary.abs(), lessThan(1e-9));
  });

  test('a late frame at high speed and 2× does not leave a trail', () {
    final legacy = _straightLag(
      speed: 8,
      steps: 2,
      samples: 120,
      legacy: true,
      hitchAt: 30,
    );
    final now = _straightLag(
      speed: 8,
      steps: 2,
      samples: 120,
      legacy: false,
      hitchAt: 30,
    );
    expect(legacy, greaterThan(1.5));
    expect(now.abs(), lessThan(1e-6));
  });

  test('the same walk matches at 30 Hz and 60 Hz samples', () {
    const speed = 12.0;
    final fine = _Follow();
    final coarse = _Follow();
    final legacyFine = _Follow();
    final legacyCoarse = _Follow();
    var heroFine = 0.0;
    var heroCoarse = 0.0;
    for (var i = 0; i < 8; i++) {
      heroFine += speed / 60;
      fine.sample(heroFine, 0, 1 / 60, legacy: false);
      legacyFine.sample(heroFine, 0, 1 / 60, legacy: true);
      if (i.isOdd) {
        heroCoarse += speed / 30;
        coarse.sample(heroCoarse, 0, 1 / 30, legacy: false);
        legacyCoarse.sample(heroCoarse, 0, 1 / 30, legacy: true);
      }
    }
    expect(fine.x, closeTo(heroFine, 1e-6));
    expect(coarse.x, closeTo(heroCoarse, 1e-6));
    expect((fine.x! - coarse.x!).abs(), lessThan(1e-6));
    expect((legacyFine.x! - legacyCoarse.x!).abs(), greaterThan(0.5));
  });

  test('an abrupt reverse does not keep traveling the old way', () {
    double overshoot({required bool legacy}) {
      final cam = _Follow();
      var hero = 0.0;
      var dir = 1.0;
      double worst = 0;
      double? camAtTurn;
      for (var i = 0; i < 120; i++) {
        if (i == 60) {
          dir = -1;
          camAtTurn = cam.x;
        }
        hero += dir * 12 * 2 / 60;
        cam.sample(hero, 0, 2 / 60, legacy: legacy);
        worst = math.max(worst, (hero - cam.x!).abs());
        if (i >= 60 && camAtTurn != null) {
          worst = math.max(worst, cam.x! - camAtTurn);
        }
      }
      return worst;
    }

    expect(overshoot(legacy: true), greaterThan(2));
    expect(overshoot(legacy: false), lessThan(0.05));
  });

  test('stopping does not snap the last third of a tile', () {
    List<double> jumps({required bool legacy}) {
      final cam = _Follow();
      var hero = 0.0;
      for (var i = 0; i < 90; i++) {
        hero += 12 * 2 / 60;
        cam.sample(hero, 0, 2 / 60, legacy: legacy);
      }
      final out = <double>[];
      for (var i = 0; i < 24; i++) {
        final prev = cam.x!;
        cam.sample(hero, 0, 2 / 60, legacy: legacy);
        out.add((cam.x! - prev).abs());
      }
      return out;
    }

    final before = jumps(legacy: true);
    final grew = [
      for (var i = 1; i < before.length; i++) before[i] > before[i - 1] * 1.8,
    ].any((grew) => grew);
    expect(before.reduce(math.max), greaterThan(0.3));
    expect(grew, isTrue);
    final after = jumps(legacy: false);
    expect(after.reduce(math.max), lessThan(0.02));
  });

  test('a pin switch, death, and respawn glide without passing the hero', () {
    final heroes = [
      (x: 4.0, y: 8.0, alive: true, index: 0),
      (x: 6.5, y: 8.0, alive: true, index: 1),
    ];
    final pinned = dungeonPartyFocus(
      heroes: heroes,
      mapCenterX: 10,
      mapCenterY: 10,
      pinIndex: 0,
    );
    expect(pinned.x, 4);
    final corpseStillPinned = dungeonPartyFocus(
      heroes: [
        (x: 4.0, y: 8.0, alive: false, index: 0),
        (x: 6.5, y: 8.0, alive: true, index: 1),
      ],
      mapCenterX: 10,
      mapCenterY: 10,
      pinIndex: 0,
    );
    expect(corpseStillPinned.x, 4, reason: 'a chosen hero stays the aim');
    final living = dungeonPartyFocus(
      heroes: [
        (x: 4.0, y: 8.0, alive: false, index: 0),
        (x: 6.5, y: 8.0, alive: true, index: 1),
      ],
      mapCenterX: 10,
      mapCenterY: 10,
      pinIndex: null,
    );
    expect(living.x, 6.5);

    void glide({
      required double from,
      required double to,
      required double speed,
    }) {
      final now = _Follow()
        ..x = from
        ..y = 0
        ..aimX = from
        ..aimY = 0;
      final legacy = _Follow()
        ..x = from
        ..y = 0;
      var focus = to;
      for (var i = 0; i < 8; i++) {
        focus += speed / 60;
        now.sample(focus, 0, 1 / 60, legacy: false);
        legacy.sample(focus, 0, 1 / 60, legacy: true);
        final lo = math.min(from, focus);
        final hi = math.max(from, focus);
        expect(now.x!, inInclusiveRange(lo - 1e-6, hi + 1e-6));
      }
      final nowGap = (focus - now.x!).abs();
      final legacyGap = (focus - legacy.x!).abs();
      expect(nowGap, lessThan(0.75));
      expect(legacyGap, greaterThan(nowGap + 0.35));
    }

    glide(from: 4, to: 6.5, speed: 3.2);
    glide(from: 6.5, to: 4, speed: -3.2);
    glide(from: 6.5, to: 4, speed: 0);
  });

  test('a new floor still snaps, and a paused sample holds', () {
    final fresh = dungeonCamEase(
      prevX: 0,
      prevY: 0,
      prevTargetX: 0,
      prevTargetY: 0,
      targetX: 30,
      targetY: 4,
      newWorld: true,
      dt: 2 / 60,
    );
    expect(fresh.x, 30);
    expect(fresh.y, 4);
    final held = dungeonCamEase(
      prevX: 2,
      prevY: 3,
      prevTargetX: 2,
      prevTargetY: 3,
      targetX: 5,
      targetY: 5,
      newWorld: false,
      dt: 0,
    );
    expect(held.x, 2);
    expect(held.y, 3);
  });

  test('2× shake samples do not strobe, and one punch is not doubled', () {
    int reversals(List<double> samples) {
      final delta = [
        for (var i = 0; i < samples.length - 1; i++)
          samples[i + 1] - samples[i],
      ];
      var flips = 0;
      for (var i = 0; i < delta.length - 1; i++) {
        if (delta[i] * delta[i + 1] < 0) flips++;
      }
      return flips;
    }

    final frames = [for (var f = 0; f < 60; f += 2) f];
    final legacy = [for (final f in frames) math.sin(f * 1.7) * 0.3];
    final now = [
      for (final f in frames)
        dungeonCamShake(x: 0, y: 0, shakeAmp: 0.3, visualFrame: f).x,
    ];
    expect(reversals(legacy), greaterThan(20));
    expect(reversals(now), lessThan(14));
    expect(now.map((v) => v.abs()).reduce(math.max), closeTo(0.3, 0.05));

    const frame = 10;
    final once = dungeonCamShakeOffset(shakeAmp: 0.3, visualFrame: frame);
    final origin = dungeonCamOrigin(
      focusX: 0,
      focusY: 0,
      visibleCols: 0,
      visibleRows: 0,
      shakeAmp: 0.3,
      visualFrame: frame,
    );
    final stacked = dungeonCamShake(
      x: origin.camX,
      y: origin.camY,
      shakeAmp: 0.3,
      visualFrame: frame,
    );
    expect(origin.camX, closeTo(once.x, 1e-9));
    expect(stacked.x, closeTo(once.x * 2, 1e-9));
  });

  test('a goal under the party card is not in the clear view', () {
    expect(
      dungeonPackInClearView(
        partyX: 50,
        partyY: 8,
        packX: 52,
        packY: 18,
        visibleCols: 20,
        visibleRows: 36,
      ),
      isFalse,
    );
    expect(
      dungeonPackInClearView(
        partyX: 50,
        partyY: 8,
        packX: 52,
        packY: 12,
        visibleCols: 20,
        visibleRows: 36,
      ),
      isTrue,
    );
  });

  test('a pack that fits shares the frame and does not steal the gate', () {
    expect(
      dungeonSharesFrame(
        partyX: 10,
        partyY: 20,
        packX: 12,
        packY: 28,
        visibleCols: 20,
        visibleRows: 32,
      ),
      isTrue,
    );
    expect(
      dungeonGateFocus(
        partyX: 10,
        partyY: 20,
        packX: 12,
        packY: 28,
        closedGates: [(x: 11, y: 24)],
        visibleCols: 20,
        visibleRows: 32,
      ),
      isNull,
    );
  });

  test('when the pack does not fit the closed gate stays in frame', () {
    final focus = dungeonGateFocus(
      partyX: 10,
      partyY: 40,
      packX: 10,
      packY: 8,
      closedGates: [(x: 10, y: 24)],
      visibleCols: 20,
      visibleRows: 22,
    );
    expect(focus, isNotNull);
    final halfY = 11.0;
    expect(focus!.y - 24, lessThanOrEqualTo(halfY - 8));
    expect(focus.y, lessThan(40));
  });

  test('an east pack keeps the gate between them', () {
    final focus = dungeonGateFocus(
      partyX: 52,
      partyY: 9,
      packX: 34,
      packY: 8,
      closedGates: [(x: 51, y: 16), (x: 44, y: 9)],
      visibleCols: 20,
      visibleRows: 28,
    );
    expect(focus, isNotNull);
    expect((focus!.x - 44).abs(), lessThanOrEqualTo(10));
    expect((focus.y - 9).abs(), lessThanOrEqualTo(8));
  });

  test('a far pack with no gate on the hall still enters the frame', () {
    final focus = dungeonNextFocus(
      partyX: 50,
      partyY: 10,
      packX: 50,
      packY: 40,
      closedGates: [(x: 12, y: 12)],
      visibleCols: 20,
      visibleRows: 28,
    );
    final halfY = 14.0;
    expect((40 - focus.y).abs(), lessThanOrEqualTo(halfY - 6));
  });

  test(
    'a long Sandy gap widens the view until the party and pack share it',
    () {
      final cols = dungeonFitCols(
        partyX: 51,
        partyY: 7,
        goalX: 52,
        goalY: 37,
        viewWidth: 360,
        viewHeight: 780,
        targetCols: 20,
        topInsetPx: 100,
        bottomInsetPx: 200,
      );
      expect(cols, greaterThan(20));
      expect(cols, lessThanOrEqualTo(36));
      final tile = 360 / cols;
      final rows = 780 / tile;
      final top = 100 / tile + 1.2;
      final bottom = 200 / tile + 1.2;
      expect((7 - 37).abs() + top + bottom, lessThanOrEqualTo(rows + 0.2));
    },
  );

  test('a short phone keeps the hero above the party card', () {
    const rows = 640 / 18;
    final framed = dungeonIncludeParty(
      focusX: 10,
      focusY: 40,
      heroes: [(x: 10, y: 22)],
      visibleCols: 20,
      visibleRows: rows,
      marginTop: 7,
      marginBottom: 14,
    );
    final halfY = rows / 2;
    final screen = 22 - framed.y + halfY;
    expect(screen, greaterThanOrEqualTo(7));
    expect(screen, lessThanOrEqualTo(rows - 14));
  });

  test('a hero at the edge is pulled back inside the phone', () {
    final framed = dungeonIncludeParty(
      focusX: 10,
      focusY: 8,
      heroes: [(x: 10, y: 20)],
      visibleCols: 20,
      visibleRows: 22,
    );
    final halfY = 11.0;
    expect(20 - framed.y, lessThanOrEqualTo(halfY - 4.5));
  });
}
