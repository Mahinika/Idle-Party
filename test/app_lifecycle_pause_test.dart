import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/funnel_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  test('appPaused freezes spatialTick combat', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
    );
    await director.boot();
    director.enterDungeon();
    expect(director.state.inDungeon, isTrue);
    expect(director.spatial, isNotNull);

    final frameBefore = director.visualFrame;
    director.spatialTick();
    expect(director.visualFrame, greaterThan(frameBefore));

    final pausedFrame = director.visualFrame;
    director.setAppPaused(true);
    expect(director.appPaused, isTrue);
    director.spatialTick();
    director.spatialTick();
    expect(director.visualFrame, pausedFrame);

    director.setAppPaused(false);
    director.spatialTick();
    expect(director.visualFrame, greaterThan(pausedFrame));
  });

  test('uiPaused still freezes combat independently of appPaused', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
    );
    await director.boot();
    director.enterDungeon();
    director.spatialTick();
    final frame = director.visualFrame;
    director.setUiPaused(true);
    director.spatialTick();
    expect(director.visualFrame, frame);
    director.setUiPaused(false);
    director.spatialTick();
    expect(director.visualFrame, greaterThan(frame));
  });

  test('resume after 2h pays hub gold and offline_gold', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final hits = <String>[];
    AppAnalytics.debugSink = (name, _) => hits.add(name);
    addTearDown(() => AppAnalytics.debugSink = null);
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    await director.boot();
    final before = director.state.gold;
    director.setAppPaused(true);
    director.debugStampAway(lastUpdatedAgo: const Duration(hours: 2));
    director.setAppPaused(false);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(director.state.gold, greaterThan(before));
    expect(director.offlineSummary, isNotNull);
    expect(director.offlineSummary!.goldGained, greaterThan(0));
    expect(
      FunnelAnalytics.has(director.state, FunnelAnalytics.offlineGold),
      isTrue,
    );
    expect(hits, contains('welcome_back'));
  });

  test('Welcome Back offers the ad only after the first boss', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final hits = <String>[];
    AppAnalytics.debugSink = (name, _) => hits.add(name);
    addTearDown(() => AppAnalytics.debugSink = null);
    final seed = GameLogic.createInitialState().copyWith(bossVictories: 1);
    final director = GameDirector.preview(initialState: seed);
    addTearDown(director.dispose);
    await director.boot();
    hits.clear();
    director.setAppPaused(true);
    director.debugStampAway(lastUpdatedAgo: const Duration(hours: 2));
    director.setAppPaused(false);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(hits, contains('welcome_back'));
    expect(hits, contains('welcome_back_ad_offer'));
  });

  test('a long foreground stint logs session_length on pause', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final hits = <String>[];
    AppAnalytics.debugSink = (name, params) {
      hits.add(name);
      if (name == 'session_length') {
        expect(params?['seconds'], greaterThanOrEqualTo(15));
      }
    };
    addTearDown(() => AppAnalytics.debugSink = null);
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    await director.boot();
    director.debugStampForeground(ago: const Duration(seconds: 40));
    director.setAppPaused(true);
    expect(hits, ['session_length']);
    director.setAppPaused(true);
    expect(hits, ['session_length']);
  });

  test('resume after 5s shows no Welcome Back and no offline_gold', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    await director.boot();
    final before = director.state.gold;
    director.setAppPaused(true);
    director.debugStampAway(lastUpdatedAgo: const Duration(seconds: 5));
    director.setAppPaused(false);
    await Future<void>.delayed(Duration.zero);
    expect(director.offlineSummary, isNull);
    expect(director.state.gold, before);
    expect(
      FunnelAnalytics.has(director.state, FunnelAnalytics.offlineGold),
      isFalse,
    );
  });

  test('resume the next calendar day logs d1_return', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final installed = DateTime.now().toUtc();
    final base = GameLogic.createInitialState();
    final seed = base.copyWith(
      metaDepth: base.metaDepth.copyWith(
        funnelInstallMs: installed.millisecondsSinceEpoch,
        funnelLogged: const ['first_open', 'app_ready'],
      ),
    );
    final director = GameDirector.preview(initialState: seed);
    addTearDown(director.dispose);
    await director.boot();
    expect(
      FunnelAnalytics.has(director.state, FunnelAnalytics.d1Return),
      isFalse,
    );
    final yesterday = DateTime.utc(
      installed.year,
      installed.month,
      installed.day,
    ).subtract(const Duration(days: 1));
    director.setAppPaused(true);
    director.debugStampAway(funnelInstallMs: yesterday.millisecondsSinceEpoch);
    director.setAppPaused(false);
    await Future<void>.delayed(Duration.zero);
    expect(
      FunnelAnalytics.has(director.state, FunnelAnalytics.d1Return),
      isTrue,
    );
    expect(director.offlineSummary, isNull);
  });

  test(
    'resume paints the caught-up hero level before the next frame',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final director = GameDirector.preview();
      addTearDown(director.dispose);
      await director.boot();
      director.enterDungeon();
      director.setAppPaused(true);
      director.debugStampAway(lastUpdatedAgo: const Duration(hours: 2));
      final before = director.state.heroes.first.level;
      final expected = GameLogic.applyOfflineProgress(
        director.state,
        const Duration(hours: 2),
      );
      final seen = <int>[];
      director.addListener(() {
        if (director.state.heroes.isEmpty) return;
        seen.add(director.state.heroes.first.level);
      });
      director.setAppPaused(false);
      expect(director.state.heroes.first.level, before);
      expect(seen, isEmpty);
      for (
        var i = 0;
        i < 80 && director.state.heroes.first.level == before;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      final level = director.state.heroes.first.level;
      expect(level, expected.state.heroes.first.level);
      expect(level, greaterThan(before));
      expect(seen, isNotEmpty);
      expect(seen.every((shown) => shown == level), isTrue);
    },
  );

  test('a new away credit clears the Welcome Back ad grant', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    await director.boot();
    director.debugGrantWelcomeBackAd();
    expect(director.debugWelcomeBackAdGranted, isTrue);
    final blocked = await director.watchWelcomeBackGoldAd(40);
    expect(blocked, isFalse);
    director.setAppPaused(true);
    director.debugStampAway(lastUpdatedAgo: const Duration(hours: 2));
    director.setAppPaused(false);
    expect(director.debugWelcomeBackAdGranted, isFalse);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(director.debugWelcomeBackAdGranted, isFalse);
    expect(director.offlineSummary, isNotNull);
  });

  test('boot does not publish the pre-away hero level', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final away = DateTime.now().subtract(const Duration(hours: 2));
    final seed = GameLogic.enterDungeon(GameLogic.createInitialState(now: away))
        .copyWith(lastUpdated: away);
    final savedLevel = seed.heroes.first.level;
    final director = GameDirector.preview(initialState: seed);
    addTearDown(director.dispose);
    final seen = <int>[];
    director.addListener(() {
      if (director.state.heroes.isEmpty) return;
      seen.add(director.state.heroes.first.level);
    });
    await director.boot(deferCombatLoop: false);
    final level = director.state.heroes.first.level;
    expect(level, greaterThan(savedLevel));
    expect(seen, isNotEmpty);
    expect(seen.every((shown) => shown == level), isTrue);
    expect(seen, isNot(contains(savedLevel)));
  });
}
