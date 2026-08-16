import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/boot_intro_screen.dart';
import 'package:idle_party/ui/new_game_party_picker.dart';
import 'package:idle_party/ui/start_menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> skipBootIntro(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.byType(BootIntroScreen), findsOneWidget);
  await tester.pump(BootIntroScreen.inputUnlock);
  expect(find.text('SKIP'), findsOneWidget);
  await tester.tap(find.text('SKIP'));
  await tester.pump();
  // Start menu ignores taps for ~900ms.
  await tester.pump(const Duration(milliseconds: 950));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot intro plays before the start menu and can be skipped',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final director = GameDirector.preview();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(BootIntroScreen), findsOneWidget);
    expect(find.text(StoryLore.introBeats.first.title), findsWidgets);
    expect(find.text(StoryLore.introBeats.first.body), findsOneWidget);
    expect(find.byType(StartMenuScreen), findsNothing);

    await tester.pump(BootIntroScreen.beatDuration);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text(StoryLore.introBeats[1].title), findsOneWidget);

    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.byType(StartMenuScreen), findsOneWidget);
    expect(find.byType(BootIntroScreen), findsNothing);
  });

  testWidgets('start menu shows Continue and New Game', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final director = GameDirector.preview();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: true),
    );
    await skipBootIntro(tester);

    expect(find.byType(StartMenuScreen), findsOneWidget);
    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.text(StoryLore.introTagline), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('NEW GAME'), findsOneWidget);

    // Still on menu after time passes (no auto-dismiss).
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(StartMenuScreen), findsOneWidget);

    // Input lock unlocks after ~900ms (already passed above).
    await tester.tap(find.text('NEW GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(StartMenuScreen), findsNothing);
    expect(find.byType(NewGamePartyPicker), findsOneWidget);
    expect(find.text('NEW PARTY'), findsOneWidget);
    expect(find.text('ARMS  Arms Warrior'), findsOneWidget);
    expect(find.text('LOCKED'), findsWidgets);
    expect(find.text('SET'), findsOneWidget);
  });

  testWidgets('new game start reaches hub with chosen party size',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final director = GameDirector.preview();

    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: true),
    );
    await skipBootIntro(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // preview() seeds an in-memory save, so Continue is available.
    expect(director.hasExistingSave, isTrue);

    await tester.tap(find.text('NEW GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(NewGamePartyPicker), findsOneWidget);

    await tester.ensureVisible(find.text('START'));
    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Existing save → confirm overwrite.
    expect(find.text('Overwrite save?'), findsOneWidget);
    await tester.tap(find.text('OVERWRITE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(NewGamePartyPicker), findsNothing);
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(director.state.heroes.length, 3);
    expect(
      director.state.heroes.map((h) => h.specId).toSet(),
      HeroSpecs.starterUnlocked.toSet(),
    );
  });
}
