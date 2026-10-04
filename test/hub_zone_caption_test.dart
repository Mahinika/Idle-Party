import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hub/hub_world_map.dart';

void main() {
  testWidgets('the zone name under the map is tall enough to tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectedZoneCaption(
            dungeon: DungeonCatalog.byId('storm'),
            unlocked: true,
            partyLevel: 28,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(GestureDetector)).height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
    await tester.tap(find.text('Stormwake Hollow'));
    await tester.pumpAndSettle();
    expect(find.text('CLOSE'), findsOneWidget);
  });
}
