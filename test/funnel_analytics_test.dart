import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/funnel_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';

void main() {
  final install = DateTime.utc(2026, 9, 12, 14, 0);

  tearDown(() {
    AppAnalytics.debugSink = null;
  });

  test('mandate funnel names are the live event ids', () {
    expect(
      FunnelAnalytics.allNames,
      containsAll([
        'first_open',
        'app_ready',
        'first_enter',
        'first_reward',
        'first_boss',
        'd1_return',
        'time_to_combat',
      ]),
    );
  });

  test('new install emits first_open then app_ready once', () {
    final state = GameLogic.createInitialState(now: install);
    final first = FunnelAnalytics.onNewInstall(state, install);
    expect(
      first.events.map((e) => e.name),
      [FunnelAnalytics.firstOpen, FunnelAnalytics.appReady],
    );
    expect(first.state.metaDepth.funnelInstallMs, install.millisecondsSinceEpoch);
    expect(
      FunnelAnalytics.onNewInstall(first.state, install).events,
      isEmpty,
    );
  });

  test('first_enter logs seconds_to_combat once', () {
    var state = FunnelAnalytics.onNewInstall(
      GameLogic.createInitialState(now: install),
      install,
    ).state;
    final enterAt = install.add(const Duration(seconds: 47));
    final tick = FunnelAnalytics.onFirstEnter(
      state,
      enterAt,
      dungeonId: 'sandy',
      sessionReadyMs: install.millisecondsSinceEpoch,
    );
    expect(tick.events.map((e) => e.name), [
      FunnelAnalytics.firstEnter,
      FunnelAnalytics.timeToCombat,
    ]);
    expect(tick.events.first.params['dungeon_id'], 'sandy');
    expect(tick.events.first.params['seconds_to_combat'], 47);
    expect(tick.events[1].params['seconds'], 47);
    expect(
      FunnelAnalytics.onFirstEnter(
        tick.state,
        enterAt.add(const Duration(seconds: 10)),
        dungeonId: 'sandy',
        sessionReadyMs: install.millisecondsSinceEpoch,
      ).events,
      isEmpty,
    );
  });

  test('first_reward and first_boss fire once', () {
    var state = FunnelAnalytics.onNewInstall(
      GameLogic.createInitialState(now: install),
      install,
    ).state;
    final reward = FunnelAnalytics.onFirstReward(state);
    expect(reward.events.single.name, FunnelAnalytics.firstReward);
    expect(FunnelAnalytics.onFirstReward(reward.state).events, isEmpty);

    final boss = FunnelAnalytics.onFirstBoss(reward.state);
    expect(boss.events.single.name, FunnelAnalytics.firstBoss);
    expect(FunnelAnalytics.onFirstBoss(boss.state).events, isEmpty);
  });

  test('d1_return fires on the next UTC day, not the same day', () {
    var state = FunnelAnalytics.onNewInstall(
      GameLogic.createInitialState(now: install),
      install,
    ).state;
    final sameDay = FunnelAnalytics.onExistingSession(
      state,
      install.add(const Duration(hours: 8)),
    );
    expect(sameDay.events, isEmpty);

    final nextDay = FunnelAnalytics.onExistingSession(
      state,
      DateTime.utc(2026, 9, 13, 8),
    );
    expect(nextDay.events.single.name, FunnelAnalytics.d1Return);
    expect(nextDay.events.single.params['days_since_install'], 1);
    expect(
      FunnelAnalytics.onExistingSession(
        nextDay.state,
        DateTime.utc(2026, 9, 14),
      ).events,
      isEmpty,
    );
  });

  test('legacy save backfills funnel flags without emitting', () {
    final veteran = GameLogic.createInitialState(now: install).copyWith(
      lifetimeGoldEarned: 9000,
      bossVictories: 4,
    );
    final tick = FunnelAnalytics.onExistingSession(veteran, install);
    expect(tick.events, isEmpty);
    expect(tick.state.metaDepth.funnelInstallMs, greaterThan(0));
    expect(
      tick.state.metaDepth.funnelLogged,
      containsAll([
        FunnelAnalytics.firstOpen,
        FunnelAnalytics.appReady,
        FunnelAnalytics.firstEnter,
        FunnelAnalytics.firstReward,
        FunnelAnalytics.firstBoss,
        FunnelAnalytics.d1Return,
      ]),
    );
  });

  test('funnel fields round-trip and survive Ascend', () {
    var state = FunnelAnalytics.onNewInstall(
      GameLogic.createInitialState(now: install),
      install,
    ).state;
    state = FunnelAnalytics.onFirstEnter(
      state,
      install.add(const Duration(seconds: 30)),
      dungeonId: 'sandy',
      sessionReadyMs: install.millisecondsSinceEpoch,
    ).state;
    final loaded = GameLogic.stateFromJson(state.toJson());
    expect(loaded.metaDepth.funnelInstallMs, state.metaDepth.funnelInstallMs);
    expect(loaded.metaDepth.funnelLogged, state.metaDepth.funnelLogged);

    final raw = GameLogic.createInitialState(now: install).toJson();
    final md = Map<String, dynamic>.from(raw['metaDepth'] as Map);
    md.remove('funnelInstallMs');
    md.remove('funnelLogged');
    raw['metaDepth'] = md;
    final legacy = GameLogic.stateFromJson(raw);
    expect(legacy.metaDepth.funnelInstallMs, 0);
    expect(legacy.metaDepth.funnelLogged, isEmpty);

    final ascended = GameLogic.ascend(loaded, now: install);
    expect(
      ascended.metaDepth.funnelLogged,
      contains(FunnelAnalytics.firstEnter),
    );
    expect(ascended.metaDepth.funnelInstallMs, loaded.metaDepth.funnelInstallMs);
  });

  test('New Game then enter dungeon records the funnel via AppAnalytics', () async {
    final hits = <String>[];
    AppAnalytics.debugSink = (name, _) => hits.add(name);

    final director = GameDirector(
      InMemoryGameStorage(),
      enableSpatialLoop: false,
    );
    await director.boot();
    await director.startNewGame(HeroSpecs.starterUnlocked);
    expect(
      hits,
      containsAll([FunnelAnalytics.firstOpen, FunnelAnalytics.appReady]),
    );
    director.enterDungeon(dungeonId: 'sandy');
    expect(hits, contains(FunnelAnalytics.firstEnter));
    expect(hits, contains(FunnelAnalytics.timeToCombat));
    expect(
      director.state.metaDepth.funnelLogged,
      containsAll([
        FunnelAnalytics.firstOpen,
        FunnelAnalytics.appReady,
        FunnelAnalytics.firstEnter,
        FunnelAnalytics.timeToCombat,
      ]),
    );
    director.dispose();
  });

  test('AppAnalytics no-ops safely under flutter test', () async {
    await AppAnalytics.init();
    await AppAnalytics.syncConsent();
    await AppAnalytics.enterDungeon(
      dungeonId: 'sandy',
      keyLevel: 0,
      floor: 1,
    );
    await AppAnalytics.leaveDungeon(dungeonId: 'sandy', floor: 1);
    await AppAnalytics.partyWipe(dungeonId: 'sandy', floor: 1, streak: 1);
    await AppAnalytics.ascend(fromAl: 0, toAl: 1);
    await AppAnalytics.logEvent(FunnelAnalytics.appReady);
  });
}
