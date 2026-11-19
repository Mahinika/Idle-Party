import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/mission.dart' show Mission, MissionType;
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
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
    expect(tester.takeException(), isNull);
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