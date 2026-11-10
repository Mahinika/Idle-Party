import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/shell/home/town_life.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> folkPng(WidgetTester tester) async {
    final bytes = await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('town-folk')),
      );
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  Future<void> pumpTown(
    WidgetTester tester, {
    required GameDirector director,
    required MenuRouter router,
    bool disableAnimations = false,
    bool ticker = true,
  }) async {
    tester.view.physicalSize = TownPreview.phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TickerMode(
        enabled: ticker,
        child: MediaQuery(
          data: MediaQueryData(
            size: TownPreview.phoneSize,
            disableAnimations: disableAnimations,
          ),
          child: MaterialApp(
            home: TownPreview(
              director: director,
              router: router,
              size: TownPreview.phoneSize,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(TownViewport));
      for (final path in CustomAssets.townAssetPaths) {
        await precacheImage(AssetImage(path), ctx);
      }
    });
    await tester.pump();
  }

  GameDirector directorFor(VfxQuality quality) {
    return GameDirector.preview(
      initialState: GameLogic.createInitialState(
        now: DateTime.utc(2026, 11, 8),
      ).copyWith(inDungeon: false, vfxQuality: quality, bossVictories: 1),
    );
  }

  testWidgets('walkers advance, then freeze when motion is off', (tester) async {
    final director = directorFor(VfxQuality.full);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpTown(tester, director: director, router: router);
    final first = await folkPng(tester);
    expect(first.length, greaterThan(500));
    await tester.pump(const Duration(milliseconds: 720));
    final later = await folkPng(tester);
    expect(later, isNot(equals(first)));

    director.debugHoldSave(director.state);
    director.setVfxQuality(VfxQuality.minimal);
    await tester.pump();
    expect(tester.widget<TownFolkLayer>(find.byType(TownFolkLayer)).motion, isFalse);
    final held = await folkPng(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(await folkPng(tester), equals(held));
  });

  testWidgets('system reduce-motion and a paused app do not tick', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    final director = directorFor(VfxQuality.full);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    final baseline = tester.binding.transientCallbackCount;

    await pumpTown(tester, director: director, router: router, disableAnimations: true);
    expect(tester.binding.transientCallbackCount, baseline);
    final still = await folkPng(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(await folkPng(tester), equals(still));

    await pumpTown(tester, director: director, router: router);
    expect(tester.binding.transientCallbackCount, greaterThan(baseline));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, baseline);
    final frozen = await folkPng(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(await folkPng(tester), equals(frozen));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(baseline));
  });

  testWidgets('offstage ticker and dispose leave no town ticker', (tester) async {
    final director = directorFor(VfxQuality.full);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final baseline = tester.binding.transientCallbackCount;

    await pumpTown(tester, director: director, router: router, ticker: false);
    expect(tester.binding.transientCallbackCount, baseline);
    final still = await folkPng(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(await folkPng(tester), equals(still));

    await pumpTown(tester, director: director, router: router);
    expect(tester.binding.transientCallbackCount, greaterThan(baseline));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, baseline);
  });
}
