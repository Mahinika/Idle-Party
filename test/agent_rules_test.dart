import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = Directory('.cursor/rules')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mdc'))
      .toList();

  test('every rule has a one-line description Cursor can read', () {
    expect(rules, isNotEmpty);
    for (final f in rules) {
      final lines = f.readAsLinesSync();
      expect(lines.first.trim(), '---', reason: f.path);
      final end = lines.indexWhere((l) => l.trim() == '---', 1);
      expect(end, greaterThan(0), reason: '${f.path}: frontmatter not closed');
      final front = lines.sublist(1, end);
      final desc = front.firstWhere(
        (l) => l.startsWith('description:'),
        orElse: () => '',
      );
      final value = desc.replaceFirst('description:', '').trim();
      expect(value, isNotEmpty, reason: '${f.path}: missing description');
      expect(
        value.startsWith('>') || value.startsWith('|'),
        isFalse,
        reason: '${f.path}: Cursor shows a folded description as the text ">-"',
      );
      expect(
        front.any((l) => l.startsWith('alwaysApply:')),
        isTrue,
        reason: '${f.path}: missing alwaysApply',
      );
    }
  });

  test('rules and AGENTS.md only point at rules and skills that exist', () {
    final ref = RegExp(r'\.cursor/(rules/[\w-]+\.mdc|skills/[\w-]+)');
    for (final f in <File>[...rules, File('AGENTS.md')]) {
      for (final m in ref.allMatches(f.readAsStringSync())) {
        final path = '.cursor/${m.group(1)}';
        expect(
          FileSystemEntity.typeSync(path),
          isNot(FileSystemEntityType.notFound),
          reason: '${f.path} points at missing $path',
        );
      }
    }
  });

  test('the session hook still finds the Now line', () {
    expect(
      File('.cursor/rules/20-how-we-work.mdc').readAsStringSync(),
      contains('**Now:**'),
    );
  });

  test('gear art standard names files that exist', () {
    final rule = File('.cursor/rules/gear-art-standard.mdc').readAsStringSync();
    final skill = File('.cursor/skills/gear-art/SKILL.md').readAsStringSync();
    for (final text in <String>[rule, skill]) {
      expect(text, contains('tool/gear_style.py'));
      expect(text, contains('tool/check_paper_doll_facit.py'));
    }
    expect(File('tool/gear_style.py').existsSync(), isTrue);
    expect(File('tool/check_paper_doll_facit.py').existsSync(), isTrue);
  });

  test('AGENTS.md carries no block managed by another app', () {
    expect(
      File('AGENTS.md').readAsStringSync(),
      isNot(contains('pandaos-managed')),
    );
  });
}
