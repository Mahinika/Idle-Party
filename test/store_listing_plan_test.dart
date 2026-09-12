import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play listing plan leads with first-minute combat', () {
    final md = File('docs/STORE_LISTING.md').readAsStringSync();
    final plan = md.split('### Screenshot plan').last.split('## How we capture')[0];
    expect(plan, contains('out/01_01_combat_a.png'));
    expect(plan, contains('out/02_02_combat_b.png'));
    expect(plan, contains('Your party fights on its own'));
    expect(plan, contains('Same fight while you are away'));
    expect(plan, isNot(contains('| 1 | `marketing/02_todays_chase')));
    expect(plan, isNot(contains('| 2 | `marketing/')));
    expect(plan, isNot(contains('08_keystone')));
  });
}
