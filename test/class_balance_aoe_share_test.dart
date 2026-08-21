@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// Dense AoE share board (N awake trash clumped around the party).
///
/// Not a CI gate — use when comparing cleave/AoE kits vs single-target.
void main() {
  test('AoE×20 AL20 F21 share board runs', () {
    final report = runClassBalanceSim(const [
      '--share-only',
      '--trials=3',
      '--mode=live',
      '--aoe-enemies=20',
      '--al=20',
      '--floor=21',
      '--band=mid',
      '--level=40',
    ]);
    expect(report, contains('aoe-enemies: 20'));
    expect(report, contains('ascension: AL20'));
    expect(report, contains('floor: 21'));
    expect(report, contains('AoE×20'));
    expect(report, contains('| spec | share% | vs med | flag |'));
    expect(report, contains('Wrote tool/out/class_balance_share.json'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
