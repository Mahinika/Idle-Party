import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';

import 'shell_golden_harness.dart';
import 'support/role_icons_fight_harness.dart';

const _artifactDir = '/opt/cursor/artifacts/role-icons';

/// Default true on feat/role-icons branch; set false on a fight-ui-stack worktree.
const _afterIconsBranch = bool.fromEnvironment(
  'ROLE_ICONS_AFTER',
  defaultValue: true,
);

Future<void> _pumpUntilDolls(WidgetTester tester) async {
  await pumpGoldenFrames(tester, ms: 200);
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _writeShot(WidgetTester tester, GlobalKey key, String name) async {
  await settleGoldenImages(tester);
  await _pumpUntilDolls(tester);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final img = image!;
  final png = await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.png),
  );
  img.dispose();
  final dir = Directory(_artifactDir);
  dir.createSync(recursive: true);
  File('$_artifactDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('before — text roles on test/fight-ui-stack strip', (
    tester,
  ) async {
    if (_afterIconsBranch) return;
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

      tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.binding.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        roleIconsScaledScaffold(
          scale: scale,
          body: RepaintBoundary(
            key: shotKey,
            child: RoleIconsFightStripHarness(
              director: director,
              router: router,
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 500);
      while (tester.takeException() != null) {}
      final suffix = scale == 1.0 ? '1.0' : '1.45';
      await _writeShot(tester, shotKey, 'before_fight_party_strip_$suffix');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}