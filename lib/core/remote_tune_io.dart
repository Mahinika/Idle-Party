import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'app_analytics.dart';
import 'firebase_boot.dart';
import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart' as test_env;
import 'remote_tune.dart';

Future<void>? _inFlight;

Future<void> refresh() {
  if (test_env.inFlutterTestProcess()) return Future<void>.value();
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return Future<void>.value();
  }
  final current = _inFlight;
  if (current != null) return current;
  final run = _refresh();
  _inFlight = run;
  return run.whenComplete(() {
    if (identical(_inFlight, run)) _inFlight = null;
  });
}

Future<void> _refresh() async {
  try {
    // Installation id only. Ad consent does not gate this fetch.
    await FirebaseBoot.ensureInitialized();
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 12),
      ),
    );
    await rc.setDefaults(RemoteTune.defaults);
    // Last session's fetch applies now. This fetch waits for the next launch.
    await rc.activate();
    RemoteTune.apply(
      dailyCap: rc.getInt(RemoteTune.keyDailyCap),
      firstDelaySec: rc.getInt(RemoteTune.keyFirstDelaySec),
      intervalSec: rc.getInt(RemoteTune.keyIntervalSec),
      visibleSec: rc.getInt(RemoteTune.keyVisibleSec),
      shopFeaturedId: rc.getString(RemoteTune.keyShopFeatured),
      firstClimbAutoContinue: rc.getBool(RemoteTune.keyFirstClimbAutoContinue),
      firstClimbPlayNow: rc.getBool(RemoteTune.keyFirstClimbPlayNow),
      welcomeBackFirstReturnShort:
          rc.getBool(RemoteTune.keyWelcomeBackFirstReturnShort),
      townEnabled: rc.getBool(RemoteTune.keyTownEnabled),
      guaranteedFirstBoss: rc.getBool(RemoteTune.keyGuaranteedFirstBoss),
      vipPassListed: rc.getBool(RemoteTune.keyVipPassListed),
      liveEventId: rc.getString(RemoteTune.keyLiveEventId),
      liveEventMul: rc.getDouble(RemoteTune.keyLiveEventMul),
      liveEventStart: rc.getString(RemoteTune.keyLiveEventStart),
      liveEventEnd: rc.getString(RemoteTune.keyLiveEventEnd),
      fromRemote: true,
    );
    await rc.fetch();
    final shop = RemoteTune.shopFeaturedId;
    await AppAnalytics.logEvent('remote_tune', {
      'wisp_cap': RemoteTune.wispDailyCap,
      'wisp_first_s': RemoteTune.wispFirstDelayMs ~/ 1000,
      'wisp_every_s': RemoteTune.wispIntervalMs ~/ 1000,
      'shop': shop.isEmpty ? 'default' : shop,
    });
    if (kDebugMode) {
      debugPrint(
        'Remote Config applied '
        'cap=${RemoteTune.wispDailyCap} '
        'first=${RemoteTune.wispFirstDelayMs ~/ 1000}s '
        'every=${RemoteTune.wispIntervalMs ~/ 1000}s '
        'shop=${shop.isEmpty ? 'default' : shop}',
      );
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('Remote Config skipped: $e\n$st');
  }
}
