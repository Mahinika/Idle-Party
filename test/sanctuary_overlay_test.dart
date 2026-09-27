import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';

void main() {
  testWidgets('CAMP stays up when a track costs more than essence', (
    tester,
  ) async {
    // Gold Find Lv68 costs 831e. 745e matches the live wallet that painted
    // the red "Invalid argument(s): 1" screen after bulk buys.
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        essence: 745,
        ascensionLevel: 1,
        sanctuaryGoldLevel: 68,
      ),
    );
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SanctuaryOverlay(director: director),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Gold Find'), findsWidgets);
    expect(find.textContaining('War Altar'), findsWidgets);
  });
}
