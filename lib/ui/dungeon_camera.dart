import 'dart:math' as math;

/// One live sim step. Matches [GameDirector]'s dungeon clock.
const double dungeonCamSimStep = 1 / 60;

/// Seconds to bleed a leftover aim error. Constant-speed travel does not use
/// this: the camera takes the focus step itself, so lag does not grow with
/// move speed or with 2× pace.
const double dungeonCamFollowTau = 0.05;

/// Seconds to glide a real retarget (pin, death, pack bias) of a tile or more.
const double dungeonCamRetargetTau = 0.09;

/// Shake in sim time, about 4.5 Hz and 6 Hz. Indexing the sine by the raw
/// frame made a 2× pace sample jump ~195° and strobe.
const double dungeonCamShakeOmega = 28;
const double dungeonCamShakeOmegaY = 38;

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
  final punch = dungeonCamShakeOffset(
    shakeAmp: shakeAmp,
    visualFrame: visualFrame,
  );
  camX += punch.x;
  camY += punch.y;
  return (camX: camX, camY: camY);
}

/// Glide the camera toward [targetX]/[targetY].
///
/// A new floor or a jump of [snapDistance] snaps. Anything smaller keeps the
/// focus step when the aim only walked, and glides when the aim itself jumped
/// by [retargetDistance] (another hero, a death, a pack bias). The old slack
/// snap followed tiny steps exactly, then a single late frame at high speed
/// and 2× dropped the camera into a 12% catch it could not leave while the
/// party was still moving. This never passes the target.
({double x, double y}) dungeonCamEase({
  required double? prevX,
  required double? prevY,
  double? prevTargetX,
  double? prevTargetY,
  required double targetX,
  required double targetY,
  required bool newWorld,
  double dt = dungeonCamSimStep,
  double snapDistance = 10,
  double retargetDistance = 1,
  double followTau = dungeonCamFollowTau,
  double retargetTau = dungeonCamRetargetTau,
}) {
  if (newWorld || prevX == null || prevY == null) {
    return (x: targetX, y: targetY);
  }
  if (dt <= 0) return (x: prevX, y: prevY);
  final gx = targetX - prevX;
  final gy = targetY - prevY;
  final gap = math.sqrt(gx * gx + gy * gy);
  if (gap >= snapDistance || gap == 0) {
    return (x: targetX, y: targetY);
  }
  final aimX = prevTargetX;
  final aimY = prevTargetY;
  final hasAim = aimX != null && aimY != null;
  final motion = hasAim
      ? math.sqrt(math.pow(targetX - aimX, 2) + math.pow(targetY - aimY, 2))
      : 0.0;
  final retarget =
      gap >= retargetDistance || (hasAim && motion >= retargetDistance);
  if (!hasAim || retarget) {
    final tau = math.max(0.001, retarget ? retargetTau : followTau);
    final alpha = (1 - math.exp(-dt / tau)).clamp(0.0, 1.0);
    return (x: prevX + gx * alpha, y: prevY + gy * alpha);
  }
  final keep = (1 - math.exp(-dt / math.max(0.001, followTau))).clamp(0.0, 1.0);
  final errX = aimX - prevX;
  final errY = aimY - prevY;
  return (x: targetX - errX * (1 - keep), y: targetY - errY * (1 - keep));
}

/// Punch offset in tiles. [visualFrame] is a sim-step counter, so the phase
/// advances in sim seconds and a 2× sample does not alias.
({double x, double y}) dungeonCamShakeOffset({
  required double shakeAmp,
  required int visualFrame,
}) {
  if (shakeAmp <= 0.02) return (x: 0, y: 0);
  final t = visualFrame * dungeonCamSimStep;
  return (
    x: math.sin(t * dungeonCamShakeOmega) * shakeAmp,
    y: math.cos(t * dungeonCamShakeOmegaY) * shakeAmp * 0.85,
  );
}

