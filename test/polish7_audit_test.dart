import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/changelog.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/game_storage.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/hub/hub_header.dart';
import 'package:idle_party/ui/shell/beast_overlay.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/wipe_overlay.dart';
import 'package:idle_party/ui/start_menu_screen.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/meta/farm_strength_picker.dart';
import 'package:idle_party/ui/meta/play_games_section.dart';
import 'package:idle_party/ui/redeem_coupon_dialog.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Polish 7 audit (Nov 19): regressions for the findings in
/// layout-brick/polish7/fynd.md. Sizes: 360x780 and A56 412x915 at 1.0 and
/// the 1.45 cap.
const _sizes = [Size(360, 780), Size(412, 915)];
final _scales = [1.0, GameTheme.typeScaleMax];

bool _overlaps(Rect a, Rect b) => a.intersect(b).width > 0.5 && a.intersect(b).height > 0.5;

void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  group('P049 a locked GEAR tab never rebuilds the router mid-build', () {
    for (final panel in [GearPanel.merge, GearPanel.roster]) {
      for (final scale in _scales) {
        a100TestHome('early save opens ${panel.name} @$scale', (t) async {
          final (_, r) = await a100Pump(
            t,
            _sizes.first,
            scale,
            fresh: true,
            clearedFloors: 1,
          );
          r.open(MenuRoute.gear, gear: panel);
          await a100Settle(t);
          expect(t.takeException(), isNull);
          // The locked tab falls back to GEAR, and the router agrees.
          expect(r.gearPanel, GearPanel.gear);
          expect(r.route, MenuRoute.gear);
        });
      }
    }
  });

  group('P016 welcome back never says "nothing" above a prize', () {
    final s = GameLogic.createInitialState(now: shellGoldenNow);
    test('a waiting chest gets a prize line, not "no gold or essence"', () {
      final line = GameLogic.returnGainLine(
        s,
        goldGained: 0,
        essenceGained: 0,
        prizeWaiting: true,
      );
      expect(line.toLowerCase(), isNot(contains('no gold or essence')));
      expect(line.toLowerCase(), contains('prize'));
      expect(line, isNot(contains('button below')));
    });
    test('nothing at all still names the real next button', () {
      final none = GameLogic.returnGainLine(s, goldGained: 0, essenceGained: 0);
      expect(none, contains('No gold or essence'));
      expect(none, contains('ENTER DUNGEON'));
      expect(none, contains('next fight'));
      final cave = GameLogic.returnGainLine(
        s,
        goldGained: 0,
        essenceGained: 0,
        nextLabel: 'CONTINUE',
      );
      expect(cave, contains('CONTINUE is the next fight'));
    });
  });

  group('P046 redeem shows no live code and needs input', () {
    for (final scale in _scales) {
      testWidgets('dialog @$scale', (t) async {
        t.view.physicalSize = _sizes.first;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await a100Director();
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showRedeemCouponDialog(ctx, d),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        expect(find.text('REDEEM CODE'), findsOneWidget);
        expect(find.textContaining('FOREVERSCROLLS'), findsNothing);
        GameButton redeem() =>
            t.widget<GameButton>(find.byKey(RedeemCouponKeys.redeem));
        expect(redeem().onPressed, isNull, reason: 'empty field');
        expect(redeem().style, GameButtonStyle.go);
        await t.enterText(find.byType(TextField), '   ');
        await t.pump();
        expect(redeem().onPressed, isNull, reason: 'blank field');
        await t.enterText(find.byType(TextField), 'ABC');
        await t.pump();
        expect(redeem().onPressed, isNotNull);
        await t.tap(find.text('CLOSE'));
        await t.pumpAndSettle();
        d.dispose();
      });
    }
  });

  group('P033 the FARM sheet close X sits on its own row', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        a100TestHome('farm sheet ${a100Label(size, scale)}', (t) async {
          final (d, _) = await a100Pump(t, size, scale, maxed: true);
          unawaitedSheet(
            FarmStrengthPicker.openSheet(t.element(find.byType(HomeShell)), d),
          );
          await a100Settle(t);
          final x = t.getRect(find.byKey(MenuChrome.sheetCloseKey));
          for (final m in [1, 2, 4]) {
            final tile = t.getRect(find.byKey(FarmStrengthPicker.tierKey(m)));
            expect(_overlaps(x, tile), isFalse, reason: '$m× tile under X');
            expect(tile.top, greaterThanOrEqualTo(x.bottom - 0.5));
          }
          expect(find.text(FarmStrengthPicker.title), findsOneWidget);
          expect(x.width, greaterThanOrEqualTo(GameTheme.minTouch - 0.5));
        });
      }
    }
  });

  group('P027 the target card never covers the floor line', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final maxed in [false, true]) {
          a100TestHome(
            'fight ${maxed ? 'late' : 'early'} ${a100Label(size, scale)}',
            (t) async {
              final (d, _) = maxed
                  ? await a100Pump(t, size, scale, maxed: true)
                  : await a100Pump(
                      t,
                      size,
                      scale,
                      fresh: true,
                      clearedFloors: 1,
                    );
              d.dismissOfflineSummary();
              for (var i = 0; i < 12; i++) {
                await t.pump(const Duration(milliseconds: 150));
              }
              final title = find.byKey(TargetCornerHud.titleKey);
              final line = find.byWidgetPredicate(
                (w) => w is Text && (w.data ?? '').startsWith('F1 ·'),
              );
              if (title.evaluate().isEmpty || line.evaluate().isEmpty) {
                fail('fight HUD not drawn: title/line missing');
              }
              final card = t.getRect(
                find
                    .ancestor(of: title, matching: find.byType(Container))
                    .first,
              );
              for (final e in line.evaluate()) {
                final r = t.getRect(find.byWidget(e.widget));
                expect(_overlaps(card, r), isFalse, reason: 'card $card line $r');
              }
            },
          );
        }
      }
    }
  });

  test('P041 the season line has no console-id notes', () {
    for (final boards in [false, true]) {
      final line = PlayGamesSection.seasonLine('2026-11', boards: boards);
      expect(line, isNot(contains('Console')));
      expect(line, isNot(contains('ids')));
      expect(line, isNot(contains('reuses')));
      expect(line, contains('cloud backup'));
    }
  });

  test('P018 patch notes match the town-home layout (F100)', () {
    final top = ChangelogCatalog.releases.first;
    final text = [top.summary ?? '', ...top.changed].join(' ');
    expect(text, isNot(contains('The fight is the home screen')));
    expect(text, isNot(contains('Scrolls now sit on the fight rail')));
    expect(text, contains('GUILD'));
    expect(text, contains('VAULT'));
  });

  // ---------------------------------------------------------------- batch 2
  Future<void> bind(WidgetTester t, Size size, double scale) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Iterable<GameButton> buttons(WidgetTester t) =>
      t.widgetList<GameButton>(find.byType(GameButton));

  group('P001/P035 PARTY WIPED: one go face, every offer kept', () {
    for (final scale in _scales) {
      testWidgets('wipe panel @$scale', (t) async {
        await bind(t, _sizes.first, scale);
        final d = await a100Director();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: GameTheme.stoneDeep,
              body: Center(
                child: DungeonWipePanel(
                  director: d,
                  farm: false,
                  dailyEcho: false,
                ),
              ),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 300));
        final all = buttons(t).toList();
        final go = all.where((b) => b.style == GameButtonStyle.go).toList();
        expect(go, hasLength(1));
        expect(go.single.label, startsWith('RETRY'));
        final revive = all.where((b) => b.label == 'REVIVE — WATCH AD');
        expect(revive, hasLength(1), reason: 'the revive offer stays');
        expect(revive.single.primary, isFalse);
        expect(revive.single.icon, UiIcon.watchAd);
        final ticket = all.where((b) => b.label == 'WATCH AD · +1 ticket');
        expect(ticket, hasLength(1), reason: 'the ticket offer stays');
        expect(find.textContaining('second wipe farms'), findsNothing);
        await t.pumpWidget(const SizedBox.shrink());
        d.dispose();
      });
    }
  });

  group('P009 CHOOSE SAVE says what a tap does', () {
    for (final scale in _scales) {
      testWidgets('save picker @$scale', (t) async {
        await bind(t, _sizes.first, scale);
        final opened = <int>[];
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SaveSlotPicker(
                slots: const [
                  SaveSlotSummary(
                    index: 0,
                    partyName: 'Aegis Vale Ember',
                    zoneName: 'Sandy Caverns',
                    ascensionLevel: 2,
                    partyLevel: 14,
                  ),
                  SaveSlotSummary(index: 1),
                  SaveSlotSummary(index: 2, corrupt: true),
                ],
                activeSlot: 0,
                onOpenSlot: opened.add,
                onEraseSlot: (_) {},
                onBack: () {},
              ),
            ),
          ),
        );
        expect(find.byKey(const ValueKey('save-slot-go-0')), findsOneWidget);
        expect(find.text('PLAY'), findsOneWidget);
        expect(find.text('NEW GAME'), findsOneWidget);
        expect(find.byKey(const ValueKey('save-slot-go-2')), findsNothing);
        final erase = buttons(t).where((b) => b.label == 'ERASE').toList();
        expect(erase, hasLength(2), reason: 'occupied + corrupt can erase');
        for (final b in erase) {
          expect(b.style, isNot(GameButtonStyle.red));
          expect(b.tip, startsWith('Erase save'));
        }
        await t.tap(find.text('PLAY'));
        await t.tap(find.text('NEW GAME'));
        expect(opened, [0, 1]);
        a100ExpectWhole(t, find.text('Sandy Caverns · Lv 14 · AL 2'));
      });
    }
  });

  group('P002/P034 INCOME sheet has one exit', () {
    testWidgets('income sheet', (t) async {
      await bind(t, _sizes.first, 1.0);
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showHubIncomeSheet(
                ctx,
                incomeLine: '21g/min',
                multiplierLine: 'Gold',
                displayTitle: '',
                willRank: '',
                collectionScore: 0,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(MenuChrome.sheetCloseKey), findsOneWidget);
      expect(find.text('CLOSE'), findsNothing);
      await t.tap(find.byKey(MenuChrome.sheetCloseKey));
      await t.pumpAndSettle();
      expect(find.text('INCOME'), findsNothing);
    });
  });

  group('P057 PETS: one template for both hatch buttons', () {
    for (final scale in _scales) {
      testWidgets('pets @$scale', (t) async {
        await bind(t, _sizes.first, scale);
        final d = await a100Director(maxed: true);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: BeastOverlay(director: d)),
            ),
          ),
        );
        await t.pump();
        final hatch = buttons(t).where((b) => b.label.startsWith('HATCH'));
        final egg = buttons(t).where((b) => b.label.startsWith('EGG'));
        expect(hatch, hasLength(1));
        expect(egg, hasLength(1));
        expect(hatch.single.label, isNot(endsWith('e')));
        expect(hatch.single.icon, UiIcon.essence);
        expect(egg.single.icon, UiIcon.cinders);
        expect(hatch.single.dense, egg.single.dense);
        expect(
          hatch.single.style,
          anyOf(GameButtonStyle.essence, GameButtonStyle.grey),
        );
        await t.pumpWidget(const SizedBox.shrink());
        d.dispose();
      });
    }
  });

  test('P036 DAILY VAULT body reads in order', () {
    final body = HomeCatalog.vaultBody(clears: 0, target: 1);
    expect(body, isNot(contains('then to')));
    expect(body, contains('Then tap VAULT'));
  });
}

void unawaitedSheet(Future<void> f) {}
