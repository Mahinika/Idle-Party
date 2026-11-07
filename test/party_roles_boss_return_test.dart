import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/enemy_specials.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';

SpatialActor _hero({
  required String id,
  required HeroSpecId spec,
  required double x,
  required double y,
  int hp = 400,
  int defense = 0,
}) {
  final def = HeroSpecs.def(spec);
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.hero,
    x: x,
    y: y,
    hp: hp,
    maxHp: hp,
    attack: 0,
    defense: defense,
    moveSpeed: 0,
    attackRange: 1.2,
    attackCooldown: 1,
    heroRole: def.gearAffinity,
    heroSpecId: spec,
  );
}

SpatialActor _enemy({
  required String id,
  required double x,
  required double y,
  EnemyArchetype archetype = EnemyArchetype.brute,
  int attack = 40,
  EnemyRole role = EnemyRole.normal,
}) {
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.enemy,
    x: x,
    y: y,
    hp: 200,
    maxHp: 200,
    attack: attack,
    defense: 0,
    moveSpeed: 0,
    attackRange: archetype == EnemyArchetype.ranged ? 4.5 : 1.2,
    attackCooldown: 1,
    role: role,
    archetype: archetype,
  );
}

TileMap _openMap() {
  const cols = 12;
  const rows = 10;
  final tiles = List<TileKind>.filled(cols * rows, TileKind.floor);
  for (var x = 0; x < cols; x++) {
    tiles[x] = TileKind.wall;
    tiles[(rows - 1) * cols + x] = TileKind.wall;
  }
  for (var y = 0; y < rows; y++) {
    tiles[y * cols] = TileKind.wall;
    tiles[y * cols + cols - 1] = TileKind.wall;
  }
  return TileMap(
    cols: cols,
    rows: rows,
    tiles: tiles,
    spawnPoints: const [(2, 2)],
    exitPoint: (cols - 3, rows - 3),
    enemySpawns: const [(8, 5)],
  );
}

SpatialWorld _world({
  required List<SpatialActor> heroes,
  required List<SpatialActor> enemies,
  String dungeonId = 'sandy',
}) {
  return SpatialWorld(
    map: _openMap(),
    heroes: heroes,
    enemies: enemies,
    projectiles: <SpatialProjectile>[],
    groundLoot: [],
    isTreasure: false,
    dungeonId: dungeonId,
  );
}

