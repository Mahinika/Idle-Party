import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';

/// Polish 4: ESSENCE tiles carry icons.
void main() {
  testWidgets('every ESSENCE tile has an icon tile; locked ones are dim', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        highestFloorCleared: 1,
      ),
    );
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EssenceTilesScreen(director: director, router: router),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final label in ['BLESSING', 'RELICS', 'PETS', 'CODEX', 'CRAFT']) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      final icon = find.descendant(
        of: tile,
        matching: find.byType(UpgradeIconTile),
      );
      expect(icon, findsOneWidget, reason: label);
      final open = tester.widget<InkWell>(tile.first).onTap != null;
      expect(tester.widget<UpgradeIconTile>(icon).dim, !open, reason: label);
    }
  });
}
