import 'package:flutter/painting.dart';

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

  /// Drop Flutter's [ImageCache] on paused / hidden / detached, not on a
  /// brief inactive shade swipe.
  ///
  /// Does not dispose combat-sprite images still held by the dungeon
  /// view, hero rig, or party dolls. Disposing those while the view is
  /// mounted makes CustomPaint fail with "non-genuine Image" until a remount.
  static void trimForBackground() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }
}
