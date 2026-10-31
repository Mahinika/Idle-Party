import 'dart:async';

/// How long a Play Core update probe may block cold start.
///
/// [InAppUpdate.checkForUpdate] can sit forever with no network. The splash
/// awaits that probe, so it must give up.
const Duration playUpdateCheckTimeout = Duration(seconds: 3);

/// Completes with [TimeoutException] if [future] outlives [timeout].
Future<T> boundPlayUpdateCall<T>(
  Future<T> future, {
  Duration timeout = playUpdateCheckTimeout,
}) {
  return future.timeout(timeout);
}
