import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';

/// Polish 6 #20: FORGE and CAMP cards show how far a track is toward its
/// existing soft-cap knee. Display only: the knees are the ones the sheet
/// math already uses, and nothing about prices or gains changes.
void main() {
  final base = GameLogic.createInitialState(now: DateTime(2026, 11, 17));

  test('FORGE bar is points over the same knee as the gain line', () {
    expect(ForgeOverlay.forgeSoftProgress(base, PartyUpgradeType.attack), 0);
    final half = base.copyWith(
      attackBonus: (GameLogic.forgeAttackSoftAt / 2).round(),
      critBonus: 25,
      masteryBonus: (GameLogic.forgeMasterySoftAt * 3).round(),
    );
    expect(
      ForgeOverlay.forgeSoftProgress(half, PartyUpgradeType.attack),
      closeTo(0.5, 1e-9),
    );
    // CRIT's knee is 25 (as in the FORGE info line); MASTERY clamps at 1.
    expect(ForgeOverlay.forgeSoftProgress(half, PartyUpgradeType.crit), 1);
    expect(ForgeOverlay.forgeSoftProgress(half, PartyUpgradeType.mastery), 1);
    // The bar is full exactly when the card says SOFT.
    for (final type in PartyUpgradeType.values) {
      final (_, _, soft) = ForgeOverlay.forgeGainLine(half, type);
      expect(
        ForgeOverlay.forgeSoftProgress(half, type) >= 1,
        soft,
        reason: type.name,
      );
    }
  });

  test(
    'CAMP bar uses the sanctuary knees (40 levels for power / HP / DEF)',
    () {
      expect(SanctuaryOverlay.campSoftProgress('power', 0), 0);
      expect(
        SanctuaryOverlay.campSoftProgress('power', 20),
        closeTo(0.5, 1e-9),
      );
      expect(SanctuaryOverlay.campSoftProgress('vitality', 40), 1);
      expect(
        SanctuaryOverlay.campSoftProgress('defense', 10),
        closeTo(0.25, 1e-9),
      );
      expect(SanctuaryOverlay.campSoftProgress('gold', 10), closeTo(0.5, 1e-9));
      expect(SanctuaryOverlay.campSoftProgress('xp', 99), 1);
    },
  );

  testWidgets('SoftCapBar fills its share and says it to a reader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 200, child: SoftCapBar(value: 0.25)),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(SoftCapBar));
    expect(bar.height, 4);
    final fill = tester.getRect(find.byType(FractionallySizedBox));
    expect(fill.width, closeTo(50, 0.5));
    expect(find.bySemanticsLabel('Level soft cap 25%'), findsOneWidget);
  });
}
