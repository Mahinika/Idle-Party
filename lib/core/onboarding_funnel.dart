import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'funnel_analytics.dart';

/// Install-scoped onboarding steps. Flags live in SharedPreferences, not in
/// the save, so a second slot cannot replay the funnel.
///
/// An existing save with an empty flag list is marked done without events.
/// That keeps players who installed before this measurement out of the
/// new-user funnel. The cohort day is the first launch of this build for
/// those saves, and the real first launch when the phone had no save.
abstract final class OnboardingFunnel {
  static const prefsKey = 'idle_party_onboarding_funnel';
  static const installMsKey = 'idle_party_install_ms';

  static const launch = 'onboarding_launch';

  /// First dungeon enter. Same id as the per-save event. [step_index] is
  /// attached only the first time on this install.
  static const firstFight = 'first_enter';

  /// First TRAIN spend (forge gold). Same id as the per-save event.
  static const firstTrain = 'first_upgrade';

  static const firstBoss = 'first_boss';
  static const firstCraft = 'first_craft';

  /// First Welcome Back card. Later cards keep the name and omit [step_index].
  static const firstReturn = 'welcome_back';

  static const List<String> steps = <String>[
    launch,
    firstFight,
    firstTrain,
    firstBoss,
    firstCraft,
    firstReturn,
  ];

  /// These events also fire on later saves or later cards. The step param
  /// is the once-per-install mark. [launch] and [firstCraft] are not here:
  /// they are logged only on the claim.
  static const Set<String> repeatSteps = <String>{
    firstFight,
    firstTrain,
    firstBoss,
    firstReturn,
  };

  static final Set<String> _seen = <String>{};
  static int _installMs = 0;
  static Future<void> _flushChain = Future<void>.value();
  static Future<void>? _loading;

  static int? stepIndex(String name) {
    final index = steps.indexOf(name);
    if (index < 0) return null;
    return index + 1;
  }

  static Future<void> load() {
    // A Future completed inside one widget test's fake clock never resumes
    // in the next test. Skip the cache there.
    if (test_env.inFlutterTestProcess()) {
      return _prefsAvailable ? _read() : Future<void>.value();
    }
    return _loading ??= _read();
  }

  /// Widget tests have no prefs channel unless they install the in-memory
  /// store. Touching the real channel there never completes, so tests that
  /// need the disk set this after `SharedPreferences.setMockInitialValues`.
  @visibleForTesting
  static bool debugReadPrefs = false;

  static bool get _prefsAvailable {
    if (!test_env.inFlutterTestProcess()) return true;
    return debugReadPrefs;
  }

  static Future<void> _read() async {
    if (!_prefsAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen.addAll(prefs.getStringList(prefsKey) ?? const <String>[]);
      final stored = prefs.getInt(installMsKey) ?? 0;
      if (stored > 0) _installMs = stored;
    } catch (_) {
      // A broken store stays in memory for this process.
    }
  }

  /// Veteran install: every step is already behind them. No events.
  static void backfillSilently() {
    if (_seen.isNotEmpty) return;
    _seen.addAll(steps);
    _touchInstallClock();
    _scheduleFlush();
  }

  /// First time this install: the 1-based step. Later: null.
  static int? claim(String name) {
    final index = stepIndex(name);
    if (index == null || _seen.contains(name)) return null;
    _seen.add(name);
    _touchInstallClock();
    _scheduleFlush();
    return index;
  }

  /// Adds `step_index` the first time [name] is a [repeatSteps] event.
  static Map<String, Object>? attachStep(
    String name,
    Map<String, Object>? params,
  ) {
    if (!repeatSteps.contains(name)) return params;
    final step = claim(name);
    if (step == null) return params;
    return <String, Object>{...?params, 'step_index': step};
  }

  static int? daysSince(DateTime now) {
    if (_installMs <= 0) return null;
    final install = DateTime.fromMillisecondsSinceEpoch(
      _installMs,
      isUtc: true,
    );
    return FunnelAnalytics.utcCalendarDaysApart(install, now.toUtc());
  }

  /// `YYYYMMDD` in UTC. Null until the install clock exists.
  static String? cohortUtc() {
    if (_installMs <= 0) return null;
    final install = DateTime.fromMillisecondsSinceEpoch(
      _installMs,
      isUtc: true,
    );
    final year = install.year.toString().padLeft(4, '0');
    final month = install.month.toString().padLeft(2, '0');
    final day = install.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  static void _touchInstallClock() {
    if (_installMs > 0) return;
    _installMs = DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  static void _scheduleFlush() {
    final seen = _seen.toList(growable: false);
    final ms = _installMs;
    // Chaining onto a Future from an earlier widget test never resumes.
    if (test_env.inFlutterTestProcess()) {
      _flushChain = _write(seen, ms);
      return;
    }
    _flushChain = _flushChain.then((_) => _write(seen, ms));
  }

  static Future<void> _write(List<String> seen, int ms) async {
    if (!_prefsAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, seen);
      if (ms > 0) await prefs.setInt(installMsKey, ms);
    } catch (_) {}
  }

  @visibleForTesting
  static Future<void> debugFlush() => _flushChain;

  @visibleForTesting
  static void debugReset() {
    _seen.clear();
    _installMs = 0;
    _loading = null;
    _flushChain = Future<void>.value();
  }
}