/// Punch applied after the eased camera, so a glide is not shaken early.
///
/// The live view calls this once. [dungeonCamOrigin] can add the same offset
/// when a caller passes [shakeAmp]; do not stack both on one frame.
({double x, double y}) dungeonCamShake({
  required double x,
  required double y,
  required double shakeAmp,
  required int visualFrame,
}) {
  final punch = dungeonCamShakeOffset(
    shakeAmp: shakeAmp,
    visualFrame: visualFrame,
  );
  return (x: x + punch.x, y: y + punch.y);
}

({double x, double y}) dungeonPartyFocus({
  required Iterable<({double x, double y, bool alive, int index})> heroes,
  required double mapCenterX,
  required double mapCenterY,
  int? pinIndex,
}) {
  if (pinIndex != null) {
    for (final h in heroes) {
      if (h.index == pinIndex && h.alive) return (x: h.x, y: h.y);
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
  final shiftX = ((cx - party.x) * bias).clamp(
    -maxShiftX.abs(),
    maxShiftX.abs(),
  );
  final shiftY = ((cy - party.y) * bias).clamp(
    -maxShiftY.abs(),
    maxShiftY.abs(),
  );
  return (x: party.x + shiftX, y: party.y + shiftY);
}

/// Live aim. An in-frame fight stays on the party.
///
/// The old in-frame branch sat halfway between the party and the single
/// nearest living enemy. A death, or two foes trading which one is nearer,
/// moved that point to the other side of the party and the view snapped
/// with it. The pack is already on screen in that case, so the party
/// (or the pinned hero) is the aim. A foe that does not fit still uses the
/// gate, then the capped pack nudge. The exit and a chest with no fight
/// still use the stairs framing.
({double x, double y}) dungeonLiveFocus({
  required bool awaitingExit,
  required bool inFight,
  required bool goalInClearView,
  required double partyX,
  required double partyY,
  required double? goalX,
  required double? goalY,
  required double exitX,
  required double exitY,
  required ({double x, double y})? gateFocus,
  required Iterable<({double x, double y, bool alive, int index})> heroes,
  required Iterable<({double x, double y, bool alive})> awakeEnemies,
  required double mapCenterX,
  required double mapCenterY,
  int? pinIndex,
  required double visibleCols,
  required double visibleRows,
  double marginTop = 4.5,
  double marginBottom = 4.5,
  double nearbyTiles = 9,
  double maxShiftX = 3.5,
  double maxShiftY = 3.5,
}) {
  if (awaitingExit) {
    return dungeonStairsFocus(
      partyX: partyX,
      partyY: partyY,
      exitX: exitX,
      exitY: exitY,
      visibleCols: visibleCols,
      visibleRows: visibleRows,
    );
  }
  if (inFight) {
    if (goalInClearView) {
      return dungeonPartyFocus(
        heroes: heroes,
        mapCenterX: mapCenterX,
        mapCenterY: mapCenterY,
        pinIndex: pinIndex,
      );
    }
    return gateFocus ??
        dungeonCombatFocus(
          heroes: heroes,
          awakeEnemies: awakeEnemies,
          mapCenterX: mapCenterX,
          mapCenterY: mapCenterY,
          pinIndex: pinIndex,
          nearbyTiles: nearbyTiles,
          maxShiftX: maxShiftX,
          maxShiftY: maxShiftY,
        );
  }
  if (goalInClearView && goalX != null && goalY != null) {
    return dungeonStairsFocus(
      partyX: partyX,
      partyY: partyY,
      exitX: goalX,
      exitY: goalY,
      visibleCols: visibleCols,
      visibleRows: visibleRows,
      topInset: marginTop,
      bottomInset: marginBottom,
    );
  }
  return gateFocus ?? (x: partyX, y: partyY);
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

/// Columns so the party and a goal can share one portrait phone.
///
/// Stays on [targetCols] when that view already clears the HUD. Widens
/// toward [maxCols] when the gap is longer than the screen. Does not
/// shrink a pinch-in.
double dungeonFitCols({
  required double partyX,
  required double partyY,
  required double goalX,
  required double goalY,
  required double viewWidth,
  required double viewHeight,
  required double targetCols,
  double topInsetPx = 0,
  double bottomInsetPx = 0,
  double maxCols = 36,
}) {
  if (viewWidth <= 1 || viewHeight <= 1) return targetCols;
  final start = targetCols.clamp(12.0, maxCols);
  bool fits(double cols) {
    final tile = viewWidth / cols;
    if (tile <= 0) return false;
    final rows = viewHeight / tile;
    final top = topInsetPx <= 0 ? 5.0 : topInsetPx / tile + 1.2;
    final bottom = bottomInsetPx <= 0 ? 6.0 : bottomInsetPx / tile + 1.2;
    final needY = (partyY - goalY).abs() + top + bottom;
    final needX = (partyX - goalX).abs() + 4;
    return needY <= rows && needX <= cols;
  }

  if (fits(start)) return start;
  var cols = start;
  while (cols + 2 <= maxCols) {
    cols += 2;
    if (fits(cols)) return cols;
  }
  return maxCols.clamp(12.0, maxCols);
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

/// Keeps an in-frame fight on the party when one death leaves the next
/// survivor a couple of tiles outside the card. A pack that is actually
/// off the phone still falls through so the gate can take the aim.
bool dungeonGoalHoldsClear({
  required bool wasClear,
  required double partyX,
  required double partyY,
  required double packX,
  required double packY,
  required double visibleCols,
  required double visibleRows,
  double cardRows = 12,
  double marginX = 2,
  double topMargin = 5,
  double slackTiles = 3,
}) {
  if (dungeonPackInClearView(
    partyX: partyX,
    partyY: partyY,
    packX: packX,
    packY: packY,
    visibleCols: visibleCols,
    visibleRows: visibleRows,
    cardRows: cardRows,
    marginX: marginX,
    topMargin: topMargin,
  )) {
    return true;
  }
  if (!wasClear || slackTiles <= 0) return false;
  return dungeonPackInClearView(
    partyX: partyX,
    partyY: partyY,
    packX: packX,
    packY: packY,
    visibleCols: visibleCols,
    visibleRows: visibleRows,
    cardRows: math.max(0, cardRows - slackTiles),
    marginX: math.max(0, marginX - 0.75),
    topMargin: math.max(0, topMargin - slackTiles),
  );
}

/// The pack or chest sits in the picture above the party card.
///
/// [dungeonSharesFrame] still answers "could one tall view hold both".
/// The card covers the bottom of the stage, so a goal ten tiles south of
/// the party can pass that test and still be hidden.
bool dungeonPackInClearView({
  required double partyX,
  required double partyY,
  required double packX,
  required double packY,
  required double visibleCols,
  required double visibleRows,
  double cardRows = 12,
  double marginX = 2,
  double topMargin = 5,
}) {
  final halfX = math.max(1.0, visibleCols / 2 - marginX);
  if ((packX - partyX).abs() > halfX) return false;
  final dy = packY - partyY;
  if (dy >= 0) {
    final south = math.max(2.0, visibleRows / 2 - cardRows);
    return dy <= south;
  }
  final north = math.max(2.0, visibleRows / 2 - topMargin);
  return -dy <= north;
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
  bool onlyWhenApart = true,
}) {
  if (onlyWhenApart &&
      dungeonSharesFrame(
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
  double bottomInset = 18,
  bool onlyWhenApart = true,
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
        onlyWhenApart: onlyWhenApart,
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
  double? marginTop,
  double? marginBottom,
}) {
  var x = focusX;
  var y = focusY;
  final halfX = math.max(1.0, visibleCols / 2);
  final halfY = math.max(1.0, visibleRows / 2);
  final top = marginTop ?? marginY;
  final bottom = marginBottom ?? marginY;
  for (final h in heroes) {
    final loX = h.x - halfX + marginX;
    final hiX = h.x + halfX - marginX;
    if (loX <= hiX) x = x.clamp(loX, hiX);
    // loY keeps the hero above the bottom card. hiY keeps it under the top HUD.
    final loY = h.y - halfY + bottom;
    final hiY = h.y + halfY - top;
    if (loY <= hiY) {
      y = y.clamp(loY, hiY);
    } else {
      y = loY;
    }
  }
  return (x: x, y: y);
}
