import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/meta/codex_overlay.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/settings_overlay.dart';

/// Real app scale (OS × game, capped) and a raw large-font stress that does
/// not go through the cap. The stress case must still lay out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void phone(WidgetTester tester, {required Size logical, double os = 1}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
    tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
    tester.platformDispatcher.textScaleFactorTestValue = os;
  }

  void release(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required double os,
    required double game,
    required bool compose,
    required Size logical,
  }) async {
    phone(tester, logical: logical, os: os);
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    ).copyWith(homeLayout: HomeLayout.home, uiTextScale: game);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    addTearDown(() => release(tester));
    final shell = HomeShell(director: director, router: router, onLeave: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final child = shell;
            if (!compose) return child;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: GameTheme.composeTextScaler(
                  platform: MediaQuery.textScalerOf(context),
                  gameScale: game,
                ),
              ),
              child: child,
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('FIGHT'), findsOneWidget);
  }

  for (final logical in const [Size(360, 780), Size(360, 640)]) {
    for (final os in const [1.0, 1.4, 2.0]) {
      for (final game in const [1.0, kUiTextScaleMax]) {
        testWidgets(
          'composed home ${logical.height.toInt()} os $os game $game',
          (tester) async {
            await pumpHome(
              tester,
              os: os,
              game: game,
              compose: true,
              logical: logical,
            );
          },
        );
      }
    }
    testWidgets('raw scale 2 still lays out ${logical.height.toInt()}', (
      tester,
    ) async {
      await pumpHome(
        tester,
        os: 2,
        game: 1,
        compose: false,
        logical: logical,
      );
    });
  }

  testWidgets('settings text presets name the slider ends', (tester) async {
    expect(SettingsOverlay.textPresets.first.$2, kUiTextScaleMin);
    expect(SettingsOverlay.textPresets.last.$2, kUiTextScaleMax);
  });

  testWidgets('a long button keeps its type size on a short phone', (
    tester,
  ) async {
    phone(tester, logical: const Size(360, 640), os: 2);
    addTearDown(() => release(tester));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GameButton(
              label: 'Spend the whole wallet on the recommended track',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.text('Spend the whole wallet on the recommended track'),
    );
    expect(text.style?.fontSize, GameTheme.typeButton);
    expect(text.maxLines, 2);
  });

  testWidgets('text scale percent stays one line at max on a short phone', (
    tester,
  ) async {
    phone(tester, logical: const Size(360, 640), os: 2);
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 11, 7),
    ).copyWith(uiTextScale: kUiTextScaleMax);
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    addTearDown(() => release(tester));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsOverlay(director: director, onClose: () {}),
        ),
      ),
    );
    await tester.pump();
    final display = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('DISPLAY'),
    );
    await tester.tap(display);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.contains('%') || s.contains('DISPLAY') || s.contains('Text'))
        .toList();
    expect(shown, contains('145%'));
    final percent = tester.widget<Text>(find.text('145%'));
    expect(percent.maxLines, 1);
    expect(percent.softWrap, isFalse);
  });

  testWidgets('empty market and codex name the next step at scale 2', (
    tester,
  ) async {
    phone(tester, logical: const Size(360, 640), os: 2);
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    addTearDown(() => release(tester));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: MarketOverlay(director: director),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No upgrades'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: CodexOverlay(director: director),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No monsters discovered'), findsOneWidget);
  });
}
