import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;

/// When true, [encodeGameJson] uses an isolate even inside a test.
bool debugEncodeOnIsolate = false;

/// JSON text for a save map. Encoding runs off the UI isolate.
/// Widget tests encode on the caller so a fixed pump still sees the write.
Future<String> encodeGameJson(Map<String, dynamic> json) {
  if (debugEncodeOnIsolate || !test_env.inFlutterTestProcess()) {
    return compute(encodeGameJsonSync, json);
  }
  return Future<String>.value(encodeGameJsonSync(json));
}

/// Top-level so [compute] can send it to an isolate.
String encodeGameJsonSync(Map<String, dynamic> json) => jsonEncode(json);
