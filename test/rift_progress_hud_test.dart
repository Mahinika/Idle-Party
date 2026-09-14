import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/shell/rift_progress_hud.dart';

void main() {
  testWidgets('Farm bar shows percent and elapsed, no GR leftover clock',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RiftProgressHud(
            progress01: 0.34,
            guardianActive: false,
            farm: true,
            tier: 5,
            timerMs: 45_000,
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('FARM R5 34% · 00:45 elapsed'), findsOneWidget);
    expect(find.text('FARM R5'), findsOneWidget);
    expect(find.text('34%'), findsOneWidget);
    expect(find.text('00:45'), findsOneWidget);
  });

  testWidgets('GR bar shows leftover clock and BEHIND semantics',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RiftProgressHud(
            progress01: 0.10,
            guardianActive: false,
            farm: false,
            tier: 21,
            timerMs: 50_000,
            parMs: 100_000,
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('GR21 10% · 00:50 left · BEHIND'),
      findsOneWidget,
    );
    expect(find.text('GR21'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
  });

  testWidgets('Guardian phase swaps percent for GUARDIAN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RiftProgressHud(
            progress01: 1,
            guardianActive: true,
            farm: true,
            tier: 1,
            timerMs: 12_000,
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('FARM R1 GUARDIAN · 00:12 elapsed'),
      findsOneWidget,
    );
    expect(find.text('GUARDIAN'), findsOneWidget);
  });
}
