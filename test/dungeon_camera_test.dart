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

  test('a long Sandy gap widens the view until the party and pack share it', () {
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
  });

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
