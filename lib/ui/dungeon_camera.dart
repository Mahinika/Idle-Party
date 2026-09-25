import 'dart:math' as math;

/// Viewport origin in tile space so the focus stays at screen center.
///
/// Does **not** clamp to the map — short floors used to pin camY at 0 and the
/// party walked up/down the phone instead of the camera following.
({double camX, double camY}) dungeonCamOrigin({
  required double focusX,
  required double focusY,
  required double visibleCols,
  required double visibleRows,
  double shakeAmp = 0,
  int visualFrame = 0,
}) {
  var camX = focusX - visibleCols / 2;
  var camY = focusY - visibleRows / 2;
  if (shakeAmp > 0.02) {
    camX += math.sin(visualFrame * 1.7) * shakeAmp;
    camY += math.cos(visualFrame * 2.3) * shakeAmp * 0.85;
  }
  return (camX: camX, camY: camY);
}

({double x, double y}) dungeonPartyFocus({
  required Iterable<({double x, double y, bool alive, int index})> heroes,
  required double mapCenterX,
  required double mapCenterY,
  int? pinIndex,
}) {
  if (pinIndex != null) {
    for (final h in heroes) {
      if (h.index == pinIndex) return (x: h.x, y: h.y);
    }
  }
  final living = heroes.where((h) => h.alive).toList();
  final pack = living.isNotEmpty ? living : heroes.toList();
  if (pack.isEmpty) {
    return (x: mapCenterX, y: mapCenterY);
  }
  var sx = 0.0;
  var sy = 0.0;
  for (final h in pack) {
    sx += h.x;
    sy += h.y;
  }
  return (x: sx / pack.length, y: sy / pack.length);
}

/// Nudge party focus toward the nearby fight so threats share the frame.
///
/// Only enemies within [nearbyTiles] count. A floor-wide centroid (next
/// chamber, far elites) used to park the camera on empty tiles and shove
/// the party into the phone corner. [maxShiftX]/[maxShiftY] keep the pin
/// on screen even when the local pack sits at the edge of that radius.
({double x, double y}) dungeonCombatFocus({
  required Iterable<({double x, double y, bool alive, int index})> heroes,
  required Iterable<({double x, double y, bool alive})> awakeEnemies,
  required double mapCenterX,
  required double mapCenterY,
  int? pinIndex,
  double packBias = 0.38,
  double nearbyTiles = 9,
  double maxShiftX = 3.5,
  double maxShiftY = 3.5,
}) {
  final party = dungeonPartyFocus(
    heroes: heroes,
    mapCenterX: mapCenterX,
    mapCenterY: mapCenterY,
    pinIndex: pinIndex,
  );
  final living = awakeEnemies.where((e) => e.alive).toList();
  if (living.isEmpty || packBias <= 0) return party;
  final reach = nearbyTiles <= 0 ? 0.0 : nearbyTiles;
  final reach2 = reach * reach;
  var ex = 0.0;
  var ey = 0.0;
  var n = 0;
  for (final e in living) {
    final dx = e.x - party.x;
    final dy = e.y - party.y;
    if (dx * dx + dy * dy > reach2) continue;
    ex += e.x;
    ey += e.y;
    n++;
  }
  if (n == 0) return party;
  final cx = ex / n;
  final cy = ey / n;
  final bias = packBias.clamp(0.0, 0.55);
  final shiftX = ((cx - party.x) * bias).clamp(-maxShiftX.abs(), maxShiftX.abs());
  final shiftY = ((cy - party.y) * bias).clamp(-maxShiftY.abs(), maxShiftY.abs());
  return (x: party.x + shiftX, y: party.y + shiftY);
}
