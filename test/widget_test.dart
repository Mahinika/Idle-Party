// ignore_for_file: avoid_relative_lib_imports, uri_does_not_exist, undefined_function

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/main.dart';

void main() {
  testWidgets('renders the idle party MVP screen', (WidgetTester tester) async {
    final director = GameDirector.preview();

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.text('GOLD'), findsWidgets);
    expect(find.text('Advance 1 Tick'), findsOneWidget);
    expect(find.text('INVENTORY BOARD'), findsOneWidget);

    await tester.tap(find.text('Advance 1 Tick'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('BATTLE'), findsWidgets);
  });
}
