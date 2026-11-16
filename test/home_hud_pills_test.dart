import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/chunky_face.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/hud_pills.dart';

/// Batch 4: currency capsules, a floor hex, gold per minute in the cave,
/// an orange 2× and MENU as its own button. Nothing shrinks at 1.45.
void main() {
  Future<GameDirector> pumpBar(
    WidgetTester tester, {
    double scale = 1,
    bool dungeon = true,
    int pace = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var seeded = GameLogic.createInitialState(
      now: DateTime(2026, 11, 16),
    ).copyWith(
      homeLayout: HomeLayout.home,
      bossVictories: 2,
      highestFloorCleared: 4,
      gold: 1234567,
      essence: 99999,
      ascensionLevel: 12,
      combatPace: pace,
    );
    if (dungeon) seeded = GameLogic.enterDungeon(seeded);
    final director = GameDirector.preview(initialState: seeded);
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

  testWidgets('cave HUD: pills, hex floor badge, green gold per minute', (
    tester,
  ) async {
    final director = await pumpBar(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(HudPill), findsNWidgets(3));
    expect(find.text('AL 12'), findsOneWidget);
    final floor = director.state.currentRoom.floorNumber;
    expect(
      find.descendant(
        of: find.byType(HexBadge),
        matching: find.text('F$floor'),
      ),
      findsOneWidget,
    );
    final perMin = GoldIncome.hubGoldPerMinute(director.state);
    if (perMin > 0) {
      final rate = tester.widget<Text>(
        find.text('+${GoldIncome.perMinuteLabel(perMin)}'),
      );
      expect(rate.style?.color, GameTheme.gainGreen);
    }
    final menu = find.ancestor(
      of: find.byType(ChunkyFace).last,
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(menu.first).height,
        greaterThanOrEqualTo(GameTheme.minTouch));
  });

  testWidgets('2× is the orange boost face, 1× is stone', (tester) async {
    await pumpBar(tester, pace: 2);
    final fast = tester.widget<ChunkyFace>(
      find.ancestor(of: find.text('2×'), matching: find.byType(ChunkyFace)),
    );
    expect(fast.tone, ChunkyTone.orange);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpBar(tester, pace: 1);
    final slow = tester.widget<ChunkyFace>(
      find.ancestor(of: find.text('1×'), matching: find.byType(ChunkyFace)),
    );
    expect(slow.tone, ChunkyTone.stone);
  });

  for (final dungeon in [true, false]) {
    testWidgets('HUD fits 360 at text scale 1.45 (dungeon: $dungeon)', (
      tester,
    ) async {
      await pumpBar(tester, scale: GameTheme.typeScaleMax, dungeon: dungeon);
      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsNothing);
      for (final pill in find.byType(HudPill).evaluate()) {
        final r = tester.getRect(find.byWidget(pill.widget));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(360));
      }
      expect(
        tester.getRect(find.bySemanticsLabel('MENU')).right,
        lessThanOrEqualTo(360),
      );
      expect(find.byType(HexBadge), dungeon ? findsOneWidget : findsNothing);
    });
  }
}
