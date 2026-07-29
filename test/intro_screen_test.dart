import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/ui/intro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('intro stays until ENTER is pressed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final director = GameDirector.preview();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: true),
    );

    // Allow bootstrap/boot without pumpAndSettle (torch loop never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.text(StoryLore.introTagline), findsOneWidget);

    // Still on intro after time passes (no auto-dismiss).
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(IntroScreen), findsOneWidget);

    // Input lock unlocks after ~900ms (already passed above).
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(IntroScreen), findsNothing);
    expect(find.textContaining('ENTER DUNGEON'), findsOneWidget);
  });
}
