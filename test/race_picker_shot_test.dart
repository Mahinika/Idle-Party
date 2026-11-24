import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hero_look_row.dart';
import 'package:idle_party/ui/menu_chrome.dart';

@Tags(['artifact'])
void main() {
  testWidgets('race picker golden for PR artifact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                height: 300,
                child: DecoratedBox(
                  key: const Key('race-golden'),
                  decoration: MenuChrome.panel(opaque: true),
                  child: HeroLookRow(
                    value: HeroRace.nightElf,
                    compact: true,
                    title: 'RACE',
                    columns: 4,
                    hint: HeroRace.pickerSummary,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const Key('race-golden')),
      matchesGoldenFile('goldens/race_picker_ui.png'),
    );
  });
}