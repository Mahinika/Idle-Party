import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/main.dart';

void main() {
  testWidgets('renders the idle party IS2 shell', (WidgetTester tester) async {
    final director = GameDirector.preview();

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.textContaining('FARM'), findsWidgets);
    expect(find.textContaining('BAG'), findsWidgets);
    expect(find.textContaining('COMBINATOR'), findsOneWidget);
    expect(find.textContaining('God Hand'), findsOneWidget);
  });
}
