import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Looks gate from tool/check_paper_doll_facit.py (armor stack vs _src).
void main() {
  test('paper-doll facit gate passes for all families', () {
    final root = Directory.current;
    final script = File('${root.path}/tool/check_paper_doll_facit.py');
    expect(script.existsSync(), isTrue, reason: 'run from repo root');
    final result = Process.runSync(
      'py',
      ['tool/check_paper_doll_facit.py'],
      workingDirectory: root.path,
      runInShell: true,
    );
    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
