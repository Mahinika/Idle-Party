@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// Dense AoE share board (N awake trash clumped around the party).
///
/// Combat is single-target identity; it must not sit above the live-light
/// ±20% DPS-share band on this board (`docs/archive/audits/2026-09-13-aoe-cata.md`).
void main() {
  test('AoE pack focus combat vs caster kits', () {
    final report = runClassBalanceSim(const [
      '--share-only',
      // Match the live-light gate trial count — AoE×12 is deterministic but
      // we keep parity with `class_balance_gate_test`.
      '--trials=4',
      '--mode=live',
      '--aoe-enemies=12',
      '--focus=combat,elemental,fire,assassination,subtlety,unholy,feral,demonology,enhancement,marksmanship,arms,fury',
    ]);
    expect(report, contains('aoe-enemies: 12'));
    expect(report, contains('| spec | share% | vs med | flag |'));

    final parsed = _parseCombatShareBoard(report);
    expect(parsed, isNotNull, reason: 'share board missing combat row');
    final (:median, :combatShare, :combatFlag) = parsed!;
    final hi = median * 1.20;
    expect(
      combatShare,
      lessThanOrEqualTo(hi + 0.05),
      reason: 'combat AoE×12 share $combatShare% above HIGH band '
          '(median ${median.toStringAsFixed(1)}%, cap ${hi.toStringAsFixed(1)}%)',
    );
    expect(combatFlag, isNot(contains('HIGH')));
    expect(report.contains('- **HIGH** combat'), isFalse);
  }, timeout: const Timeout(Duration(minutes: 8)));

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

/// Parses median share % and the combat row from a `--share-only` report.
({double median, double combatShare, String combatFlag})? _parseCombatShareBoard(
  String report,
) {
  final medianMatch = RegExp(r'vs median ([\d.]+)%').firstMatch(report);
  final combatMatch = RegExp(
    r'^\| combat \| ([\d.]+) \| [^|]+\| ([^|]*)\|',
    multiLine: true,
  ).firstMatch(report);
  if (medianMatch == null || combatMatch == null) return null;
  return (
    median: double.parse(medianMatch.group(1)!),
    combatShare: double.parse(combatMatch.group(1)!),
    combatFlag: combatMatch.group(2)!.trim(),
  );
}