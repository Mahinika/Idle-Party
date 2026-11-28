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
  static final Set<ui.Image> _disposed = <ui.Image>{};

  /// Bumps when [clear] disposes cached images so mounted views can reload.
  static int _epoch = 0;
  static int get epoch => _epoch;

  /// Whether [image] was disposed by [clear] or is debug-disposed in tests.
  static bool isDisposed(ui.Image? image) {
    if (image == null) return false;
    if (_disposed.contains(image)) return true;
    var disposed = false;
    assert(() {
      disposed = image.debugDisposed;
      return true;
    }());
    return disposed;
  }

  static bool anyDisposed(Iterable<ui.Image?> images) => images.any(isDisposed);

  static Future<ui.Image> load(
    String asset, {
    int? targetWidth,
    int? targetHeight,
  }) {
    final key = '$asset@${targetWidth ?? 0}x${targetHeight ?? 0}';
    final hit = _images[key];
    if (hit != null) return Future<ui.Image>.value(hit);
    return _inflight.putIfAbsent(key, () async {
      try {
        final data = await rootBundle.load(asset);
        final bytes = data.buffer.asUint8List();
        var capW = targetWidth;
        if (capW == null) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          final natural = descriptor.width;
          descriptor.dispose();
          buffer.dispose();
          if (natural > 512) capW = 512;
        }
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: capW,
          targetHeight: targetHeight,
        );
        final frame = await codec.getNextFrame();
        _images[key] = frame.image;
        return frame.image;
      } finally {
        // A failed decode must not stick, or every later paint misses it.
        _inflight.remove(key);
      }
    });
  }

  static void clear() {
    _epoch++;
    for (final img in _images.values) {
      _disposed.add(img);
      img.dispose();
    }
    _images.clear();
    _inflight.clear();
  }
}
