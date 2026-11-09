import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// The 96px pass stays in the mite's league: thick ink, interior marks,
/// and brass/rime silhouettes that are not the golem.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> load(String name) async {
    final bytes = File('assets/custom/enemies/$name').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<(int colors, Uint8List mask, int w, int h)> measure(String name) async {
    final image = await load(name);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(data, isNotNull);
    final bytes = data!.buffer.asUint8List();
    final colors = <int>{};
    final mask = Uint8List(image.width * image.height);
    for (var i = 0; i < mask.length; i++) {
      final a = bytes[i * 4 + 3];
      if (a > 16) {
        mask[i] = 1;
        colors.add(
          (bytes[i * 4] << 16) | (bytes[i * 4 + 1] << 8) | bytes[i * 4 + 2],
        );
      }
    }
    return (colors.length, mask, image.width, image.height);
  }

  test('thin 96px enemies keep mite-level detail and their canvas', () async {
    for (final name in [
      'sandy_tank.png',
      'king_tank.png',
      'hell_brute.png',
      'storm_brute.png',
      'boss_brass.png',
      'boss_rime.png',
    ]) {
      final (colors, _, w, h) = await measure(name);
      expect(w, 96, reason: name);
      expect(h, 96, reason: name);
      expect(colors, greaterThanOrEqualTo(55), reason: name);
    }
  });

  test('brass and rime are not the golem silhouette', () async {
    final (_, golem, _, _) = await measure('golem.png');
    final (_, brass, _, _) = await measure('boss_brass.png');
    final (_, rime, _, _) = await measure('boss_rime.png');
    expect(brass, isNot(equals(golem)));
    expect(rime, isNot(equals(golem)));
    expect(brass, isNot(equals(rime)));
  });
}
