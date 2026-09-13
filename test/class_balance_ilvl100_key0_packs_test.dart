@Tags(['sim'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_class_balance.dart';

/// AL20 KEY+0 pack ladder at pinned iLvl 100: ST / 5 / 10 / 20.
void main() {
  const packN = int.fromEnvironment('AOE_N', defaultValue: 0);
  const focusRaw = String.fromEnvironment('FOCUS', defaultValue: '');
  const mergeOnly = bool.fromEnvironment('MERGE', defaultValue: false);
  final packs = packN > 0 ? <int>[packN] : const [1, 5, 10, 20];

  test('AL20 iLvl100 KEY+0 pack ladder', () {
    if (mergeOnly) return;
    final boards = <int, Map<String, dynamic>>{};
    for (final n in packs) {
      boards[n] = _runPack(n, focusRaw: focusRaw);
    }
    if (packs.length == 4) {
      final md = comparisonMarkdown(boards);
      File('tool/out/ilvl100_key0_packs.md').writeAsStringSync(md);
      // ignore: avoid_print
      print(md);
      _assertRecordedDps(boards);
    }
  }, timeout: const Timeout(Duration(minutes: 90)));

  test('AL20 iLvl100 KEY+0 merge comparison', () {
    if (!mergeOnly) return;
    final boards = <int, Map<String, dynamic>>{};
    for (final n in const [1, 5, 10, 20]) {
      final file = File('tool/out/ilvl100_key0_x$n.json');
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      boards[n] =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }
    final md = comparisonMarkdown(boards);
    File('tool/out/ilvl100_key0_packs.md').writeAsStringSync(md);
    // ignore: avoid_print
    print(md);
    _assertRecordedDps(boards);
  });
}

Map<String, dynamic> _runPack(int n, {String focusRaw = ''}) {
  final jsonPath = 'tool/out/ilvl100_key0_x$n.json';
  final args = <String>[
    '--share-only',
    '--trials=2',
    '--mode=live',
    '--band=mid',
    '--level=100',
    '--al=20',
    '--ilvl=100',
    '--floor=21',
    '--party-size=5',
    '--max-seconds=30',
    '--all-specs',
    '--aoe-full-hp',
    '--aoe-enemies=$n',
    '--json-out=$jsonPath',
    if (focusRaw.isNotEmpty) '--focus=$focusRaw',
  ];
  final report = runClassBalanceSim(args);
  expect(report.contains('KEY:'), isFalse);
  expect(report, contains('ilvl: 100'));
  expect(report, contains('floor: 21'));
  expect(report, contains('aoe-full-hp: true'));
  expect(report, contains('aoe-enemies: $n'));
  expect(report, contains('ascension: AL20'));
  final json =
      jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
  expect(json['key'], 0);
  expect(json['ilvl'], 100);
  expect(json['al'], 20);
  expect(json['aoeEnemies'], n);
  return json;
}

void _assertRecordedDps(Map<int, Map<String, dynamic>> boards) {
  expect(_dps(boards[20]!, 'combat'), greaterThan(0));
  expect(_dps(boards[20]!, 'elemental'), greaterThan(0));
  expect(_dps(boards[1]!, 'combat'), greaterThan(0));
  expect(_dps(boards[1]!, 'elemental'), greaterThan(0));
}

double _dps(Map<String, dynamic> board, String spec) {
  final specs = (board['specs'] as List).cast<Map<String, dynamic>>();
  final row = specs.firstWhere((s) => s['spec'] == spec);
  return (row['dps'] as num).toDouble();
}

String comparisonMarkdown(Map<int, Map<String, dynamic>> boards) {
  final buf = StringBuffer();
  buf.writeln('# AL20 iLvl 100 KEY+0 pack ladder');
  buf.writeln();
  buf.writeln(
    'Live mid band, party Lv100, **iLvl 100** rare kits, **KEY off**, '
    'F21, 5-man, 30s cap, 2 trials. Each pack body has ST dummy HP '
    '(not a split F1 budget). Forced awake pack (1 / 5 / 10 / 20).',
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
