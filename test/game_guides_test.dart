import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_guides.dart';

void main() {
  test('guides cover core systems with unique ids', () {
    final topics = GameGuides.topics;
    expect(topics.length, greaterThanOrEqualTo(12));
    final ids = topics.map((t) => t.id).toSet();
    expect(ids.length, topics.length);
    expect(ids, containsAll(['basics', 'god_hand', 'ascend', 'hardmode']));
    for (final t in topics) {
      expect(t.title, isNotEmpty);
      expect(t.body.length, greaterThan(40));
    }
  });
}
