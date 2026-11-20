import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gear/gear_bis_planner.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/feedback_toast.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/core/menu_router.dart';

import 'shell_golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wornLine uses Equipped copy', () {
    expect(
      GearBiSPlanner.wornLine(const ['Aegis Amulet of the Gorilla']),
      'Equipped: Aegis Amulet of the Gorilla',
    );
    expect(
      GearBiSPlanner.wornLine(const ['Ring A', 'Ring B']),
      'Equipped: Ring A (+1)',
    );
  });

  testWidgets('target strip golden swarm at 411 scale 1.0', (tester) async {
    final key = GlobalKey();
    final director = await _pumpTargetStripGolden(
      tester,
      key,
      size: const Size(411, 891),
      scale: 1,
      name: 'Cave Slime',
      role: EnemyRole.normal,
      archetype: EnemyArchetype.swarm,
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile(
        'goldens/widgets/playtest_target_swarm_411_scale1.png',
      ),
    );
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('target strip golden elite at 360x640 scale 1.45', (tester) async {
    final key = GlobalKey();
    final director = await _pumpTargetStripGolden(
      tester,
      key,
      size: const Size(360, 640),
      scale: GameTheme.typeScaleMax,
      name: 'SOUL SPITTER',
      role: EnemyRole.elite,
      archetype: EnemyArchetype.brute,
    );
    final title = tester.widget<Text>(find.byKey(TargetCornerHud.titleKey));
    expect(title.data, 'SOUL SPITTER');
    expect(title.data, isNot(contains('…')));
    expect(find.text('ELITE'), findsOneWidget);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile(
        'goldens/widgets/playtest_target_elite_360_scale145.png',
      ),
    );
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('target strip golden boss at 360x640 scale 1.45', (tester) async {
    final key = GlobalKey();
    final director = await _pumpTargetStripGolden(
      tester,
      key,
      size: const Size(360, 640),
      scale: GameTheme.typeScaleMax,
      name: 'Earth Kraken',
      role: EnemyRole.boss,
      archetype: EnemyArchetype.brute,
    );
    final title = tester.widget<Text>(find.byKey(TargetCornerHud.titleKey));
    expect(title.data, 'EARTH KRAKEN');
    expect(title.data, isNot(contains('…')));
    expect(find.text('BOSS'), findsOneWidget);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile(
        'goldens/widgets/playtest_target_boss_360_scale145.png',
      ),
    );
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('long gear toast wraps at 360 and 411', (tester) async {
    const msg =
        'Equipped: Aegis Amulet of the Gorilla (+2) · combo ready';
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 411.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: FeedbackToast(message: msg, maxLines: 2, docked: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.textContaining('Equipped:'));
      expect(text.maxLines, 2);
      expect(text.softWrap, isTrue);
    }
  });

  testWidgets('home kit abilities wrap with no wait text', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    final entered = GameLogic.enterDungeon(
      director.state.copyWith(homeLayout: HomeLayout.home),
    );
    final world = SpatialCombat.build(entered);
    for (final h in world.heroes) {
      for (final entry in h.abilityCd.entries) {
        h.abilityCd[entry.key] = 4.5;
      }
    }
    director.debugAttachSpatial(world);
    director.debugHoldSave(entered);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: PartyCornerHud(
                director: director,
                selectedHeroIndex: 0,
                onSelectHero: (_) {},
                onOpenEquip: () {},
                homeRow: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final heroName = director.state.combatHeroes.first.shownName.trim();
    await tester.tap(find.text(heroName));
    await tester.pump();
    await tester.tap(find.text(heroName));
    await tester.pump();
    expect(find.text('wait'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fight top bar golden with elite target at 411', (tester) async {
    await ensureShellGoldenFonts();
    final director = await _fightDirectorPinnedEnemy(
      name: 'ELITE RAID SLIME',
      role: EnemyRole.elite,
      archetype: EnemyArchetype.brute,
    );
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    final router = MenuRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          backgroundColor: GameTheme.stoneDeep,
          body: RepaintBoundary(
            key: key,
            child: HomeTopBar(director: director, router: router),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(TargetCornerHud.titleKey).evaluate().isNotEmpty) break;
    }
  await pumpGoldenFrames(tester, ms: 200);
    final title = tester.widget<Text>(find.byKey(TargetCornerHud.titleKey));
    expect(title.data, 'ELITE RAID SLIME');
    expect(title.data, isNot(contains('…')));
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/widgets/playtest_home_topbar_elite_411.png'),
    );
    director.dispose();
    directorLive = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}

Future<GameDirector> _pumpTargetStripGolden(
  WidgetTester tester,
  GlobalKey key, {
  required Size size,
  required double scale,
  required String name,
  required EnemyRole role,
  required EnemyArchetype archetype,
}) async {
  await ensureShellGoldenFonts();
  final director = await _fightDirectorPinnedEnemy(
    name: name,
    role: role,
    archetype: archetype,
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          backgroundColor: GameTheme.stoneDeep,
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: size.width - 16,
              child: TargetCornerHud(director: director, edgeInset: false),
            ),
          ),
        ),
      ),
    ),
  );
  await pumpGoldenFrames(tester, ms: 200);
  return director;
}

Future<GameDirector> _fightDirectorPinnedEnemy({
  required String name,
  EnemyRole role = EnemyRole.normal,
  EnemyArchetype archetype = EnemyArchetype.brute,
}) async {
  final base = GameLogic.createInitialState();
  final director = GameDirector.preview(
    initialState: base.copyWith(
      homeLayout: HomeLayout.home,
      highestFloorCleared: 1,
      bossVictories: 1,
      metaDepth: base.metaDepth.copyWith(lifetimeFloorClears: 1),
      inDungeon: true,
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
  final world = director.spatial;
  if (world == null || world.enemies.isEmpty) {
    return director;
  }
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
    archetype: archetype,
  );
  final idx = world.enemies.indexWhere((e) => e.id == template.id);
  if (idx >= 0) {
    world.enemies[idx] = replacement;
  }
  director.hudFocusEnemyId = replacement.id;
  return director;
}
