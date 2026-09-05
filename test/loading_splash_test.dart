import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/loading_splash.dart';

void main() {
  testWidgets('loading splash shows Loading…', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingSplash()));
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
