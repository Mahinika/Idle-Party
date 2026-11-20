import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/app_memory.dart';
import 'package:idle_party/ui/decoded_image_cache.dart';

void main() {
  test(
    'configureImageCache caps the Flutter cache below the default 100 MB',
    () {
      TestWidgetsFlutterBinding.ensureInitialized();
      AppMemory.configureImageCache();
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.maximumSize, AppMemory.imageCacheSize);
      expect(cache.maximumSizeBytes, AppMemory.imageCacheBytes);
      expect(cache.maximumSizeBytes, lessThan(100 << 20));
    },
  );

  test('trimForBackground clears the Flutter image cache', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppMemory.configureImageCache();
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    // The current live count is already empty in this binding; the call
    // must still be safe and leave both maps empty.
    AppMemory.trimForBackground();
    expect(cache.currentSize, 0);
    expect(cache.liveImageCount, 0);
  });

  test(
    'trimForBackground keeps a held DecodedImageCache image usable',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      AppMemory.configureImageCache();
      final image = await DecodedImageCache.load(
        CustomAssets.iconSword,
        targetWidth: 32,
      );
      final width = image.width;
      expect(width, greaterThan(0));
      expect(DecodedImageCache.isDisposed(image), isFalse);
      final epoch = DecodedImageCache.epoch;
      AppMemory.trimForBackground();
      expect(DecodedImageCache.epoch, epoch);
      expect(DecodedImageCache.isDisposed(image), isFalse);
      expect(image.width, width);
      // A genuine image still draws after trim.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(image, Offset.zero, ui.Paint());
      recorder.endRecording().dispose();
    },
  );
}
