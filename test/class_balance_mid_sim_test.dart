@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// One-shot mid-band balance probe (not default CI).
void main() {
  test('mid band class balance', () {
    final report = runClassBalanceSim(const [
      '--trials=12',
      '--band=mid',
      '--mode=live',
    ]);
    expect(report, contains('mid'));
    expect(report, contains('mode: live'));
    expect(report, contains('DPS'));
  }, timeout: const Timeout(Duration(minutes: 60)));
}
