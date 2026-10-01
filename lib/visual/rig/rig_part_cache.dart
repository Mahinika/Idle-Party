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
  }) {
    final hit = _ready[cacheKey];
    if (hit != null) return Future.value(hit);
    return _pending.putIfAbsent(cacheKey, () async {
      final atlas = await _build(image, rig, cropTop, cropBottom);
      _ready[cacheKey] = atlas;
      _pending.remove(cacheKey);
      return atlas;
    });
  }

  static Future<RigAtlas> _build(
    ui.Image image,
    RigData rig,
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
    final pieces = <_Draft>[];
    for (final part in rig.drawOrder) {
      final mask = rig.masks[part];
      if (mask == null) continue;
      var minX = width;
      var minY = height;
      var maxX = -1;
      var maxY = -1;
      for (var y = y0; y < y1 && y < height; y++) {
        for (var x = 0; x < width && x < RigData.canvas; x++) {
          if (mask[y * RigData.canvas + x] == 0) continue;
          final alpha = bytes[(y * width + x) * 4 + 3];
          if (alpha == 0) continue;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
      if (maxX < 0) continue;
      pieces.add(_Draft(part, minX, minY, maxX, maxY));
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
          if (sy >= height || sx >= width) continue;
          if (rig.masks[piece.part]![sy * RigData.canvas + sx] == 0) continue;
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
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  int get w => maxX - minX + 1;
  int get h => maxY - minY + 1;
}
