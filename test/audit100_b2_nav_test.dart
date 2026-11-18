import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/nav_copy.dart';
import 'package:idle_party/ui/shell/app_bottom_bar.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/home_menu_grid.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit 100, batch 2: navigation and menu naming.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  test('F004 a plain ESSENCE open lights no tile; a pick does', () {
    final r = MenuRouter();
    addTearDown(r.dispose);
    r.open(MenuRoute.essence);
    expect(r.essenceHubLit, isNull, reason: 'a tile lit by default');
    r.essencePanel = EssencePanel.tracks;
    expect(r.essenceHubLit, EssencePanel.tracks);
    r.close();
    r.open(MenuRoute.essence);
    expect(r.essenceHubLit, isNull);
    r.open(MenuRoute.essence, essence: EssencePanel.pets);
    expect(r.essenceHubLit, EssencePanel.pets);
  });

  test('F099 ESSENCE has no CODEX sub-screen; the title stays ESSENCE', () {
    final r = MenuRouter();
    addTearDown(r.dispose);
    r.open(MenuRoute.essence);
    expect(r.title, 'ESSENCE');
    r.essencePanel = EssencePanel.tracks;
    r.pushSub();
    expect(r.title, 'ESSENCE');
  });

  test('F080 a deep link to a MENU section lands on that section', () {
    final r = MenuRouter();
    addTearDown(r.dispose);
    r.open(MenuRoute.more, more: MoreSection.settings);
    expect(r.homeAtSub, isTrue);
    expect(r.title, 'SETTINGS');
    r.back();
    expect(r.route, MenuRoute.more);
    expect(r.homeAtSub, isFalse, reason: 'BACK returns to the MENU grid');
    r.close();
    r.open(MenuRoute.more);
    expect(r.homeAtSub, isFalse, reason: 'plain MENU opens the grid');
  });

  test('F081 one name for the menu: MENU', () {
    expect(AppBottomBar.labelFor(MenuRoute.more), 'MENU');
    expect(
      NavCopy.playerText('Finish on MORE · QUESTS (5).', HomeLayout.home),
      'Finish on MENU · QUESTS (5).',
    );
  });

  test('F082 no GUIDES tile that opens the INFO screen', () {
    final labels = HomeCatalog.of(HomePlace.menuGrid).map((e) => e.label);
    expect(labels, isNot(contains('GUIDES')));
    expect(labels, contains('INFO'));
  });

  test('F045 the open nav tab keeps its name', () {
    expect(
      HomeNavBar.tabSemantics('ESSENCE', selected: true),
      'ESSENCE, selected. Tap to close',
    );
    expect(HomeNavBar.tabSemantics('ESSENCE', selected: false), 'ESSENCE');
  });

  for (final size in a100Sizes) {
    for (final scale in a100Scales) {
      final tag = a100Label(size, scale);

      a100TestHome('F045 open ESSENCE tab still says ESSENCE $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.essence);
        await a100Settle(t);
        final nav = find.byType(HomeNavBar);
        expect(
          find.descendant(of: nav, matching: find.text('CLOSE')),
          findsNothing,
        );
        expect(
          find.descendant(of: nav, matching: find.text('ESSENCE')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('ESSENCE, selected. Tap to close'),
          findsOneWidget,
        );
      });

      a100TestHome('F078/F079 MENU has a title and no hole $tag', (t) async {
        final (director, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.more);
        await a100Settle(t);
        expect(find.byType(HomeMenuGrid), findsOneWidget);
        expect(find.text(HomeMenuGrid.hint), findsOneWidget);
        final n = HomeCatalog.of(
          HomePlace.menuGrid,
        ).where((e) => e.visible(director.state, director)).length;
        final wide = find.byKey(HomeMenuGrid.lastWideKey);
        if (n.isOdd) {
          expect(wide, findsOneWidget);
          final grid = t.getSize(find.byType(HomeMenuGrid));
          expect(t.getSize(wide).width, greaterThan(grid.width * 0.8));
        } else {
          expect(wide, findsNothing);
        }
        expect(t.takeException(), isNull);
      });

      a100TestHome('F009 KEY has one exit, not BACK too $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.key);
        await a100Settle(t);
        expect(find.byKey(HomeShell.backRowKey), findsNothing);
        router.open(MenuRoute.more, more: MoreSection.settings);
        await a100Settle(t);
        expect(
          find.byKey(HomeShell.backRowKey),
          findsOneWidget,
          reason: 'BACK to the MENU grid is a real step',
        );
      });

      a100TestHome('F044/F099 INFO from MENU has no section rail $tag', (
        t,
      ) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.more, more: MoreSection.info);
        await a100Settle(t);
        expect(find.byType(HomeMenuGrid), findsNothing);
        expect(find.text('SETTINGS'), findsNothing, reason: 'section rail');
        expect(find.text('CREDITS'), findsNothing, reason: 'section rail');
        expect(find.text('PATCH NOTES'), findsNothing, reason: 'MENU tile');
        expect(t.takeException(), isNull);
      });
    }
  }

  a100TestHome('F005 VAULT shows a vault card, not the QUESTS board', (
    t,
  ) async {
    final (director, router) = await a100Pump(t, a100Sizes.first, 1.0);
    final vault = HomeCatalog.of(
      HomePlace.rightRail,
    ).firstWhere((e) => e.id == 'vault');
    vault.open(t.element(find.byType(HomeShell)), director, router);
    await a100Settle(t);
    expect(find.text(HomeCatalog.vaultTitle), findsOneWidget);
    expect(router.route, MenuRoute.none);
    await t.tap(find.text('OK'));
    await a100Settle(t);
    expect(find.text(HomeCatalog.vaultTitle), findsNothing);
  });
}
