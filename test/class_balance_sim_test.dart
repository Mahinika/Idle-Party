@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// Runs the class-balance SpatialCombat suite (Flutter embedder required).
///
/// ```
/// flutter test test/class_balance_sim_test.dart --reporter expanded
/// flutter test test/class_balance_sim_test.dart --dart-define=QUICK=1 --reporter expanded
/// ```
void main() {
  test('class balance simulation report', () {
    // Default: light Prot+Disc F5 DPS sweep in live mode (primary balance gate).
    // FULL=1 → light band both anchors + tank/healer
    // MID=1 → mid band F5+boss DPS + tank/healer (clear-rate gate)
    // MODE=afk|bare overrides default live parity.
    const full = bool.fromEnvironment('FULL', defaultValue: false);
    const mid = bool.fromEnvironment('MID', defaultValue: false);
    const mode = String.fromEnvironment('MODE', defaultValue: 'live');
    final args = mid
        ? <String>['--trials=12', '--band=mid', '--mode=$mode']
        : full
            ? <String>['--trials=16', '--band=light', '--mode=$mode']
            : <String>['--quick', '--trials=16', '--mode=$mode'];
    final report = runClassBalanceSim(args);
    expect(report, contains('Class balance simulation'));
    expect(report, contains('DPS'));
    expect(report, contains('mode: $mode'));
  }, timeout: const Timeout(Duration(minutes: 45)));
}
