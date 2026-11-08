import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/spatial_dungeon_view.dart';

/// The slider has to move the live [MyApp] scaler, including a reload of a
/// save that already stored the value. HomeShell wrapped in a test
/// [MediaQuery] does not count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugHoldFloorBake();

  void phone(
    WidgetTester tester, {
    required Size logical,
    double os = 1,
    double top = 0,
    double bottom = 0,
  }) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.viewPadding = FakeViewPadding(
      top: top * 2,
      bottom: bottom * 2,
    );
    tester.view.padding = FakeViewPadding(top: top * 2, bottom: bottom * 2);
    tester.platformDispatcher.textScaleFactorTestValue = os;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<GameDirector> pumpApp(
    WidgetTester tester, {
    required double game,
    required bool dungeon,
    bool showIntro = false,
  }) async {
    var state = GameLogic.createInitialState(
      now: DateTime(2026, 11, 7),
    ).copyWith(
      homeLayout: HomeLayout.home,
      uiTextScale: game,
      bossVictories: 1,
      highestFloorCleared: 2,
    );
    if (dungeon) state = GameLogic.enterDungeon(state);
    final director = GameDirector.preview(initialState: state);
    await director.boot();
    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: showIntro),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    if (showIntro) {
      await tester.pump(const Duration(seconds: 1));
    }
    return director;
  }

  double scaleOf(WidgetTester tester, Finder finder) {
    return MediaQuery.textScalerOf(tester.element(finder)).scale(1);
  }

  testWidgets('slider change and a reloaded save both scale MyApp', (
    tester,
  ) async {
    phone(tester, logical: const Size(360, 780));
    final director = await pumpApp(tester, game: 1, dungeon: true);
    expect(tester.takeException(), isNull);
    expect(scaleOf(tester, find.text('FIGHT')), closeTo(1, 0.001));
    expect(find.text('HEROES'), findsOneWidget);

    director.setUiTextScale(kUiTextScaleMax);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(scaleOf(tester, find.text('FIGHT')), closeTo(kUiTextScaleMax, 0.001));
    expect(scaleOf(tester, find.text('FARM')), closeTo(kUiTextScaleMax, 0.001));
    expect(scaleOf(tester, find.text('FORGE')), closeTo(kUiTextScaleMax, 0.001));
    expect(find.text('145%'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await pumpApp(tester, game: kUiTextScaleMax, dungeon: true);
    expect(tester.takeException(), isNull);
    expect(scaleOf(tester, find.text('FIGHT')), closeTo(kUiTextScaleMax, 0.001));
    expect(scaleOf(tester, find.text('CAMP')), closeTo(kUiTextScaleMax, 0.001));
  });

  testWidgets('start menu uses the same saved scale', (tester) async {
    phone(tester, logical: const Size(360, 780));
    await pumpApp(
      tester,
      game: kUiTextScaleMax,
      dungeon: false,
      showIntro: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('SKIP'), findsOneWidget);
    expect(
      scaleOf(tester, find.text('SKIP')),
      closeTo(kUiTextScaleMax, 0.001),
    );
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('NEW GAME'), findsWidgets);
    expect(
      scaleOf(tester, find.text('NEW GAME').first),
      closeTo(kUiTextScaleMax, 0.001),
    );
  });

  testWidgets('OS 2 times game 1 is the slider ceiling inside MyApp', (
    tester,
  ) async {
    phone(tester, logical: const Size(360, 780), os: 2);
    await pumpApp(tester, game: 1, dungeon: true);
    expect(tester.takeException(), isNull);
    expect(scaleOf(tester, find.text('FIGHT')), closeTo(GameTheme.typeScaleMax, 0.001));
    expect(scaleOf(tester, find.text('FARM')), closeTo(GameTheme.typeScaleMax, 0.001));
  });

  for (final logical in const [Size(360, 780), Size(360, 640)]) {
    for (final dungeon in const [true, false]) {
      final where = dungeon ? 'fight' : 'camp';
      testWidgets('MyApp $where ${logical.height.toInt()} at slider max', (
        tester,
      ) async {
        phone(tester, logical: logical);
        await pumpApp(tester, game: kUiTextScaleMax, dungeon: dungeon);
        expect(tester.takeException(), isNull);
        expect(find.text('FORGE'), findsWidgets);
        expect(find.text('MARKET'), findsWidgets);
        expect(find.text('HEROES'), findsOneWidget);
        expect(find.text('FIGHT'), findsOneWidget);
        if (dungeon) {
          expect(find.text('CAMP'), findsWidgets);
          expect(find.text('FARM'), findsOneWidget);
          expect(find.text('PUSH'), findsOneWidget);
        } else {
          expect(find.text('INN'), findsWidgets);
          expect(find.text('GUILD'), findsWidgets);
        }
        expect(
          tester.getSize(find.text('FORGE').first).height,
          greaterThan(10),
        );
        expect(
          tester.getSize(find.text('FORGE').first).width,
          greaterThan(28),
        );
      });

      testWidgets(
        'OS 2 capped $where ${logical.height.toInt()} still lays out',
        (tester) async {
          phone(tester, logical: logical, os: 2);
          await pumpApp(tester, game: 1, dungeon: dungeon);
          expect(tester.takeException(), isNull);
          expect(
            scaleOf(tester, find.text('FIGHT')),
            closeTo(GameTheme.typeScaleMax, 0.001),
          );
          expect(find.text('FORGE'), findsWidgets);
          expect(find.text('FIGHT'), findsOneWidget);
        },
      );
    }
  }

  testWidgets('A56 gesture inset keeps the home nav above 34', (tester) async {
    phone(tester, logical: const Size(360, 780), bottom: 34);
    await pumpApp(tester, game: 1, dungeon: true);
    expect(tester.takeException(), isNull);
    final label = tester.getRect(find.text('FIGHT'));
    expect(780 - label.bottom, greaterThanOrEqualTo(34));
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('FIGHT'), findsOneWidget);
  });

  testWidgets('short phone keeps a 44 top and 34 bottom margin', (tester) async {
    phone(tester, logical: const Size(360, 640), top: 44, bottom: 34);
    await pumpApp(tester, game: kUiTextScaleMax, dungeon: false);
    expect(tester.takeException(), isNull);
    final label = tester.getRect(find.text('FIGHT'));
    expect(640 - label.bottom, greaterThanOrEqualTo(34));
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('FORGE'), findsWidgets);
    expect(find.text('INN'), findsWidgets);
  });

  testWidgets('raw scale 2 camp and fight docks lay out without the app cap', (
    tester,
  ) async {
    phone(tester, logical: const Size(360, 640), os: 2);
    Future<void> shell({required bool dungeon}) async {
      var state = GameLogic.createInitialState(
        now: DateTime(2026, 11, 7),
      ).copyWith(
        homeLayout: HomeLayout.home,
        bossVictories: 1,
        highestFloorCleared: 2,
      );
      if (dungeon) state = GameLogic.enterDungeon(state);
      final director = GameDirector.preview(initialState: state);
      final router = MenuRouter();
      addTearDown(director.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: HomeShell(
              director: director,
              router: router,
              onLeave: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(scaleOf(tester, find.text('FIGHT')), closeTo(2, 0.001));
      expect(find.text('FORGE'), findsWidgets);
      expect(find.text('MARKET'), findsWidgets);
      if (dungeon) {
        expect(find.text('CAMP'), findsWidgets);
      } else {
        expect(find.text('INN'), findsWidgets);
      }
    }

    await shell(dungeon: false);
    await shell(dungeon: true);
    expect(find.text('FARM'), findsOneWidget);
  });

  testWidgets('top 44 keeps the home header below the cutout', (tester) async {
    phone(tester, logical: const Size(360, 780), top: 44);
    await pumpApp(tester, game: 1, dungeon: true);
    expect(tester.takeException(), isNull);
    final header = tester.getRect(find.text('AL 0'));
    expect(header.top, greaterThanOrEqualTo(44));
    final menu = tester.getRect(find.bySemanticsLabel('MENU'));
    expect(menu.top, greaterThanOrEqualTo(44));
  });

  testWidgets('top 44 keeps the start title below the cutout', (tester) async {
    phone(tester, logical: const Size(360, 780), top: 44);
    await pumpApp(
      tester,
      game: 1,
      dungeon: false,
      showIntro: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('SKIP'), findsOneWidget);
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('IDLE PARTY'));
    expect(title.top, greaterThanOrEqualTo(44));
    final start = tester.getRect(find.text('NEW GAME'));
    expect(start.top, greaterThanOrEqualTo(44));
  });

  testWidgets('top 44 keeps a dialog title below the cutout', (tester) async {
    phone(tester, logical: const Size(360, 640), top: 44, bottom: 34);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final context = tester.element(find.byType(SizedBox));
    showDialog<void>(
      context: context,
      builder: (context) => MenuChrome.dialog(
        title: 'REDEEM CODE',
        content: const Text('Paste a code from a friend.'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('CLOSE')),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('REDEEM CODE'));
    expect(title.top, greaterThanOrEqualTo(44));
    expect(find.text('CLOSE'), findsOneWidget);
  });
}
