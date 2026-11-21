import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/hud_pills.dart';
import 'package:idle_party/ui/shell/shell_common.dart';

import 'shell_golden_harness.dart';

/// Audit 100, batch 1: compact big numbers, a HUD that keeps the gold amount
/// at 1.45, one pill height, speed only in a cave, a MENU caption, and no
/// zero pills on a new save.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  group('formatCount', () {
    test('short scale past a million', () {
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1,000');
      expect(formatCount(12345), '12.3k');
      expect(formatCount(999949), '999.9k');
      expect(formatCount(999950), '1M');
      expect(formatCount(1000000), '1M');
      expect(formatCount(987654321), '987.7M');
      expect(formatCount(999960000), '1B');
      expect(formatCount(4200000000000), '4.2T');
      expect(formatCount(987654321098765), '987.7T');
      expect(formatCount(1000000000000000), '1Qa');
      expect(formatCount(2000000000000000000), '2Qi');
      expect(formatCount(-12345), '-12.3k');
    });

    test('gold keeps commas under a million and suffixes above', () {
      expect(formatGold(12000), '12,000g');
      expect(formatGold(987654321098765), '987.7Tg');
    });

    test('a huge value never prints more than 7 characters', () {
      for (var e = 6; e <= 18; e++) {
        final n = int.parse('9' * e);
        expect(formatCount(n).length, lessThanOrEqualTo(7), reason: '$n');
      }
    });
  });

  Future<GameDirector> pumpBar(
    WidgetTester tester, {
    required GameState state,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [HomeTopBar(director: director, router: router)],
          ),
        ),
      ),
    );
    await tester.pump();
    return director;
  }

  GameState seeded({
    int gold = 12000,
    int essence = 240,
    int al = 2,
    int bosses = 2,
    bool dungeon = true,
  }) {
    var s = GameLogic.createInitialState(now: DateTime(2026, 11, 16)).copyWith(
      homeLayout: HomeLayout.home,
      bossVictories: bosses,
      highestFloorCleared: bosses > 0 ? 4 : 0,
      gold: gold,
      essence: essence,
      ascensionLevel: al,
    );
    if (dungeon) s = GameLogic.enterDungeon(s);
    return s;
  }

  bool clipped(WidgetTester tester, Finder text) {
    final p = tester.renderObject<RenderParagraph>(text);
    return p.didExceedMaxLines;
  }

  for (final scale in [1.0, GameTheme.typeScaleMax]) {
    testWidgets('huge gold and essence stay whole at $scale', (tester) async {
      await pumpBar(
        tester,
        scale: scale,
        state: seeded(gold: 987654321098765, essence: 4200000000000),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('4.2T'), findsOneWidget);
      final gold = find.text('987.7Tg');
      expect(gold, findsOneWidget);
      expect(clipped(tester, gold), isFalse);
      expect(tester.getRect(gold).right, lessThanOrEqualTo(360));
    });
  }

  testWidgets('AL, essence and gold pills share one height', (tester) async {
    final d = await pumpBar(tester, state: seeded());
    expect(d.state.gold, 12000);
    final pills = find.byType(HudPill).evaluate().toList();
    expect(pills.length, greaterThanOrEqualTo(3));
    final heights = {
      for (final e in pills)
        tester.getSize(find.byWidget(e.widget)).height.roundToDouble(),
    };
    expect(heights.length, 1, reason: '$heights');
  });

  testWidgets('a new save has no AL 0 or 0 essence pill', (tester) async {
    await pumpBar(
      tester,
      state: seeded(gold: 0, essence: 0, al: 0, bosses: 0),
    );
    expect(find.text('AL 0'), findsNothing);
    expect(find.byType(HudPill), findsOneWidget);
    expect(HomeTopBar.showsMetaPills(seeded(essence: 0, al: 0, bosses: 1)),
        isTrue);
  });

  testWidgets('speed is a cave control; town has none', (tester) async {
    await pumpBar(tester, state: seeded(dungeon: false));
    expect(find.text('1×'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^SPEED')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpBar(tester, state: seeded());
    expect(find.text('1×'), findsOneWidget);
    expect(find.text('▸'), findsOneWidget);
  });

  testWidgets('MENU has a caption through 1.45 and keeps one label', (
    tester,
  ) async {
    await pumpBar(tester, state: seeded());
    expect(find.text('MENU'), findsOneWidget);
    expect(find.bySemanticsLabel('MENU'), findsOneWidget);
    final r = tester.getRect(find.bySemanticsLabel('MENU'));
    expect(r.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(r.right, lessThanOrEqualTo(360));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpBar(tester, state: seeded(), scale: GameTheme.typeScaleMax);
    // The word stays on the face through typeScaleMax. No shrink, one label.
    expect(find.text('MENU'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    expect(find.bySemanticsLabel('MENU'), findsOneWidget);
    final scaled = tester.getRect(find.bySemanticsLabel('MENU'));
    expect(scaled.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(scaled.right, lessThanOrEqualTo(360));
  });
}
