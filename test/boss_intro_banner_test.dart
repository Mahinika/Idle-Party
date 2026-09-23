import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';

void main() {
  test('boss callout clears the corner frame at max text scale', () {
    // Same stack as TargetCornerHud: title, 28px portrait, bomb line.
    const frameBottom = 2 + (9 * 1.4 * 1.4) + 2 + 28 + (9 * 1.4 * 1.4);
    expect(bossIntroBannerTop(1.40), greaterThan(frameBottom));
    expect(bossIntroBannerTop(1.0), lessThan(bossIntroBannerTop(1.40)));
  });

  testWidgets('boss callout stays one line on a phone at large text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.4),
              ),
              child: const Scaffold(
                body: SizedBox(
                  width: 360,
                  child: BossIntroBanner(name: 'Fen Hydra'),
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('BOSS — Fen Hydra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
