import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/ui/loading_splash.dart';

void main() {
  testWidgets('loading splash shows brand and Loading…', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingSplash()));
    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.text(StoryLore.introTagline), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>(CustomAssets.splashStills.first)),
      findsOneWidget,
    );
  });

  testWidgets('loading splash advances to next still', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingSplash()));
    final first = CustomAssets.splashStills.first;
    final second = CustomAssets.splashStills[1];
    expect(find.byKey(ValueKey<String>(first)), findsOneWidget);

    await tester.pump(LoadingSplash.slideDuration);
    await tester.pump(LoadingSplash.crossfadeDuration);
    await tester.pump();

    expect(find.byKey(ValueKey<String>(second)), findsOneWidget);
  });
}
