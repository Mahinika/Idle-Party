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
