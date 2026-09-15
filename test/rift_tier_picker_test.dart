import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/meta/rift_tier_picker.dart';

void main() {
  testWidgets('rift picker shows number and steps with arrows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RiftTierPickerDialog(
            title: 'Ranked GR',
            prefix: 'GR',
            minusLabel: 'GR -',
            plusLabel: 'GR +',
            enterLabel: _enterLabel,
            initial: 20,
            minTier: 1,
            maxTier: 21,
            blurb: 'pick',
          ),
        ),
      ),
    );
    expect(find.text('GR20'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('GR +'));
    await tester.pump();
    expect(find.text('GR21'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('GR -'));
    await tester.pump();
    expect(find.text('GR20'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('GR -'));
    await tester.pump();
    expect(find.text('GR19'), findsOneWidget);
  });
}

String _enterLabel(int t) => 'ENTER RANK GR$t';
