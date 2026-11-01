import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/boot_clock.dart';

void main() {
  test('AppAnalytics no-ops safely under flutter test', () async {
    await AppAnalytics.init();
    await AppAnalytics.syncConsent();
    await AppAnalytics.enterDungeon(dungeonId: 'sandy', keyLevel: 0, floor: 1);
    await AppAnalytics.leaveDungeon(dungeonId: 'sandy', floor: 1);
    await AppAnalytics.partyWipe(dungeonId: 'sandy', floor: 1, streak: 1);
    await AppAnalytics.ascend(fromAl: 0, toAl: 1);
    await AppAnalytics.welcomeBack(where: 'hub', seconds: 120, gold: 10);
    await AppAnalytics.welcomeBackAdOffer();
    await AppAnalytics.storeView();
    await AppAnalytics.storePurchase('ad_free');
    await AppAnalytics.sessionLength(40);
  });

  test('boot clock marks stay in order', () {
    final before = BootClock.marks.length;
    BootClock.mark('main');
    BootClock.mark('runApp');
    BootClock.mark('firstFrame');
    final added = BootClock.marks.skip(before).toList();
    expect(added[0], startsWith('main '));
    expect(added[1], startsWith('runApp '));
    expect(added[2], startsWith('firstFrame '));
  });

  test('early buffer keeps a Flutter error until Crashlytics attaches', () {
    final previous = FlutterError.onError;
    addTearDown(() {
      FlutterError.onError = previous;
      AppAnalytics.debugResetEarlyErrorBuffer();
    });
    FlutterError.onError = (FlutterErrorDetails details) {};
    AppAnalytics.armEarlyErrorBuffer();
    final handler = FlutterError.onError;
    expect(handler, isNotNull);
    handler!(FlutterErrorDetails(exception: StateError('boot')));
    expect(AppAnalytics.debugBufferedErrorCount, 1);
  });

  test('measurement events keep the documented names', () async {
    final hits = <String>[];
    AppAnalytics.debugSink = (name, _) => hits.add(name);
    try {
      await AppAnalytics.welcomeBack(where: 'dungeon', seconds: 90, gold: 4);
      await AppAnalytics.welcomeBackAdOffer();
      await AppAnalytics.storeView();
      await AppAnalytics.storePurchase('long_away');
      await AppAnalytics.sessionLength(40);
      expect(hits, [
        'welcome_back',
        'welcome_back_ad_offer',
        'store_view',
        'store_purchase',
        'session_length',
      ]);
    } finally {
      AppAnalytics.debugSink = null;
    }
  });
}
