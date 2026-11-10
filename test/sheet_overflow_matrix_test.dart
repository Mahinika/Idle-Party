import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/meta/keystone_sheet.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/home/map_screen.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/settings_overlay.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';
import 'shell_golden_harness.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Size logicalSize,
  required TextScaler scaler,
  required Widget sheet,
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          textScaler: scaler,
        ),
        child: Scaffold(
          backgroundColor: GameTheme.ink,
          body: SizedBox(
            height: logicalSize.height,
            width: logicalSize.width,
            child: sheet,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
}

void main() {
  final sizes = <Size>[
    const Size(360, 640),
    const Size(360, 780),
  ];
  final scalers = <TextScaler>[
    TextScaler.noScaling,
    TextScaler.linear(GameTheme.typeScaleMax),
    const TextScaler.linear(2),
  ];

  group('sheet overflow matrix', () {
    for (final size in sizes) {
      for (final scaler in scalers) {
        final tag = '${size.width.toInt()}x${size.height.toInt()} '
            '@${scaler.scale(1).toStringAsFixed(2)}';

        testWidgets('shop $tag', (tester) async {
          final director = shopGoldenDirector();
          ShopDock.goldenTestPriceLabel = r'$4.99';
          addTearDown(() => ShopDock.goldenTestPriceLabel = '');
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: ShopDock(director: director),
          );
        });

        testWidgets('market $tag', (tester) async {
          final director = marketGoldenDirector();
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: MarketOverlay(director: director),
          );
        });

        testWidgets('quests $tag', (tester) async {
          final director = questsGoldenDirector();
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: JobsOverlay(director: director),
          );
        });

        testWidgets('settings $tag', (tester) async {
          final director = settingsGoldenDirector();
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: SettingsOverlay(director: director, onClose: () {}),
          );
        });

        testWidgets('forge summary $tag', (tester) async {
          final director = goldSheetGoldenDirector();
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: ForgeOverlay(director: director),
          );
        });

        testWidgets('essence camp $tag', (tester) async {
          final director = essenceSheetGoldenDirector();
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: SanctuaryOverlay(director: director),
          );
        });

        testWidgets('map endgame $tag', (tester) async {
          final director = endgameHubGoldenDirector();
          final router = MenuRouter();
          addTearDown(director.dispose);
          addTearDown(router.dispose);
          router.open(MenuRoute.map, mapEndgame: true);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: MapScreen(director: director, router: router),
          );
        });

        testWidgets('KEY sheet $tag', (tester) async {
          final director = endgameHubGoldenDirector();
          addTearDown(director.dispose);
          await _pumpSheet(
            tester,
            logicalSize: size,
            scaler: scaler,
            sheet: KeystoneSheet(director: director),
          );
        });
      }
    }
  });
}
