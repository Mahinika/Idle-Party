import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/dungeon_camera.dart';

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
    expect(cam.camY, lessThan(0), reason: 'short floor: camera looks above y=0');
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

  test('nearby pack nudges focus but stays within the shift cap', () {
    final focus = dungeonCombatFocus(
      heroes: [
        (x: 10.0, y: 10.0, alive: true, index: 0),
      ],
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

  test('ease follows a walk without lag', () {
    final eased = dungeonCamEase(
      prevX: 1,
      prevY: 1,
      targetX: 1.1,
      targetY: 1.05,
      newWorld: false,
    );
    expect(eased.x, 1.1);
    expect(eased.y, 1.05);
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
}
