Future<void> init() async {}

void armEarlyErrorBuffer() {}

int get debugBufferedErrorCount => 0;

void debugResetEarlyErrorBuffer() {}

Future<void> syncConsent() async {}

Future<void> logEvent(String name, [Map<String, Object>? params]) async {}

void syncCrashContext({
  required String zoneId,
  required String appVersion,
}) {}
