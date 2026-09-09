import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/ui/loading_splash.dart';

void main() {
  testWidgets('loading splash shows brand and Loading…', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingSplash()));
    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.text(StoryLore.introTagline), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
