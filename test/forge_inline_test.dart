import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';

void main() {
  testWidgets('inline SPLIT forge lists all tracks without All tracks link', (
    tester,
  ) async {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      gold: 5000,
      highestFloorCleared: 2,
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: ForgeOverlay(
              director: director,
              inlineUnderFight: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All tracks'), findsNothing);
    expect(find.text('AP'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('MASTERY'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MASTERY'), findsOneWidget);
  });
}
