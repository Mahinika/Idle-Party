import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/character_equip_panel.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/meta/roster_panel.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';
import 'package:idle_party/ui/shell/menu_surface.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit 100, batch 5: GEAR / BAG / MERGE / ROSTER.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  for (final size in a100Sizes) {
    for (final scale in a100Scales) {
      final tag = a100Label(size, scale);

      a100TestHome('F010/F012/F052 GEAR names, stats up top $tag', (t) async {
        final (director, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.gear, gear: GearPanel.gear);
        await a100Settle(t);
        final plain = GameLogic.plainPlayerChrome(director.state);
        final first = director.state.heroes.first;
        expect(
          find.textContaining(first.displayName(plainEnglish: plain)),
          findsWidgets,
        );
        expect(find.bySemanticsLabel('Previous hero'), findsNothing);
        final stats = find.byKey(CharacterEquipPanel.heroStatsLineKey);
        expect(stats, findsOneWidget);
        final nav = t.getRect(find.byType(HomeNavBar));
        expect(t.getRect(stats).bottom, lessThan(nav.top));
        expect(t.takeException(), isNull);
      });

      a100TestHome('F011/F046 open slots dashed, tabs under title $tag', (
        t,
      ) async {
        final (director, router) = await a100Pump(t, size, scale, fresh: true);
        director.unequipSlot(EquipmentSlot.ring2);
        router.open(MenuRoute.gear, gear: GearPanel.gear);
        await a100Settle(t);
        expect(find.byKey(PaperDollSlot.emptyFrameKey), findsWidgets);
        final tabs = find.byKey(MenuSurface.gearTabsKey);
        if (tabs.evaluate().isNotEmpty) {
          expect(t.getRect(tabs).top, lessThan(size.height * 0.35));
        }
        expect(t.takeException(), isNull);
      });

      a100TestHome('F014/F053/F056 empty MERGE leads with OPEN BAG $tag', (
        t,
      ) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.gear, gear: GearPanel.merge);
        await a100Settle(t);
        final open = find.byKey(InventoryDock.mergeOpenBagKey);
        expect(open, findsOneWidget);
        final merge = find.byKey(InventoryDock.mergeButtonKey);
        expect(t.getRect(open).top, lessThan(t.getRect(merge).top));
        expect(t.widget<GameButton>(merge).dense, isTrue);
        expect(find.text(InventoryDock.mergePickFirst), findsOneWidget);
        final p = t.widget<Text>(find.text(InventoryDock.mergePickFirst));
        expect(p.style?.fontStyle, FontStyle.italic);
        router.gearPanel = GearPanel.bag;
        await a100Settle(t);
        expect(find.textContaining('long-press for tip'), findsNothing);
        expect(t.takeException(), isNull);
      });

      a100TestHome('F015/F016 ROSTER in a cave reads normal $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.gear, gear: GearPanel.roster);
        await a100Settle(t);
        if (find.byType(TeamCompositionOverlay).evaluate().isEmpty) return;
        expect(
          find.byKey(TeamCompositionOverlay.leaveToSwapKey),
          findsOneWidget,
        );
        expect(find.textContaining('EMPTY ·'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
