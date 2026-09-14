import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/ui/cognifox_mark.dart';
import 'package:idle_party/ui/loading_splash.dart';

void main() {
  testWidgets('studio mark exposes Cognifox Studio for a11y', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CognifoxStudioMark())),
    );
    expect(find.byType(CognifoxStudioMark), findsOneWidget);
    expect(find.bySemanticsLabel(StoryLore.studioName), findsOneWidget);
    expect(find.text(StoryLore.studioName.toUpperCase()), findsNothing);
  });

  testWidgets('loading splash shows Cognifox Studio and Loading…', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LoadingSplash()));
    expect(find.byType(CognifoxStudioMark), findsOneWidget);
    expect(find.bySemanticsLabel(StoryLore.studioName), findsOneWidget);
    expect(find.text(StoryLore.studioName.toUpperCase()), findsNothing);
    expect(find.text('IDLE PARTY'), findsNothing);
    expect(find.text(StoryLore.introTagline), findsNothing);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final mark = tester.getRect(find.byType(CognifoxStudioMark));
    expect(mark.center.dx, closeTo(180, 24));
    expect(mark.top, greaterThan(80));
  });
}
