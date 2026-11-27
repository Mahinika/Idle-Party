import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/hub/friend_tip_block.dart';
import 'package:idle_party/ui/hub/hub_powerups.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/meta/challenge_toggles.dart';
import 'package:idle_party/ui/shell/essence_keep_panel.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit 100, batch 6: SHOP / SCROLLS / QUESTS / KEY / BLESSING / ESSENCE.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  Future<void> pumpSheet(
    WidgetTester t,
    Size size,
    double scale,
    Widget Function() body,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: body()),
      ),
    );
    await a100Settle(t);
  }

  for (final size in a100Sizes) {
    for (final scale in a100Scales) {
      final tag = a100Label(size, scale);

      testWidgets('F026/F027/F071 SHOP: one line, compact banner $tag', (
        t,
      ) async {
        final d = await a100Director();
        await pumpSheet(t, size, scale, () => ShopDock(director: d));
        final banner = find.byKey(ShopDock.billingBannerKey);
        if (banner.evaluate().isNotEmpty) {
          expect(t.getRect(banner).height, lessThan(120));
        }
        expect(find.text('Unavailable'), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        d.dispose();
        await t.pump(const Duration(milliseconds: 20));
      });

      testWidgets('F028/F029/F073/F074 SCROLLS $tag', (t) async {
        final d = await a100Director(gold: 100);
        await pumpSheet(
          t,
          size,
          scale,
          () => scrollsSheetForTest(director: d),
        );
        expect(find.byKey(ScrollsSheet.ticketPillKey), findsOneWidget);
        final tip = t.widget<GameButton>(find.byKey(FriendTipBlock.tipKey));
        expect(tip.style, GameButtonStyle.ghost);
        expect(find.byType(TextField), findsNothing);
        await t.scrollUntilVisible(
          find.text(FriendTipBlock.haveCode),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(FriendTipBlock.haveCode), findsOneWidget);
        await t.scrollUntilVisible(
          find.text(ScrollsSheet.useLabel(1)).first,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(ScrollsSheet.needTickets(1)), findsWidgets);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        d.dispose();
        await t.pump(const Duration(milliseconds: 20));
      });

      a100TestHome('F030/F031/F075/F076 QUESTS cards $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.more, more: MoreSection.quests);
        await a100Settle(t);
        expect(find.byKey(JobsOverlay.barKey(0)), findsOneWidget);
        expect(find.byKey(JobsOverlay.progressKey(0)), findsOneWidget);
        expect(find.textContaining('Progress 0/'), findsNothing);
        expect(find.text('NEW GOAL'), findsNothing);
        expect(find.text('Daily · Bounty · Side · Week · Contract'), findsNothing);
        expect(t.takeException(), isNull);
      });

      a100TestHome('F034/F035/F036/F087 KEY dial $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale, inDungeon: false);
        router.open(MenuRoute.key);
        await a100Settle(t);
        expect(find.byKey(ChallengeToggles.valueKey), findsOneWidget);
        expect(find.text('KEY +0'), findsOneWidget);
        expect(find.byKey(ChallengeToggles.enterKey), findsOneWidget);
        expect(find.text('RANKED GR'), findsNothing);
        expect(find.byKey(MenuChrome.foldChevronKey), findsWidgets);
        expect(t.takeException(), isNull);
      });

      a100TestHome('F040/F041/F096 BLESSING $tag', (t) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.essence, essence: EssencePanel.keep);
        router.pushSub();
        await a100Settle(t);
        expect(find.byType(EssenceKeepPanel), findsOneWidget);
        a100ExpectWhole(t, find.text(EssenceKeepPanel.introLine));
        expect(find.byKey(EssenceKeepPanel.masteryGoalKey('gh_dmg_5')),
            findsOneWidget);
        expect(find.textContaining('Needs Damage Lv5'), findsOneWidget);
        // The first God Hand buy sits right under the one-line intro.
        final dmg = find.textContaining('Damage ·');
        expect(dmg, findsWidgets);
        expect(t.getRect(dmg.first).top, lessThan(size.height * 0.62));
        expect(t.takeException(), isNull);
      });

      a100TestHome('F051 ESSENCE tiles show status and a buy dot $tag', (
        t,
      ) async {
        final (_, router) = await a100Pump(t, size, scale);
        router.open(MenuRoute.essence);
        await a100Settle(t);
        expect(find.textContaining('Next blessing:'), findsOneWidget);
        expect(find.byKey(EssenceTilesScreen.buyDotKey), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  }

  test('F029 ticket words', () {
    expect(ScrollsSheet.useLabel(1), 'USE · 1 ticket');
    expect(ScrollsSheet.needTickets(2), 'Need 2 tickets');
  });

  test('F034 dial ENTER label', () {
    expect(ChallengeToggles.enterLabel(0), 'ENTER');
    expect(ChallengeToggles.enterLabel(3), 'ENTER KEY +3');
  });
}
