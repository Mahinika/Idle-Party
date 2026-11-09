import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/gauntlet_pact.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/confirm_dialogs.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/meta/rift_tier_picker.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void bindPhone(WidgetTester tester, {double scale = 2, double height = 640}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(720, height * 2);
    tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
    tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final live = <GameDirector>{};

  void finish(GameDirector director) {
    if (live.remove(director)) director.dispose();
  }

  Future<GameDirector> endgameDirector() async {
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 11, 6));
    final state = base.copyWith(
      homeLayout: HomeLayout.home,
      inDungeon: false,
      heroes: [
        for (final hero in base.heroes) hero.copyWith(level: 100, xp: 0),
      ],
      heroRoster: [
        for (final hero in base.heroRoster) hero.copyWith(level: 100, xp: 0),
      ],
      lastUpdated: DateTime.now(),
    );
    final director = GameDirector.preview(initialState: state);
    live.add(director);
    addTearDown(() => finish(director));
    await director.boot(deferCombatLoop: true);
    expect(GameLogic.canEnterGauntlet(director.state), isTrue);
    expect(GameLogic.canEnterRift(director.state), isTrue);
    expect(director.state.inDungeon, isFalse);
    return director;
  }

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext) show,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('gauntlet dialog fits 360x640 scale 2 and START taps', (
    tester,
  ) async {
    bindPhone(tester);
    final director = await endgameDirector();
    await open(tester, (context) => confirmGauntletRun(context, director));
    expect(tester.takeException(), isNull);
    expect(find.text('Recommended.'), findsOneWidget);
    final recommended = GameLogic.recommendedGauntletPact(director.state);
    final title = GauntletPacts.title(recommended);
    final start = find.text(title);
    expect(start, findsWidgets);
    expect(start.hitTestable(), findsWidgets);
    await tester.tap(start.first);
    await tester.pump();
    expect(director.state.inGauntlet, isTrue);
    expect(tester.takeException(), isNull);
    finish(director);
  });

  testWidgets('farm rift picker fits and ENTER taps the recommended tier', (
    tester,
  ) async {
    bindPhone(tester);
    final director = await endgameDirector();
    await open(tester, (context) => confirmRiftRun(context, director));
    expect(tester.takeException(), isNull);
    final button = find.byWidgetPredicate(
      (widget) =>
          widget is GameButton && widget.label.startsWith('ENTER FARM R'),
    );
    expect(button, findsOneWidget);
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(director.state.inRift, isTrue);
    expect(tester.takeException(), isNull);
    finish(director);
  });

  testWidgets('ranked GR picker fits and CANCEL taps', (tester) async {
    bindPhone(tester);
    final director = await endgameDirector();
    await open(tester, (context) => confirmGreaterRiftRun(context, director));
    expect(tester.takeException(), isNull);
    expect(find.byType(RiftTierPickerDialog), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    expect(director.state.inGreaterRift, isFalse);
    expect(tester.takeException(), isNull);
    finish(director);
  });

  testWidgets('home shell fits 360x640 scale 2 with notch', (tester) async {
    bindPhone(tester);
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime.utc(2026, 11, 6)),
    ).copyWith(homeLayout: HomeLayout.home, homePanelFull: false);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          director: director,
          router: router,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('FIGHT'), findsOneWidget);
    await tester.tap(find.text('HEROES'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('CLOSE'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    expect(router.route, MenuRoute.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell fits A56 360x780 scale 2 with notch', (tester) async {
    bindPhone(tester, height: 780);
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime.utc(2026, 11, 6)),
    ).copyWith(homeLayout: HomeLayout.home, homePanelFull: true);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          director: director,
          router: router,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('FIGHT'), findsOneWidget);
    await tester.tap(find.text('HEROES'));
    await tester.pump();
    expect(find.text('CLOSE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
