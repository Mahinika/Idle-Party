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
import 'package:idle_party/ui/shell/home/home_menu_grid.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/local_reminders.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/ui/apex_forge_panel.dart';
import 'package:idle_party/ui/first_session_tips.dart';
import 'package:idle_party/ui/meta/keystone_sheet.dart';
import 'package:idle_party/ui/shell/home/floor_jump_sheet.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';
import 'package:idle_party/ui/meta/codex_overlay.dart';
import 'package:idle_party/ui/shell/relics_overlay.dart';
import 'package:idle_party/ui/shell/home/map_screen.dart';
import 'package:idle_party/ui/new_game_party_picker.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Polish 7 audit (Nov 19): regressions for the findings in
/// layout-brick/polish7/fynd.md. Sizes: 360x780 and A56 412x915 at 1.0 and
/// the 1.45 cap.
const _sizes = [Size(360, 780), Size(412, 915)];
final _scales = [1.0, GameTheme.typeScaleMax];

bool _overlaps(Rect a, Rect b) =>
    a.intersect(b).width > 0.5 && a.intersect(b).height > 0.5;

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
              final card = t.getRect(find.byKey(TargetCornerHud.stripKey));
              for (final e in line.evaluate()) {
                final r = t.getRect(find.byWidget(e.widget));
                expect(
                  _overlaps(card, r),
                  isFalse,
                  reason: 'card $card line $r',
                );
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

  // ---------------------------------------------------------------- batch 3
  Future<void> popAll(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await a100Settle(t);
    }
  }

  group('P011 town alerts sit on the building art', () {
    for (final scale in _scales) {
      a100TestHome('town alerts @$scale', (t) async {
        await a100Pump(
          t,
          _sizes.last,
          scale,
          maxed: true,
          inDungeon: false,
          live: true,
          adTickets: 3,
        );
        await a100Settle(t);
        await popAll(t);
        final alerts = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('town-alert-'),
        );
        expect(
          alerts,
          findsWidgets,
          reason: 'a maxed town has something waiting',
        );
        for (final e in alerts.evaluate()) {
          final id = (e.widget.key! as ValueKey<String>).value.substring(11);
          final b = t.getRect(find.byKey(ValueKey('town-$id')));
          final a = t.getRect(find.byWidget(e.widget));
          // Inside the building's tap box, in its upper half (the roof).
          expect(b.inflate(0.5).contains(a.topLeft), isTrue, reason: id);
          expect(b.inflate(0.5).contains(a.bottomRight), isTrue, reason: id);
          expect(a.center.dy, lessThan(b.center.dy), reason: id);
        }
      });
    }
  });

  group('P012 the town coach never fights the big button', () {
    test('Tap ENTER only when the button says ENTER', () async {
      for (final maxed in [false, true]) {
        final d = await a100Director(maxed: maxed, inDungeon: false);
        final cta = HomeShell.townCtaLabel(d.state).toUpperCase();
        expect(
          HomeShell.coachDisagreesWithTownCta('Tap ENTER.', d.state),
          !cta.startsWith('ENTER'),
          reason: cta,
        );
        expect(
          HomeShell.coachDisagreesWithTownCta('Claim the chest.', d.state),
          cta.startsWith('CLAIM'),
          reason: cta,
        );
        expect(HomeShell.coachDisagreesWithTownCta(null, d.state), isFalse);
        expect(HomeShell.coachDisagreesWithTownCta('', d.state), isFalse);
        d.dispose();
      }
    });
  });

  group('P029 a short rail count rides the icon at 1.45', () {
    void expectScrollsCount(WidgetTester t, {Finder? scrollsText}) {
      // Short ticket counts always ride the icon pip so the label never
      // becomes "SCROLLS 3" and clip at 1.45.
      expect(find.text('SCROLLS 3'), findsNothing);
      final label = scrollsText ?? find.text('SCROLLS');
      expect(label, findsOneWidget);
      final scrolls = find.ancestor(
        of: label,
        matching: find.byType(RailButton),
      );
      expect(scrolls, findsOneWidget);
      final pip = find.descendant(
        of: scrolls,
        matching: find.byKey(RailButton.countKey),
      );
      expect(pip, findsOneWidget);
      expect(
        find.descendant(of: pip, matching: find.text('3')),
        findsOneWidget,
      );
      a100ExpectWhole(t, label);
    }

    for (final scale in _scales) {
      a100TestHome('fight rail @$scale', (t) async {
        await a100Pump(
          t,
          _sizes.first,
          scale,
          live: true,
          clearedFloors: 4,
          adTickets: 3,
        );
        await a100Settle(t);
        await popAll(t);
        expectScrollsCount(t);
      });
    }

    for (final scale in _scales) {
      a100TestHome('town MENU @$scale', (t) async {
        await a100Pump(
          t,
          _sizes.first,
          scale,
          inDungeon: false,
          live: true,
          clearedFloors: 4,
          adTickets: 3,
        );
        await a100Settle(t);
        await popAll(t);
        // Town hides the fight rail; SCROLLS is on the viewport and MENU.
        expect(
          find.descendant(
            of: find.byType(TownViewport),
            matching: find.text('SCROLLS'),
          ),
          findsOneWidget,
        );
        await t.tap(find.bySemanticsLabel(RegExp(r'^MENU')).first);
        await a100Settle(t);
        expectScrollsCount(
          t,
          scrollsText: find.descendant(
            of: find.byType(HomeMenuGrid),
            matching: find.text('SCROLLS'),
          ),
        );
      });
    }
  });

  group('P031 the closed dock says how close it is', () {
    test('progress counts floors toward the first boss', () {
      final s0 = GameLogic.createInitialState(now: shellGoldenNow);
      expect(UpgradePanel.lockProgress(s0), 0.0);
      final s1 = s0.copyWith(highestFloorCleared: 1);
      expect(UpgradePanel.lockProgress(s1), 0.5);
      expect(UpgradePanel.lockProgressLine(s1), 'Floors cleared: 1/2');
      expect(
        UpgradePanel.lockProgress(s0.copyWith(highestFloorCleared: 9)),
        1.0,
      );
    });
  });

  group('P034 INCOME sheet explains the rate', () {
    testWidgets('no bare "· Gold" line', (t) async {
      await bind(t, _sizes.first, GameTheme.typeScaleMax);
      final d = await a100Director(maxed: true);
      final line = GoldIncome.multiplierLine(d.state);
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showHubIncomeSheet(
                ctx,
                incomeLine: '21g/min',
                multiplierLine: line,
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
      expect(find.text(' · Gold'), findsNothing);
      expect(find.text(line), findsOneWidget);
      expect(find.text(HubIncomeSheetKeys.howLine), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      d.dispose();
    });
  });

  // ---------------------------------------------------------------- batch 4
  group('batch 4 terms and texts', () {
    final s0 = GameLogic.createInitialState(now: shellGoldenNow);

    test('P005 one word pair: FARM/PUSH from the first floor on', () {
      expect(GameLogic.plainPlayerChrome(s0), isTrue);
      expect(
        GameLogic.dungeonModeChipLabel(DungeonMode.farm, s0),
        contains('FARM'),
      );
      expect(
        GameLogic.dungeonModeChipLabel(DungeonMode.push, s0),
        contains('PUSH'),
      );
      expect(FirstSessionTips.farmPushPlain, contains('FARM'));
      expect(FirstSessionTips.farmPushPlain, isNot(contains('Repeat')));
      for (final mode in DungeonMode.values) {
        final line = WipeAdvice.modeLineFor(s0.copyWith(dungeonMode: mode));
        expect(line, isNot(contains('Repeat')));
        expect(line, isNot(startsWith('Next')));
      }
    });

    test('P019 the quest streak does not say "in a row"', () {
      final line = JobsOverlay.introLine(chainCount: 1);
      expect(line, isNot(contains('in a row')));
      expect(line, contains('+5 essence'));
      expect(line, contains('1/3'));
    });

    test('P037/P043 sheet subtitles match their tabs', () {
      final r = MenuRouter();
      r.open(MenuRoute.more, more: MoreSection.settings);
      expect(r.jobHint, isNot(contains('zoom')));
      expect(r.jobHint, contains('account'));
      r.open(MenuRoute.more, more: MoreSection.info);
      expect(r.jobHint, isNot(contains('Patch Notes')));
    });

    test('P047 FLOORS lists a floor once and hides KEY talk early', () {
      final s = s0.copyWith(inDungeon: true);
      expect(floorJumpHint(s), isNot(contains('KEY')));
      expect(floorJumpHint(s.copyWith(hardmodeLevel: 2)), contains('KEY'));
      final here = s.currentRoom.floorNumber;
      expect(floorJumpCleared(s).every((f) => f < here), isTrue);
    });

    test('P048 KEY sheet: one intro, no "Dial, then ENTER" twice', () {
      expect(KeystoneSheet.intro, contains('ENTER'));
    });

    test('P059 the reminder opt-in reads plainly', () {
      expect(LocalReminders.optInBody, isNot(contains('names')));
      expect(LocalReminders.optInBody, contains('In the morning'));
    });

    testWidgets('P021 craft stats read as chips, item level spelled out', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApexHubPanel.statChips('i50 · 1H mace · +20 Str · +2% CRIT'),
          ),
        ),
      );
      expect(find.text('Item Lv 50'), findsOneWidget);
      expect(find.text('+20 Str'), findsOneWidget);
      expect(find.textContaining('i50'), findsNothing);
    });
  });

  group('hero names never read as a currency', () {
    test('the fire mage shows as Blaze, but keeps its saved name and id', () {
      final party = GameLogic.createInitialState().heroes;
      final fire = party.firstWhere((h) => h.name == 'Ember');
      expect(fire.shownName, 'Blaze');
      expect(fire.displayName(plainEnglish: true), 'Blaze');
      expect(fire.toJson()['name'], 'Ember');
      expect(PartyHero.specForName('Ember'), fire.specId);
      expect(PartyHero.shownNameFor('Aegis'), 'Aegis');
      for (final h in party) {
        expect(h.shownName.toLowerCase(), isNot(contains('ember')));
        expect(h.shownName.toLowerCase(), isNot(contains('cinder')));
      }
    });
  });

  // ---------------------------------------------------------------- batch 5
  group('batch 5 clipping and lists', () {
    test('P044 codex milestones say what they pay', () {
      expect(
        CodexOverlay.tierLabel(
          pct: 25,
          reward: 8,
          claimed: false,
          ready: false,
        ),
        'Reward at 25%: +8 essence',
      );
      expect(
        CodexOverlay.tierLabel(pct: 25, reward: 8, claimed: false, ready: true),
        isNot(endsWith('e')),
      );
      expect(
        CodexOverlay.tierLabel(pct: 25, reward: 8, claimed: true, ready: false),
        contains('claimed'),
      );
    });

    testWidgets('P044 empty codex tab says so under the toggle', (t) async {
      await bind(t, _sizes.first, GameTheme.typeScaleMax);
      final d = await a100Director(fresh: true);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CodexOverlay(director: d)),
        ),
      );
      await t.pump();
      final empty = find.byKey(CodexOverlay.emptyKey);
      expect(empty, findsOneWidget);
      expect(find.textContaining('No monsters discovered'), findsOneWidget);
      // Near the top, not pushed to the bottom of the sheet.
      expect(t.getRect(empty).top, lessThan(_sizes.first.height / 2));
      await t.pumpWidget(const SizedBox.shrink());
      d.dispose();
    });

    test('P056 weekly trade count has its own line', () {
      expect(RelicsOverlay.weeklyLine(1), contains('1/'));
      expect(RelicsOverlay.weeklyLine(1), contains('this week'));
    });

    test('P026 MAP zone line is plain words', () async {
      final d = await a100Director();
      final def = DungeonCatalog.byId(d.state.dungeonId);
      final line = MapScreen.zoneDetail(d.state, def, open: true, mean: 3);
      expect(line, contains('Party level 3'));
      expect(line, isNot(contains('Lv3 /')));
      d.dispose();
    });

    for (final scale in _scales) {
      testWidgets('P010 NEW PARTY class tabs wrap @$scale', (t) async {
        await bind(t, _sizes.first, scale);
        await t.pumpWidget(
          MaterialApp(
            home: NewGamePartyPicker(
              onConfirm: (specs, name, races, {sexes}) async {},
              onBack: () {},
            ),
          ),
        );
        await t.pump();
        final tabs = find.byKey(NewGamePartyPicker.classTabsKey);
        if (tabs.evaluate().isEmpty) return; // RACE tab first on this build
        expect(t.widget(tabs), isA<Wrap>());
        for (final e
            in find
                .descendant(of: tabs, matching: find.byType(GameButton))
                .evaluate()) {
          final r = t.getRect(find.byWidget(e.widget));
          expect(r.right, lessThanOrEqualTo(_sizes.first.width + 0.5));
        }
        expect(t.takeException(), isNull);
      });
    }
  });

  // ---------------------------------------------------------------- batch 6
  group('batch 6 empty states and finish', () {
    for (final scale in _scales) {
      testWidgets('P058 SHOP without Play: notes, no dead buttons @$scale', (
        t,
      ) async {
        await bind(t, _sizes.first, scale);
        final d = await a100Director();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ShopDock(director: d)),
          ),
        );
        await t.pump();
        expect(find.text('UNAVAILABLE'), findsNothing);
        expect(find.text(ShopDock.noPrice), findsNothing);
        expect(find.textContaining('Waiting for Play billing'), findsNothing);
        // The plain line sits in the one-row banner, with RETRY beside it.
        if (ShopDock.goldenTestPriceLabel.isEmpty) {
          final banner = find.byKey(ShopDock.billingBannerKey);
          expect(banner, findsOneWidget);
          expect(
            find.descendant(
              of: banner,
              matching: find.text(ShopDock.needsPlayLine),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: banner, matching: find.text('RETRY')),
            findsOneWidget,
          );
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        d.dispose();
        await t.pump(const Duration(milliseconds: 20));
      });
    }

    test('P054 ESSENCE hub says where essence comes from', () {
      expect(EssenceTilesScreen.howLine, contains('Essence'));
      final s = GameLogic.createInitialState(now: shellGoldenNow);
      expect(EssenceTilesScreen.petStatus(s), isNot(matches(RegExp(r'\de$'))));
      expect(EssenceTilesScreen.blessingStatus(s), endsWith('essence'));
    });

    test('P058 a Play-less store line counts as waiting', () {
      expect(ShopDock.isWaitingLine(ShopDock.needsPlayLine), isTrue);
      expect(ShopDock.isWaitingLine('Waiting for Play catalog…'), isTrue);
      expect(ShopDock.isWaitingLine('Prices come from Google Play.'), isFalse);
    });

    test('P037/P058 SHOP subtitle does not fight the policy line', () {
      final r = MenuRouter();
      r.open(MenuRoute.shop);
      // Names what is sold (packs), not where Cinders are spent.
      expect(r.jobHint, contains('Ad-free'));
      expect(r.jobHint, contains('Cinder packs'));
      expect(r.jobHint, isNot(contains('SCROLLS')));
    });
  });
}

void unawaitedSheet(Future<void> f) {}
