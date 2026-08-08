import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// Fast live-light CI gate for class balance (trials=4).
///
/// Full sweeps stay in [class_balance_sim_test] / mid sim (manual or long CI).
void main() {
  test('live light class balance gate', () {
    final report = runClassBalanceSim(const [
      '--quick',
      // Slightly more trials than the old 4 — cuts CI noise on ±20% edge kits.
      '--trials=6',
      '--mode=live',
    ]);
    expect(report, contains('Class balance simulation'));
    expect(report, contains('mode: live'));
    // Fail CI when any kit sits above the ±20% DPS-share band.
    final highLines = report
        .split('\n')
        .where((line) => line.contains('- **HIGH** '))
        .toList();
    expect(
      highLines,
      isEmpty,
      reason: 'DPS HIGH outliers must be tuned before merge:\n'
          '${highLines.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 12)));
}
