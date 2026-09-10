import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_guides.dart';

void main() {
  test('guides cover core systems with unique ids', () {
    final topics = GameGuides.topics;
    expect(topics.length, greaterThanOrEqualTo(12));
    final ids = topics.map((t) => t.id).toSet();
    expect(ids.length, topics.length);
    expect(ids, containsAll([
      'basics',
      'dailies',
      'god_hand',
      'ascend',
      'hardmode',
      'gates',
      'power_shelves',
    ]));
    final dailies = topics.firstWhere((t) => t.id == 'dailies');
    expect(dailies.title, 'THREE DAILIES');
    expect(dailies.body, contains('Daily Vault'));
    expect(dailies.body, contains('Daily Run'));
    expect(dailies.body, contains('Quests'));
    expect(dailies.body.toLowerCase(), contains('not the same'));
    final shelves = topics.firstWhere((t) => t.id == 'power_shelves');
    expect(shelves.body.toLowerCase(), contains('gold tracks'));
    expect(shelves.body.toLowerCase(), contains('ascend blessing'));
    expect(shelves.body.toLowerCase(), contains('wipes on ascend'));
    final gates = topics.firstWhere((t) => t.id == 'gates');
    expect(gates.body, contains('AL20'));
    expect(gates.body, contains('Daily Vault'));
    expect(gates.body, contains('Daily Run'));
    expect(gates.body.toLowerCase(), contains('not the same'));
    for (final t in topics) {
      expect(t.title, isNotEmpty);
      expect(t.body.length, greaterThan(40));
      expect(
        t.body.toUpperCase(),
        isNot(contains('LOADOUTS')),
        reason: '${t.id} should not teach the hidden LOADOUTS tab',
      );
    }
    final basics = topics.firstWhere((t) => t.id == 'basics');
    expect(basics.body, contains('GEAR'));
    expect(basics.body, contains('GOLD'));
    expect(basics.body, contains('SHOP'));
    expect(basics.body, contains('ESSENCE'));
    expect(basics.body.toUpperCase(), isNot(contains('META (')));
  });
}
