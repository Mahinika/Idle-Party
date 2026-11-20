import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/meta/roster_panel.dart';
import 'package:idle_party/ui/party_role_icon.dart';

import 'shell_golden_harness.dart';
import 'support/role_icons_fight_harness.dart';

const _artifactDir = '/opt/cursor/artifacts/role-icons';

Future<void> _pumpUntilDolls(WidgetTester tester) async {
  final baseline = HeroDollSprite.pendingLoads;
  await pumpGoldenFrames(tester, ms: 100);
  final sw = Stopwatch()..start();
  var idle = 0;
  while (sw.elapsedMilliseconds < 6000) {
    if (HeroDollSprite.pendingLoads <= baseline) {
      idle++;
      if (idle >= 2) break;
    } else {
      idle = 0;
    }
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 16)),
    );
  }
  await pumpGoldenFrames(tester, ms: 200);
}

Future<ui.Image> _captureBoundary(
  WidgetTester tester,
  GlobalKey key, {
  bool waitForDolls = true,
}) async {
  if (waitForDolls) {
    await settleGoldenImages(tester);
    await _pumpUntilDolls(tester);
  } else {
    await pumpGoldenFrames(tester, ms: 100);
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  return image!;
}

Future<void> _writePng(
  WidgetTester tester,
  ui.Image img,
  String path,
) async {
  final png = await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.png),
  );
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

Future<void> _writeZoomedIcon(
  WidgetTester tester,
  GlobalKey shotKey,
  ui.Image full,
  String path,
) async {
  final icon = find.byKey(PartyRoleIcon.keyFor(PartyRoleBucket.tank)).first;
  final iconRect = tester.getRect(icon);
  final shotRect = tester.getRect(find.byKey(shotKey));
  final rel = Rect.fromLTWH(
    iconRect.left - shotRect.left,
    iconRect.top - shotRect.top,
    iconRect.width,
    iconRect.height,
  );

  final dpr = 2.0;
  final pad = 6.0;
  final crop = Rect.fromLTRB(
    (rel.left - pad) * dpr,
    (rel.top - pad) * dpr,
    (rel.right + pad) * dpr,
    (rel.bottom + pad) * dpr,
  );

  late Uint8List pngBytes;
  await tester.runAsync(() async {
  final raw = await full.toByteData(format: ui.ImageByteFormat.rawRgba);
  final w = crop.width.round();
  final h = crop.height.round();
  final scale = 3;
  final outW = w * scale;
  final outH = h * scale;
  final bytes = raw!;
  final fullW = full.width;

  final out = Uint8List(outW * outH * 4);
  for (var oy = 0; oy < outH; oy++) {
    for (var ox = 0; ox < outW; ox++) {
      final sx = crop.left.round() + ox ~/ scale;
      final sy = crop.top.round() + oy ~/ scale;
      final si = (sy * fullW + sx) * 4;
      final di = (oy * outW + ox) * 4;
      out[di] = bytes.getUint8(si);
      out[di + 1] = bytes.getUint8(si + 1);
      out[di + 2] = bytes.getUint8(si + 2);
      out[di + 3] = bytes.getUint8(si + 3);
    }
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final src = await ui.ImmutableBuffer.fromUint8List(out);
  final descriptor = ui.ImageDescriptor.raw(
    src,
    width: outW,
    height: outH,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  canvas.drawImage(frame.image, Offset.zero, Paint()..filterQuality = FilterQuality.none);
  frame.image.dispose();
  final picture = recorder.endRecording();
  final zoomImg = await picture.toImage(outW, outH);
  final png = await zoomImg.toByteData(format: ui.ImageByteFormat.png);
  pngBytes = png!.buffer.asUint8List();
  zoomImg.dispose();
  });
  File(path).parent.createSync(recursive: true);
  File(path).writeAsBytesSync(pngBytes);
}

void main() {
  testWidgets('fight party strip role icons at 1.0 and 1.45', (tester) async {
    await ensureShellGoldenFonts();
    final shotKey = GlobalKey();
    for (final scale in [1.0, 1.45]) {
      final director = await roleIconsArtifactDirector();
      addTearDown(director.dispose);
      final router = MenuRouter();
      addTearDown(router.dispose);

      tester.view.physicalSize = const Size(720, 1560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: shellGoldenScaffold(
            RepaintBoundary(
              key: shotKey,
              child: RoleIconsFightStripHarness(
                director: director,
                router: router,
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 500);
      while (tester.takeException() != null) {}
      expect(find.text('Tank'), findsNothing);
      expect(
        find.byKey(PartyRoleIcon.keyFor(PartyRoleBucket.tank)),
        findsOneWidget,
      );
      expect(
        find.byKey(PartyRoleIcon.keyFor(PartyRoleBucket.healer)),
        findsOneWidget,
      );
      expect(
        find.byKey(PartyRoleIcon.keyFor(PartyRoleBucket.dps)),
        findsNWidgets(3),
      );

      final suffix = scale == 1.0 ? '1.0' : '1.45';
      final img = await _captureBoundary(tester, shotKey);
      await _writePng(tester, img, '$_artifactDir/fight_party_strip_$suffix.png');
      if (scale == 1.0) {
        await _writeZoomedIcon(
          tester,
          shotKey,
          img,
          '$_artifactDir/icon_card_zoom_3x.png',
        );
      }
      img.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('inn roster header copy', (tester) async {
    final shotKey = GlobalKey();
    final state = await roleIconsArtifactFightState();
    final innDirector = GameDirector.preview(
      initialState: state.copyWith(inDungeon: false, ascensionLevel: 1),
    );
    addTearDown(innDirector.dispose);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: RepaintBoundary(
            key: shotKey,
            child: TeamCompositionOverlay(director: innDirector),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 300);
    expect(find.textContaining('Tap ADD'), findsNothing);
    expect(find.textContaining('Fixed roles: TANK'), findsOneWidget);
    final img = await _captureBoundary(tester, shotKey, waitForDolls: false);
    await _writePng(tester, img, '$_artifactDir/inn_roster_header.png');
    img.dispose();
  });
}