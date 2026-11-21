import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/meta/codex_overlay.dart';
import 'package:idle_party/ui/shell/craft_overlay.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/home_menu_grid.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit F099 (Robert): CRAFT and CODEX live only in MENU.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  test('the catalog has CRAFT and CODEX on the MENU grid only', () {
    final labels = <String, List<HomePlace>>{};
    for (final e in HomeCatalog.entries) {
      labels.putIfAbsent(e.label, () => []).add(e.place);
    }
    expect(labels['CRAFT'], [HomePlace.menuGrid]);
    expect(labels['CODEX'], [HomePlace.menuGrid]);
  });

  test('source scan: only MENU (and the town FORGE) opens CRAFT', () {
    final craftOpeners = <String>[];
    final codexHosts = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('more: MoreSection.craft')) craftOpeners.add(f.path);
      if (text.contains('CodexOverlay(director')) codexHosts.add(f.path);
    }
    // MENU grid, plus the town FORGE building: the one documented extra
    // entry to CRAFT (Robert kept it on purpose).
    craftOpeners.sort();
    expect(craftOpeners, [
      'lib/ui/shell/home/home_catalog.dart',
      'lib/ui/shell/home/town_viewport.dart',
    ]);
    expect(codexHosts, ['lib/ui/shell/power_meta_pillars.dart']);
  });

  test('deep links still land through the MENU route', () {
    final r = MenuRouter();
    addTearDown(r.dispose);
    // Chase "CODEX · PETS" (ChaseOp.navMoreInfo) lands on the CODEX pane.
    r.open(MenuRoute.more, more: MoreSection.info, infoPane: 1);
    expect(r.route, MenuRoute.more);
    expect(r.moreSection, MoreSection.info);
    expect(r.moreInfoPane, 1);
    expect(r.homeAtSub, isTrue);
    r.open(MenuRoute.more, more: MoreSection.craft);
    expect(r.moreSection, MoreSection.craft);
    expect(r.title, 'CRAFT');
    expect(r.homeAtSub, isTrue);
  });

  for (final scale in a100Scales) {
    final size = const Size(360, 640);
    final tag = a100Label(size, scale);

    a100TestHome('ESSENCE hub has no CRAFT or CODEX $tag', (t) async {
      final (_, router) = await a100Pump(t, size, scale, maxed: true);
      router.open(MenuRoute.essence);
      await a100Settle(t);
      expect(find.text('BLESSING'), findsOneWidget);
      expect(find.text('CODEX'), findsNothing);
      expect(find.text('CRAFT'), findsNothing);
      expect(t.takeException(), isNull);
    });

    a100TestHome('MENU CODEX and CRAFT tiles land, 44 dp $tag', (t) async {
      final (_, router) = await a100Pump(t, size, scale, maxed: true);
      router.open(MenuRoute.more);
      await a100Settle(t);
      final grid = find.byType(HomeMenuGrid);
      expect(grid, findsOneWidget);
      expect(t.takeException(), isNull, reason: 'grid');
      for (final label in ['CODEX', 'CRAFT']) {
        final tile = find.descendant(of: grid, matching: find.text(label));
        expect(tile, findsOneWidget, reason: label);
        final hit = find.ancestor(of: tile, matching: find.byType(InkWell));
        final r = t.getRect(hit.first);
        expect(r.height, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
        expect(r.bottom, lessThanOrEqualTo(size.height));
      }
      await t.tap(find.descendant(of: grid, matching: find.text('CODEX')));
      await a100Settle(t);
      expect(router.moreSection, MoreSection.info);
      expect(router.moreInfoPane, 1);
      expect(find.byType(CodexOverlay), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'CODEX');

      router.close();
      router.open(MenuRoute.more);
      await a100Settle(t);
      await t.tap(
        find.descendant(
          of: find.byType(HomeMenuGrid),
          matching: find.text('CRAFT'),
        ),
      );
      await a100Settle(t);
      expect(router.moreSection, MoreSection.craft);
      expect(find.byType(CraftOverlay), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
