import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final weeksDir = Directory('docs/weeks');
  final detalj = RegExp(r'detalj\s+\d+', caseSensitive: false);
  final mustRow = RegExp(r'^\d+\. Måste', multiLine: true);

  const w47to53En = <int, String>{
    47: 'Five heroes stay in a line on a real floor.',
    48: 'Your weapon stays beside your body, not under your neighbor.',
    49: 'A gate, a chest, and the first boss fit with the line.',
    50: 'A wipe shows the line on the floor below.',
    51: 'Reopening the app mid-fight still shows the line.',
    52: 'After Ascend, the line is back on floor 1 with an empty bag.',
    53: 'The Ranked GR card names the month and the same time as the fight.',
  };

  int countMustRows(String text) =>
      mustRow.allMatches(text).length;

  String? enMening(String text) {
    for (final line in text.split('\n')) {
      if (line.startsWith('**En mening:**')) {
        return line.substring('**En mening:**'.length).trim();
      }
    }
    return null;
  }

  test('calendar 2026 has ISO week files w01–w53', () {
    for (var w = 1; w <= 53; w++) {
      final path = '${weeksDir.path}/2026-w${w.toString().padLeft(2, '0')}.md';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('2026 week row counts and no detalj padding', () {
    for (var w = 1; w <= 53; w++) {
      final name = '2026-w${w.toString().padLeft(2, '0')}.md';
      final text = File('${weeksDir.path}/$name').readAsStringSync();
      final rows = countMustRows(text);

      if (w == 43) {
        expect(rows, 5, reason: name);
        continue;
      }
      if (w == 42) {
        expect(rows, greaterThanOrEqualTo(25), reason: name);
        continue;
      }

      expect(rows, 25, reason: name);
      expect(detalj.hasMatch(text), isFalse, reason: '$name must not use detalj padding');
    }
  });

  test('2026 w44–w53 have no ej klar rows after year-end batch', () {
    final ejKlar = RegExp(r'—\s*ej klar', caseSensitive: false);
    for (var w = 44; w <= 53; w++) {
      final name = '2026-w${w.toString().padLeft(2, '0')}.md';
      final text = File('${weeksDir.path}/$name').readAsStringSync();
      expect(ejKlar.hasMatch(text), isFalse, reason: name);
    }
  });

  test('2026 w47–w53 En mening matches YEAR_ROADMAP generator copy', () {
    for (final entry in w47to53En.entries) {
      final name = '2026-w${entry.key.toString().padLeft(2, '0')}.md';
      final text = File('${weeksDir.path}/$name').readAsStringSync();
      expect(enMening(text), entry.value, reason: name);
    }
  });
}
