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

/// Glide the camera toward [targetX]/[targetY].
///
/// A walk (gap at most [followSlack]) snaps, so the party does not lag.
/// A pack waking up is a medium jump and eases in. A new floor or a huge
/// jump snaps. The step is always a fraction of the remaining gap, so the
/// camera never passes the target.
({double x, double y}) dungeonCamEase({
  required double? prevX,
  required double? prevY,
  required double targetX,
  required double targetY,
  required bool newWorld,
  double followSlack = 0.35,
  double snapDistance = 10,
  double catchFraction = 0.12,
}) {
  if (newWorld || prevX == null || prevY == null) {
    return (x: targetX, y: targetY);
  }
  final dx = targetX - prevX;
  final dy = targetY - prevY;
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist <= followSlack || dist >= snapDistance) {
    return (x: targetX, y: targetY);
  }
  final step = dist * catchFraction.clamp(0.01, 0.95);
  return (x: prevX + dx / dist * step, y: prevY + dy / dist * step);
}

/// Punch applied after the eased camera, so a glide is not shaken early.
({double x, double y}) dungeonCamShake({
  required double x,
  required double y,
  required double shakeAmp,
  required int visualFrame,
}) {
  if (shakeAmp <= 0.02) return (x: x, y: y);
  return (
    x: x + math.sin(visualFrame * 1.7) * shakeAmp,
    y: y + math.cos(visualFrame * 2.3) * shakeAmp * 0.85,
  );
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

/// Pull the cleared floor toward the stairs so the exit sits under the HUD.
///
/// The party stays in the same clear area. If the gap is longer than the
/// phone, the stairs stay in frame and the party sits on the near edge.
({double x, double y}) dungeonStairsFocus({
  required double partyX,
  required double partyY,
  required double exitX,
  required double exitY,
  required double visibleCols,
  required double visibleRows,
  double topInset = 8,
  double bottomInset = 6,
  double sideInset = 2,
}) {
  double axis({
    required double party,
    required double exit,
    required double half,
    required double insetTowardExit,
    required double insetTowardParty,
  }) {
    final towardExit = (half - insetTowardExit).clamp(1.0, half);
    final towardParty = (half - insetTowardParty).clamp(1.0, half);
    if (exit <= party) {
      final maxFocus = exit + towardExit;
      final minFocus = party - towardParty;
      if (minFocus <= maxFocus) {
        return ((party + exit) / 2).clamp(minFocus, maxFocus);
      }
      return maxFocus;
    }
    final minFocus = exit - towardExit;
    final maxFocus = party + towardParty;
    if (minFocus <= maxFocus) {
      return ((party + exit) / 2).clamp(minFocus, maxFocus);
    }
    return minFocus;
  }

  final halfX = math.max(1.0, visibleCols / 2);
  final halfY = math.max(1.0, visibleRows / 2);
  final stairsNorth = exitY <= partyY;
  return (
    x: axis(
      party: partyX,
      exit: exitX,
      half: halfX,
      insetTowardExit: sideInset,
      insetTowardParty: sideInset,
    ),
    y: axis(
      party: partyY,
      exit: exitY,
      half: halfY,
      insetTowardExit: stairsNorth ? topInset : bottomInset,
      insetTowardParty: stairsNorth ? bottomInset : topInset,
    ),
  );
}

/// Party and pack can share one phone view, with room for sprites and HUD.
bool dungeonSharesFrame({
  required double partyX,
  required double partyY,
  required double packX,
  required double packY,
  required double visibleCols,
  required double visibleRows,
  double marginX = 2,
  double marginY = 5,
}) {
  final spanX = math.max(0.0, visibleCols - marginX * 2);
  final spanY = math.max(0.0, visibleRows - marginY * 2);
  return (partyX - packX).abs() <= spanX && (partyY - packY).abs() <= spanY;
}

bool _spans(double a, double b, double p, double pad) {
  final lo = math.min(a, b) - pad;
  final hi = math.max(a, b) + pad;
  return p >= lo && p <= hi;
}

/// When the party and the next pack cannot share the phone, keep the closed
/// gate in frame. Returns null when they already fit, or no gate sits between
/// them. Room size is not part of this: the hall stays, the gate wins.
({double x, double y})? dungeonGateFocus({
  required double partyX,
  required double partyY,
  required double packX,
  required double packY,
  required Iterable<({double x, double y})> closedGates,
  required double visibleCols,
  required double visibleRows,
  double bottomInset = 6,
}) {
  if (dungeonSharesFrame(
    partyX: partyX,
    partyY: partyY,
    packX: packX,
    packY: packY,
    visibleCols: visibleCols,
    visibleRows: visibleRows,
  )) {
    return null;
  }
  ({double x, double y})? best;
  var bestScore = double.infinity;
  for (final g in closedGates) {
    // The long axis must cross the gate. The short axis stays inside the
    // hall, so a closer gate on another leg does not steal the frame.
    final vertical = (packY - partyY).abs() >= (packX - partyX).abs();
    final onPath = vertical
        ? _spans(partyY, packY, g.y, 1.5) &&
              (g.x - partyX).abs() <= 6 &&
              (g.x - packX).abs() <= 6
        : _spans(partyX, packX, g.x, 1.5) &&
              (g.y - partyY).abs() <= 6 &&
              (g.y - packY).abs() <= 6;
    if (!onPath) continue;
    final dx = g.x - partyX;
    final dy = g.y - partyY;
    final score = dx * dx + dy * dy;
    if (score < bestScore) {
      bestScore = score;
      best = (x: g.x, y: g.y);
    }
  }
  if (best == null) return null;
  return dungeonStairsFocus(
    partyX: partyX,
    partyY: partyY,
    exitX: best.x,
    exitY: best.y,
    visibleCols: visibleCols,
    visibleRows: visibleRows,
    bottomInset: bottomInset,
  );
}

/// Closed gate when one sits between them. Otherwise the pack, so a new
/// floor does not open on an empty hall.
({double x, double y}) dungeonNextFocus({
  required double partyX,
  required double partyY,
  required double packX,
  required double packY,
  required Iterable<({double x, double y})> closedGates,
  required double visibleCols,
  required double visibleRows,
  double bottomInset = 9,
}) {
  return dungeonGateFocus(
        partyX: partyX,
        partyY: partyY,
        packX: packX,
        packY: packY,
        closedGates: closedGates,
        visibleCols: visibleCols,
        visibleRows: visibleRows,
        bottomInset: bottomInset,
      ) ??
      dungeonStairsFocus(
        partyX: partyX,
        partyY: partyY,
        exitX: packX,
        exitY: packY,
        visibleCols: visibleCols,
        visibleRows: visibleRows,
        bottomInset: bottomInset,
      );
}

/// Pull focus so each hero's sprite stays inside the phone, clear of the HUD.
({double x, double y}) dungeonIncludeParty({
  required double focusX,
  required double focusY,
  required Iterable<({double x, double y})> heroes,
  required double visibleCols,
  required double visibleRows,
  double marginX = 2.2,
  double marginY = 4.5,
}) {
  var x = focusX;
  var y = focusY;
  final halfX = math.max(1.0, visibleCols / 2);
  final halfY = math.max(1.0, visibleRows / 2);
  for (final h in heroes) {
    final loX = h.x - halfX + marginX;
    final hiX = h.x + halfX - marginX;
    if (loX <= hiX) x = x.clamp(loX, hiX);
    final loY = h.y - halfY + marginY;
    final hiY = h.y + halfY - marginY;
    if (loY <= hiY) y = y.clamp(loY, hiY);
  }
  return (x: x, y: y);
}
