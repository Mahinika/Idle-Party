import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = Directory('.cursor/rules')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mdc'))
      .toList();

  final skillDirs = Directory('.cursor/skills')
      .listSync()
      .whereType<Directory>()
      .toList();

  String baseName(FileSystemEntity e) =>
      e.uri.pathSegments.where((s) => s.isNotEmpty).last;

  Map<String, String> skillFront(Directory d) {
    final lines = File('${d.path}/SKILL.md').readAsLinesSync();
    expect(lines.first.trim(), '---', reason: d.path);
    final end = lines.indexWhere((l) => l.trim() == '---', 1);
    expect(end, greaterThan(0), reason: '${d.path}: frontmatter not closed');
    final out = <String, String>{};
    String? key;
    for (final l in lines.sublist(1, end)) {
      final m = RegExp(r'^([\w-]+):\s*(.*)$').firstMatch(l);
      if (m != null) {
        key = m.group(1)!;
        final v = m.group(2)!.trim();
        out[key] = (v == '>-' || v == '>' || v == '|') ? '' : v;
      } else if (key != null) {
        out[key] = '${out[key]} ${l.trim()}'.trim();
      }
    }
    return out;
  }

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

  test('rules, skills, commands, and AGENTS.md only point at rules and skills that exist', () {
    final ref = RegExp(r'\.cursor/(rules/[\w-]+\.mdc|skills/[\w-]+)');
    final docs = <File>[
      ...rules,
      File('AGENTS.md'),
      ...Directory('.cursor/skills')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
      ...Directory('.cursor/commands')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
    ];
    for (final f in docs) {
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

  test('every skill has a SKILL.md whose name matches its folder', () {
    expect(skillDirs, isNotEmpty);
    for (final d in skillDirs) {
      expect(File('${d.path}/SKILL.md').existsSync(), isTrue, reason: d.path);
      final front = skillFront(d);
      expect(front['name'], baseName(d), reason: d.path);
      expect(
        front['description'] ?? '',
        isNotEmpty,
        reason: '${d.path}: missing description',
      );
    }
  });

  test('skills the model picks say when not to use them', () {
    for (final d in skillDirs) {
      final front = skillFront(d);
      if (front['disable-model-invocation'] == 'true') continue;
      expect(
        front['description'],
        contains('Do not'),
        reason: '${d.path}: add "Do not use for ... (sibling-skill)"',
      );
    }
  });

  test('skill descriptions only name skills and rules that exist', () {
    final known = <String>{
      ...skillDirs.map(baseName),
      ...rules.map((f) => baseName(f).replaceFirst('.mdc', '')),
    };
    final ref = RegExp(r'\(([a-z0-9]+(?:-[a-z0-9]+)+)\)');
    for (final d in skillDirs) {
      final desc = skillFront(d)['description'] ?? '';
      for (final m in ref.allMatches(desc)) {
        expect(
          known,
          contains(m.group(1)),
          reason: '${d.path} names a missing skill (${m.group(1)})',
        );
      }
    }
  });

  test('skills only name repo files that exist', () {
    final path = RegExp(
      r'(?<![\w/.-])((?:lib|test|tool|docs|assets)/[\w./-]+\.(?:dart|py|md|json|png|yml))',
    );
    final docs = Directory('.cursor/skills')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'));
    for (final f in docs) {
      for (final m in path.allMatches(f.readAsStringSync())) {
        final p = m.group(1)!;
        if (p.contains('tool/out/') || p.contains('playshots/')) continue;
        expect(
          FileSystemEntity.typeSync(p),
          isNot(FileSystemEntityType.notFound),
          reason: '${f.path} names missing $p',
        );
      }
    }
  });
}
