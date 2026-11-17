import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/character_equip_panel.dart';
import 'package:idle_party/ui/hero_look_row.dart';

void main() {
  testWidgets('GEAR doll has no race LOOK grid after party create', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = GameLogic.createInitialState(now: DateTime(2026, 9, 20));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CharacterEquipPanel(
              state: state,
              heroIndex: 0,
              onSelectHero: (_) {},
              selectedItemId: null,
              onSelectItem: (_) {},
              onUnequip: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HeroLookRow), findsNothing);
    expect(find.text('LOOK'), findsNothing);
    expect(find.text('DWARF'), findsNothing);
    expect(find.text('N.ELF'), findsNothing);
  });

  testWidgets('GEAR stats line never starts with a "·" separator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = GameLogic.createInitialState(now: DateTime(2026, 9, 20));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CharacterEquipPanel(
              state: state,
              heroIndex: 0,
              onSelectHero: (_) {},
              selectedItemId: null,
              onSelectItem: (_) {},
              onUnequip: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final stats = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('HP ') || s.contains('WIPED'))
        .toList();
    expect(stats, isNotEmpty);
    for (final s in stats) {
      expect(s.trimLeft().startsWith('·'), isFalse, reason: s);
    }
  });
}
