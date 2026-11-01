import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/ad_config.dart';
import 'package:idle_party/core/ad_offer.dart';
import 'package:idle_party/core/ad_rewarded.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';
import 'package:idle_party/ui/shell/boost_ad_button.dart';
import 'package:idle_party/ui/shell/wipe_overlay.dart';

void main() {
  setUp(() => AdRewarded.prepareOfferCalls = 0);

  test('release rewarded id is the one POWERUPS hour unit', () {
    expect(
      AdConfig.liveRewardedUnitId,
      'ca-app-pub-4980376195917009/5225353586',
    );
    expect(AdConfig.testRewardedUnitId, isNot(AdConfig.liveRewardedUnitId));
  });

  test('HUD watch shows only between offers when no scroll is running', () {
    final fresh = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 8));
    expect(
      AdOffer.showHudButton(
        fresh,
        welcomeUp: false,
        wipeUp: false,
        fightLive: false,
      ),
      isFalse,
    );

    final played = fresh.copyWith(bossVictories: 1);
    expect(
      AdOffer.showHudButton(
        played,
        welcomeUp: false,
        wipeUp: false,
        fightLive: false,
      ),
      isTrue,
    );
    expect(
      AdOffer.showHudButton(
        played,
        welcomeUp: true,
        wipeUp: false,
        fightLive: false,
      ),
      isFalse,
    );
    expect(
      AdOffer.showHudButton(
        played,
        welcomeUp: false,
        wipeUp: true,
        fightLive: false,
      ),
      isFalse,
    );
    expect(
      AdOffer.showHudButton(
        played,
        welcomeUp: false,
        wipeUp: false,
        fightLive: true,
      ),
      isFalse,
    );

    final boosted = played.copyWith(
      metaDepth: played.metaDepth.copyWith(
        adAtkUntilMs: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
    expect(
      AdOffer.showHudButton(
        boosted,
        welcomeUp: false,
        wipeUp: false,
        fightLive: false,
      ),
      isFalse,
    );
    expect(AdBoost.combatBoostActive(boosted.metaDepth), isTrue);

    final free = played.copyWith(
      metaDepth: played.metaDepth.copyWith(adFree: true),
    );
    expect(
      AdOffer.showHudButton(
        free,
        welcomeUp: false,
        wipeUp: false,
        fightLive: false,
      ),
      isFalse,
    );
  });

  testWidgets('boot does not preload a rewarded ad', (tester) async {
    final director = GameDirector.preview();
    await director.boot();
    await tester.pump(const Duration(seconds: 3));
    expect(AdRewarded.prepareOfferCalls, 0);
    director.dispose();
  });

  testWidgets('HUD watch preloads when it is the only offer', (tester) async {
    final fresh = GameLogic.createInitialState();
    final director = GameDirector.preview(
      initialState: fresh.copyWith(bossVictories: 1),
    );
    await director.boot();
    AdRewarded.prepareOfferCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoostAdButton(director: director)),
      ),
    );
    await tester.pump();
    expect(find.text(AdOffer.hudLabel), findsOneWidget);
    expect(AdRewarded.prepareOfferCalls, 1);

    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: director.state,
        secondsApplied: 60,
        goldGained: 10,
        essenceGained: 1,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
      ),
    );
    director.notifyListeners();
    await tester.pump();
    expect(find.text(AdOffer.hudLabel), findsNothing);

    director.dismissOfflineSummary();
    director.debugOpenWipeChoice();
    await tester.pump();
    expect(find.text(AdOffer.hudLabel), findsNothing);
    director.dispose();
  });

  testWidgets('Welcome Back preloads and names 2× loot', (tester) async {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 8),
    ).copyWith(bossVictories: 1);
    final summary = OfflineProgressResult(
      state: state,
      secondsApplied: 3600,
      goldGained: 40,
      essenceGained: 2,
      roomsCleared: 0,
      highestFloorDelta: 0,
      bossDelta: 0,
    );
    expect(summary.welcomeBackAdOffer, isTrue);
    final director = GameDirector.preview();
    director.uiFeedback.presentOffline(summary);
    AdRewarded.prepareOfferCalls = 0;
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
    expect(find.text('Watch ad: 2× offline loot'), findsOneWidget);
    expect(
      find.textContaining('gold and essence are doubled'),
      findsOneWidget,
    );
    expect(AdRewarded.prepareOfferCalls, greaterThan(0));
    director.dispose();
  });

  testWidgets('wipe keeps its own ad and preloads that offer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final director = GameDirector.preview();
    await tester.pumpWidget(
      MaterialApp(
        home: DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
      ),
    );
    expect(find.text('WATCH AD · +1 ticket'), findsOneWidget);
    expect(find.text('RETRY FLOOR'), findsOneWidget);
    expect(AdRewarded.prepareOfferCalls, 1);
    director.dispose();
  });
}
