@Tags(['facit'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Looks gate from tool/check_paper_doll_facit.py (live armor stack vs _src).
void main() {
  test('paper-doll facit gate passes for all families', () {
    final root = Directory.current;
    final script = File('${root.path}/tool/check_paper_doll_facit.py');
    expect(script.existsSync(), isTrue, reason: 'run from repo root');
    final python = _pythonExecutable();
    if (python == null) {
      fail('need python3/py/python for facit');
    }
    if (!_pillowInstalled(python)) {
      markTestSkipped(
        'Pillow is not installed. pip install pillow, then rerun the facit gate.',
      );
      return;
    }
    final result = Process.runSync(
      python,
      ['tool/check_paper_doll_facit.py'],
      workingDirectory: root.path,
      runInShell: true,
    );
    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('facit selftest catches a bad picture of each kind', () {
    final python = _pythonExecutable();
    if (python == null) {
      fail('need python3/py/python for facit');
    }
    if (!_pillowInstalled(python)) {
      markTestSkipped(
        'Pillow is not installed. pip install pillow, then rerun the facit selftest.',
      );
      return;
    }
    final result = Process.runSync(
      python,
      ['tool/check_paper_doll_facit.py', '--selftest'],
      workingDirectory: Directory.current.path,
      runInShell: true,
    );
    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  });
}

bool _pillowInstalled(String python) {
  final probe = Process.runSync(
    python,
    ['-c', 'import PIL'],
    runInShell: true,
  );
  return probe.exitCode == 0;
}

String? _pythonExecutable() {
  for (final exe in ['python3', 'py', 'python']) {
    final probe = Process.runSync(exe, ['--version'], runInShell: true);
    final out = '${probe.stdout}${probe.stderr}';
    if (probe.exitCode == 0 &&
        RegExp(r'python\s+\d', caseSensitive: false).hasMatch(out)) {
      return exe;
    }
  }
  return null;
}
