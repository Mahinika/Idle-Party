import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/floater_label_cache.dart';
import 'package:idle_party/ui/game_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(FloaterLabelCache.reset);
  tearDown(FloaterLabelCache.reset);

  const size = 14.0;
  const maxWidth = 200.0;
  const red = Color(0xFFFF6A4A);
  final outline = GameTheme.lootInkShadow;

  void paintOnCanvas(TextPainter painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Offset.zero);
    recorder.endRecording().dispose();
  }

  test(
    'cache overflow never disposes a painter fetched earlier in the same frame',
    () {
      FloaterLabelCache.beginFrame();
      for (var i = 0; i < 23; i++) {
        FloaterLabelCache.of(
          text: 'U$i',
          size: size,
          color: red,
          maxWidth: maxWidth,
        );
      }
      expect(FloaterLabelCache.length, 23);

      final a = FloaterLabelCache.of(
        text: 'X',
        size: size,
        color: red,
        maxWidth: maxWidth,
      );
      expect(FloaterLabelCache.length, 24);
      expect(a.width, greaterThan(0));
      expect(a.height, greaterThan(0));

      // Outline-style miss at cap: this is the mid-frame overflow that used
      // to dispose [a] (the fill fetched just before) and crash on a.width.
      final b = FloaterLabelCache.of(
        text: 'Y',
        size: size,
        color: outline,
        maxWidth: maxWidth,
      );
      expect(a.width, greaterThan(0), reason: 'fill fetched earlier this frame');
      expect(a.height, greaterThan(0));
      expect(a.width.isFinite, isTrue);
      expect(a.height.isFinite, isTrue);
      expect(b.width, greaterThan(0));
      expect(b.height, greaterThan(0));
      expect(() => paintOnCanvas(a), returnsNormally);
      expect(() => paintOnCanvas(b), returnsNormally);
      FloaterLabelCache.endFrame();
      // Dispose is deferred to the next frame's beginFrame.
      FloaterLabelCache.beginFrame();
      expect(FloaterLabelCache.length, lessThanOrEqualTo(FloaterLabelCache.cap));
    },
  );

  test(
    'parity flip sequence (same text, different color) does not crash',
    () {
      // 11 unique fill+outline pairs, then a same-text/different-color fill
      // (outline hits, parity flips), then one more pair whose outline misses
      // at length 24. Old clear-all disposed the just-fetched fill.
      const gold = Color(0xFFFFE08A);
      const gear = Color(0xFFB8E986);
      const payoff = '+12g · +8 XP';

      FloaterLabelCache.beginFrame();
      void pair(String text, Color fill) {
        final tp = FloaterLabelCache.of(
          text: text,
          size: size,
          color: fill,
          maxWidth: maxWidth,
        );
        final tpOutline = FloaterLabelCache.of(
          text: text,
          size: size,
          color: outline,
          maxWidth: maxWidth,
        );
        expect(tp.width, greaterThan(0), reason: text);
        expect(tp.height, greaterThan(0), reason: text);
        expect(tp.width.isFinite, isTrue);
        expect(tpOutline.width, greaterThan(0));
        expect(() => paintOnCanvas(tp), returnsNormally);
        expect(() => paintOnCanvas(tpOutline), returnsNormally);
      }

      for (var i = 0; i < 11; i++) {
        pair(i == 10 ? payoff : 'U$i', gold);
      }
      expect(FloaterLabelCache.length, 22);

      // Flip: same text and size, different fill ARGB, shared outline color.
      pair(payoff, gear);
      expect(FloaterLabelCache.length, 23);

      pair('Z', gold);
      expect(FloaterLabelCache.length, greaterThanOrEqualTo(24));

      // Keep going through 30 floaters (loop-style pair calls).
      for (var i = 0; i < 17; i++) {
        pair('E$i', i.isEven ? gold : gear);
      }
      FloaterLabelCache.endFrame();
      FloaterLabelCache.beginFrame();
      expect(FloaterLabelCache.length, lessThanOrEqualTo(FloaterLabelCache.cap));
    },
  );

  test('cache stays bounded after 1000 unique keys', () {
    for (var i = 0; i < 1000; i++) {
      if (i % 20 == 0) {
        FloaterLabelCache.endFrame();
        FloaterLabelCache.beginFrame();
      }
      final tp = FloaterLabelCache.of(
        text: 'K$i',
        size: size,
        color: red,
        maxWidth: maxWidth,
      );
      expect(tp.width, greaterThan(0));
    }
    FloaterLabelCache.endFrame();
    FloaterLabelCache.beginFrame();
    expect(FloaterLabelCache.length, lessThanOrEqualTo(FloaterLabelCache.cap));

    // Mid-frame growth is allowed; the next beginFrame brings it back to cap.
    FloaterLabelCache.beginFrame();
    for (var i = 0; i < 1000; i++) {
      FloaterLabelCache.of(
        text: 'OneFrame$i',
        size: size,
        color: red,
        maxWidth: maxWidth,
      );
    }
    expect(FloaterLabelCache.length, greaterThan(FloaterLabelCache.cap));
    FloaterLabelCache.endFrame();
    expect(FloaterLabelCache.length, greaterThan(FloaterLabelCache.cap));
    FloaterLabelCache.beginFrame();
    expect(FloaterLabelCache.length, lessThanOrEqualTo(FloaterLabelCache.cap));
  });

  test('LRU keeps a hot key across overflow cycles', () {
    FloaterLabelCache.beginFrame();
    final hot = FloaterLabelCache.of(
      text: 'HOT',
      size: size,
      color: red,
      maxWidth: maxWidth,
    );
    for (var cycle = 0; cycle < 50; cycle++) {
      for (var i = 0; i < FloaterLabelCache.cap; i++) {
        FloaterLabelCache.of(
          text: 'c$cycle-$i',
          size: size,
          color: red,
          maxWidth: maxWidth,
        );
      }
      // Re-touch the hot key at the end of the frame so LRU leaves it in cache.
      final again = FloaterLabelCache.of(
        text: 'HOT',
        size: size,
        color: red,
        maxWidth: maxWidth,
      );
      expect(identical(again, hot), isTrue, reason: 'cycle $cycle');
      FloaterLabelCache.endFrame();
      FloaterLabelCache.beginFrame();
    }
    final still = FloaterLabelCache.of(
      text: 'HOT',
      size: size,
      color: red,
      maxWidth: maxWidth,
    );
    expect(identical(still, hot), isTrue);
    FloaterLabelCache.endFrame();
  });

  test('reset disposes everything once and is safe to call twice', () {
    final first = FloaterLabelCache.of(
      text: 'once',
      size: size,
      color: red,
      maxWidth: maxWidth,
    );
    expect(first.width, greaterThan(0));
    FloaterLabelCache.reset();
    expect(FloaterLabelCache.length, 0);
    // Second reset must not double-dispose the already-disposed painter.
    expect(FloaterLabelCache.reset, returnsNormally);
    expect(FloaterLabelCache.length, 0);
    // A new lookup after reset is a fresh, valid painter.
    final again = FloaterLabelCache.of(
      text: 'once',
      size: size,
      color: red,
      maxWidth: maxWidth,
    );
    expect(identical(again, first), isFalse);
    expect(again.width, greaterThan(0));
    expect(() => paintOnCanvas(again), returnsNormally);
  });
}
