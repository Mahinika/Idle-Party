import 'package:flutter/foundation.dart';

/// Cold-start marks for logcat. Filter `[IP] boot-clock`.
///
/// Prints in release too, so a test APK can time the Play icon against the
/// splash. A handful of lines, no save data.
///
/// Typical order after the Play icon:
/// `main` → `runApp` → `firstFrame` → `saveBootStart` (with `playUpdateProbeStart`)
/// → `saveBootEnd` / `playUpdateProbeEnd` (overlap) → `townArtWarmup*` after paint
/// → `firebase` → `remoteTune`.
abstract final class BootClock {
  static final DateTime _start = DateTime.now();
  static final List<String> marks = <String>[];

  static void mark(String name) {
    final ms = DateTime.now().difference(_start).inMilliseconds;
    marks.add('$name $ms');
    debugPrint('[IP] boot-clock · $name · ${ms}ms');
  }

  /// Mark name without the trailing millisecond column.
  static String nameOf(String mark) => mark.split(' ').first;

  /// Indexes of every mark with this name in [marks].
  static List<int> indexesOf(String name) {
    final out = <int>[];
    for (var i = 0; i < marks.length; i++) {
      if (nameOf(marks[i]) == name) out.add(i);
    }
    return out;
  }
}
