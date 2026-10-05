import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_analytics.dart';
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
    final allowed = await ConsentInformation.instance.canRequestAds();
    if (!allowed) {
      RemoteTune.reset();
      return;
    }
    await Firebase.initializeApp();
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 12),
      ),
    );
    await rc.setDefaults(RemoteTune.defaults);
    await rc.fetchAndActivate();
    RemoteTune.apply(
      dailyCap: rc.getInt(RemoteTune.keyDailyCap),
      firstDelaySec: rc.getInt(RemoteTune.keyFirstDelaySec),
      intervalSec: rc.getInt(RemoteTune.keyIntervalSec),
      visibleSec: rc.getInt(RemoteTune.keyVisibleSec),
      shopFeaturedId: rc.getString(RemoteTune.keyShopFeatured),
      fromRemote: true,
    );
    final shop = RemoteTune.shopFeaturedId;
    await AppAnalytics.logEvent('remote_tune', {
      'wisp_cap': RemoteTune.wispDailyCap,
      'wisp_first_s': RemoteTune.wispFirstDelayMs ~/ 1000,
      'wisp_every_s': RemoteTune.wispIntervalMs ~/ 1000,
      'shop': shop.isEmpty ? 'default' : shop,
    });
    debugPrint(
      'Remote Config applied '
      'cap=${RemoteTune.wispDailyCap} '
      'first=${RemoteTune.wispFirstDelayMs ~/ 1000}s '
      'every=${RemoteTune.wispIntervalMs ~/ 1000}s '
      'shop=${shop.isEmpty ? 'default' : shop}',
    );
  } catch (e, st) {
    debugPrint('Remote Config skipped: $e\n$st');
  }
}
