import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/boot_clock.dart';
import 'package:idle_party/core/measurement_consent.dart';

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

  test('FirebaseInitProvider is not installed on the main thread', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('xmlns:tools="http://schemas.android.com/tools"'),
    );
    expect(
      manifest,
      contains(
        'android:name="com.google.firebase.provider.FirebaseInitProvider"',
      ),
    );
    expect(manifest, contains('tools:node="remove"'));
    for (final key in <String>[
      'google_analytics_default_allow_analytics_storage',
      'google_analytics_default_allow_ad_storage',
      'google_analytics_default_allow_ad_user_data',
      'google_analytics_default_allow_ad_personalization_signals',
      'firebase_analytics_collection_enabled',
      'firebase_crashlytics_collection_enabled',
    ]) {
      final nameAt = manifest.indexOf('android:name="$key"');
      expect(nameAt, greaterThan(-1), reason: key);
      final end = nameAt + 160;
      final window = manifest.substring(
        nameAt,
        end > manifest.length ? manifest.length : end,
      );
      expect(window, contains('android:value="false"'), reason: key);
    }
  });

  test(
    'consent mode grants all four signals, and a decline still measures',
    () {
      const yes = MeasurementConsent(granted: true);
      expect(yes.analyticsStorage, isTrue);
      expect(yes.adStorage, isTrue);
      expect(yes.adUserData, isTrue);
      expect(yes.adPersonalization, isTrue);
      expect(yes.analyticsCollection, isTrue);
      expect(yes.crashlytics, isTrue);

      const no = MeasurementConsent(granted: false);
      expect(no.analyticsStorage, isFalse);
      expect(no.adStorage, isFalse);
      expect(no.adUserData, isFalse);
      expect(no.adPersonalization, isFalse);
      expect(no.crashlytics, isFalse);
      expect(no.analyticsCollection, isTrue);
    },
  );

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

  test('store purchase keeps the Play price only with a currency', () async {
    final hits = <Map<String, Object>?>[];
    AppAnalytics.debugSink = (_, params) => hits.add(params);
    try {
      await AppAnalytics.storePurchase('ad_free', value: 2.99, currency: 'sek');
      await AppAnalytics.storePurchase('long_away', value: 4, currency: 'EU');
      await AppAnalytics.storePurchase('supporter');
      expect(hits[0], {
        'product_id': 'ad_free',
        'value': 2.99,
        'currency': 'SEK',
      });
      expect(hits[1], {'product_id': 'long_away'});
      expect(hits[2], {'product_id': 'supporter'});
    } finally {
      AppAnalytics.debugSink = null;
    }
  });
}
