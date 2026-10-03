import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'rig_data.dart';

/// One cut piece of a 128 image, packed into an atlas.
class RigPiece {
  const RigPiece({
    required this.part,
    required this.rect,
    required this.pivotX,
    required this.pivotY,
  });

  final String part;
  final ui.Rect rect;
  final double pivotX;
  final double pivotY;
}

class RigAtlas {
  const RigAtlas({required this.image, required this.pieces});

  final ui.Image image;
  final List<RigPiece> pieces;
}

/// Splits a 128 overlay by the family part map. Keyed by path, family, and crop.
abstract final class RigPartCache {
  static final Map<String, RigAtlas> _ready = {};

  /// Weapon images after the haft is joined. The still doll reads these too.
  static final Map<String, ui.Image> prepared = {};
  static final Map<String, Future<RigAtlas>> _pending = {};

  static String key(String path, String family, double cropTop, double cropBottom) =>
      '$family|$cropTop|$cropBottom|$path';

  static RigAtlas? peek(String cacheKey) => _ready[cacheKey];

  static Future<RigAtlas> cut({
    required ui.Image image,
    required RigData rig,
    required String cacheKey,
    double cropTop = 0,
    double cropBottom = 1,
    bool seal = false,
  }) {
    final hit = _ready[cacheKey];
    if (hit != null) return Future.value(hit);
    return _pending.putIfAbsent(cacheKey, () async {
      final source = seal ? await solidImage(image) : image;
      final atlas = await _build(source, rig, cacheKey, cropTop, cropBottom);
      _ready[cacheKey] = atlas;
      _pending.remove(cacheKey);
      return atlas;
    });
  }

  /// Hands stay on the arm, and a helm stays on the head. The body map
  /// underneath does not change. A chest collar stays on the head: moving
  /// it to the torso draws it under the face and hides the neckline.
  static String claimFor(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    if (name.startsWith('hands_')) return 'hands';
    if (name.startsWith('helm_')) return 'helm';
    return '';
  }

  static const armParts = {
    'upper_l',
    'upper_r',
    'fore_l',
    'fore_r',
    'hand_l',
    'hand_r',
  };

  /// Which bone draws the pixel at [index] for this picture.
  static String? partAt({
    required RigData rig,
    required List<String?> body,
    required List<String?> nearestArm,
    required int index,
    required String claim,
  }) {
    final owned = index >= 0 && index < body.length ? body[index] : null;
    if (claim == 'helm' && rig.bones.containsKey('head')) return 'head';
    if (claim == 'hands') {
      if (owned != null && armParts.contains(owned)) return owned;
      final arm = index >= 0 && index < nearestArm.length ? nearestArm[index] : null;
      return arm ?? owned;
    }
    return owned;
  }

  static List<String?> bodyParts(RigData rig) {
    final body = List<String?>.filled(RigData.canvas * RigData.canvas, null);
    for (final part in rig.drawOrder) {
      final mask = rig.masks[part];
      if (mask == null) continue;
      for (var i = 0; i < mask.length && i < body.length; i++) {
        if (mask[i] != 0 && body[i] == null) body[i] = part;
      }
    }
    return body;
  }

  /// Nearest upper arm, forearm, or hand, so a gauntlet pixel on the chest
  /// still bends with that arm.
  static List<String?> nearestArms(RigData rig) {
    final canvas = RigData.canvas;
    final owner = List<String?>.filled(canvas * canvas, null);
    final queue = <int>[];
    for (final part in armParts) {
      final mask = rig.masks[part];
      if (mask == null) continue;
      for (var i = 0; i < mask.length && i < owner.length; i++) {
        if (mask[i] == 0 || owner[i] != null) continue;
        owner[i] = part;
        queue.add(i);
      }
    }
    var head = 0;
    while (head < queue.length) {
      final i = queue[head++];
      final part = owner[i];
      if (part == null) continue;
      final x = i % canvas;
      final y = i ~/ canvas;
      for (final step in const [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ]) {
        final nx = x + step[0];
        final ny = y + step[1];
        if (nx < 0 || ny < 0 || nx >= canvas || ny >= canvas) continue;
        final j = ny * canvas + nx;
        if (owner[j] != null) continue;
        owner[j] = part;
        queue.add(j);
      }
    }
    return owner;
  }

