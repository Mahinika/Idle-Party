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
}
