import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ui_feedback.dart';
import 'package:idle_party/ui/shell/dungeon_loot_log.dart';

void main() {
  test(
    'one notice slot — celebrate replaces tip, tip queues behind celebrate',
    () {
      final ui = UiFeedback();
      expect(ui.showToast('Bought ATK', life: 2), isTrue);
      expect(ui.toast, 'Bought ATK');
      expect(ui.noticeKind, NoticeKind.tip);

      expect(ui.presentClear('F1 CLEAR · +10g', life: 2.8), isTrue);
      expect(ui.toast, 'F1 CLEAR · +10g');
      expect(ui.celebrating, isTrue);
      expect(ui.clearSummary, 'F1 CLEAR · +10g');

      expect(ui.showToast('New ability!', life: 2), isTrue);
      expect(ui.toast, 'F1 CLEAR · +10g'); // still celebrate
      ui.tick(3);
      expect(ui.toast, 'New ability!');
      expect(ui.noticeKind, NoticeKind.tip);
    },
  );

  test('loot log keeps the last five floor lines', () {
    final ui = UiFeedback();
    expect(ui.pushLootLine('  '), isFalse);
    expect(ui.pushLootLine('F1 CLEAR · +10g'), isTrue);
    expect(ui.pushLootLine('F1 CLEAR · +10g'), isFalse);
    for (var floor = 2; floor <= 7; floor++) {
      expect(ui.pushLootLine('F$floor CLEAR · +${floor}0g'), isTrue);
    }
    expect(ui.lootLog, [
      'F3 CLEAR · +30g',
      'F4 CLEAR · +40g',
      'F5 CLEAR · +50g',
      'F6 CLEAR · +60g',
      'F7 CLEAR · +70g',
    ]);
    ui.clearLootLog();
    expect(ui.lootLog, isEmpty);
  });

  testWidgets('loot log paints the lines, newest last', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DungeonLootLog(lines: ['F1 CLEAR · +10g', 'F2 CLEAR · +20g']),
        ),
      ),
    );
    expect(find.text('F1 CLEAR · +10g'), findsOneWidget);
    expect(find.text('F2 CLEAR · +20g'), findsOneWidget);
    final first = tester.getTopLeft(find.text('F1 CLEAR · +10g'));
    final second = tester.getTopLeft(find.text('F2 CLEAR · +20g'));
    expect(second.dy, greaterThan(first.dy));
  });

  test('danger replaces celebrate immediately', () {
    final ui = UiFeedback();
    ui.presentClear('F1 CLEAR');
    expect(ui.showToast('WIPED', life: 4, kind: NoticeKind.danger), isTrue);
    expect(ui.toast, 'WIPED');
    expect(ui.noticeKind, NoticeKind.danger);
    expect(ui.celebrating, isFalse);
  });
}
