import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/nav_copy.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/mission.dart' show Mission, MissionType;
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/feedback_toast.dart';
import 'package:idle_party/ui/shell/play_shell.dart';

const _sizes = <Size>[
  Size(360, 780),
  Size(360, 640),
];
const _scales = [1.0, 1.45];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in _sizes) {
    for (final scale in _scales) {
      testWidgets(
        'target strip sits under HUD row and above map $size @ $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final director = await _fightDirector();
          var directorLive = true;
          addTearDown(() {
            if (directorLive) director.dispose();
          });
          final router = MenuRouter();
          addTearDown(router.dispose);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: PlayShell(director: director, router: router),
                ),
              ),
            ),
          );

          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 50));
            if (director.dungeonTilesReady &&
                find.byKey(TargetCornerHud.stripKey).evaluate().isNotEmpty) {
              break;
            }
          }
          await tester.pump(const Duration(milliseconds: 400));

          final strip = tester.getRect(find.byKey(TargetCornerHud.stripKey));
          final topBar = tester.getRect(find.byType(HomeTopBar));
          final topHud = find.byType(DungeonTopHud);
          final mapTop = topHud.evaluate().isNotEmpty
              ? tester.getRect(topHud).bottom
              : strip.bottom;

          expect(strip.top, greaterThanOrEqualTo(topBar.top - 0.5));
          expect(strip.bottom, lessThanOrEqualTo(topBar.bottom + 1));
          expect(strip.left, greaterThanOrEqualTo(8 - 0.5));
          expect(strip.right, lessThanOrEqualTo(size.width - 8 + 0.5));
          expect(
            strip.bottom,
            lessThanOrEqualTo(mapTop + 1),
            reason: 'strip must sit above the floor line overlay',
          );
          expect(strip.height, closeTo(targetStripHeight(TextScaler.linear(scale)), 4));

          await tester.pump(const Duration(milliseconds: 400));
          director.dispose();
          directorLive = false;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 20));
        },
      );
    }
  }

  testWidgets('boss banner clears target strip at max text scale', (tester) async {
    const scale = 1.45;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(scale),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: targetStripHeight(const TextScaler.linear(scale)),
                    child: const ColoredBox(color: Color(0xFF22181D)),
                  ),
                  const Expanded(
                    child: SizedBox(
                      width: 360,
                      child: BossIntroBanner(name: 'Fen Hydra'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    final strip = tester.getRect(find.byType(SizedBox).first);
    final banner = tester.getRect(find.text('BOSS — Fen Hydra'));
    expect(banner.top, greaterThanOrEqualTo(strip.bottom - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim chip keeps enemy title readable at 360x640 1.45', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final director = await _fightDirector();
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    director.debugHoldSave(
      director.state.copyWith(
        missions: [
          Mission(
            id: 't1',
            type: MissionType.defeatEnemies,
            title: 'Test',
            target: 1,
            progress: 1,
            goldReward: 10,
            essenceReward: 1,
          ),
          Mission(
            id: 't2',
            type: MissionType.defeatEnemies,
            title: 'Test 2',
            target: 1,
            progress: 1,
            goldReward: 10,
            essenceReward: 1,
          ),
        ],
      ),
    );
    expect(HubChase.forState(director.state).kind, HubChaseKind.claimMissions);
    final router = MenuRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: PlayShell(director: director, router: router),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final title = find.byKey(TargetCornerHud.titleKey);
      if (title.evaluate().isEmpty) continue;
      final text = tester.widget<Text>(title).data ?? '';
      if (text.length > 4 && !text.startsWith('ME')) break;
    }

    final title = tester.widget<Text>(find.byKey(TargetCornerHud.titleKey));
    expect(title.data, isNot(matches(RegExp(r'^ME\.\.\.'))));
    expect(title.data!.length, greaterThan(4));
    expect(find.textContaining('QUESTS ·'), findsOneWidget);
    final chip = find.ancestor(
      of: find.textContaining('QUESTS ·'),
      matching: find.byType(InkWell),
    );
    expect(
      tester.getSize(chip.first).height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
    director.dispose();
    directorLive = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('chase line shows in SPLIT when not claim-ready', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final base = GameLogic.createInitialState().copyWith(
      homeLayout: HomeLayout.home,
      bossVictories: 2,
      highestFloorCleared: 4,
      homePanelFull: false,
      inDungeon: true,
    );
    final state = GameLogic.enterDungeon(base);
    expect(HubChase.forState(state).title, isNotEmpty);

    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTopBar(director: director, router: router),
        ),
      ),
    );
    await tester.pump();
    final chaseTitle =
        NavCopy.playerText(HubChase.forState(state).title, HomeLayout.home);
    expect(find.text(chaseTitle), findsOneWidget);
  });

  testWidgets('quest chip inlines on wide phone with one claimable', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final director = await _fightDirector();
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    director.debugHoldSave(
      director.state.copyWith(
        homePanelFull: true,
        missions: [
          Mission(
            id: 't1',
            type: MissionType.defeatEnemies,
            title: 'Test',
            target: 1,
            progress: 1,
            goldReward: 10,
            essenceReward: 1,
          ),
        ],
      ),
    );
    expect(HubChase.forState(director.state).kind, HubChaseKind.claimMissions);
    final router = MenuRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(411, 891),
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: PlayShell(director: director, router: router),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (director.dungeonTilesReady &&
          find.byKey(TargetCornerHud.stripKey).evaluate().isNotEmpty &&
          find.textContaining('QUESTS ·').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 400));

    final hex = tester.getRect(
      find.bySemanticsLabel(
        'Floor ${director.state.currentRoom.floorNumber}, open floor list',
      ),
    );
    final chip = tester.getRect(find.textContaining('QUESTS ·'));
    expect(chip.top, lessThan(95), reason: 'chip should sit on the target row');
    expect(chip.top, greaterThan(hex.top - 6));

    final title = tester.widget<Text>(find.byKey(TargetCornerHud.titleKey));
    final label = title.data ?? '';
    expect(label, isNot(contains('…')));
    expect(label.trim().length, greaterThan(4));
    expect(tester.takeException(), isNull);
    director.dispose();
    directorLive = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('quest chase moves beside floor badge, not under it', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final base = GameLogic.createInitialState().copyWith(
      homeLayout: HomeLayout.home,
      bossVictories: 2,
      highestFloorCleared: 4,
      metaDepth: GameLogic.createInitialState().metaDepth.copyWith(
        dailyVaultClaimed: true,
      ),
    );
    var state = GameLogic.enterDungeon(base);
    state = state.copyWith(
      homePanelFull: true,
      missions: [
        Mission(
          id: 't1',
          type: MissionType.defeatEnemies,
          title: 'Test',
          target: 1,
          progress: 1,
          goldReward: 10,
          essenceReward: 1,
        ),
      ],
    );
    expect(HubChase.forState(state).kind, HubChaseKind.claimMissions);

    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTopBar(director: director, router: router),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Claim quest reward'), findsNothing);
    expect(find.textContaining('QUESTS ·'), findsOneWidget);
    final hex = tester.getRect(
      find.bySemanticsLabel(
        'Floor ${director.state.currentRoom.floorNumber}, open floor list',
      ),
    );
    final chip = tester.getRect(find.textContaining('QUESTS ·'));
    expect(chip.top, lessThan(95), reason: 'chip should sit on the target row');
    expect(chip.top, greaterThan(hex.top - 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('achievement toast wraps without clip at 360 and 411', (tester) async {
    const msg = 'Achievement unlocked · +18e · Bulwark Thrown on';
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 411.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(width, 800),
              textScaler: TextScaler.noScaling,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: FeedbackToast(message: msg, maxLines: 2),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final textFinder = find.textContaining('Achievement unlocked');
      final toastText = tester.widget<Text>(textFinder);
      expect(toastText.maxLines, 2);
      expect(toastText.softWrap, isTrue);
      expect(tester.getSize(find.byType(FeedbackToast)).width, lessThanOrEqualTo(width + 1));
    }
  });
}

Future<GameDirector> _fightDirector() async {
  final base = GameLogic.createInitialState();
  final director = GameDirector.preview(
    initialState: base.copyWith(
      homeLayout: HomeLayout.home,
      highestFloorCleared: 1,
      bossVictories: 1,
      metaDepth: base.metaDepth.copyWith(lifetimeFloorClears: 1),
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