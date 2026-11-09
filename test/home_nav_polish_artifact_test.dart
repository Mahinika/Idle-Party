import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/shell/home/home_menu_grid.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

import 'shell_golden_harness.dart';

Future<void> _writeShot(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  testWidgets('home nav polish artifact shots', (tester) async {
    final out = Directory('/opt/cursor/artifacts/home-nav-polish/after');
    final director = homeShellGoldenDirector();
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);

    for (final scale in <double>[1.0, 1.45]) {
      final label = scale == 1.0 ? 'text-1.0' : 'text-1.45';
      bindA56View(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final shellKey = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: shellGoldenScaffold(
            RepaintBoundary(
              key: shellKey,
              child: HomeShell(
                director: director,
                router: router,
                onLeave: () {},
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 800);
      await _writeShot(
        tester,
        shellKey,
        '${out.path}/home_shell_fight_$label.png',
      );

      router.open(MenuRoute.more);
      await tester.pump();
      await pumpGoldenFrames(tester, ms: 400);
      final menuKey = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: shellGoldenScaffold(
            SizedBox(
              height: 640,
              child: RepaintBoundary(
                key: menuKey,
                child: HomeMenuGrid(director: director, router: router),
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 400);
      await _writeShot(
        tester,
        menuKey,
        '${out.path}/home_menu_grid_$label.png',
      );

      router.close();
      router.open(MenuRoute.map);
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: shellGoldenScaffold(
            RepaintBoundary(
              key: shellKey,
              child: HomeShell(
                director: director,
                router: router,
                onLeave: () {},
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 600);
      await _writeShot(
        tester,
        shellKey,
        '${out.path}/home_map_sheet_$label.png',
      );
      router.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
