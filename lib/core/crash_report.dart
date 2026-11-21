import 'package:flutter/foundation.dart';

/// Layout and paint errors leave the app running. Crashlytics must not
/// count them as fatal crashes.
///
/// A rendering-library error (RenderFlex overflow and the rest of that
/// library) is non-fatal. [PlatformDispatcher.onError] and zone errors stay
/// fatal; this helper does not classify those.
bool flutterErrorIsNonFatal(FlutterErrorDetails details) {
  if (details.library == 'rendering library') return true;
  final message = details.exceptionAsString();
  return message.contains('RenderFlex overflowed');
}
