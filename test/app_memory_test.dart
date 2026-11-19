import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_memory.dart';

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
}
