import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';
import 'package:idle_party/ui/confirm_dialogs.dart';
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
  final director = GameDirector.preview(
    initialState: _freezeFightClock(
      GameLogic.enterDungeon(
        _quietHubState().copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: true,
        ),
      ),
    ),
  );
  await _bootFightQuiet(director);
  return director;
}

GameDirector goldSheetGoldenDirector() {
  return GameDirector.preview(
    initialState: _quietHubState().copyWith(
      ascensionLevel: 3,
      bossVictories: 2,
      highestDungeonCleared: 2,
      highestFloorCleared: 3,
      gold: 18000,
    ),
  );
}

GameDirector forgeInlineGoldenDirector() {
  final state = GameLogic.enterDungeon(
    _quietHubState().copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      gold: 12000,
      highestFloorCleared: 4,
      bossVictories: 2,
    ),
  );
  return GameDirector.preview(initialState: state);
}

GameDirector essenceSheetGoldenDirector() {
  return GameDirector.preview(
    initialState: _quietHubState().copyWith(
      ascensionLevel: 2,
      essence: 240,
      bossVictories: 2,
      highestFloorCleared: 4,
    ),
  );
}

GameDirector marketGoldenDirector() {
  final director = GameDirector.preview(
    initialState: _quietHubState().copyWith(
      ascensionLevel: 2,
      bossVictories: 2,
      highestFloorCleared: 4,
      gold: 25000,
    ),
  );
  director.ensureMarketListings();
  return director;
}

GameDirector questsGoldenDirector() {
  return GameDirector.preview(
    initialState: _quietHubState().copyWith(
      ascensionLevel: 1,
      bossVictories: 2,
      highestFloorCleared: 3,
    ),
  );
}

GameDirector settingsGoldenDirector() => hubGoldenDirector();

GameState endgamePartyGoldenState() {
  final base = _quietHubState().copyWith(
    ascensionLevel: 8,
    bossVictories: 10,
    highestFloorCleared: 24,
  );
  return base.copyWith(
    heroes: [
      for (final h in base.heroes) h.copyWith(level: GameLogic.maxHeroLevel),
    ],
    metaDepth: base.metaDepth.copyWith(gauntletBestFloor: 12),
  );
}

GameDirector endgameHubGoldenDirector() =>
    GameDirector.preview(initialState: endgamePartyGoldenState());

GameDirector gauntletDialogGoldenDirector() => endgameHubGoldenDirector();

Future<void> showGauntletDialogGolden(
  WidgetTester tester,
  GameDirector director,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmGauntletRun(context, director),
          child: const Text('open gauntlet'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open gauntlet'));
  await pumpGoldenFrames(tester);
}

Future<void> showRiftDialogGolden(
  WidgetTester tester,
  GameDirector director,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmRiftRun(context, director),
          child: const Text('open rift'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open rift'));
  await pumpGoldenFrames(tester);
}

Future<void> showGreaterRiftDialogGolden(
  WidgetTester tester,
  GameDirector director,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmGreaterRiftRun(context, director),
          child: const Text('open gr'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open gr'));
  await pumpGoldenFrames(tester);
}

/// Boot reads the machine clock. A fixture stamped at [shellGoldenNow] would
/// look months away and open Welcome Back over the cave. A clock a few
/// minutes ahead makes that gap negative, so catch-up is a no-op.
GameState _freezeFightClock(GameState state) => state.copyWith(
  lastUpdated: DateTime.now().add(const Duration(minutes: 10)),
);

Future<void> _bootFightQuiet(GameDirector director) async {
  await director.boot();
  director.dismissOfflineSummary();
  director.clearToast();
}

Future<GameDirector> homeShellFightGoldenDirector() async {
  final director = GameDirector.preview(
    initialState: _freezeFightClock(
      GameLogic.enterDungeon(
        _quietHubState().copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: false,
        ),
      ),
    ),
  );
  await _bootFightQuiet(director);
  return director;
}

Future<GameDirector> fightGoldenDirector() async {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  final director = GameDirector.preview(
    initialState: _freezeFightClock(
      base.copyWith(
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
    ),
  );
  await _bootFightQuiet(director);
  director.enterDungeon();
  return director;
}

/// Fixed floor plus a melee hit, a dead foe, and a gold floater.
/// Welcome Back stays on its own golden.
Future<GameDirector> fightHitGoldenDirector({
  VfxQuality vfx = VfxQuality.full,
}) async {
  final prior = GameLogic.random;
  GameLogic.random = Random(7);
  try {
    final base = GameLogic.createInitialState(now: shellGoldenNow);
    final director = GameDirector.preview(
      initialState: _freezeFightClock(
        base.copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: true,
          vfxQuality: vfx,
          seenChangelogVersion: MetaSystems.currentVersion,
          metaDepth: base.metaDepth.copyWith(reviewPrompted: true),
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
      ),
    );
    await _bootFightQuiet(director);
    director.enterDungeon();
    stageFightHitProof(director);
    return director;
  } finally {
    GameLogic.random = prior;
  }
}

/// Pins one hit, one death, and one gold number on the live world.
void stageFightHitProof(GameDirector director) {
  final world = director.spatial;
  if (world == null) return;
  SpatialActor? hero;
  for (final h in world.heroes) {
    if (!h.isPet && h.hp > 0) {
      hero = h;
      break;
    }
  }
  if (hero == null) return;
  hero.hitFlash = 0.12;
  SpatialActor? foe;
  for (final e in world.enemies) {
    if (e.hp > 0 && !e.dormant) {
      foe = e;
      break;
    }
  }
  foe ??= world.enemies.isEmpty ? null : world.enemies.first;
  if (foe != null) {
    foe
      ..hp = 0
      ..x = hero.x + 1.1
      ..y = hero.y + 0.15;
    world.bursts.add(
      SpatialBurst(
        x: foe.x,
        y: foe.y,
        life: 0.45,
        argb: 0xFFFFC14A,
        radius: 0.8,
      ),
    );
    world.floaters.add(
      SpatialFloater(
        x: foe.x,
        y: foe.y - 0.35,
        text: '18',
        argb: 0xFFFFE8A0,
        life: 0.7,
        priority: 1,
      ),
    );
  }
  world.floaters.add(
    SpatialFloater(
      x: hero.x,
      y: hero.y - 0.7,
      text: '8g',
      argb: 0xFFFFD060,
      life: 0.8,
      priority: 2,
    ),
  );
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
