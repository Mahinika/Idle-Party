import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/confirm_dialogs.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/home/floor_jump_sheet.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/shell_common.dart';
import 'package:idle_party/ui/shell/whats_new_overlay.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit 100, batch 4: dialogs and sheets.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  test('F025/F070 MAX slices say what they are worth, no jargon', () {
    expect(
      ForgeOverlay.sliceLabel(ForgeGoldSpendMode.pct25, 12000),
      '25% · ${formatGold(3000)}',
    );
    expect(ForgeOverlay.sliceLabel(ForgeGoldSpendMode.pct5, null), '5%');
    expect(ForgeOverlay.sliceHint, isNot(contains('GOLD track')));
    expect(ForgeOverlay.sliceTitle, isNot(contains('wallet slice')));
  });

  test('F033 current patch notes have no layout spec lines', () {
    final text = MetaSystems.releases.first.bullets.join(' ');
    expect(text, isNot(contains('is the list only')));
    expect(text, isNot(contains('Bottom bar is')));
  });

  test('F086 return line: "You can buy AP now (83g)."', () {
    final rich = GameLogic.createInitialState(
      now: DateTime(2026, 11, 7),
    ).copyWith(gold: 50000);
    final line = GameLogic.returnGainLine(
      rich,
      goldGained: 100,
      essenceGained: 0,
      canOpenGold: true,
    );
    expect(line, contains(GameLogic.returnCanBuy));
    expect(line, isNot(contains('wallet covers')));
    expect(line, isNot(contains(' g)')));
  });

  for (final size in a100Sizes) {
    for (final scale in a100Scales) {
      final tag = a100Label(size, scale);

      a100TestHome('F006 FLOORS sheet hugs its rows $tag', (t) async {
        final (director, _) = await a100Pump(t, size, scale, fresh: true);
        showFloorJumpSheet(t.element(find.byType(HomeShell)), director);
        await a100Settle(t);
        expect(find.text('FLOORS'), findsOneWidget);
        final dialog = t.getRect(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        );
        if (director.state.maxReachableFloor <= 1) {
          expect(find.byKey(floorJumpEmptyKey), findsOneWidget);
        }
        expect(dialog.height, lessThan(size.height * 0.6));
        expect(t.takeException(), isNull);
        await t.tap(find.text('CANCEL'));
        await a100Settle(t);
      });

      a100TestHome('F032/F077 DAILY RUN: reward once, rules folded $tag', (
        t,
      ) async {
        final (director, _) = await a100Pump(t, size, scale, inDungeon: false);
        if (director.isDailyClaimedToday) return;
        confirmDailyRun(t.element(find.byType(HomeShell)), director);
        await a100Settle(t);
        expect(find.text('DAILY RUN'), findsOneWidget);
        expect(find.textContaining('Reward:'), findsOneWidget);
        expect(find.textContaining(RegExp(r'\+\d+e\b')), findsNothing);
        expect(find.text('How it works'), findsOneWidget);
        expect(
          find.text(dailyRunRules(director.dailyEchoFloor)),
          findsNothing,
          reason: 'rules start folded',
        );
        expect(t.takeException(), isNull);
        await t.tap(find.text('CANCEL'));
        await a100Settle(t);
      });

      a100TestHome('F083 PATCH NOTES has a scrollbar $tag', (t) async {
        final (director, _) = await a100Pump(t, size, scale);
        WhatsNewOverlay.show(t.element(find.byType(HomeShell)), director);
        await a100Settle(t);
        expect(find.byKey(WhatsNewOverlay.scrollbarKey), findsOneWidget);
        expect(find.text('MENU · PATCH NOTES'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(find.text('CLOSE').last);
        await a100Settle(t);
      });

      a100TestHome('F047/F069 flask sheet: flasks only, X closes $tag', (
        t,
      ) async {
        await a100Pump(t, size, scale, gold: 200000);
        await t.tap(find.text('MARKET').first);
        await a100Settle(t);
        await t.tap(find.bySemanticsLabel('Flasks').first);
        await a100Settle(t);
        expect(find.text('MARKET · flasks'), findsOneWidget);
        expect(find.text('ALL GEAR'), findsNothing);
        final close = find.widgetWithText(GameButton, 'CLOSE');
        expect(close, findsOneWidget);
        final x = t.getSize(close);
        expect(x.width, greaterThanOrEqualTo(44));
        expect(x.height, greaterThanOrEqualTo(44));
        await t.tap(close);
        await a100Settle(t);
        expect(find.text('MARKET · flasks'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
