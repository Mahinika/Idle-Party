import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/local_reminders.dart';
import 'package:idle_party/ui/meta/codex_overlay.dart';
import 'package:idle_party/ui/meta/notify_opt_in.dart';
import 'package:idle_party/ui/shell/beast_overlay.dart';
import 'package:idle_party/ui/shell/craft_overlay.dart';
import 'package:idle_party/ui/shell/relics_overlay.dart';
import 'package:idle_party/ui/start_menu_screen.dart';

/// WS-D empty states and small-phone layout for meta sheets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void phone360x640Scale2(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
    tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
  }

  void releasePhone(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  testWidgets('CRAFT before first boss names the unlock', (tester) async {
    addTearDown(() => releasePhone(tester));
    phone360x640Scale2(tester);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    );
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CraftOverlay(director: director))),
    );
    await tester.pump();
    expect(find.text('CRAFT opens after the first boss.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title save slots fit 360x640 at text scale 2', (tester) async {
    addTearDown(() => releasePhone(tester));
    phone360x640Scale2(tester);
    final slots = List<SaveSlotSummary>.generate(
      5,
      (i) => SaveSlotSummary(
        index: i,
        partyName: i == 0 ? 'The Ember Guard' : null,
        zoneName: i == 0 ? 'Sandy Caverns' : null,
        partyLevel: i == 0 ? 3 : null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SaveSlotPicker(
          slots: slots,
          activeSlot: 0,
          onOpenSlot: (_) {},
          onEraseSlot: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      expect(find.text('SAVE $i'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    GameDirector director,
    Widget sheet,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            width: 360,
            child: sheet,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('codex empty copy at text scale 2', (tester) async {
    addTearDown(() => releasePhone(tester));
    phone360x640Scale2(tester);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    );
    addTearDown(director.dispose);
    await pumpSheet(tester, director, CodexOverlay(director: director));
    expect(
      find.text(
        'No monsters discovered yet. Fight your way through a dungeon.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pets empty copy at text scale 2', (tester) async {
    addTearDown(() => releasePhone(tester));
    phone360x640Scale2(tester);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(
        now: DateTime(2026, 11, 7),
      ).copyWith(bossVictories: 1),
    );
    addTearDown(director.dispose);
    await pumpSheet(tester, director, BeastOverlay(director: director));
    expect(find.text('No pets yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('relics empty copy at text scale 2', (tester) async {
    addTearDown(() => releasePhone(tester));
    phone360x640Scale2(tester);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(
        now: DateTime(2026, 11, 7),
      ).copyWith(bossVictories: 1),
    );
    addTearDown(director.dispose);
    await pumpSheet(tester, director, RelicsOverlay(director: director));
    expect(
      find.textContaining('No relics yet. Embers from bosses'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('notify opt-in dialog fits 360x640 at text scale 2', (tester) async {
    addTearDown(() => releasePhone(tester));
    phone360x640Scale2(tester);
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NotifyOptInOverlay(director: director),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(LocalReminders.optInTitle), findsOneWidget);
    expect(find.textContaining('Never between 10pm and 8am'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('bad save JSON import returns null', () {
    expect(GameLogic.importSaveJson('not-json-at-all'), isNull);
    expect(GameLogic.importSaveJson('[1,2,3]'), isNull);
  });
}
