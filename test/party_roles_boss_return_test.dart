import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/ui/shell/play_nav.dart';
import 'helpers/seeded.dart';
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

SpatialWorld _walled() {
  final map = _openMap();
  final tiles = List<TileKind>.from(map.tiles);
  for (var y = 4; y <= 6; y++) {
    tiles[y * map.cols + 7] = TileKind.wall;
  }
  final walled = TileMap(
    cols: map.cols,
    rows: map.rows,
    tiles: tiles,
    spawnPoints: map.spawnPoints,
    exitPoint: map.exitPoint,
    enemySpawns: map.enemySpawns,
  );
  return SpatialWorld(
    map: walled,
    heroes: [],
    enemies: [],
    projectiles: <SpatialProjectile>[],
    groundLoot: [],
    isTreasure: false,
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
    expect(find.textContaining('No gold or essence this time'), findsOneWidget);
    expect(find.text('OPEN GOLD'), findsNothing);
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
        tester.view.viewPadding = FakeViewPadding.zero;
        tester.view.padding = FakeViewPadding.zero;
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('WELCOME BACK'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size == const Size(360, 640) && scale == 1.45) {
          final leaveFirst = find.text('ENTER DUNGEON').evaluate().isNotEmpty
              ? find.text('ENTER DUNGEON')
              : find.text('CONTINUE');
          await tester.tap(leaveFirst);
          await tester.pumpAndSettle();
          tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
          tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 44, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: MaterialApp(
                home: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        showOfflineProgressDialog(context, director),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          director.uiFeedback.presentOffline(card());
          await tester.tap(find.text('open'), warnIfMissed: false);
          await tester.pumpAndSettle();
          if (find.text('WELCOME BACK').evaluate().isEmpty) {
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Up next'), findsOneWidget);
          expect(
            tester.getRect(find.text('WELCOME BACK')).top,
            greaterThanOrEqualTo(44),
          );
          await _writeWelcomeShot(
            tester,
            'welcome_back_360x640_145_cutout.png',
          );
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

  test('live focus uses a clear shot and the nearest tank', () {
    final world = _walled();
    final enemy = _enemy(
      id: 'shot',
      x: 6.8,
      y: 5,
      archetype: EnemyArchetype.ranged,
    );
    final behind = _hero(id: 'back', spec: HeroSpecId.fire, x: 8.2, y: 5);
    final tank = _hero(id: 'tank', spec: HeroSpecId.protection, x: 6.8, y: 2);
    expect(
      SpatialCombat.canShoot(world, enemy.x, enemy.y, behind.x, behind.y),
      isFalse,
    );
    expect(
      SpatialCombat.canShoot(world, enemy.x, enemy.y, tank.x, tank.y),
      isTrue,
    );
    expect(
      SpatialCombat.enemyFocusForTest(enemy, [behind, tank], world: world)?.id,
      'tank',
      reason: 'a nearer hero behind a wall loses to an open tank',
    );
    final walledTank = _hero(
      id: 'nearw',
      spec: HeroSpecId.protection,
      x: 8.2,
      y: 5,
    );
    final openTank = _hero(
      id: 'openf',
      spec: HeroSpecId.guardian,
      x: 6.8,
      y: 2,
    );
    expect(
      SpatialCombat.enemyFocusForTest(enemy, [
        walledTank,
        openTank,
      ], world: world)?.id,
      'openf',
      reason:
          'the nearer tank is behind the wall, so the open tank is the anchor',
    );

    final open = _world(
      heroes: [
        _hero(id: 'far', spec: HeroSpecId.protection, x: 2, y: 5),
        _hero(id: 'near', spec: HeroSpecId.guardian, x: 6, y: 5),
      ],
      enemies: [_enemy(id: 'm', x: 8, y: 5)],
    );
    final melee = open.enemies.first;
    expect(
      SpatialCombat.enemyFocusForTest(melee, open.heroes, world: open)?.id,
      'near',
    );

    final dead = _hero(
      id: 'dead',
      spec: HeroSpecId.protection,
      x: 6,
      y: 5,
      hp: 0,
    );
    final dps = _hero(id: 'dps', spec: HeroSpecId.arms, x: 4, y: 5);
    expect(
      SpatialCombat.enemyFocusForTest(melee, [dead, dps], world: open)?.id,
      'dps',
    );

    final marked = _hero(id: 'mark', spec: HeroSpecId.fire, x: 2, y: 5);
    melee.forcedTargetId = marked.id;
    melee.forcedTargetTimer = 3;
    expect(
      SpatialCombat.enemyFocusForTest(melee, [tank, marked], world: open)?.id,
      'mark',
    );

    final caster = _enemy(
      id: 'bow',
      x: 8,
      y: 5,
      archetype: EnemyArchetype.ranged,
    );
    final coverTank = _hero(id: 'ct', spec: HeroSpecId.protection, x: 5, y: 5);
    final farHeal = _hero(id: 'fh', spec: HeroSpecId.discipline, x: 2, y: 5);
    final plain = _world(heroes: [coverTank, farHeal], enemies: [caster]);
    expect(
      SpatialCombat.enemyFocusForTest(caster, plain.heroes, world: plain)?.id,
      'ct',
      reason: 'distance cover, both shots open',
    );
  });

  test('Sandy lighter chip is the nearest tank in the ring', () {
    final far = _hero(id: 'far', spec: HeroSpecId.protection, x: 6.4, y: 5);
    final near = _hero(id: 'near', spec: HeroSpecId.guardian, x: 5.3, y: 5);
    final dps = _hero(id: 'dps', spec: HeroSpecId.arms, x: 5.6, y: 5);
    final boss = _enemy(
      id: 'sandy',
      x: 5,
      y: 5,
      attack: 100,
      role: EnemyRole.boss,
    );
    final world = _world(heroes: [far, near, dps], enemies: [boss]);
    debugSandySlamForTest(world, boss);
    expect(400 - near.hp, lessThan(400 - far.hp));
    expect(400 - near.hp, lessThan(400 - dps.hp));
  });

  test('Goblin mark can slip and King decree can be answered', () {
    final far = _hero(id: 'far', spec: HeroSpecId.arms, x: 1.2, y: 5);
    final boss = _enemy(id: 'goblin', x: 8, y: 5, role: EnemyRole.boss);
    final add = _enemy(id: 'add', x: 7.2, y: 5);
    add.hp = 40;
    final slipped = _world(
      heroes: [far],
      enemies: [boss, add],
      dungeonId: 'goblin',
    );
    debugGoblinRallyForTest(slipped, boss, focus: far);
    expect(add.hp, 40);
    expect(slipped.floaters.any((f) => f.text == 'SLIP'), isTrue);

    final close = _hero(id: 'close', spec: HeroSpecId.fire, x: 7.2, y: 5);
    final boss2 = _enemy(id: 'goblin2', x: 8, y: 5, role: EnemyRole.boss);
    final add2 = _enemy(id: 'add2', x: 7.4, y: 5);
    add2.hp = 40;
    final held = _world(
      heroes: [close],
      enemies: [boss2, add2],
      dungeonId: 'goblin',
    );
    debugGoblinRallyForTest(held, boss2, focus: close);
    expect(add2.hp, greaterThan(40));
    expect(held.floaters.any((f) => f.text == 'HEAL'), isTrue);

    final answered = _hero(id: 'in', spec: HeroSpecId.arms, x: 6.2, y: 5);
    final back = _hero(id: 'out', spec: HeroSpecId.fire, x: 2, y: 5);
    final king = _enemy(id: 'king', x: 5, y: 5, role: EnemyRole.boss);
    final kingWorld = _world(
      heroes: [answered, back],
      enemies: [king],
      dungeonId: 'king',
    );
    debugBossTelegraphForTest(kingWorld, king);
    expect(answered.attackSlowTimer, 0);
    expect(back.attackSlowTimer, greaterThanOrEqualTo(2.5));
    expect(kingWorld.floaters.any((f) => f.text == 'DECREE'), isTrue);
  });

  test('four Sandy seeds clear floor 1 and the floor 2 boss in 75s', () {
    const specs = <List<HeroSpecId>?>[
      null,
      [HeroSpecId.arms, HeroSpecId.fire, HeroSpecId.combat],
      [HeroSpecId.protection, HeroSpecId.arms, HeroSpecId.fire],
      [HeroSpecId.protection, HeroSpecId.guardian, HeroSpecId.arms],
    ];
    for (final seed in const [1, 2, 3, 4]) {
      for (final party in specs) {
        seedAll(seed);
        var state = GameLogic.enterDungeon(
          GameLogic.createInitialState(
            now: DateTime(2026, 11, 7),
          ).copyWith(dungeonMode: DungeonMode.push),
          dungeonId: 'sandy',
        );
        if (party != null) {
          state = state.copyWith(
            heroes: [
              for (var i = 0; i < party.length; i++)
                state.heroes[i].copyWith(specId: party[i]),
            ],
          );
        }
        var world = SpatialCombat.build(state, roleCover: true);
        var wiped = false;
        for (var i = 0; i < 1500; i++) {
          final step = SpatialCombat.step(world, state, dt: 0.05);
          world = step.world;
          state = step.state;
          if (step.goldFromKills > 0) {
            state = GameLogic.creditCombatGold(state, step.goldFromKills);
          }
          if (step.partyWiped) {
            wiped = true;
            break;
          }
          if (step.roomCleared) {
            state = GameLogic.completeCurrentRoom(
              state,
              goldGain: 0,
              skipLootRoll: true,
            );
            if (!state.inDungeon || state.highestFloorCleared >= 2) break;
            world = SpatialCombat.build(state, roleCover: true);
          }
        }
        expect(
          wiped,
          isFalse,
          reason: 'seed $seed ${party ?? 'starter'} wiped',
        );
        expect(
          state.highestFloorCleared,
          greaterThanOrEqualTo(2),
          reason:
              'seed $seed ${party ?? 'starter'} floor ${state.currentRoom.floorNumber}',
        );
        expect(state.bossVictories, greaterThanOrEqualTo(1));
      }
    }
    unseedAll();
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('return line names a real buy and does not invent gold', () {
    final poor = GameLogic.createInitialState(now: DateTime(2026, 11, 7));
    final none = GameLogic.returnGainLine(
      poor,
      goldGained: 0,
      essenceGained: 0,
      canOpenGold: true,
    );
    expect(none, contains('No gold or essence'));
    expect(none, isNot(contains('Open GOLD')));

    final rich = poor.copyWith(gold: 50000);
    final covered = GameLogic.returnGainLine(
      rich,
      goldGained: 100,
      essenceGained: 0,
      canOpenGold: true,
    );
    expect(covered, contains('brought back 100 gold'));
    expect(covered, contains('wallet covers'));
    expect(covered, contains('Open GOLD'));
    final short = poor.copyWith(gold: 1);
    final gap = GameLogic.returnGainLine(
      short,
      goldGained: 1,
      essenceGained: 0,
      canOpenGold: true,
    );
    expect(gap, contains('still needs'));
    expect(gap, isNot(contains('Open GOLD')));
    final noButton = GameLogic.returnGainLine(
      rich,
      goldGained: 100,
      essenceGained: 0,
    );
    expect(noButton, isNot(contains('Open GOLD')));
  });

  testWidgets('OPEN GOLD is the forge and does not pay again', (tester) async {
    final rich = GameLogic.createInitialState(
      now: DateTime(2026, 11, 7),
    ).copyWith(gold: 50000);
    final director = GameDirector.preview(initialState: rich);
    addTearDown(director.dispose);
    final router = MenuRouter();
    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: rich,
        secondsApplied: 60,
        goldGained: 100,
        essenceGained: 0,
        roomsCleared: 1,
        highestFloorDelta: 0,
        bossDelta: 0,
        wasInDungeon: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayNav(
          router: router,
          onEnterDungeon: (_) {},
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOfflineProgressDialog(context, director),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN GOLD'), findsOneWidget);
    await tester.tap(find.text('OPEN GOLD'));
    await tester.pumpAndSettle();
    expect(router.route, MenuRoute.gold);
    expect(director.state.gold, 50000);
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
