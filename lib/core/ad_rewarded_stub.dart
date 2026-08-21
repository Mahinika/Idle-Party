import 'ad_rewarded.dart';

bool get realAdsAvailable => false;

Future<void> warmup() async {}

Future<AdWatchResult> showRewarded() async => AdWatchResult.unavailable;