  /// A one-pixel hole in the plate fills in.
  ///
  /// Returns [image] when nothing changed. A face window stays open: a clear
  /// pixel is filled only when three neighbors on the cross are already solid.
  static Future<ui.Image> solidImage(
    ui.Image image, {
    bool thicken = false,
    bool join = false,
  }) async {
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) return image;
    final bytes = Uint8List.fromList(raw.buffer.asUint8List());
    final sealed = sealBytes(bytes, image.width, image.height);
    final grown = thicken && thickenLines(bytes, image.width, image.height);
    final joined = join && joinGaps(bytes, image.width, image.height);
    if (!sealed && !grown && !joined) return image;
    return _image(bytes, image.width, image.height);
  }

  /// Joins two parts of one sprite when only a step or two of empty pixels
  /// sits between them. A blade and its haft that miss by a diagonal read
  /// as a broken weapon. A wider opening stays open.
  static bool joinGaps(Uint8List bytes, int width, int height) {
    final count = width * height;
    final owner = List<int>.filled(count, -1);
    final parts = <List<int>>[];
    for (var i = 0; i < count; i++) {
      if (owner[i] != -1 || bytes[i * 4 + 3] < 128) continue;
      final id = parts.length;
      final cells = <int>[i];
      owner[i] = id;
      var cursor = 0;
      while (cursor < cells.length) {
        final here = cells[cursor++];
        final x = here % width;
        final y = here ~/ width;
        for (final step in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = x + step.$1;
          final ny = y + step.$2;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final next = ny * width + nx;
          if (owner[next] != -1 || bytes[next * 4 + 3] < 128) continue;
          owner[next] = id;
          cells.add(next);
        }
      }
      if (cells.length >= 8) parts.add(cells);
    }
    var changed = false;
    for (var a = 0; a < parts.length; a++) {
      for (var b = a + 1; b < parts.length; b++) {
        var best = 99;
        var from = 0;
        var to = 0;
        for (final left in parts[a]) {
          final lx = left % width;
          final ly = left ~/ width;
          for (final right in parts[b]) {
            final gap = (lx - right % width).abs();
            final gy = (ly - right ~/ width).abs();
            final dist = gap > gy ? gap : gy;
            if (dist >= best) continue;
            best = dist;
            from = left;
            to = right;
            if (best <= 1) break;
          }
          if (best <= 1) break;
        }
        if (best > 2) continue;
        changed = _bridge(bytes, width, from, to) || changed;
      }
    }
    return changed;
  }

  /// A dark outline pixel hides the joint. Use a brighter neighbor instead.
  static int _vivid(Uint8List bytes, int width, int pixel) {
    final x0 = pixel % width;
    final y0 = pixel ~/ width;
    var best = pixel * 4;
    var lum = bytes[best] + bytes[best + 1] + bytes[best + 2];
    final height = bytes.length ~/ (width * 4);
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = x0 + dx;
        final y = y0 + dy;
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        final index = (y * width + x) * 4;
        if (bytes[index + 3] < 128) continue;
        final next = bytes[index] + bytes[index + 1] + bytes[index + 2];
        if (next <= lum) continue;
        lum = next;
        best = index;
      }
    }
    return best;
  }

  static bool _bridge(Uint8List bytes, int width, int from, int to) {
    final x0 = from % width;
    final y0 = from ~/ width;
    final x1 = to % width;
    final y1 = to ~/ width;
    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final steps = dx > dy ? dx : dy;
    if (steps == 0 || steps > 2) return false;
    final src = _vivid(bytes, width, from);
    var changed = false;
    void paint(int x, int y) {
      if (x < 0 || y < 0) return;
      final index = (y * width + x) * 4;
      if (index < 0 || index + 3 >= bytes.length || bytes[index + 3] >= 128) {
        return;
      }
      bytes[index] = bytes[src];
      bytes[index + 1] = bytes[src + 1];
      bytes[index + 2] = bytes[src + 2];
      bytes[index + 3] = bytes[src + 3];
      changed = true;
    }

    if (steps == 1) {
      paint(x0, y1);
      paint(x1, y0);
      return changed;
    }
    final midX = (x0 + x1) ~/ 2;
    final midY = (y0 + y1) ~/ 2;
    // Two pixels, so a later turn does not snap the joint back open.
    paint(midX, midY);
    paint(midX + 1, midY);
    paint(midX, midY + 1);
    return changed;
  }

  /// Gives a one-pixel line a second pixel so a turn does not snap it.
  ///
  /// Nearest-neighbor rotation drops a one-pixel string into specks, and
  /// those specks are then deleted. A line pixel (two solid neighbors or
  /// fewer) copies itself into one empty side. A face window stays open.
  static bool thickenLines(Uint8List bytes, int width, int height) {
    final prior = Uint8List.fromList(bytes);
    var changed = false;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        if (prior[index + 3] < 128) continue;
        var solid = 0;
        final holes = <int>[];
        for (final step in const [
          (1, 0),
          (-1, 0),
          (0, 1),
          (0, -1),
        ]) {
          final nx = x + step.$1;
          final ny = y + step.$2;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final next = (ny * width + nx) * 4;
          if (prior[next + 3] >= 128) {
            solid++;
          } else {
            holes.add(next);
          }
        }
        if (solid > 2 || holes.isEmpty) continue;
        final hole = holes.first;
        if (bytes[hole + 3] >= 128) continue;
        bytes[hole] = prior[index];
        bytes[hole + 1] = prior[index + 1];
        bytes[hole + 2] = prior[index + 2];
        bytes[hole + 3] = prior[index + 3];
        changed = true;
      }
    }
    return changed;
  }

  /// True when [bytes] changed. [bytes] is tightly packed RGBA.
  static bool sealBytes(Uint8List bytes, int width, int height) {
    var changed = false;
    for (var pass = 0; pass < 4; pass++) {
      final prior = Uint8List.fromList(bytes);
      var step = false;
      for (var y = 1; y < height - 1; y++) {
        for (var x = 1; x < width - 1; x++) {
          final index = (y * width + x) * 4;
          if (prior[index + 3] > 40) continue;
          final cols = <int>[];
          for (final next in [
            index - 4,
            index + 4,
            index - width * 4,
            index + width * 4,
          ]) {
            if (prior[next + 3] <= 40) continue;
            cols.add(next);
          }
          if (cols.length < 3) continue;
          cols.sort((a, b) {
            final left = prior[a] + prior[a + 1] + prior[a + 2];
            final right = prior[b] + prior[b + 1] + prior[b + 2];
            return left.compareTo(right);
          });
          final pick = cols[cols.length ~/ 2];
          bytes[index] = prior[pick];
          bytes[index + 1] = prior[pick + 1];
          bytes[index + 2] = prior[pick + 2];
          bytes[index + 3] = 255;
          step = true;
        }
      }
      if (!step) break;
      changed = true;
    }
    return changed;
  }

  static Future<RigAtlas> _build(
    ui.Image image,
    RigData rig,
    String cacheKey,
    double cropTop,
    double cropBottom,
  ) async {
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      throw StateError('rig image has no pixels');
    }
    final bytes = raw.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final y0 = (cropTop * RigData.canvas).floor().clamp(0, RigData.canvas);
    final y1 = (cropBottom * RigData.canvas).ceil().clamp(0, RigData.canvas);
    final claim = claimFor(cacheKey);
    final body = bodyParts(rig);
    final arms = claim == 'hands' ? nearestArms(rig) : const <String?>[];
    final boxes = <String, _Draft>{};
    for (var y = y0; y < y1 && y < height; y++) {
      for (var x = 0; x < width && x < RigData.canvas; x++) {
        if (bytes[(y * width + x) * 4 + 3] == 0) continue;
        final part = partAt(
          rig: rig,
          body: body,
          nearestArm: arms,
          index: y * RigData.canvas + x,
          claim: claim,
        );
        if (part == null || rig.bones[part] == null) continue;
        final box = boxes[part];
        if (box == null) {
          boxes[part] = _Draft(part, x, y, x, y);
        } else {
          box.grow(x, y);
        }
      }
    }
    final pieces = <_Draft>[];
    for (final part in rig.drawOrder) {
      final box = boxes[part];
      if (box != null) pieces.add(box);
    }
    if (pieces.isEmpty) {
      final empty = await _image(Uint8List(4), 1, 1);
      return RigAtlas(image: empty, pieces: const []);
    }
    final atlasW = pieces.fold<int>(0, (sum, piece) => sum + piece.w);
    final atlasH = pieces.fold<int>(1, (max, piece) => piece.h > max ? piece.h : max);
    final pixels = Uint8List(atlasW * atlasH * 4);
    final placed = <RigPiece>[];
    var cursor = 0;
    for (final piece in pieces) {
      for (var y = 0; y < piece.h; y++) {
        for (var x = 0; x < piece.w; x++) {
          final sx = piece.minX + x;
          final sy = piece.minY + y;
          if (sy >= height || sx >= width || sx >= RigData.canvas) continue;
          final part = partAt(
            rig: rig,
            body: body,
            nearestArm: arms,
            index: sy * RigData.canvas + sx,
            claim: claim,
          );
          if (part != piece.part) continue;
          final src = (sy * width + sx) * 4;
          final dst = ((y * atlasW) + cursor + x) * 4;
          pixels[dst] = bytes[src];
          pixels[dst + 1] = bytes[src + 1];
          pixels[dst + 2] = bytes[src + 2];
          pixels[dst + 3] = bytes[src + 3];
        }
      }
      final bone = rig.bones[piece.part]!;
      placed.add(
        RigPiece(
          part: piece.part,
          rect: ui.Rect.fromLTWH(cursor.toDouble(), 0, piece.w.toDouble(), piece.h.toDouble()),
          pivotX: bone.restX - piece.minX,
          pivotY: bone.restY - piece.minY,
        ),
      );
      cursor += piece.w;
    }
    return RigAtlas(image: await _image(pixels, atlasW, atlasH), pieces: placed);
  }

  static Future<ui.Image> _image(Uint8List pixels, int width, int height) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }
}

class _Draft {
  _Draft(this.part, this.minX, this.minY, this.maxX, this.maxY);

  final String part;
  int minX;
  int minY;
  int maxX;
  int maxY;

  int get w => maxX - minX + 1;
  int get h => maxY - minY + 1;

  void grow(int x, int y) {
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }
}