void main() {
  test('melee sticks to the tank; a caster shoots an exposed hero', () {
    final tank = _hero(id: 'tank', spec: HeroSpecId.protection, x: 4, y: 5);
    final healer = _hero(id: 'heal', spec: HeroSpecId.discipline, x: 2, y: 5);
    final melee = _enemy(id: 'brute', x: 8, y: 5);
    final covered = SpatialCombat.enemyFocusForTest(melee, [tank, healer]);
    expect(covered?.id, 'tank');

    final caster = _enemy(
      id: 'shot',
      x: 8,
      y: 5,
      archetype: EnemyArchetype.ranged,
    );
    expect(
      SpatialCombat.enemyFocusForTest(caster, [tank, healer])?.id,
      'tank',
      reason: 'healer stands behind the tank',
    );

    healer.x = 7.2;
    expect(
      SpatialCombat.enemyFocusForTest(caster, [tank, healer])?.id,
      'heal',
      reason: 'healer stepped in front of the shot',
    );

    final noTank = [
      _hero(id: 'a', spec: HeroSpecId.arms, x: 6, y: 5),
      _hero(id: 'b', spec: HeroSpecId.fire, x: 3, y: 5),
    ];
    expect(SpatialCombat.enemyFocusForTest(melee, noTank)?.id, 'a');
    expect(SpatialCombat.enemyFocusForTest(caster, noTank)?.id, 'a');
  });

  test('Sandy cover, Goblin rally, and King decree are different', () {
    final tank = _hero(id: 'tank', spec: HeroSpecId.protection, x: 5, y: 5);
    final dps = _hero(id: 'dps', spec: HeroSpecId.arms, x: 5.2, y: 5);
    final back = _hero(id: 'back', spec: HeroSpecId.fire, x: 2, y: 5);
    final sandy = _enemy(
      id: 'sandy',
      x: 5,
      y: 5,
      attack: 100,
      role: EnemyRole.boss,
    );
    final sandyWorld = _world(heroes: [tank, dps, back], enemies: [sandy]);
    debugSandySlamForTest(sandyWorld, sandy);
    final tankLost = 400 - tank.hp;
    final dpsLost = 400 - dps.hp;
    expect(tankLost, greaterThan(0));
    expect(dpsLost, greaterThan(tankLost));
    expect(back.hp, 400);
    expect(back.attackSlowTimer, 0);

    final boss = _enemy(id: 'goblin', x: 5, y: 5, role: EnemyRole.boss);
    boss.hp = 80;
    final add = _enemy(id: 'add', x: 6, y: 5);
    add.hp = 40;
    final goblinWorld = _world(
      heroes: [_hero(id: 'h', spec: HeroSpecId.fire, x: 3, y: 5)],
      enemies: [boss, add],
      dungeonId: 'goblin',
    );
    debugGoblinRallyForTest(goblinWorld, boss);
    expect(add.hp, greaterThan(40));
    expect(boss.hp, 80);

    final kingHero = _hero(id: 'k', spec: HeroSpecId.fire, x: 3, y: 5);
    final king = _enemy(id: 'king', x: 5, y: 5, role: EnemyRole.boss);
    final kingWorld = _world(
      heroes: [kingHero],
      enemies: [king],
      dungeonId: 'king',
    );
    debugBossTelegraphForTest(kingWorld, king);
    expect(kingHero.attackSlowTimer, greaterThanOrEqualTo(2.5));
    expect(kingHero.x, 3);
    expect(kingWorld.floaters.any((f) => f.text == 'DECREE'), isTrue);
    expect(sandyWorld.floaters.any((f) => f.text == 'SLAM'), isTrue);
    expect(goblinWorld.floaters.any((f) => f.text == 'HEAL'), isTrue);
  });

  test('early Sandy is clearable with a tank or with three damage heroes', () {
    GameState fight(List<HeroSpecId> specs) {
      final base = GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
        dungeonId: 'sandy',
      );
      final heroes = [
        for (var i = 0; i < specs.length; i++)
          base.heroes[i].copyWith(specId: specs[i]),
      ];
      return base.copyWith(heroes: heroes);
    }

    int livingAfter(GameState state) {
      var world = SpatialCombat.build(state, roleCover: true);
      for (var i = 0; i < 40; i++) {
        final step = SpatialCombat.step(world, state, dt: 0.05);
        world = step.world;
        state = step.state;
      }
      return world.heroes.where((h) => h.hp > 0).length;
    }

    final withTank = fight(const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.arms,
    ]);
    final allDamage = fight(const [
      HeroSpecId.arms,
      HeroSpecId.fire,
      HeroSpecId.combat,
    ]);
    expect(livingAfter(withTank), 3);
    expect(livingAfter(allDamage), 3);
  });

  test('offline zero, negative, and a second resume do not invent gold', () {
    final start = GameLogic.createInitialState(now: DateTime(2026, 11, 7));
    final zero = GameLogic.applyOfflineProgress(start, Duration.zero);
    final negative = GameLogic.applyOfflineProgress(
      start,
      const Duration(seconds: -8),
    );
    expect(zero.goldGained, 0);
    expect(zero.state.gold, start.gold);
    expect(negative.goldGained, 0);
    expect(negative.state.gold, start.gold);

    final once = GameLogic.applyOfflineProgress(
      start,
      const Duration(seconds: 45),
    );
    final again = GameLogic.applyOfflineProgress(once.state, Duration.zero);
    expect(again.state.gold, once.state.gold);
    expect(again.goldGained, 0);

    final round = GameState.fromJson(once.state.toJson());
    expect(round.gold, once.state.gold);
    expect(round.heroes.length, once.state.heroes.length);
  });

  testWidgets('Welcome Back next step is calm and names a reachable job', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    );
    addTearDown(director.dispose);
    await tester.binding.setSurfaceSize(const Size(360, 780));
    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: director.state,
        secondsApplied: 0,
        goldGained: 0,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
        levelsGained: 0,
        gearFinds: 0,
        wasInDungeon: false,
      ),
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
    await tester.pumpAndSettle();
    final next = tester.widget<Text>(find.textContaining('Up next:'));
    expect(next.style?.color, isNot(GameTheme.accentWarn));
    expect(find.textContaining('Why:'), findsOneWidget);
    expect(find.textContaining('missed'), findsNothing);
    expect(find.textContaining('hurry'), findsNothing);
    await _writeWelcomeShot(tester, 'welcome_back_360x780.png');
  });

  testWidgets('Welcome Back fits 360x780 and 360x640 at 1, 1.45, and raw 2', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    );
    addTearDown(director.dispose);
    OfflineProgressResult card() => OfflineProgressResult(
      state: director.state,
      secondsApplied: 0,
      goldGained: 0,
      essenceGained: 0,
      roomsCleared: 0,
      highestFloorDelta: 0,
      bossDelta: 0,
      levelsGained: 0,
      gearFinds: 0,
      wasInDungeon: false,
    );
    for (final size in const [Size(360, 780), Size(360, 640)]) {
      for (final scale in const [1.0, 1.45, 2.0]) {
        await tester.binding.setSurfaceSize(size);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showOfflineProgressDialog(context, director),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        director.uiFeedback.presentOffline(card());
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('WELCOME BACK'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size == const Size(360, 640) && scale == 1.45) {
          await _writeWelcomeShot(tester, 'welcome_back_360x640_145.png');
        }
        final leave = find.text('ENTER DUNGEON').evaluate().isNotEmpty
            ? find.text('ENTER DUNGEON')
            : find.text('CONTINUE');
        await tester.tap(leave);
        await tester.pumpAndSettle();
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _writeWelcomeShot(WidgetTester tester, String name) async {
  final element = tester.element(find.text('WELCOME BACK'));
  RenderObject? object = element.renderObject;
  while (object != null && object is! RenderRepaintBoundary) {
    object = object.parent;
  }
  final boundary = object! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  final dir = Directory('/opt/cursor/artifacts/party-roles');
  dir.createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}
