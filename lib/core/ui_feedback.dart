import 'game_logic.dart';

/// How an ephemeral notice should look. One slot — never toast + clear at once.
enum NoticeKind {
  /// Buys, claims, tips, softups.
  tip,

  /// Floor / KEY / zone payoff.
  celebrate,

  /// Wipe / hard stop (replaces anything).
  danger,
}

/// Single ephemeral notice + Welcome Back lifetime — not combat state.
class UiFeedback {
  String? _message;
  double _life = 0;
  NoticeKind _kind = NoticeKind.tip;
  String? _lastMessage;
  DateTime? _lastAt;

  /// One tip waiting while [celebrate] owns the slot.
  String? _pendingTip;
  double _pendingTipLife = 0;

  OfflineProgressResult? _offlineSummary;
  double _offlineSummaryLife = 0;

  /// Active notice text (any kind).
  String? get toast => _life > 0 ? _message : null;

  NoticeKind get noticeKind => _kind;

  bool get celebrating => toast != null && _kind == NoticeKind.celebrate;

  /// Back-compat for HUD that keyed off the old clear banner.
  String? get clearSummary => celebrating ? _message : null;

  OfflineProgressResult? get offlineSummary =>
      _offlineSummaryLife > 0 ? _offlineSummary : null;

  bool get hasActiveTimers =>
      _life > 0 ||
      _pendingTip != null ||
      _offlineSummaryLife > 0;

  bool get toastWasShowing => _message != null || _life > 0;

  /// Tip / danger notice. [presentClear] is celebrate.
  /// Returns false when identical-spam is dropped.
  bool showToast(
    String message, {
    double life = 2.4,
    NoticeKind kind = NoticeKind.tip,
  }) {
    if (kind == NoticeKind.celebrate) {
      return _setNotice(message, life: life, kind: kind);
    }
    if (kind == NoticeKind.danger) {
      _pendingTip = null;
      return _setNotice(message, life: life, kind: kind);
    }
    // Tip while celebrate owns the slot → queue one tip for after.
    if (celebrating) {
      _pendingTip = message;
      _pendingTipLife = life;
      _lastMessage = message;
      _lastAt = DateTime.now();
      return true;
    }
    return _setTip(message, life: life);
  }

  /// Floor / KEY / zone celebration — same slot as toast, green style.
  bool presentClear(String text, {double life = 2.8}) =>
      showToast(text, life: life, kind: NoticeKind.celebrate);

  void clearToast() {
    if (_message == null && _life <= 0 && _pendingTip == null) return;
    _message = null;
    _life = 0;
    _pendingTip = null;
    _kind = NoticeKind.tip;
  }

  void dismissOfflineSummary() {
    _offlineSummary = null;
    _offlineSummaryLife = 0;
  }

  void presentOffline(OfflineProgressResult summary, {double life = 14}) {
    _offlineSummary = summary;
    _offlineSummaryLife = life;
  }

  void tick(double dt) {
    if (_life > 0) {
      _life = (_life - dt).clamp(0, 99);
      if (_life <= 0) {
        _message = null;
        if (_pendingTip != null) {
          final tip = _pendingTip!;
          final tipLife = _pendingTipLife;
          _pendingTip = null;
          _message = tip;
          _life = tipLife;
          _kind = NoticeKind.tip;
        } else {
          _kind = NoticeKind.tip;
        }
      }
    }
    if (_offlineSummaryLife > 0) {
      _offlineSummaryLife = (_offlineSummaryLife - dt).clamp(0, 99);
      if (_offlineSummaryLife <= 0) _offlineSummary = null;
    }
  }

  bool _setNotice(String message, {required double life, required NoticeKind kind}) {
    final now = DateTime.now();
    // Celebrate (CLEAR) needs a longer window — floor clear can fire twice
    // in the same beat from stairs + room-complete.
    final windowMs = kind == NoticeKind.celebrate ? 3500 : 1500;
    if (_lastMessage == message &&
        _lastAt != null &&
        now.difference(_lastAt!).inMilliseconds < windowMs) {
      return false;
    }
    _lastMessage = message;
    _lastAt = now;
    _message = message;
    _life = life;
    _kind = kind;
    if (kind == NoticeKind.celebrate) {
      // Fresh celebrate drops a queued tip that belonged to the prior beat.
      _pendingTip = null;
    }
    return true;
  }

  bool _setTip(String message, {required double life}) {
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastAt != null &&
        now.difference(_lastAt!).inMilliseconds < 1500) {
      return false;
    }
    _lastMessage = message;
    _lastAt = now;
    if (_message != null &&
        _life > 0.35 &&
        _kind == NoticeKind.tip &&
        _message != message &&
        (_message!.length + message.length) < 72 &&
        !_isCleanupToast(_message!) &&
        !_isCleanupToast(message)) {
      _message = '$_message · $message';
    } else {
      _message = message;
    }
    _life = life;
    _kind = NoticeKind.tip;
    return true;
  }

  static bool _isCleanupToast(String m) {
    final lower = m.toLowerCase();
    return lower.contains('junk') ||
        lower.contains('scrap') ||
        lower.contains('disassemble') ||
        lower.contains('cleaned') ||
        lower.contains('sold ') ||
        lower.contains('ilvl') ||
        lower.contains('bag unstuck') ||
        lower.contains('bag full') ||
        lower.contains('bag cleared');
  }
}
