import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

import 'package:idle_party/ui/hub/hub_world_map.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/home/map_screen.dart';
import 'package:idle_party/core/hub_endgame_act.dart';

import 'shell_golden_harness.dart';

/// Polish 6 (fynd 1–13, 17–19): regressions for the bugs found in the
/// 20-point layout audit. Sizes: A56 360x780 and small 360x640, at 1.0 and
/// the 1.45 text cap.
const _sizes = [Size(360, 780), Size(360, 640)];
final _scales = [1.0, GameTheme.typeScaleMax];

Future<GameDirector> _director({
  bool fresh = false,
  bool inDungeon = true,
  bool maxed = false,
}) => withShellGoldenWeek(() async {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  var s = fresh
      ? base.copyWith(
          homeLayout: HomeLayout.home,
          vfxQuality: VfxQuality.minimal,
        )
      : base.copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: false,
          ascensionLevel: 2,
          bossVictories: 2,
          highestDungeonCleared: 1,
          highestFloorCleared: 4,
          gold: 12000,
          essence: 240,
          vfxQuality: VfxQuality.minimal,
          seenChangelogVersion: MetaSystems.currentVersion,
          metaDepth: base.metaDepth.copyWith(
            reviewPrompted: true,
            lifetimeFloorClears: 6,
          ),
        );
  if (maxed) {
    s = s.copyWith(
      heroes: [
        for (final h in s.heroes) h.copyWith(level: GameLogic.maxHeroLevel),
      ],
    );
  }
  if (inDungeon) s = GameLogic.enterDungeon(s);
  final d = GameDirector.preview(initialState: s);
  await d.boot(deferCombatLoop: true);
  d.dismissOfflineSummary();
  d.clearToast();
  return d;
});

Future<(GameDirector, MenuRouter)> _pump(
  WidgetTester tester,
  Size size,
  double scale, {
  bool fresh = false,
  bool maxed = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final director = await _director(fresh: fresh, maxed: maxed);
  final router = MenuRouter();
  _live = (director, router);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: HomeShell(director: director, router: router, onLeave: () {}),
    ),
  );
  await tester.pump();
  return (director, router);
}

(GameDirector, MenuRouter)? _live;

