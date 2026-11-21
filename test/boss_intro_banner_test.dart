import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';

void main() {
  test('boss callout clears the target strip at max text scale', () {
    const scale = 1.45;
    final stripBottom = targetStripHeight(const TextScaler.linear(scale));
    expect(bossIntroBannerTop(scale), greaterThan(stripBottom));
    expect(bossIntroBannerTop(1.0), lessThan(bossIntroBannerTop(scale)));
  });

  testWidgets('boss callout wraps to two lines on a phone at large text',
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
    final banner = tester.widget<Text>(find.text('BOSS — Fen Hydra'));
    expect(banner.maxLines, 2);
    expect(banner.softWrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long boss name stays visible at 360', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: const Scaffold(
            body: BossIntroBanner(name: 'EARTH KRAKEN'),
          ),
        ),
      ),
    );
    expect(find.textContaining('EARTH KRAKEN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}