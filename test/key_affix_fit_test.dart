import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/meta/challenge_toggles.dart';

void main() {
  testWidgets('a long KEY affix fits a phone width', (tester) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) overflows.add(text);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now().toUtc();
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      heroes: [
        for (final hero in base.heroes) hero.copyWith(level: 100, xp: 0),
      ],
      heroRoster: [
        for (final hero in base.heroRoster) hero.copyWith(level: 100, xp: 0),
      ],
      hardmodeLevel: 4,
      metaDepth: base.metaDepth.copyWith(
        weeklyKey: GameLogic.isoWeekKey(now),
        weeklyModifier: 'iron',
      ),
    );
    final director = GameDirector.preview(initialState: state);
    await director.boot();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ChallengeToggles(director: director, lockExpanded: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('packs tankier'), findsOneWidget);
    expect(overflows, isEmpty);
    director.dispose();
  });
}
