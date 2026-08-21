import 'keystone.dart';

/// Encode / decode seasonal Play Games scores (single int per board).
abstract final class PlayGamesScores {
  static const int _keyStride = 1000000000;
  static const int _timePad = 999999999;

  /// Higher KEY always ranks above lower KEY; same KEY → faster clear wins.
  static int encodeTimedKey({required int keyLevel, required int clearMs}) {
    final key = keyLevel.clamp(0, 99);
    final ms = clearMs.clamp(0, _timePad - 1);
    return key * _keyStride + (_timePad - ms);
  }

  static ({int keyLevel, int clearMs}) decodeTimedKey(int score) {
    final key = score ~/ _keyStride;
    final clearMs = _timePad - (score % _keyStride);
    return (keyLevel: key, clearMs: clearMs.clamp(0, _timePad));
  }

  static String formatTimedLabel(int keyLevel, int clearMs) =>
      'KEY +$keyLevel · ${Keystone.formatTimer(clearMs)}';

  static String formatTimedScore(int score) {
    final d = decodeTimedKey(score);
    return formatTimedLabel(d.keyLevel, d.clearMs);
  }

  /// True when [key]/[clearMs] should replace the stored season PB.
  static bool isBetterTimed({
    required int newKey,
    required int newClearMs,
    required int bestKey,
    required int bestClearMs,
  }) {
    if (newKey > bestKey) return true;
    if (newKey < bestKey) return false;
    if (bestKey <= 0) return newKey > 0;
    return newClearMs < bestClearMs || bestClearMs <= 0;
  }

  /// Conflict helper: newer stamp wins when gap > [skewMs].
  static CloudConflict resolveConflict({
    required int localMs,
    required int cloudMs,
    int skewMs = 60000,
  }) {
    if (localMs <= 0 && cloudMs > 0) return CloudConflict.preferCloud;
    if (cloudMs <= 0 && localMs > 0) return CloudConflict.preferLocal;
    final delta = localMs - cloudMs;
    if (delta > skewMs) return CloudConflict.preferLocal;
    if (delta < -skewMs) return CloudConflict.preferCloud;
    return CloudConflict.askUser;
  }
}

enum CloudConflict { preferLocal, preferCloud, askUser }
