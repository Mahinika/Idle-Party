import 'package:flutter/painting.dart';

import '../ui/decoded_image_cache.dart';

/// Caps and trims decoded image memory so a backgrounded process is a
/// smaller target for Android's killer.
abstract final class AppMemory {
  /// Enough for the hub and one dungeon scene, well under Flutter's
  /// 100 MB default.
  static const int imageCacheSize = 200;
  static const int imageCacheBytes = 64 << 20;

  static void configureImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = imageCacheSize;
    cache.maximumSizeBytes = imageCacheBytes;
  }

  /// Drop decoded sprites and the Flutter image cache. Call on
  /// paused / hidden / detached, not on a brief inactive shade swipe.
  static void trimForBackground() {
    DecodedImageCache.clear();
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }
}
