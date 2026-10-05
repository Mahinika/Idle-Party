import 'package:flutter_test/flutter_test.dart';
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
    expect(FunnelAnalytics.has(director.state, FunnelAnalytics.d1Return), isFalse);
    final yesterday = DateTime.utc(
      installed.year,
      installed.month,
      installed.day,
    ).subtract(const Duration(days: 1));
    director.setAppPaused(true);
    director.debugStampAway(funnelInstallMs: yesterday.millisecondsSinceEpoch);
    director.setAppPaused(false);
    await Future<void>.delayed(Duration.zero);
    expect(FunnelAnalytics.has(director.state, FunnelAnalytics.d1Return), isTrue);
    expect(director.offlineSummary, isNull);
  });
}
