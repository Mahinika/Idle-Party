import 'ad_rewarded.dart';

bool get realAdsAvailable => false;

Future<void> prepareOffer({String? placement}) async {}

Future<void> warmup() async {}

Future<AdWatchResult> showRewarded({required String placement}) async =>
    AdWatchResult.unavailable;

Future<void> showPrivacyOptions() async {}
