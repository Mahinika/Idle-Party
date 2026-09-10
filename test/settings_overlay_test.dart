import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/ui/shell/settings_overlay.dart';

void main() {
  testWidgets('settings splits sound display bag and account into local tabs', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);

    await tester.pumpWidget(_host(director));

    expect(find.text('Mute all sound'), findsOneWidget);
    expect(find.text('UI text scale'), findsNothing);

    await tester.tap(_tab('DISPLAY'));
    await tester.pumpAndSettle();
    expect(find.text('UI text scale'), findsOneWidget);
    expect(find.text('Mute all sound'), findsNothing);

    await tester.tap(_tab('BAG'));
    await tester.pumpAndSettle();
    expect(find.text('AUTO-SELL · GOLD'), findsOneWidget);
    expect(find.text('UI text scale'), findsNothing);

    await tester.tap(_tab('ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY NOTES (LOCAL)'), findsOneWidget);
    expect(find.text('AUTO-SELL · GOLD'), findsNothing);
  });

  testWidgets('bag cleanup deep link opens the BAG tab', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);

    await tester.pumpWidget(_host(director, bagFiltersScrollNonce: 1));
    await tester.pumpAndSettle();

    expect(find.text('AUTO-SELL · GOLD'), findsOneWidget);
    expect(find.text('Mute all sound'), findsNothing);
  });
}

Widget _host(GameDirector director, {int bagFiltersScrollNonce = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 700,
        child: SettingsOverlay(
          director: director,
          onClose: () {},
          bagFiltersScrollNonce: bagFiltersScrollNonce,
        ),
      ),
    ),
  );
}

Finder _tab(String label) {
  return find.descendant(of: find.byType(TabBar), matching: find.text(label));
}
