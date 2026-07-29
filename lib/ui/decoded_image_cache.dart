import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Shared decoded [ui.Image] cache for combat sprites.
///
/// Avoids re-decoding heroes/loot/pets on every dungeon switch and caps
/// decode size so oversized PNGs never hit the GPU at native resolution.
abstract final class DecodedImageCache {
  static final Map<String, ui.Image> _images = <String, ui.Image>{};
  static final Map<String, Future<ui.Image>> _inflight =
      <String, Future<ui.Image>>{};

  static Future<ui.Image> load(
    String asset, {
    int? targetWidth,
    int? targetHeight,
  }) {
    final key = '$asset@${targetWidth ?? 0}x${targetHeight ?? 0}';
    final hit = _images[key];
    if (hit != null) return Future<ui.Image>.value(hit);
    return _inflight.putIfAbsent(key, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      _images[key] = frame.image;
      _inflight.remove(key);
      return frame.image;
    });
  }

  static void clear() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _inflight.clear();
  }
}
