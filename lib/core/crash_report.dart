import 'package:flutter/foundation.dart';

/// Layout and paint errors leave the app running. Crashlytics must not
/// count them as fatal crashes.
///
/// A rendering-library error (RenderFlex overflow and the rest of that
/// library) is non-fatal. Other [FlutterError]s stay fatal.
bool flutterErrorIsNonFatal(FlutterErrorDetails details) {
  if (details.library == 'rendering library') return true;
  final message = details.exceptionAsString();
  return message.contains('RenderFlex overflowed');
}

/// Uncaught async errors from [PlatformDispatcher.onError] do not end the
/// process. Crashlytics records them as non-fatal. Framework errors that
/// actually crash stay on [flutterErrorIsNonFatal].
bool platformAsyncErrorIsFatal(Object error, StackTrace stack) {
  // The process is still running, so none of these are fatal crashes.
  return false;
}
