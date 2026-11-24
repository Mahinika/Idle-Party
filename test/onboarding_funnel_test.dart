import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/analytics_events.dart';
import 'package:idle_party/core/analytics_guard.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/onboarding_funnel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OnboardingFunnel.debugReadPrefs = true;
    OnboardingFunnel.debugReset();
    AppAnalytics.debugSink = null;
    await OnboardingFunnel.load();
  });

  tearDown(() {
    AppAnalytics.debugSink = null;
    OnboardingFunnel.debugReadPrefs = false;
    OnboardingFunnel.debugReset();
  });

  test('onboarding steps are ordered and once per install', () async {
    final hits = <String, Map<String, Object>?>{};
    AppAnalytics.debugSink = (name, params) {
      hits.putIfAbsent(name, () => params);
    };

    await AppAnalytics.logOnboardingOnce(OnboardingFunnel.launch);
    await AppAnalytics.logOnboardingOnce(OnboardingFunnel.launch);
    await AppAnalytics.logEvent(OnboardingFunnel.firstFight, {
      'dungeon_id': 'sandy',
    });
    await AppAnalytics.logEvent(OnboardingFunnel.firstFight, {
      'dungeon_id': 'goblin',
    });
    await AppAnalytics.logEvent(OnboardingFunnel.firstTrain);
    await AppAnalytics.logEvent(OnboardingFunnel.firstBoss);
    await AppAnalytics.logOnboardingOnce(OnboardingFunnel.firstCraft, {
      'slot': 'weapon',
    });
    await AppAnalytics.logOnboardingOnce(OnboardingFunnel.firstCraft, {
      'slot': 'helm',
    });
    await AppAnalytics.welcomeBack(where: 'hub', seconds: 90, gold: 4);
    await AppAnalytics.welcomeBack(where: 'dungeon', seconds: 120, gold: 8);

    expect(hits[OnboardingFunnel.launch]?['step_index'], 1);
    expect(hits[OnboardingFunnel.firstFight]?['step_index'], 2);
    expect(hits[OnboardingFunnel.firstFight]?['dungeon_id'], 'sandy');
    expect(hits[OnboardingFunnel.firstTrain]?['step_index'], 3);
    expect(hits[OnboardingFunnel.firstBoss]?['step_index'], 4);
    expect(hits[OnboardingFunnel.firstCraft]?['step_index'], 5);
    expect(hits[OnboardingFunnel.firstCraft]?['slot'], 'weapon');
    expect(hits[OnboardingFunnel.firstReturn]?['step_index'], 6);
    expect(hits[OnboardingFunnel.firstReturn]?['where'], 'hub');
    expect(hits.length, OnboardingFunnel.steps.length);

    await OnboardingFunnel.debugFlush();
    OnboardingFunnel.debugReset();
    await OnboardingFunnel.load();
    hits.clear();
    await AppAnalytics.logOnboardingOnce(OnboardingFunnel.launch);
    await AppAnalytics.logEvent(OnboardingFunnel.firstFight);
    await AppAnalytics.welcomeBack(where: 'hub', seconds: 30, gold: 1);
    expect(hits.containsKey(OnboardingFunnel.launch), isFalse);
    expect(hits[OnboardingFunnel.firstFight]?['step_index'], isNull);
    expect(hits[OnboardingFunnel.firstReturn]?['step_index'], isNull);
  });

  test(
    'an existing save is marked done in prefs and not in the save',
    () async {
      final before = GameLogic.createInitialState().toJson();
      OnboardingFunnel.backfillSilently();
      await OnboardingFunnel.debugFlush();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(OnboardingFunnel.prefsKey),
        OnboardingFunnel.steps,
      );
      expect(prefs.getInt(OnboardingFunnel.installMsKey), greaterThan(0));

      final after = GameLogic.createInitialState().toJson();
      expect(after.keys, before.keys);
      expect(
        (after['metaDepth'] as Map).keys,
        (before['metaDepth'] as Map).keys,
      );
      expect(after.toString().contains(OnboardingFunnel.prefsKey), isFalse);

      final hits = <String>[];
      AppAnalytics.debugSink = (name, _) => hits.add(name);
      await AppAnalytics.logOnboardingOnce(OnboardingFunnel.launch);
      await AppAnalytics.logOnboardingOnce(OnboardingFunnel.firstCraft);
      expect(hits, isEmpty);
    },
  );

  test('a phone with no save logs launch once from boot', () async {
    final hits = <Map<String, Object>?>[];
    AppAnalytics.debugSink = (name, params) {
      if (name == OnboardingFunnel.launch) hits.add(params);
    };
    final director = GameDirector(
      InMemoryGameStorage(),
      enableSpatialLoop: false,
    );
    await director.boot();
    await director.boot();
    expect(hits, hasLength(1));
    expect(hits.single?['step_index'], 1);
    expect(
      director.state.toJson().toString(),
      isNot(contains(OnboardingFunnel.prefsKey)),
    );
    director.dispose();
  });

  test(
    'param guard enforces Firebase limits and keeps bools numeric',
    () async {
      expect(AnalyticsGuard.shouldSend('session_start'), isFalse);
      expect(AnalyticsGuard.shouldSend('first_open'), isFalse);
      expect(AnalyticsGuard.shouldSend('in_app_purchase'), isFalse);
      expect(AnalyticsGuard.eventName('firebase_custom'), isNull);
      expect(AnalyticsGuard.eventName('1bad'), isNull);
      expect(AnalyticsGuard.eventName('a' * 41), isNull);
      expect(AnalyticsGuard.shouldSend('first_craft'), isTrue);

      final long = 'x' * 101;
      final raw = <String, Object>{
        'gauntlet': true,
        'note': long,
        'bad key': 'no',
        'nan': double.nan,
        for (var i = 0; i < 26; i++) 'p${i.toString().padLeft(2, '0')}': i,
      };
      final safe = AnalyticsGuard.params(raw)!;
      expect(safe.length, AnalyticsGuard.maxParams);
      expect(safe.containsKey('p25'), isFalse);
      expect(safe['gauntlet'], 1);
      expect((safe['note'] as String).length, AnalyticsGuard.maxParamValue);
      expect(safe.containsKey('bad key'), isFalse);
      expect(safe.containsKey('nan'), isFalse);

      final hits = <Map<String, Object>?>[];
      AppAnalytics.debugSink = (_, params) => hits.add(params);
      await AppAnalytics.logEvent('party_wipe', {
        'gauntlet': false,
        'floor': 2,
      });
      expect(hits.single?['gauntlet'], 0);
      expect(hits.single?['floor'], 2);

      await AppAnalytics.logEvent('session_start');
      expect(
        AnalyticsGuard.userProperty('days_since_install_too_long', '1'),
        isNull,
      );
      final cut = AnalyticsGuard.userProperty('install_cohort', 'y' * 40);
      expect(cut?.value.length, AnalyticsGuard.maxUserPropValue);
      expect(
        AnalyticsEvents.billingUserCanceled('BillingResponse.userCanceled'),
        isTrue,
      );
      expect(AnalyticsEvents.billingUserCanceled('1'), isTrue);
      expect(
        AnalyticsEvents.billingUserCanceled('BillingResponse.error'),
        isFalse,
      );
    },
  );
}
