import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

import 'abilities_61_render_test.dart' show abilities61RenderIds;
import 'shell_golden_harness.dart';

const _frameLives = <double>[0.08, 0.18, 0.32, 0.48, 0.68, 0.88];
const _frameSize = 128.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  test('61 ability animation strips (6 frames)', () async {
    expect(abilities61RenderIds.length, 61);
    for (final id in abilities61RenderIds) {
      final def = ClassKits.defFor(id)!;
      final frames = <Uint8List>[];
      for (final life in _frameLives) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, _frameSize, _frameSize),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF231A28),
        );
        SpellShapePaint.paintAbilityShowcase(
          canvas,
          tileRect: const Rect.fromLTWH(8, 8, _frameSize - 16, _frameSize - 16),
          def: def,
          life: life,
        );
        frames.add(await _pngFromRecorder(recorder, _frameSize.round(), _frameSize.round()));
      }
      final stripW = (_frameSize * frames.length).round();
      final stripRecorder = ui.PictureRecorder();
      final stripCanvas = Canvas(stripRecorder);
      stripCanvas.drawRect(
        Rect.fromLTWH(0, 0, stripW.toDouble(), _frameSize),
        Paint()..color = const Color(0xFF141018),
      );
      for (var i = 0; i < frames.length; i++) {
        final codec = await ui.instantiateImageCodec(frames[i]);
        final img = (await codec.getNextFrame()).image;
        stripCanvas.drawImage(img, Offset(i * _frameSize, 0), Paint());
        img.dispose();
      }
      final stripBytes = await _pngFromRecorder(stripRecorder, stripW, _frameSize.round());
      expect(stripBytes.lengthInBytes, greaterThan(2000));

      if (Platform.environment['RENDER_ABILITIES_61'] == '1') {
        final base = Directory('docs/design/abilities-61/rendered/anim');
        base.createSync(recursive: true);
        final name = id.name;
        File('${base.path}/${name}_strip.png').writeAsBytesSync(stripBytes);
        final frameDir = Directory('${base.path}/$name');
        frameDir.createSync(recursive: true);
        for (var i = 0; i < frames.length; i++) {
          File('${frameDir.path}/f$i.png').writeAsBytesSync(frames[i]);
        }
      }
    }
  });
}

Future<Uint8List> _pngFromRecorder(ui.PictureRecorder recorder, int w, int h) async {
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}