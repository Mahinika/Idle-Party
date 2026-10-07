import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/dungeon_bar_layout.dart';
import 'package:idle_party/visual/body_family.dart';

void main() {
  const tile = 24.0;
  const centerY = 200.0;

  void expectAboveHead(double scale) {
    final top = DungeonBarLayout.top(
      centerY: centerY,
      tile: tile,
      scale: scale,
    );
    final height = DungeonBarLayout.barHeight(tile);
    final spriteTop = centerY - tile * scale / 2;
    expect(height, greaterThanOrEqualTo(4));
    expect(
      top + height,
      lessThanOrEqualTo(spriteTop),
      reason: 'bar overlaps the sprite at scale $scale',
    );
  }

  test('HP bar stays above every body and a form sprite', () {
    for (final family in BodyFamily.values) {
      expectAboveHead(1.72 * BodyFamilyCatalog.hudReadScale(family));
    }
    expectAboveHead(1.42);
    expectAboveHead(0.95);
    // Attack flash grows the warrior square; the bar must follow that scale.
    expectAboveHead(1.72 * BodyFamilyCatalog.hudReadScale(BodyFamily.warrior) * 1.32);
  });
}
