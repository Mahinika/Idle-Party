import 'dart:math';

/// Carved footprint shape for one chamber (docs/FLOOR_BLUEPRINT.md).
enum RoomSilhouette { rect, oval, diamond, el, plus, chamfer, blob }

/// Integer room rect in tile space.
class RoomRect {
  RoomRect(this.x, this.y, this.w, this.h);
  final int x, y, w, h;
  int get cx => x + w ~/ 2;
  int get cy => y + h ~/ 2;

  bool overlaps(RoomRect o, {int pad = 1}) {
    return x - pad < o.x + o.w &&
        x + w + pad > o.x &&
        y - pad < o.y + o.h &&
        y + h + pad > o.y;
  }
}

abstract final class RoomSilhouettes {
  /// Symmetric shapes read as "built on purpose" (shrine, throne, arena).
  static const List<RoomSilhouette> symmetric = [
    RoomSilhouette.oval,
    RoomSilhouette.diamond,
    RoomSilhouette.chamfer,
    RoomSilhouette.plus,
  ];

  static bool contains(
    RoomRect r,
    int x,
    int y,
    RoomSilhouette silhouette,
    int salt,
  ) {
    final lx = x - r.x;
    final ly = y - r.y;
    if (lx < 0 || ly < 0 || lx >= r.w || ly >= r.h) return false;
    final mx = r.w ~/ 2;
    final my = r.h ~/ 2;
    if ((lx - mx).abs() <= 1 && (ly - my).abs() <= 1) return true;
    final dx = lx - (r.w - 1) / 2.0;
    final dy = ly - (r.h - 1) / 2.0;
    switch (silhouette) {
      case RoomSilhouette.rect:
        return true;
      case RoomSilhouette.oval:
        final rx = max(1.2, r.w / 2.0 - 0.15);
        final ry = max(1.2, r.h / 2.0 - 0.15);
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.06;
      case RoomSilhouette.diamond:
        final nx = dx.abs() / max(1.0, r.w / 2.0);
        final ny = dy.abs() / max(1.0, r.h / 2.0);
        return nx + ny <= 1.12;
      case RoomSilhouette.el:
        final thickW = max(3, r.w ~/ 2);
        final thickH = max(3, r.h ~/ 2);
        if (salt.isOdd) {
          return lx < thickW || ly < thickH;
        }
        return lx >= r.w - thickW || ly >= r.h - thickH;
      case RoomSilhouette.plus:
        final armW = max(3, r.w ~/ 3);
        final armH = max(3, r.h ~/ 3);
        return dx.abs() <= armW / 2 || dy.abs() <= armH / 2;
      case RoomSilhouette.chamfer:
        final cut = max(2, min(r.w, r.h) ~/ 4);
        final fromL = lx;
        final fromR = r.w - 1 - lx;
        final fromT = ly;
        final fromB = r.h - 1 - ly;
        if (fromL + fromT < cut) return false;
        if (fromR + fromT < cut) return false;
        if (fromL + fromB < cut) return false;
        if (fromR + fromB < cut) return false;
        return true;
      case RoomSilhouette.blob:
        final rx = max(1.2, r.w / 2.0);
        final ry = max(1.2, r.h / 2.0);
        final ang = atan2(dy, dx);
        final wobble =
            0.14 * sin(ang * 3 + salt) + 0.08 * cos(ang * 5 + salt * 0.37);
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 0.92 + wobble;
    }
  }

  /// Carve [r] with [silhouette] through [setFloor].
  static void carve(
    RoomRect r,
    void Function(int x, int y) setFloor,
    RoomSilhouette silhouette,
    Random rng,
  ) {
    final salt = rng.nextInt(64);
    for (var yy = r.y; yy < r.y + r.h; yy++) {
      for (var xx = r.x; xx < r.x + r.w; xx++) {
        if (contains(r, xx, yy, silhouette, salt)) setFloor(xx, yy);
      }
    }
    setFloor(r.cx, r.cy);
    if (silhouette == RoomSilhouette.blob || silhouette == RoomSilhouette.oval) {
      final nubs = 1 + rng.nextInt(3);
      for (var i = 0; i < nubs; i++) {
        final nx = r.x + rng.nextInt(max(1, r.w));
        final ny = r.y + rng.nextInt(max(1, r.h));
        if ((nx - r.cx).abs() + (ny - r.cy).abs() <= max(r.w, r.h) ~/ 2 + 1) {
          setFloor(nx, ny);
          setFloor(nx + (rng.nextBool() ? 1 : 0), ny);
        }
      }
    }
  }
}
