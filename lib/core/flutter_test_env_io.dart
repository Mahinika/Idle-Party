import 'dart:io' show Platform;

/// True when running under `flutter test` (desktop host still reports android).
bool inFlutterTestProcess() => Platform.environment.containsKey('FLUTTER_TEST');
