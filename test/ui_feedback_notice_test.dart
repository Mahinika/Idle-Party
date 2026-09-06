import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ui_feedback.dart';

void main() {
  test('one notice slot — celebrate replaces tip, tip queues behind celebrate', () {
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
