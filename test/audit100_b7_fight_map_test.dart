import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hub/hub_world_map.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/home_gold_dock.dart';
import 'package:idle_party/ui/shell/home/map_screen.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit 100, batch 7: FIGHT / MAP / TOWN / first session.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  for (final size in a100Sizes) {
    for (final scale in a100Scales) {
      final tag = a100Label(size, scale);

      a100TestHome('F018 enemy title is whole $tag', (t) async {
        await a100Pump(t, size, scale);
        await a100Settle(t);
        final title = find.byKey(TargetCornerHud.titleKey);
        if (title.evaluate().isEmpty) return;
        for (final e
            in find
                .descendant(of: title, matching: find.byType(RichText))
                .evaluate()) {
          final p = e.renderObject! as RenderParagraph;
          expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
        }
        expect(t.takeException(), isNull);
      });

      a100TestHome('F020 party names are not cut for a level $tag', (t) async {
        final (director, _) = await a100Pump(t, size, scale, full: true);
        await a100Settle(t);
        for (final h in director.state.heroes) {
          final name = h.name.trim();
          if (name.isEmpty) continue;
          if (find.text(name).evaluate().isEmpty) continue;
          a100ExpectWhole(t, find.text(name));
        }
        expect(t.takeException(), isNull);
      });

      a100TestHome('F021/F022 FULL: panel arrow and buy dots $tag', (t) async {
        await a100Pump(t, size, scale, full: true);
        await a100Settle(t);
        // The seam toggle is an arrow now (Robert), no word labels.
        final seam = find.byType(FightFieldControls);
        for (final word in ['BIG VIEW', 'BIG', 'FORGE', 'TALL']) {
          expect(
            find.descendant(of: seam, matching: find.text(word)),
            findsNothing,
            reason: word,
          );
        }
        expect(
          find.descendant(of: seam, matching: find.text('▲')),
          findsOneWidget,
        );
        expect(find.byKey(MenuChrome.segmentDotKey(0)), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      a100TestHome('seam arrow: ▲ grows the upgrade panel, ▼ shrinks $tag', (
        t,
      ) async {
        final (director, _) = await a100Pump(
          t,
          size,
          scale,
          full: true,
          live: true,
        );
        await a100Settle(t);
        final h = t.ensureSemantics();
        final face = find.byKey(FightFieldControls.panelToggleFaceKey);
        // FULL = big fight, only the FORGE/CAMP/MARKET row: ▲ expands.
        expect(director.state.homePanelFull, isTrue);
        expect(find.byType(UpgradePanel), findsNothing);
        expect(
          find.descendant(of: face, matching: find.text('▲')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Expand upgrades'), findsOneWidget);
        expect(find.byTooltip('Expand upgrades'), findsOneWidget);
        final r = t.getRect(face);
        expect(r.width, closeTo(r.height, 2.01), reason: 'square-ish face');
        expect(r.width, lessThanOrEqualTo(GameTheme.minTouch));
        final hit = t.getRect(
          find.ancestor(of: face, matching: find.byType(InkWell)).first,
        );
        expect(hit.width, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
        expect(hit.height, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
        expect(hit.right, lessThanOrEqualTo(size.width));

        await t.tap(face);
        await a100Settle(t);
        // SPLIT = the upgrade list under the fight: ▼ shrinks it back.
        expect(director.state.homePanelFull, isFalse);
        expect(find.byType(UpgradePanel), findsOneWidget);
        expect(
          find.descendant(of: face, matching: find.text('▼')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Show big fight view'), findsOneWidget);
        expect(find.byTooltip('Show big fight view'), findsOneWidget);

        await t.tap(face);
        await a100Settle(t);
        expect(director.state.homePanelFull, isTrue);
        expect(find.byType(UpgradePanel), findsNothing);
        h.dispose();
        expect(t.takeException(), isNull);
      });

      a100TestHome('F039 locked FORGE/CAMP/MARKET: padlocks, lock card $tag', (
        t,
      ) async {
        final (director, _) = await a100Pump(
          t,
          size,
          scale,
          fresh: true,
          full: true,
        );
        await a100Settle(t);
        expect(find.byKey(MenuChrome.segmentLockKey(2)), findsOneWidget);
        await t.tap(find.text('MARKET').last);
        await a100Settle(t);
        expect(find.byKey(UpgradePanel.lockedCardKey), findsOneWidget);
        final h = director.state.heroes.first;
        expect(find.text('${h.name}  Lv${h.level}'), findsNothing);
        expect(t.takeException(), isNull);
      });

      a100TestHome('F049/F050/F089 PATH card, padlocks, here $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.map);
        await a100Settle(t);
        expect(find.byKey(MapScreen.zoneCardKey), findsOneWidget);
        expect(find.byKey(MapZoneMarker.lockKey), findsWidgets);
        expect(find.text(MapScreen.youAreHere), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      a100TestHome('F088 ENDGAME lock line once $tag', (t) async {
        final (director, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.map, mapEndgame: true);
        await a100Settle(t);
        final line = MapScreen.endgameLockLine(director.state);
        expect(find.byKey(MapScreen.endgameLockHeaderKey), findsOneWidget);
        expect(find.text(line), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      a100TestHome('F095 locked ESSENCE tiles have padlocks $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale, fresh: true);
        router.open(MenuRoute.essence);
        await a100Settle(t);
        expect(find.byKey(EssenceTilesScreen.lockKey), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  }

  test('F090 town line does not repeat the cave name', () {
    expect(
      townProgressLine(ascensionLevel: 0, cave: 'Sandy Caverns'),
      isNot(contains('Sandy')),
    );
  });

  test(
    'F094 no BOSS NEXT while the first-climb coach says the floor',
    () async {
      final d = await a100Director(fresh: true);
      addTearDown(d.dispose);
      expect(firstBossBitForTest(d.state, GameLogic.firstBossFloor - 1), '');
      expect(firstBossBitForTest(d.state, GameLogic.firstBossFloor), ' · BOSS');
    },
  );

  test('F093 town ENTER pulses while the coach says Tap ENTER', () async {
    final d = await a100Director(fresh: true, inDungeon: false);
    addTearDown(d.dispose);
    expect(TownEnterCoach.active(d.state), isTrue);
    final inside = await a100Director(fresh: true);
    addTearDown(inside.dispose);
    expect(TownEnterCoach.active(inside.state), isFalse);
  });

  test('F060 FORGE rows lead with a level like CAMP', () async {
    final d = await a100Director(fresh: true);
    addTearDown(d.dispose);
    expect(
      ForgeOverlay.levelPrefix(d.state, PartyUpgradeType.attack),
      'Lv0 · ',
    );
  });

  test('F061 STA accent is on the dusk palette, not moss', () {
    expect(GameTheme.statVitality, isNot(const Color(0xFF7E9A5E)));
  });

  test('F049 zone detail names cleared, here and party level', () async {
    final d = await a100Director();
    addTearDown(d.dispose);
    final def = DungeonCatalog.byId(d.state.dungeonId);
    final line = MapScreen.zoneDetail(d.state, def, open: true, mean: 5);
    expect(line, contains('You are here'));
    expect(line, contains('Party level 5'));
    expect(line, isNot(contains(' / ')));
  });

  test('F022 dock dots are off while FORGE is locked', () async {
    final d = await a100Director(fresh: true);
    addTearDown(d.dispose);
    expect(HomeGoldDock.dots(d.state), [false, false, false]);
  });
}
