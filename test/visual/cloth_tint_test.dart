import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/visual/character_layer.dart';
import 'package:idle_party/visual/character_visual_painter.dart';
import 'package:idle_party/visual/character_visual_pose.dart';
import 'package:idle_party/visual/hero_anim_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spec color paints cloth only', () async {
    const n = 8;
    final body = Uint8List(n * n * 4);
    final mask = Uint8List(n * n * 4);
    void put(Uint8List buf, int x, int y, int r, int g, int b, int a) {
      final i = (y * n + x) * 4;
      buf[i] = r;
      buf[i + 1] = g;
      buf[i + 2] = b;
      buf[i + 3] = a;
    }

    put(body, 3, 3, 220, 210, 240, 255);
    put(body, 4, 4, 40, 36, 70, 255);
    put(mask, 3, 3, 180, 180, 180, 255);

    final bodyImg = await _image(n, body);
    final maskImg = await _image(n, mask);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()),
      Paint()..color = const Color(0xFF00CC44),
    );
    CharacterVisualPainter.paintOwnedHero(
      canvas,
      const Offset(n / 2, n / 2),
      n.toDouble(),
      body: bodyImg,
      images: {'mask': maskImg},
      pose: const CharacterVisualPose(
        layers: [
          ResolvedLayer(id: CharacterLayerId.body, col: 0, row: 0),
        ],
        anim: HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
        flipX: false,
        layerOrder: [CharacterLayerId.body],
        bodyTint: Color(0xFFFF4010),
        bodyTintAsset: 'mask',
      ),
    );
    final shot = await recorder.endRecording().toImage(n, n);
    final data = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(data, isNotNull);
    final px = data!.buffer.asUint8List();

    List<int> at(int x, int y) {
      final i = (y * n + x) * 4;
      return [px[i], px[i + 1], px[i + 2], px[i + 3]];
    }

    final corner = at(0, 0);
    expect(
      corner[1],
      greaterThan(corner[0] + 40),
      reason: 'empty box stays backdrop',
    );
    // Mask 180 modulated by 0xFFFF4010, then drawn over the body.
    expect(at(3, 3), [180, 45, 11, 255]);
    expect(at(4, 4), [40, 36, 70, 255]);
  });
}

Future<ui.Image> _image(int n, Uint8List rgba) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: n,
    height: n,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}
