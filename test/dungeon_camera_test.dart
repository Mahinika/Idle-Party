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
        (x: 2, y: 2, alive: true),
        (x: 6, y: 4, alive: true),
        (x: 99, y: 99, alive: false),
      ],
      mapCenterX: 10,
      mapCenterY: 10,
    );
    expect(f.x, 4);
    expect(f.y, 3);
  });
}
