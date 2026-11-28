/// At most one save flush per two seconds. Pause and exit pass [immediate]
/// and write on this call.
abstract final class SaveFlushGate {
  static const int windowMs = 2000;

  /// Milliseconds to wait before the write. 0 means write now.
  static int delayMs({
    required int nowMs,
    required int lastWriteMs,
    required bool immediate,
  }) {
    if (immediate || lastWriteMs <= 0) return 0;
    final elapsed = nowMs - lastWriteMs;
    if (elapsed >= windowMs) return 0;
    return windowMs - elapsed;
  }
}
