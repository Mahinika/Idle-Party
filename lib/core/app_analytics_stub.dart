Future<void> init() async {}

void armEarlyErrorBuffer() {}

int get debugBufferedErrorCount => 0;

void debugResetEarlyErrorBuffer() {}

void Function(Object error, StackTrace? stack, {required bool fatal})?
debugRecordPlatformError;

void debugEmitPlatformError(Object error, StackTrace stack) {
  debugRecordPlatformError?.call(error, stack, fatal: false);
}

Future<void> syncConsent() async {}

Future<void> logEvent(String name, [Map<String, Object>? params]) async {}

Future<void> setUserProperty(String name, String value) async {}

void syncCrashContext({required String zoneId, required String appVersion}) {}

Future<void> adImpression({
  required String adFormat,
  required String adUnitName,
  double? value,
  String? currency,
  String? placement,
}) async {}
