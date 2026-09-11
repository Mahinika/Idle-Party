import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/ui/apex_forge_panel.dart';

void main() {
  testWidgets('CRAFT sheet is hero then slot then one craft button', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: SingleChildScrollView(
              child: ApexHubPanel(director: director),
            ),
          ),
        ),
      ),
    );

    expect(find.text('HERO'), findsOneWidget);
    expect(find.text('SLOT'), findsOneWidget);
    expect(find.text('RECIPE'), findsOneWidget);
    expect(find.text('CRAFT R1'), findsOneWidget);
    expect(find.text('PARTY GOALS'), findsNothing);
    expect(find.text('FARM TARGET'), findsNothing);
    expect(find.text('CHANGE GOAL'), findsNothing);
    expect(find.text('OWNED R0'), findsNothing);
  });
}