/// testWidgets that tears the shell down before the timer check.
void _testHome(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    _live = null;
    await body(tester);
    final live = _live;
    if (live != null) {
      await tester.pumpWidget(const SizedBox.shrink());
      live.$1.dispose();
      live.$2.dispose();
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

String _label(Size size, double scale) =>
    '${size.width.toInt()}x${size.height.toInt()} @$scale';

/// Text [text] is drawn whole: no ellipsis, no line cut, wider than its box.
void _expectWhole(WidgetTester tester, Finder text) {
  expect(text, findsWidgets);
  for (final e in text.evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
    if (!p.softWrap || p.maxLines == 1) {
      expect(
        p.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.size.width + 0.5),
        reason: 'cut: ${p.text.toPlainText()}',
      );
    }
  }
}

void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  // Polish 7 #2: at 1.45 the SETTINGS rail (QUESTS · CRAFT · INFO ·
  // SETTINGS · CREDITS) scrolled the first tab off ("UESTS").
  for (final size in _sizes) {
    for (final scale in _scales) {
      // Home MENU sections have no second rail of sections any more (audit
      // F044); the MENU grid itself is the list. Its labels stay whole and
      // a tile still lands on its section.
      _testHome('MENU grid labels are whole and on screen '
          '${_label(size, scale)}', (tester) async {
        final (_, router) = await _pump(tester, size, scale);
        router.open(MenuRoute.more);
        await _settle(tester);
        for (final label in ['INFO', 'SETTINGS', 'REDEEM']) {
          final f = find.text(label);
          expect(f, findsWidgets, reason: label);
          final r = tester.getRect(f.last);
          expect(r.left, greaterThanOrEqualTo(0), reason: label);
          expect(r.right, lessThanOrEqualTo(size.width), reason: label);
          _expectWhole(tester, f.last);
        }
        await tester.tap(find.text('SETTINGS').last);
        await _settle(tester);
        expect(router.moreSection, MoreSection.settings);
        expect(router.homeAtSub, isTrue);
        expect(find.byKey(MenuChrome.tabGridKey), findsNothing);
      });
    }
  }

  _testHome('a rail that fits keeps the one-row TabBar', (tester) async {
    final (_, router) = await _pump(tester, const Size(360, 780), 1);
    router.open(MenuRoute.more);
    await _settle(tester);
    await tester.tap(find.text('SETTINGS').first);
    await _settle(tester);
    // SOUND · DISPLAY · BAG · ACCOUNT fit at 1.0: no rows layout anywhere
    // on this screen except where labels overflow.
    expect(find.text('SOUND'), findsWidgets);
    expect(
      find.ancestor(
        of: find.text('SOUND'),
        matching: find.byKey(MenuChrome.tabGridKey),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('SOUND').first,
        matching: find.byType(TabBar),
      ),
      findsOneWidget,
    );
  });

  // Polish 7 #3: the ESSENCE hub gave no hint which panel is open.
  _testHome('ESSENCE hub lights the active tile only', (tester) async {
    final (_, router) = await _pump(tester, const Size(360, 640), 1.45);
    router.open(MenuRoute.essence);
    router.essencePanel = EssencePanel.relics;
    await _settle(tester);
    expect(find.text('ESSENCE'), findsWidgets);
    Color? rim(String label) {
      final box = tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      return (box.border! as Border).top.color;
    }

    expect(rim('RELICS'), GameTheme.toggleOnAccent);
    for (final other in ['BLESSING', 'PETS', 'CODEX']) {
      expect(rim(other), isNot(GameTheme.toggleOnAccent), reason: other);
    }
    // Screen readers hear which tile is active.
    bool? selected(String label) => tester
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          ),
        )
        .properties
        .selected;
    expect(selected('RELICS'), isTrue);
    for (final other in ['BLESSING', 'PETS', 'CODEX']) {
      expect(selected(other), isNot(isTrue), reason: other);
    }
  });

  // Polish 7 #4: the MENU button is an icon; it must stay reachable by its
  // label (the capture script looked for visible text and missed it).
  for (final scale in _scales) {
    _testHome('MENU button is labelled, 44 dp, and opens MORE @$scale', (
      tester,
    ) async {
      final (_, router) = await _pump(tester, const Size(360, 640), scale);
      final menu = find.bySemanticsLabel(RegExp(r'^MENU$'));
      expect(menu, findsOneWidget);
      final r = tester.getRect(menu);
      expect(r.width, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
      expect(r.height, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
      await tester.tap(menu);
      await _settle(tester);
      expect(router.route, MenuRoute.more);
    });
  }

  // Polish 7 #5: MAP on 360x640 was a thumbnail (~150 / ~85 px wide).
  for (final scale in _scales) {
    _testHome('MAP uses the full width on 360x640 @$scale', (tester) async {
      final (director, router) = await _pump(
        tester,
        const Size(360, 640),
        scale,
      );
      router.open(MenuRoute.map);
      await _settle(tester);
      final scroll = find.byKey(ZonePathMap.scrollKey);
      expect(scroll, findsOneWidget);
      final board = tester.getRect(find.byType(ZonePathMap));
      final image = ZonePathMap.containRect(
        Size(board.width, board.width / ZonePathMap.mapAspect),
      );
      expect(image.width, greaterThanOrEqualTo(board.width - 0.5));
      expect(board.width, greaterThanOrEqualTo(360 * 0.85));
      // It opens on the selected cave: HERE is inside the visible board.
      final here = tester.getRect(find.text('HERE'));
      expect(here.top, greaterThanOrEqualTo(board.top - 0.5));
      expect(here.bottom, lessThanOrEqualTo(board.bottom + 0.5));
      expect(director.state.dungeonId, isNotEmpty);
    });
  }

  _testHome('MAP at 360x780 @1.0 keeps the whole board', (tester) async {
    final (_, router) = await _pump(tester, const Size(360, 780), 1);
    router.open(MenuRoute.map);
    await _settle(tester);
    expect(find.byKey(ZonePathMap.scrollKey), findsNothing);
  });

  for (final scale in _scales) {
    _testHome('locked ENDGAME rows read as locked @$scale', (tester) async {
      final (director, router) = await _pump(
        tester,
        const Size(360, 640),
        scale,
      );
      router.open(MenuRoute.map, mapEndgame: true);
      await _settle(tester);
      expect(GameLogic.endgameUnlocked(director.state), isFalse);
      final n = HubEndgameAct.nodes.length;
      // Lazy list: count the rows that are built.
      final locks = find.byKey(MapScreen.lockKey);
      expect(locks, findsWidgets);
      expect(locks.evaluate().length, lessThanOrEqualTo(n));
      final line = MapScreen.endgameLockLine(director.state);
      expect(line, contains('Lv${GameLogic.maxHeroLevel}'));
      expect(find.text(line), findsWidgets);
      final first = HubEndgameAct.nodes.first.shortLabel;
      expect(
        find.bySemanticsLabel(RegExp('^$first\\. Locked\\.')),
        findsOneWidget,
      );
      final dim = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((o) => o.opacity == MapScreen.lockedPortraitOpacity);
      expect(dim.length, locks.evaluate().length);
    });
  }

  _testHome('open ENDGAME rows have no lock', (tester) async {
    final (director, router) = await _pump(
      tester,
      const Size(360, 640),
      1,
      maxed: true,
    );
    router.open(MenuRoute.map, mapEndgame: true);
    await _settle(tester);
    expect(GameLogic.endgameUnlocked(director.state), isTrue);
    expect(find.byKey(MapScreen.lockKey), findsNothing);
  });
}
