import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

void main() {
  test('fight seam rails still open on SCROLLS', () {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(
        now: DateTime(2026, 11, 9),
      ).copyWith(homeLayout: HomeLayout.home, bossVictories: 1),
    );
    addTearDown(director.dispose);
    final entries = FightSeamRails.visibleEntries(director.state, director);
    expect(entries.first.id, 'scrolls');
  });

  testWidgets('home fight rails stay readable at shipped text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seeded = GameLogic.createInitialState(
      now: DateTime.now().add(const Duration(minutes: 10)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      bossVictories: 1,
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
            textScaler: const TextScaler.linear(1.45),
          ),
          child: child!,
        ),
        home: HomeShell(director: director, router: router, onLeave: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Healer'), findsWidgets);
    expect(find.text('SCROLLS'), findsOneWidget);
    final railButton = tester.getSize(find.byType(RailButton).first);
    expect(railButton.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(railButton.width, greaterThanOrEqualTo(GameTheme.minTouch));
    final rail = tester.getSize(find.byType(FightSeamRails));
    expect(rail.height, greaterThanOrEqualTo(GameTheme.minTouch));
  });
}
