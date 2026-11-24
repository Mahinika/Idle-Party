import 'package:flutter/foundation.dart';

/// Firebase Analytics free-tier limits. Names that fail these checks are
/// dropped before the SDK call. String values are truncated.
///
/// https://firebase.google.com/docs/reference/cpp/group/event-names
/// (40-char names, 100-char string values, 25 params, 24/36 user properties).
abstract final class AnalyticsGuard {
  static const maxEventName = 40;
  static const maxParamName = 40;
  static const maxParamValue = 100;
  static const maxParams = 25;
  static const maxUserPropName = 24;
  static const maxUserPropValue = 36;

  static final RegExp _eventName = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,39}$');
  static final RegExp _userPropName = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,23}$');

  /// Automatically collected. Logging them is rejected by the SDK.
  static const Set<String> reservedEvents = <String>{
    'ad_activeview',
    'ad_click',
    'ad_exposure',
    'ad_impression',
    'ad_query',
    'ad_reward',
    'app_clear_data',
    'app_exception',
    'app_remove',
    'app_store_refund',
    'app_store_subscription_cancel',
    'app_store_subscription_convert',
    'app_store_subscription_renew',
    'app_update',
    'error',
    'first_open',
    'first_visit',
    'in_app_purchase',
    'notification_dismiss',
    'notification_foreground',
    'notification_open',
    'notification_receive',
    'os_update',
    'screen_view',
    'session_start',
    'user_engagement',
  };

  static String buildMode() {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  /// Null when [raw] cannot be sent. Reserved names are returned so the
  /// caller can record them locally and still skip the SDK.
  static String? eventName(String raw) {
    final name = raw.trim();
    if (!_eventName.hasMatch(name)) return null;
    if (_blockedPrefix(name)) return null;
    return name;
  }

  static bool isReserved(String name) => reservedEvents.contains(name);

  static bool shouldSend(String name) {
    final safe = eventName(name);
    return safe != null && !isReserved(safe);
  }

  /// Bool becomes 0/1 (the SDK accepts only String and num). Strings longer
  /// than 100 characters are cut. Extra params past 25 are dropped.
  static Map<String, Object>? params(Map<String, Object>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final out = <String, Object>{};
    for (final entry in raw.entries) {
      if (out.length >= maxParams) break;
      final key = entry.key.trim();
      if (!_eventName.hasMatch(key) || _blockedPrefix(key)) continue;
      final value = paramValue(entry.value);
      if (value == null) continue;
      out[key] = value;
    }
    if (out.isEmpty) return null;
    return out;
  }

  static Object? paramValue(Object value) {
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value;
    if (value is double) {
      if (!value.isFinite) return null;
      return value;
    }
    if (value is num) {
      if (value is double && !value.isFinite) return null;
      return value;
    }
    if (value is String) {
      if (value.length <= maxParamValue) return value;
      return value.substring(0, maxParamValue);
    }
    return null;
  }

  /// Null when the pair cannot be sent. Values are cut to 36 characters.
  static ({String name, String value})? userProperty(
    String name,
    String value,
  ) {
    final key = name.trim();
    if (!_userPropName.hasMatch(key) || _blockedPrefix(key)) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final cut = text.length <= maxUserPropValue
        ? text
        : text.substring(0, maxUserPropValue);
    return (name: key, value: cut);
  }

  static bool _blockedPrefix(String name) {
    return name.startsWith('firebase_') ||
        name.startsWith('google_') ||
        name.startsWith('ga_');
  }
}
