import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/ui/cognifox_mark.dart';
import 'package:idle_party/ui/loading_splash.dart';

void main() {
  testWidgets('loading splash shows Cognifox Studio and Loading…', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingSplash()));
    expect(find.byType(CognifoxStudioMark), findsOneWidget);
    expect(find.text(StoryLore.studioName.toUpperCase()), findsOneWidget);
    expect(find.text('IDLE PARTY'), findsNothing);
    expect(find.text(StoryLore.introTagline), findsNothing);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
