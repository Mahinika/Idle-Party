import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';

void main() {
  testWidgets('a mid-fight question closes when the party leaves', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 17);
    final state = GameLogic.createInitialState(
      now: now,
    ).copyWith(inDungeon: true);
    final director = GameDirector.preview(initialState: state);
    await director.boot();
    director.enterDungeon();
    expect(director.state.inDungeon, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => DismissDialogOnLeave(
                      director: director,
                      child: const Text('SWITCH TO FARM?'),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('SWITCH TO FARM?'), findsOneWidget);

    director.leaveDungeon();
    await tester.pumpAndSettle();
    expect(find.text('SWITCH TO FARM?'), findsNothing);
    expect(director.state.inDungeon, isFalse);
    director.dispose();
  });
}
