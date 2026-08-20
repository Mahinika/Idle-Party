import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/enemy.dart';

void main() {
  test('EnemyUnit.fromJson soft-parses doubles and unknown enums', () {
    final unit = EnemyUnit.fromJson(<String, dynamic>{
      'name': 'Slime',
      'level': 3.0,
      'currentHp': 12.5,
      'rewardGold': '4',
      'role': 'not_a_role',
      'archetype': 'also_bad',
      'stats': <String, dynamic>{
        'attack': 5.0,
        'defense': 1,
        'maxHp': 20,
      },
    });
    expect(unit.name, 'Slime');
    expect(unit.level, 3);
    expect(unit.currentHp, 12);
    expect(unit.rewardGold, 4);
    expect(unit.role, EnemyRole.normal);
    expect(unit.archetype, EnemyArchetype.brute);
    expect(unit.attack, 5);
  });
}
