import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/app_memory.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/decoded_image_cache.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/spatial_dungeon_view.dart';
import 'package:idle_party/visual/rig/hero_rig_painter.dart';

void main() {
  // Opt out of async floor-band baking so unmount cannot leave a pending
  // picture.toImage future on the test clock.
  debugHoldFloorBake();

  testWidgets('trim on pause then resume still paints a held cache image', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => DecodedImageCache.load(CustomAssets.iconSword, targetWidth: 32),
    );
    expect(image, isNotNull);
    await tester.pumpWidget(_heldImageApp(image!));
    expect(tester.takeException(), isNull);
    _sendPaused(tester);
    AppMemory.trimForBackground();
    expect(DecodedImageCache.isDisposed(image), isFalse);
    _sendResumed(tester);
    await tester.pump(Duration.zero);
    expect(DecodedImageCache.isDisposed(image), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_heldImageApp(image));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SpatialDungeonView reloads disposed art on resume without paint errors',
    (tester) async {
      final director = GameDirector.preview(
        initialState: GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
      );
      var directorLive = true;
      addTearDown(() {
        if (directorLive) director.dispose();
      });
      await director.boot();
      director.enterDungeon();

      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                width: 411,
                height: 640,
                child: SpatialDungeonView(director: director),
              ),
              HeroDollSprite(hero: director.state.heroes.first, size: 48),
            ],
          ),
        ),
      );
      await _waitForTiles(tester, director);
      expect(
        director.dungeonTilesReady,
        isTrue,
        reason: 'floor art should decode before the resume probe',
      );
      expect(tester.takeException(), isNull);

      // Recreates the pre-fix background trim, which disposed cache images
      // while the fight view was still mounted.
      DecodedImageCache.clear();
      HeroRigPainter.evictDisposedImages();
      _sendPaused(tester);
      _sendResumed(tester);
      await tester.pump(Duration.zero);
      // First frame after resume must not paint non-genuine images.
      expect(tester.takeException(), isNull);

      await _waitForTiles(tester, director);
      expect(
        director.dungeonTilesReady,
        isTrue,
        reason: 'disposed floor art should reload after resume',
      );
      expect(tester.takeException(), isNull);

      directorLive = false;
      director.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _heldImageApp(ui.Image image) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: CustomPaint(size: const Size(32, 32), painter: _ImagePainter(image)),
  );
}

Future<void> _waitForTiles(WidgetTester tester, GameDirector director) async {
  // Floor art decodes off the test clock (see fight_phone_fit_test).
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    if (director.dungeonTilesReady) return;
    expect(tester.takeException(), isNull);
  }
}

void _sendPaused(WidgetTester tester) {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _sendResumed(WidgetTester tester) {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant _ImagePainter oldDelegate) =>
      oldDelegate.image != image;
}
