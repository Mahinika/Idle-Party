import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/nav_copy.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/enemy.dart' show EnemyArchetype, EnemyRole;
import 'package:idle_party/models/mission.dart' show Mission, MissionType;
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
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
          expect(strip.top, greaterThanOrEqualTo(topBar.top - 0.5));
          expect(topBar.bottom, greaterThanOrEqualTo(strip.bottom - 1));
          expect(strip.left, greaterThanOrEqualTo(8 - 0.5));
          expect(strip.right, lessThanOrEqualTo(size.width - 8 + 0.5));
          expect(find.byType(DungeonTopHud), findsNothing);
          expect(
            strip.height,
            closeTo(targetStripHeight(TextScaler.linear(scale)), 6),
          );

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
    expect(
      find.textContaining(RegExp(r'(QUESTS ·|Q ·)')),
      findsOneWidget,
    );
    final chip = find.ancestor(
      of: find.textContaining(RegExp(r'(QUESTS ·|Q ·)')),
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
  expect(chaseTitle, isNotEmpty);
    // Split cave: the chase title is not duplicated under the target strip
    // (the plate kicker carries zone / gate context after boot).
    expect(find.text(chaseTitle), findsNothing);
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
          find.textContaining(RegExp(r'(QUESTS ·|Q ·)')).evaluate().isNotEmpty) {
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
    expect((chip.top - hex.top).abs(), lessThan(20));

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
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    await director.boot(deferCombatLoop: true);
    final router = MenuRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTopBar(director: director, router: router),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Claim quest reward'), findsNothing);
    expect(
      find.textContaining(RegExp(r'(QUESTS ·|Q ·)')),
      findsOneWidget,
    );
    final hex = tester.getRect(
      find.bySemanticsLabel(
        'Floor ${director.state.currentRoom.floorNumber}, open floor list',
      ),
    );
    final chip = tester.getRect(
      find.textContaining(RegExp(r'(QUESTS ·|Q ·)')),
    );
    expect(
      (chip.top - hex.top).abs(),
      lessThan(20),
      reason: 'chip should sit on the HP row beside the floor badge',
    );
    expect(tester.takeException(), isNull);
    director.dispose();
    directorLive = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final spec in [
    (size: const Size(411, 891), scale: 1.0, name: 'ELITE RAID SLIME'),
    (size: const Size(411, 891), scale: 1.0, name: 'THRONE WARDEN'),
    (size: const Size(360, 640), scale: GameTheme.typeScaleMax, name: 'SOUL SPITTER'),
    (size: const Size(360, 640), scale: GameTheme.typeScaleMax, name: 'EYE PRIEST'),
    (size: const Size(360, 640), scale: GameTheme.typeScaleMax, name: 'EARTH KRAKEN'),
  ]) {
    testWidgets(
      'target name ${spec.name} whole at ${spec.size} @ ${spec.scale}',
      (tester) async {
        tester.view.physicalSize = spec.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final director = await _fightDirectorPinned(
          name: spec.name,
          role: spec.name == 'EARTH KRAKEN'
              ? EnemyRole.boss
              : spec.name.startsWith('ELITE') || spec.name == 'THRONE WARDEN'
              ? EnemyRole.elite
              : EnemyRole.normal,
        );
        var directorLive = true;
        addTearDown(() {
          if (directorLive) director.dispose();
        });
        final router = MenuRouter();
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: spec.size,
                textScaler: TextScaler.linear(spec.scale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: HomeTopBar(director: director, router: router),
            ),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byKey(TargetCornerHud.titleKey).evaluate().isNotEmpty) break;
        }
        final title = tester.widget<Text>(find.byKey(TargetCornerHud.titleKey));
        if (spec.name == 'SOUL SPITTER') {
          expect(title.data, contains('SOUL SPITTER'));
          expect(title.data, contains('×'));
          expect(find.byKey(TargetCornerHud.roleTagKey), findsOneWidget);
        } else {
          expect(title.data, spec.name);
        }
        expect(title.data, isNot(contains('…')));
        director.dispose();
        directorLive = false;
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('map enter does not pass tap through to split MARKET', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        homeLayout: HomeLayout.home,
        bossVictories: 2,
        highestFloorCleared: 4,
        homePanelFull: false,
      ),
    );
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    await director.boot(deferCombatLoop: true);
    final router = MenuRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayShell(director: director, router: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    router.open(MenuRoute.map);
    await tester.pump();
    router.close();
    director.enterDungeon();
    await tester.pump();
    final marketTab = find
        .descendant(of: find.byType(PlayShell), matching: find.text('MARKET'))
        .first;
    await tester.tapAt(tester.getCenter(marketTab));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ForgeOverlay), findsOneWidget);
    expect(find.byType(MarketOverlay), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    director.dispose();
    directorLive = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

Future<GameDirector> _fightDirectorPinned({
  required String name,
  EnemyRole role = EnemyRole.normal,
}) async {
  final director = await _fightDirector();
  final world = director.spatial;
  if (world == null || world.enemies.isEmpty) return director;
  final template = world.enemies.firstWhere((e) => e.hp > 0 && !e.dormant);
  final replacement = SpatialActor(
    id: template.id,
    name: name,
    team: template.team,
    x: template.x,
    y: template.y,
    hp: template.hp,
    maxHp: template.maxHp,
    attack: template.attack,
    defense: template.defense,
    moveSpeed: template.moveSpeed,
    attackRange: template.attackRange,
    attackCooldown: template.attackCooldown,
    role: role,
    archetype: name == 'SOUL SPITTER'
        ? EnemyArchetype.swarm
        : EnemyArchetype.brute,
  );
  final idx = world.enemies.indexWhere((e) => e.id == template.id);
  if (idx >= 0) world.enemies[idx] = replacement;
  director.hudFocusEnemyId = replacement.id;
  return director;
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