import 'package:flutter/foundation.dart';

/// Cold-start marks for logcat. Filter `[IP] boot-clock`.
///
/// Prints in release too, so a test APK can time the Play icon against the
/// Cognifox splash. A handful of lines, no save data.
abstract final class BootClock {
  static final DateTime _start = DateTime.now();
  static final List<String> marks = <String>[];

  static void mark(String name) {
    final ms = DateTime.now().difference(_start).inMilliseconds;
    marks.add('$name $ms');
    debugPrint('[IP] boot-clock · $name · ${ms}ms');
  }
}
