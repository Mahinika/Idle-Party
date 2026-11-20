import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hub/hub_powerups.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/meta/farm_strength_picker.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';
import 'package:idle_party/ui/shell/shell_common.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Robert, Nov 19 "Fixa resten": the leftover polish on PR #85.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  const phone = Size(360, 780);

  Future<void> closePrompts(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await a100Settle(t);
    }
  }

  group('home party chip CC', () {
    test('first CC word, "+" when more are active', () {
      expect(homeChipCcLabel(['SLOW']), 'SLOW');
      expect(homeChipCcLabel(['ROOT', 'SLOW']), 'ROOT+');
    });

    for (final scale in [1.0, GameTheme.typeScaleMax]) {
      a100TestHome('SLOW on every hero reads whole on 360 dp @$scale', (
        t,
      ) async {
        final (d, _) = await a100Pump(
          t,
          phone,
          scale,
          maxed: false,
          live: true,
          clearedFloors: 4,
        );
        await closePrompts(t);
        final w = d.spatial!;
        for (final a in w.heroes) {
          if (!a.isPet) a.attackSlowTimer = 30;
        }
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        d.notifyListeners();
        await t.pump(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull);
        final cc = find.byKey(homeChipCcKey);
        expect(cc, findsWidgets);
        expect(find.textContaining(' · SLOW'), findsWidgets);
        a100ExpectWhole(t, cc);
      });
    }
  });

  a100TestHome('SCROLLS opens below the HUD, like the menu panels (F048)', (
    t,
  ) async {
    await a100Pump(t, phone, 1.0, maxed: false, live: true, clearedFloors: 4);
    await closePrompts(t);
    await t.tap(find.text('SCROLLS').first, warnIfMissed: false);
    await a100Settle(t);
    final sheet = find.byKey(powerupsSheetKey);
    expect(sheet, findsOneWidget);
    final hud = t.getRect(find.byType(HomeTopBar));
    final panel = find.descendant(of: sheet, matching: find.byType(Material));
    expect(t.getRect(panel.first).top, greaterThanOrEqualTo(hud.bottom - 0.5));
    // The nav stays visible below the panel.
    expect(t.getRect(panel.first).bottom, lessThan(phone.height - 40));
    final bottom = HomeShell.topChromeBottom(
      t.element(find.byType(HomeTopBar)),
    );
    expect(bottom, isNotNull);
    expect(bottom!, greaterThanOrEqualTo(hud.bottom - 0.5));
    // Handle on top, CLOSE still closes.
    expect(
      find.descendant(of: sheet, matching: find.text('SCROLLS')),
      findsOneWidget,
    );
    await t.tap(find.text('CLOSE').first);
    await a100Settle(t);
    expect(sheet, findsNothing);
  });

  a100TestHome('FARM sheet has the handle and the shared close X (F069)', (
    t,
  ) async {
    final (d, _) = await a100Pump(
      t,
      phone,
      1.0,
      maxed: false,
      live: true,
      clearedFloors: 4,
    );
    await closePrompts(t);
    FarmStrengthPicker.openSheet(t.element(find.byType(HomeTopBar)), d);
    await a100Settle(t);
    expect(find.byKey(FarmStrengthPicker.pickerKey), findsOneWidget);
    final x = find.byKey(MenuChrome.sheetCloseKey);
    expect(x, findsOneWidget);
    expect(
      t.getSize(x).height,
      greaterThanOrEqualTo(GameTheme.minTouch - 0.01),
    );
    await t.tap(x);
    await a100Settle(t);
    expect(find.byKey(FarmStrengthPicker.pickerKey), findsNothing);
  });

  group('ESSENCE PETS tile status (F051)', () {
    test('roster and next hatch price', () {
      final s = GameLogic.createInitialState(now: shellGoldenNow);
      final cap = s.metaDepth.basePetRosterCap;
      expect(
        EssenceTilesScreen.petStatus(s),
        '${s.ownedPets.length}/$cap · hatch '
        '${formatCount(GameLogic.hatchPetCost(s))} essence',
      );
    });

    a100TestHome('PETS shows its status on the hub', (t) async {
      final (d, r) = await a100Pump(
        t,
        phone,
        GameTheme.typeScaleMax,
        maxed: true,
        live: true,
      );
      await closePrompts(t);
      r.open(MenuRoute.essence, essence: EssencePanel.tracks);
      await a100Settle(t);
      expect(t.takeException(), isNull);
      final line = find.text(EssenceTilesScreen.petStatus(d.state));
      expect(line, findsOneWidget);
    });
  });

  testWidgets('GameButton icon sits before the label (F042)', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameButton(
            label: 'WATCH AD · 2×',
            icon: UiIcon.watchAd,
            style: GameButtonStyle.grey,
            onPressed: () {},
          ),
        ),
      ),
    );
    final icon = find.byType(GameIcon);
    expect(icon, findsOneWidget);
    expect(
      t.getRect(icon).right,
      lessThanOrEqualTo(t.getRect(find.text('WATCH AD · 2×')).left),
    );
    expect(find.bySemanticsLabel('WATCH AD · 2×'), findsOneWidget);
  });

  for (final scale in [1.0, GameTheme.typeScaleMax]) {
    a100TestHome('town card: one header line, one rule line on 360 @$scale', (
      t,
    ) async {
      final (d, _) = await a100Pump(
        t,
        phone,
        scale,
        fresh: true,
        inDungeon: false,
        live: true,
        clearedFloors: 2,
      );
      await a100Settle(t);
      d.dismissOfflineSummary();
      d.claimDailyVault();
      for (var k = 0; k < 6; k++) {
        for (final m in d.state.missions.where((m) => m.canClaim).toList()) {
          d.claimMission(m.id, silent: true);
        }
      }
      d.autoEquipBetterGear();
      d.clearToast();
      await a100Settle(t);
      await closePrompts(t);
      expect(t.takeException(), isNull);
      final header = find.byKey(townHeaderKey);
      expect(header, findsOneWidget);
      a100ExpectWhole(t, find.text('Sandy Caverns'));
      final rule = find.text(FarmStrengthPicker.compactUnlockLine(d.state, 4));
      a100ExpectWhole(t, rule);
      final p = t.renderObject<RenderParagraph>(rule);
      expect(p.maxLines, 1);
      // ENTER stays a full primary target under the picker.
      final enter = find.widgetWithText(GameButton, 'ENTER');
      expect(
        t.getSize(enter).height,
        greaterThanOrEqualTo(GameTheme.primaryTouch - 0.01),
      );
      expect(
        t.getRect(find.byKey(FarmStrengthPicker.pickerKey)).bottom,
        lessThanOrEqualTo(t.getRect(enter).top),
      );
    });
  }
}
