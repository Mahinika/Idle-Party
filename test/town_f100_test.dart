import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/town_access.dart';
import 'package:idle_party/core/town_nav.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/home_menu_grid.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// F100 (Robert, Nov 19): in town the buildings are the entry points and
/// the quick rail is hidden. In the dungeon the rail stays as it was.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  HomeEntry byId(String id) =>
      HomeCatalog.entries.where((e) => e.id == id).single;

  Future<void> closePrompts(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await a100Settle(t);
    }
  }

  group('every rail entry keeps a home in town', () {
    test('each dungeon rail entry maps to a building or a town MENU cell', () {
      final rail = [
        ...HomeCatalog.of(HomePlace.leftRail),
        ...HomeCatalog.of(HomePlace.rightRail),
      ].map((e) => e.id).toSet();
      expect(rail, containsAll(['scrolls', 'quests', 'vault', 'daily']));
      expect(TownNavPolicy.townHomeOfRail.keys.toSet(), rail);
      final townMenu = HomeCatalog.of(
        HomePlace.menuGrid,
        town: true,
      ).map((e) => e.id).toSet();
      for (final id in rail) {
        final home = TownNavPolicy.townHomeOfRail[id]!;
        if (home.startsWith('building:')) continue;
        expect(townMenu, contains(home), reason: '$id → $home');
      }
      expect(TownNavPolicy.townHomeOfRail['quests'], 'building:guild');
      expect(TownNavPolicy.townHomeOfRail['vault'], 'building:vault');
      // Town has no rail at all.
      expect(HomeCatalog.of(HomePlace.leftRail, town: true), isEmpty);
      expect(HomeCatalog.of(HomePlace.rightRail, town: true), isEmpty);
      // The dungeon MENU grid is unchanged: no rail duplicates there.
      final dungeonMenu = HomeCatalog.of(
        HomePlace.menuGrid,
      ).map((e) => e.id).toSet();
      expect(dungeonMenu.intersection(TownNavPolicy.townMenuFromRail), isEmpty);
    });

    final base = GameLogic.createInitialState(now: shellGoldenNow);
    final states = <String, GameState>{
      'fresh': base,
      'one boss': base.copyWith(bossVictories: 1, highestFloorCleared: 2),
      'tickets': base.copyWith(
        bossVictories: 3,
        highestFloorCleared: 6,
        metaDepth: base.metaDepth.copyWith(adTickets: 2),
      ),
      'vault ready': base.copyWith(
        bossVictories: 3,
        highestFloorCleared: 6,
        metaDepth: base.metaDepth.copyWith(
          dailyVaultClears: GameLogic.dailyVaultClearTarget,
        ),
      ),
    };
    for (final e in states.entries) {
      test('same visibility and dots in town (${e.key})', () {
        final d = GameDirector.preview(initialState: e.value);
        addTearDown(d.dispose);
        final s = e.value;
        for (final pair in TownNavPolicy.townHomeOfRail.entries) {
          final rail = byId(pair.key);
          final home = pair.value;
          if (home.startsWith('menu_')) {
            final cell = byId(home);
            expect(
              cell.visible(s, d),
              rail.visible(s, d),
              reason: '${pair.key} visible',
            );
            expect(cell.badge(s), rail.badge(s), reason: '${pair.key} dot');
          }
        }
        // QUESTS → GUILD: open exactly when the rail chip showed, same dot.
        final quests = byId('quests');
        expect(TownAccess.guildOpen(s), quests.visible(s, d));
        expect(s.missions.any((m) => m.canClaim), quests.badge(s));
        // VAULT → VAULT building: always on the square; its dot is the
        // rail chip's "ready" dot.
        final vault = byId('vault');
        if (vault.visible(s, d)) {
          expect(TownAccess.vaultClaimable(s), vault.badge(s));
        }
      });
    }
  });

  for (final scale in [1.0, GameTheme.typeScaleMax]) {
    a100TestHome('town @$scale: SCROLLS one tap, buildings open, MENU mirror', (
      t,
    ) async {
      final (d, r) = await a100Pump(
        t,
        const Size(360, 780),
        scale,
        inDungeon: false,
        live: true,
        clearedFloors: 4,
        adTickets: 3,
      );
      await a100Settle(t);
      await closePrompts(t);
      expect(t.takeException(), isNull);
      expect(find.byType(RailButton), findsNothing);
      expect(find.byType(FightSeamRails), findsNothing);
      // QUESTS: the GUILD opens the QUESTS board.
      await t.tap(find.byKey(const ValueKey('town-guild')));
      await a100Settle(t);
      expect(r.route, MenuRoute.more);
      expect(r.moreSection, MoreSection.quests);
      r.close();
      await a100Settle(t);
      expect(find.text('SCROLLS'), findsOneWidget);
      expect(find.text('SCROLLS 3'), findsNothing);
      await t.tap(find.text('SCROLLS').first);
      await a100Settle(t);
      expect(find.text('Ad Tickets'), findsOneWidget);
      r.close();
      await a100Settle(t);
      r.open(MenuRoute.more);
      await a100Settle(t);
      expect(
        find.descendant(
          of: find.byType(HomeMenuGrid),
          matching: find.text('SCROLLS'),
        ),
        findsOneWidget,
      );
      if (GameLogic.showDailyRunOnHub(d.state) &&
          HubChase.forState(d.state).kind != HubChaseKind.dailyRun) {
        expect(
          find.descendant(
            of: find.byType(HomeMenuGrid),
            matching: find.text('DAILY RUN'),
          ),
          findsOneWidget,
        );
      }
    });
  }

  a100TestHome('no tickets: no MENU dot', (t) async {
    await a100Pump(
      t,
      const Size(360, 780),
      1.0,
      inDungeon: false,
      live: true,
      clearedFloors: 4,
      adTickets: 0,
    );
    await a100Settle(t);
    await closePrompts(t);
    expect(find.byKey(HomeTopBar.menuDotKey), findsNothing);
  });

  a100TestHome('dungeon: rail unchanged, no MENU dot, MENU has no SCROLLS', (
    t,
  ) async {
    final (_, r) = await a100Pump(
      t,
      const Size(360, 780),
      1.0,
      live: true,
      clearedFloors: 4,
      adTickets: 3,
    );
    await a100Settle(t);
    await closePrompts(t);
    expect(find.byType(FightSeamRails), findsOneWidget);
    expect(find.text('SCROLLS'), findsOneWidget);
    expect(find.text('SCROLLS 3'), findsNothing);
    expect(find.byKey(RailButton.countKey), findsOneWidget);
    for (final label in ['QUESTS', 'VAULT', 'RUN']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byKey(HomeTopBar.menuDotKey), findsNothing);
    r.open(MenuRoute.more);
    await a100Settle(t);
    expect(find.byType(HomeMenuGrid), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeMenuGrid),
        matching: find.textContaining('SCROLLS'),
      ),
      findsNothing,
    );
    expect(find.byKey(HomeTopBar.menuDotKey), findsNothing);
  });
}
