import 'remote_tune_stub.dart'
    if (dart.library.io) 'remote_tune_io.dart' as impl;

/// Fetches Remote Config on Android. No-op on web and in tests.
abstract final class RemoteTuneBoot {
  static Future<void> refresh() => impl.refresh();
}
