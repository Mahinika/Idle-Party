import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/floater_banner_stack.dart';

void main() {
  test('isStackable covers priority banners and ABSORB, not speech or raw hits', () {
    expect(
      FloaterBannerStack.isStackable(
        speech: false,
        priority: 2,
        text: 'ELITE DOWN',
      ),
      isTrue,
    );
    expect(
      FloaterBannerStack.isStackable(
        speech: false,
        priority: 2,
        text: 'LEVEL UP!',
      ),
      isTrue,
    );
    expect(
      FloaterBannerStack.isStackable(
        speech: false,
        priority: 0,
        text: 'ABSORB 12',
      ),
      isTrue,
    );
    expect(
      FloaterBannerStack.isStackable(speech: false, priority: 0, text: '18'),
      isFalse,
    );
    expect(
      FloaterBannerStack.isStackable(
        speech: true,
        priority: 2,
        text: 'ELITE DOWN',
      ),
      isFalse,
    );
  });

  test('priority banners in one cluster stack up by height plus gap', () {
    const h = 0.30;
    final dy = FloaterBannerStack.dyById(const [
      FloaterBannerSpec(
        id: 0,
        x: 4,
        y: 6,
        priority: 2,
        born: 10,
        heightTiles: h,
      ), // ELITE DOWN
      FloaterBannerSpec(
        id: 1,
        x: 4.2,
        y: 5.8,
        priority: 2,
        born: 11,
        heightTiles: h,
      ), // LEVEL UP
      FloaterBannerSpec(
        id: 2,
        x: 4.1,
        y: 6.1,
        priority: 0,
        born: 12,
        heightTiles: h,
      ), // ABSORB
    ]);
    expect(dy[0], 0.0, reason: 'highest priority, earliest born keeps authored Y');
    expect(dy[1]! < 0, isTrue, reason: 'LEVEL UP lifts up (negative Y)');
    expect(dy[2]! < dy[1]!, isTrue, reason: 'ABSORB stacks above both');
    // After offsets, vertical ranges plus the gap must not overlap.
    const banners = [
      (6.0, 0),
      (5.8, 1),
      (6.1, 2),
    ];
    for (var i = 0; i < banners.length; i++) {
      for (var j = i + 1; j < banners.length; j++) {
        final yi = banners[i].$1 + dy[banners[i].$2]!;
        final yj = banners[j].$1 + dy[banners[j].$2]!;
        final overlap =
            yi + h + FloaterBannerStack.gapTiles > yj &&
            yj + h + FloaterBannerStack.gapTiles > yi;
        expect(overlap, isFalse, reason: 'banner ${banners[i].$2} vs ${banners[j].$2}');
      }
    }
  });

  test('banners more than one tile apart keep their authored Y', () {
    const h = 0.30;
    final dy = FloaterBannerStack.dyById(const [
      FloaterBannerSpec(
        id: 0,
        x: 0,
        y: 0,
        priority: 2,
        born: 1,
        heightTiles: h,
      ),
      FloaterBannerSpec(
        id: 1,
        x: 2.5,
        y: 0,
        priority: 2,
        born: 2,
        heightTiles: h,
      ),
    ]);
    expect(dy[0], 0.0);
    expect(dy[1], 0.0);
  });

  test('fight-hit golden floaters stay unstacked at 1.2 tiles apart', () {
    // Mirrors test/shell_golden_harness.dart stageFightHitProof spacing:
    // '18' at (hero+1.1, hero-0.2) priority 1, '8g' at (hero, hero-0.7) priority 2.
    const h = 0.30;
    final dy = FloaterBannerStack.dyById(const [
      FloaterBannerSpec(
        id: 0,
        x: 1.1,
        y: -0.2,
        priority: 1,
        born: 1,
        heightTiles: h,
      ),
      FloaterBannerSpec(
        id: 1,
        x: 0,
        y: -0.7,
        priority: 2,
        born: 2,
        heightTiles: h,
      ),
    ]);
    expect(dy[0], 0.0);
    expect(dy[1], 0.0);
  });
}
