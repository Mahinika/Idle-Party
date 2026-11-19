import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/is2_shell.dart';
import 'package:idle_party/ui/shell/buy_qty_toggle.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';

/// Batch 3: FARM / PUSH / LEAVE live on the field, the tabs and ×1 / ×10 /
/// MAX share one header row, and the buy list keeps at least two rows.
void main() {
  Future<GameDirector> pumpSplit(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seeded = GameLogic.createInitialState(
      now: DateTime.now().add(const Duration(minutes: 10)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      bossVictories: 1,
      highestFloorCleared: 2,
      gold: 5000,
    );
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(seeded),
    );
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: HomeShell(director: director, router: router, onLeave: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return director;
  }

  testWidgets('FARM / PUSH and LEAVE sit on the field; camera frames above', (
    tester,
  ) async {
    await pumpSplit(tester);
    expect(tester.takeException(), isNull);
    final controls = find.byType(FightFieldControls);
    expect(controls, findsOneWidget);
    expect(
      find.descendant(of: controls, matching: find.text('LEAVE')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: controls, matching: find.text('FARM')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(FightSeam), matching: find.text('LEAVE')),
      findsNothing,
    );
    final shell = tester.widget<Is2Shell>(find.byType(Is2Shell));
    expect(shell.extraBottomInset, FightFieldControls.cameraReserve);
    final field = tester.getRect(find.byType(Is2Shell));
    final strip = tester.getRect(controls);
    expect(strip.bottom, closeTo(field.bottom, 0.5));
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.descendant(
                    of: controls,
                    matching: find.text('LEAVE'),
                  ),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
  });

  testWidgets('one header row owns ×1 / ×10 / MAX for FORGE and CAMP', (
    tester,
  ) async {
    await pumpSplit(tester);
    final panel = find.byType(UpgradePanel);
    expect(
      find.descendant(of: panel, matching: find.byType(BuyQtyToggle)),
      findsOneWidget,
    );
    final tabs = tester.getRect(
      find.descendant(of: panel, matching: find.text('MARKET')),
    );
    final toggle = tester.getRect(find.byType(BuyQtyToggle));
    expect((tabs.center.dy - toggle.center.dy).abs(), lessThan(12));

    await tester.tap(find.text('×10'));
    await tester.pump();
    expect(
      tester.widget<ForgeOverlay>(find.byType(ForgeOverlay)).spendMode,
      ForgeGoldSpendMode.x10,
    );

    await tester.tap(find.text('CAMP'));
    await tester.pump();
    expect(find.byType(BuyQtyToggle), findsOneWidget);
    expect(
      tester.widget<SanctuaryOverlay>(find.byType(SanctuaryOverlay)).qty,
      BuyQty.ten,
    );

    await tester.tap(find.text('MARKET'));
    await tester.pump();
    expect(find.byType(BuyQtyToggle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A56 SPLIT shows at least two whole FORGE rows', (tester) async {
    await pumpSplit(tester);
    final panel = tester.getRect(find.byType(UpgradePanel));
    final whole = find
        .byType(PowerUpgradeRow)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .where((r) => r.top >= panel.top && r.bottom <= panel.bottom)
        .length;
    expect(whole, greaterThanOrEqualTo(2));
  });

  testWidgets('text scale 1.45 keeps rails, header and field controls', (
    tester,
  ) async {
    await pumpSplit(tester, scale: GameTheme.typeScaleMax);
    expect(tester.takeException(), isNull);
    expect(find.text('SCROLLS'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FightSeamRails)).height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
    expect(find.byType(BuyQtyToggle), findsOneWidget);
    for (final label in ['FORGE', 'CAMP', 'MARKET']) {
      final r = tester.getRect(
        find.descendant(
          of: find.byType(UpgradePanel),
          matching: find.text(label),
        ),
      );
      expect(r.right, lessThanOrEqualTo(360));
    }
    expect(tester.getRect(find.byType(BuyQtyToggle)).right, lessThanOrEqualTo(360));
    expect(find.byType(FightFieldControls), findsOneWidget);
  });
}
