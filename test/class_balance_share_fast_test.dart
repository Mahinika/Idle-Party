import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// Fast share-board iterate loop for kit nerfs (not the CI HIGH gate).
///
/// Full band: omit `--focus`. Focused: pass a comma list of HeroSpecId names.
void main() {
  test('share-only balance board runs and flags HIGH/LOW text', () {
    final report = runClassBalanceSim(const [
      '--share-only',
      '--trials=2',
      '--mode=live',
      '--focus=demonology,affliction,destruction,combat',
    ]);
    expect(report, contains('share-only: true'));
    expect(
      report,
      contains('focus: demonology, affliction, destruction, combat'),
    );
    expect(report, contains('| spec | share% | vs med | flag |'));
    expect(report, contains('Wrote tool/out/class_balance_share.json'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
