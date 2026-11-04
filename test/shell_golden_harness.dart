import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';
import 'package:idle_party/ui/theme.dart';

/// Fixed clock for stable goldens.
final DateTime shellGoldenNow = DateTime.utc(2026, 8, 22, 14);

String get shellGoldenRoot =>
    const String.fromEnvironment('GOLDEN_ROOT', defaultValue: 'goldens/after');

Future<void> ensureShellGoldenFonts() async {
  await GoogleFonts.pendingFonts([
    GoogleFonts.pressStart2p(fontSize: 12),
    GoogleFonts.vt323(fontSize: 17, fontWeight: FontWeight.w600),
    GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700),
    GoogleFonts.vt323TextTheme(ThemeData.dark().textTheme),
  ]);
}

void bindA56View(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MediaQueryData get shellGoldenMedia => const MediaQueryData(
  size: Size(360, 780),
  textScaler: TextScaler.linear(1),
  padding: EdgeInsets.only(top: 24, bottom: 24),
);

GameState _quietHubState() {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  final offerStart = DateTime.now().toUtc().millisecondsSinceEpoch - 3600000;
  return base.copyWith(
    bossVictories: 1,
    vfxQuality: VfxQuality.minimal,
    seenChangelogVersion: MetaSystems.currentVersion,
    metaDepth: base.metaDepth.copyWith(
      reviewPrompted: true,
      notifyOptIn: true,
      shopOfferStartedMs: offerStart,
      shopStarterClaimed: false,
    ),
  );
}

GameDirector hubGoldenDirector() =>
    GameDirector.preview(initialState: _quietHubState());

GameDirector shopGoldenDirector() => hubGoldenDirector();

GameDirector gearGoldenDirector() {
  final state = _quietHubState().copyWith(
    ascensionLevel: 5,
    highestDungeonCleared: 3,
  );
  return GameDirector.preview(initialState: state);
}

GameDirector scrollsGoldenDirector() => hubGoldenDirector();

GameDirector homeShellGoldenDirector() {
  final state = GameLogic.enterDungeon(
    _quietHubState().copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
    ),
  );
  return GameDirector.preview(initialState: state);
}

GameDirector homeShellFullGoldenDirector() {
  final state = GameLogic.enterDungeon(
    _quietHubState().copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: true,
    ),
  );
  return GameDirector.preview(initialState: state);
}

Future<GameDirector> homeShellFullFightGoldenDirector() async {
  final director = homeShellFullGoldenDirector();
  await director.boot();
  return director;
}

GameDirector goldSheetGoldenDirector() {
  return GameDirector.preview(
    initialState: _quietHubState().copyWith(
      ascensionLevel: 3,
      bossVictories: 2,
      highestDungeonCleared: 2,
    ),
  );
}

GameDirector essenceSheetGoldenDirector() {
  return GameDirector.preview(
    initialState: _quietHubState().copyWith(
      ascensionLevel: 2,
      essence: 120,
      bossVictories: 2,
    ),
  );
}

Future<GameDirector> homeShellFightGoldenDirector() async {
  final director = homeShellGoldenDirector();
  await director.boot();
  return director;
}

Future<GameDirector> fightGoldenDirector() async {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  final director = GameDirector.preview(
    initialState: base.copyWith(
      highestFloorCleared: 1,
      bossVictories: 1,
      vfxQuality: VfxQuality.minimal,
      seenChangelogVersion: MetaSystems.currentVersion,
      metaDepth: base.metaDepth.copyWith(
        lifetimeFloorClears: 1,
        reviewPrompted: true,
      ),
      seenTips: const [
        'first_run',
        'hub_enter',
        'godhand',
        'farm_push',
        'kit_abilities',
        'bag',
        'forge',
        'sanctuary',
      ],
    ),
  );
  await director.boot();
  director.enterDungeon();
  return director;
}

OfflineProgressResult welcomeBackGoldenSummary(GameState state) {
  return OfflineProgressResult(
    state: state.copyWith(bossVictories: 1),
    secondsApplied: 3600,
    goldGained: 1280,
    essenceGained: 2,
    roomsCleared: 6,
    highestFloorDelta: 1,
    bossDelta: 0,
    secondsAway: 3600,
  );
}

Future<void> pumpGoldenFrames(WidgetTester tester, {int ms = 400}) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// A56 hub/shell shots need [Scaffold] so hub chrome [InkWell]s have Material.
Widget shellGoldenScaffold(Widget body) {
  return MediaQuery(
    data: shellGoldenMedia,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: GameTheme.ink,
        body: body,
      ),
    ),
  );
}

Future<void> waitForFightChrome(WidgetTester tester, GameDirector director) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    if (director.dungeonTilesReady) {
      break;
    }
  }
  director.clearToast();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump();
}

Future<void> showWelcomeBackGolden(WidgetTester tester, GameDirector director) async {
  director.uiFeedback.presentOffline(
    welcomeBackGoldenSummary(director.state),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showOfflineProgressDialog(context, director),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await pumpGoldenFrames(tester);
}

Future<void> expectShellGolden(WidgetTester tester, Finder finder, String name) {
  return expectLater(
    finder,
    matchesGoldenFile('$shellGoldenRoot/$name'),
  );
}
