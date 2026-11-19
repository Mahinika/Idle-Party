import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/run_stash_shop.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// BAG polish: the grid is the page. Big pixel icons, 4 columns, one
/// compact action row; EXPAND BAG waits at the end of the scroll.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  const a56 = Size(412, 915);

  Finder tile(int i) => find.bySemanticsLabel(RegExp('^Test Piece $i,'));

  Future<(GameDirector, MenuRouter)> openBag(
    WidgetTester t,
    Size size,
    double scale, {
    int items = 14,
  }) async {
    final (d, r) = await a100Pump(
      t,
      size,
      scale,
      maxed: true,
      live: true,
      stash: a100Stash(items),
    );
    r.open(MenuRoute.gear, gear: GearPanel.bag);
    await a100Settle(t);
    return (d, r);
  }

  for (final scale in [1.0, 1.45]) {
    final minRows = scale == 1.0 ? 4 : 3;
    a100TestHome('A56 @$scale: 4 columns and at least $minRows full rows', (
      t,
    ) async {
      await openBag(t, a56, scale);
      expect(t.takeException(), isNull);
      final first = t.getRect(tile(0).first);
      for (var i = 1; i < InventoryDock.bagColumns; i++) {
        expect(t.getRect(tile(i).first).top, closeTo(first.top, 0.5));
      }
      expect(
        t.getRect(tile(InventoryDock.bagColumns).first).top,
        greaterThan(first.bottom),
      );
      final view = t.getRect(find.byKey(InventoryDock.bagScrollKey));
      final rows =
          ((view.bottom - first.top + InventoryDock.bagGridGap) /
                  (first.height + InventoryDock.bagGridGap))
              .floor();
      expect(rows, greaterThanOrEqualTo(minRows), reason: 'rows $rows');
      // Tiles are square and still a comfortable tap target.
      expect(first.width, closeTo(first.height, 0.5));
      expect(first.width, greaterThanOrEqualTo(GameTheme.minTouch));
    });

    a100TestHome('A56 @$scale: icons fill about 60–70% of a tile', (t) async {
      await openBag(t, a56, scale);
      final side = t.getRect(tile(0).first).width;
      final icon = t.getRect(find.byKey(const ValueKey('bag-slot-icon')).first);
      expect(icon.width / side, inInclusiveRange(0.55, 0.72));
    });

    a100TestHome('A56 @$scale: AUTO, EQUIP, SELL JUNK, FILTERS share one row', (
      t,
    ) async {
      await openBag(t, a56, scale);
      final auto = t.getRect(find.byKey(InventoryDock.bagAutoEquipKey));
      final equip = t.getRect(
        find.widgetWithText(GameButton, 'EQUIP 14').evaluate().isEmpty
            ? find.widgetWithText(GameButton, 'EQUIP BEST 14')
            : find.widgetWithText(GameButton, 'EQUIP 14'),
      );
      final sell = t.getRect(find.widgetWithText(GameButton, 'SELL JUNK'));
      final filters = t.getRect(find.byKey(InventoryDock.bagFiltersKey));
      for (final r in [equip, sell, filters]) {
        expect(r.center.dy, closeTo(auto.center.dy, 1));
      }
      for (final r in [auto, equip, sell, filters]) {
        expect(r.height, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
      }
      expect(auto.right, lessThanOrEqualTo(equip.left));
      expect(equip.right, lessThanOrEqualTo(sell.left));
      expect(sell.right, lessThanOrEqualTo(filters.left));
      // The row sits under the grid, not inside the scroll.
      final view = t.getRect(find.byKey(InventoryDock.bagScrollKey));
      expect(auto.top, greaterThanOrEqualTo(view.bottom - 0.5));
      a100ExpectWhole(t, find.text('SELL JUNK'));
      a100ExpectWhole(t, find.text('AUTO'));
      // No slab: the old full-width AUTO EQUIP ON/OFF button is gone.
      expect(find.text('AUTO EQUIP ON'), findsNothing);
      expect(find.text('AUTO EQUIP OFF'), findsNothing);
    });
  }

  a100TestHome('AUTO switch toggles auto equip and reports its state', (
    t,
  ) async {
    final (d, _) = await openBag(t, a56, 1);
    final handle = t.ensureSemantics();
    expect(d.state.autoEquipUpgrades, isTrue);
    expect(
      t.getSemantics(find.byKey(InventoryDock.bagAutoEquipKey)),
      matchesSemantics(
        label: 'AUTO EQUIP',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    await t.tap(find.byKey(InventoryDock.bagAutoEquipKey));
    await a100Settle(t);
    expect(d.state.autoEquipUpgrades, isFalse);
    expect(
      t.getSemantics(find.byKey(InventoryDock.bagAutoEquipKey)),
      matchesSemantics(
        label: 'AUTO EQUIP',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  a100TestHome('FILTERS chip opens the cleanup filters in the bag scroll', (
    t,
  ) async {
    await openBag(t, a56, 1);
    expect(tile(0), findsWidgets);
    await t.tap(find.byKey(InventoryDock.bagFiltersKey));
    await a100Settle(t);
    expect(tile(0), findsNothing);
    await t.tap(find.byKey(InventoryDock.bagFiltersKey));
    await a100Settle(t);
    expect(tile(0), findsWidgets);
  });

  a100TestHome('EXPAND BAG waits at the end of the scroll, same price', (
    t,
  ) async {
    final (d, _) = await openBag(t, a56, 1);
    final buy = find.byKey(InventoryDock.bagGoldBuyKey);
    final view = t.getRect(find.byKey(InventoryDock.bagScrollKey));
    // Not in the main view on open…
    expect(buy.evaluate().isEmpty || t.getRect(buy).top >= view.bottom, isTrue);
    // …but one scroll away, with the unchanged label and price.
    await t.scrollUntilVisible(
      buy,
      300,
      scrollable: find.descendant(
        of: find.byKey(InventoryDock.bagScrollKey),
        matching: find.byType(Scrollable),
      ),
    );
    await a100Settle(t);
    expect(
      find.descendant(
        of: find.byKey(InventoryDock.bagScrollKey),
        matching: buy,
      ),
      findsOneWidget,
    );
    expect(t.widget<GameButton>(buy).label, RunStashShop.goldBuyLabel(d.state));
    expect(find.text('EXPAND BAG'), findsOneWidget);
  });

  a100TestHome('picked item keeps its details under the action row', (t) async {
    await openBag(t, a56, 1.45);
    await t.tap(tile(2).first);
    await a100Settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Test Piece 2'), findsOneWidget);
    final row = t.getRect(find.byKey(InventoryDock.bagAutoEquipKey));
    expect(t.getRect(find.text('Test Piece 2')).top, greaterThan(row.bottom));
    // The grid keeps at least two full rows above it.
    final view = t.getRect(find.byKey(InventoryDock.bagScrollKey));
    final side = t.getRect(tile(0).first).height;
    expect(view.height, greaterThanOrEqualTo(2 * side));
  });

  for (final size in const [Size(360, 640), Size(360, 780), a56]) {
    for (final scale in [1.0, 1.45]) {
      a100TestHome('bag fits ${a100Label(size, scale)}', (t) async {
        await openBag(t, size, scale);
        expect(t.takeException(), isNull);
        a100ExpectWhole(t, find.text('SELL JUNK'));
        a100ExpectWhole(t, find.text('UPGRADES'));
        await t.tap(tile(1).first);
        await a100Settle(t);
        expect(t.takeException(), isNull);
      });
    }
  }
}
