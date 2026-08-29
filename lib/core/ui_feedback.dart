import 'game_logic.dart';

/// Toast, floor-clear line, and Welcome Back lifetime — not combat state.
class UiFeedback {
  String? _toast;
  double _toastLife = 0;
  String? _lastToastMessage;
  DateTime? _lastToastAt;
  String? _clearSummary;
  double _clearSummaryLife = 0;
  OfflineProgressResult? _offlineSummary;
  double _offlineSummaryLife = 0;

  String? get toast => _toastLife > 0 ? _toast : null;

  String? get clearSummary => _clearSummaryLife > 0 ? _clearSummary : null;

  OfflineProgressResult? get offlineSummary =>
      _offlineSummaryLife > 0 ? _offlineSummary : null;

  bool get hasActiveTimers =>
      _toastLife > 0 || _clearSummaryLife > 0 || _offlineSummaryLife > 0;

  /// Returns false when identical-spam is dropped (no listener notify needed).
  bool showToast(String message, {double life = 2.4}) {
    final now = DateTime.now();
    if (_lastToastMessage == message &&
        _lastToastAt != null &&
        now.difference(_lastToastAt!).inMilliseconds < 800) {
      return false;
    }
    _lastToastMessage = message;
    _lastToastAt = now;
    if (_toast != null &&
        _toastLife > 0.35 &&
        _toast != message &&
        (_toast!.length + message.length) < 72 &&
        !_isCleanupToast(_toast!) &&
        !_isCleanupToast(message)) {
      _toast = '$_toast · $message';
    } else {
      _toast = message;
    }
    _toastLife = life;
    return true;
  }

  void clearToast() {
    if (_toast == null && _toastLife <= 0) return;
    _toast = null;
    _toastLife = 0;
  }

  bool get toastWasShowing => _toast != null || _toastLife > 0;

  void dismissOfflineSummary() {
    _offlineSummary = null;
    _offlineSummaryLife = 0;
  }

  void presentOffline(OfflineProgressResult summary, {double life = 14}) {
    _offlineSummary = summary;
    _offlineSummaryLife = life;
  }

  void presentClear(String text, {double life = 3.5}) {
    _clearSummary = text;
    _clearSummaryLife = life;
  }

  void tick(double dt) {
    if (_toastLife > 0) {
      _toastLife = (_toastLife - dt).clamp(0, 99);
      if (_toastLife <= 0) _toast = null;
    }
    if (_clearSummaryLife > 0) {
      _clearSummaryLife = (_clearSummaryLife - dt).clamp(0, 99);
      if (_clearSummaryLife <= 0) _clearSummary = null;
    }
    if (_offlineSummaryLife > 0) {
      _offlineSummaryLife = (_offlineSummaryLife - dt).clamp(0, 99);
      if (_offlineSummaryLife <= 0) _offlineSummary = null;
    }
  }

  static bool _isCleanupToast(String m) {
    final lower = m.toLowerCase();
    return lower.contains('junk') ||
        lower.contains('scrap') ||
        lower.contains('disassemble') ||
        lower.contains('cleaned') ||
        lower.contains('sold ') ||
        lower.contains('ilvl');
  }
}
