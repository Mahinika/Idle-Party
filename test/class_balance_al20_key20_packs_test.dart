@Tags(['sim'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// AL20 KEY+20 pack ladder: ST / 5 / 10 / 20 awake trash.
///
/// F1 + 5-man (tanks/healers pad) so KEY+20 actually records DPS. F21 3-man
/// one-shots casters before the first bolt.
void main() {
  const packN = int.fromEnvironment('AOE_N', defaultValue: 0);
  const focusRaw = String.fromEnvironment('FOCUS', defaultValue: '');
  const mergeOnly = bool.fromEnvironment('MERGE', defaultValue: false);
  final packs = packN > 0 ? <int>[packN] : const [1, 5, 10, 20];

  test('AL20 KEY+20 pack ladder', () {
    if (mergeOnly) return;
    final boards = <int, Map<String, dynamic>>{};
    for (final n in packs) {
      boards[n] = _runPack(n, focusRaw: focusRaw);
    }
    if (packs.length == 4) {
      final md = comparisonMarkdown(boards);
      File('tool/out/al20_key20_packs.md').writeAsStringSync(md);
      // ignore: avoid_print
      print(md);
      _assertHonestPackScale(boards);
    }
  }, timeout: const Timeout(Duration(minutes: 90)));

  test('AL20 KEY+20 merge comparison', () {
    if (!mergeOnly) return;
    final boards = <int, Map<String, dynamic>>{};
    for (final n in const [1, 5, 10, 20]) {
      final file = File('tool/out/al20_key20_x$n.json');
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      boards[n] =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }
    final md = comparisonMarkdown(boards);
    File('tool/out/al20_key20_packs.md').writeAsStringSync(md);
    // ignore: avoid_print
    print(md);
    _assertHonestPackScale(boards);
  });
}

Map<String, dynamic> _runPack(int n, {String focusRaw = ''}) {
  final jsonPath = 'tool/out/al20_key20_x$n.json';
  final args = <String>[
    '--share-only',
    '--trials=2',
    '--mode=live',
    '--band=mid',
    '--level=100',
    '--al=20',
    '--key=20',
    '--floor=1',
    '--party-size=5',
    '--max-seconds=30',
    '--all-specs',
    '--aoe-enemies=$n',
    '--json-out=$jsonPath',
    if (focusRaw.isNotEmpty) '--focus=$focusRaw',
  ];
  final report = runClassBalanceSim(args);
  expect(report, contains('KEY: +20'));
  expect(report, contains('aoe-enemies: $n'));
  expect(report, contains('ascension: AL20'));
  expect(report, contains('party-size: 5'));
  final json =
      jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
  expect(json['key'], 20);
  expect(json['al'], 20);
  expect(json['aoeEnemies'], n);
  expect(json['partySize'], 5);
  return json;
}

void _assertHonestPackScale(Map<int, Map<String, dynamic>> boards) {
  final combat20 = _dps(boards[20]!, 'combat');
  final ele20 = _dps(boards[20]!, 'elemental');
  expect(ele20, greaterThan(0), reason: 'Elemental recorded 0 DPS on ×20');
  expect(combat20, greaterThan(0), reason: 'Combat recorded 0 DPS on ×20');
  expect(
    combat20 / ele20,
    lessThan(6),
    reason: 'Combat vs Ele on 20-pack still blender-scale: '
        '${combat20.toStringAsFixed(0)} / ${ele20.toStringAsFixed(0)}',
  );
}

double _dps(Map<String, dynamic> board, String spec) {
  final specs = (board['specs'] as List).cast<Map<String, dynamic>>();
  final row = specs.firstWhere((s) => s['spec'] == spec);
  return (row['dps'] as num).toDouble();
}

String comparisonMarkdown(Map<int, Map<String, dynamic>> boards) {
  final buf = StringBuffer();
  buf.writeln('# AL20 KEY+20 pack ladder');
  buf.writeln();
  buf.writeln(
    'Live mid band, party Lv100, **F1**, 5-man (tanks/healers pad), '
    '30s cap, 2 trials. KEY+20 locked. Forced awake pack (1 / 5 / 10 / 20).',
  );
  buf.writeln();
  final names = ((boards[1]!['specs'] as List).cast<Map<String, dynamic>>())
      .map((s) => s['spec'] as String)
      .toList()
    ..sort();

  buf.writeln(
    '| spec | ST dps | ×5 | ×10 | ×20 | ST wipe | ×20 wipe | ST s | ×20 s | ×20/ST |',
  );
  buf.writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (final name in names) {
    String cell(int n, String key, {int digits = 0}) {
      final specs = (boards[n]!['specs'] as List).cast<Map<String, dynamic>>();
      final row = specs.firstWhere((s) => s['spec'] == name);
      final v = (row[key] as num).toDouble();
      return v.toStringAsFixed(digits);
    }

    final st = double.parse(cell(1, 'dps', digits: 1));
    final x20 = double.parse(cell(20, 'dps', digits: 1));
    final ratio = st <= 0 ? 0.0 : x20 / st;
    buf.writeln(
      '| $name | ${cell(1, 'dps', digits: 0)} | ${cell(5, 'dps', digits: 0)} | '
      '${cell(10, 'dps', digits: 0)} | ${cell(20, 'dps', digits: 0)} | '
      '${cell(1, 'wipePct', digits: 0)}% | ${cell(20, 'wipePct', digits: 0)}% | '
      '${cell(1, 'elapsed', digits: 1)} | ${cell(20, 'elapsed', digits: 1)} | '
      '${ratio.toStringAsFixed(2)} |',
    );
  }
  buf.writeln();
  buf.writeln('## Share flags (focus % of party damage)');
  for (final n in [1, 5, 10, 20]) {
    if (boards[n] == null) continue;
    final high = (boards[n]!['high'] as List).join(', ');
    final low = (boards[n]!['low'] as List).join(', ');
    buf.writeln('- ×$n HIGH: ${high.isEmpty ? '—' : high}');
    buf.writeln('- ×$n LOW: ${low.isEmpty ? '—' : low}');
  }
  return buf.toString();
}
