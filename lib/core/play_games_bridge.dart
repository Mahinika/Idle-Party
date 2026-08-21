import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'game_logic.dart';
import 'game_state.dart';
import 'play_games_scores.dart';
import 'play_leaderboard_ids.dart';

/// Soft-fail Play Games auth, leaderboards, and Saved Games snapshots.
///
/// No-ops on web / missing Console IDs / plugin errors — never throws into combat.
abstract final class PlayGamesBridge {
  static const String snapshotName = PlayLeaderboardIds.cloudSaveName;

  static bool _signedInCache = false;
  static DateTime? _lastCloudUploadAt;
  static Timer? _uploadDebounce;
  static GameState? _pendingUpload;

  static int? _pendingTimedScore;
  static String? _pendingTimedBoard;
  static int? _pendingGauntletScore;
  static String? _pendingGauntletBoard;

  static bool get isSignedInCached => _signedInCache;

  static DateTime? get lastCloudUploadAt => _lastCloudUploadAt;

  /// Platform supports Play Games (Android). iOS/web/tests → false soft-fail.
  static bool get isSupported {
    if (kIsWeb) return false;
    // `flutter test` on desktop still reports TargetPlatform.android for this
    // app — never touch games_services / Timers from unit tests.
    if (test_env.inFlutterTestProcess()) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<bool> refreshSignedIn() async {
    if (!isSupported) {
      _signedInCache = false;
      return false;
    }
    try {
      _signedInCache = await GameAuth.isSignedIn;
      return _signedInCache;
    } catch (e, st) {
      debugPrint('PlayGames isSignedIn failed: $e\n$st');
      _signedInCache = false;
      return false;
    }
  }

  static Future<bool> signIn() async {
    if (!isSupported) return false;
    try {
      await GameAuth.signIn();
      _signedInCache = await GameAuth.isSignedIn;
      if (_signedInCache) {
        unawaited(flushPendingScores());
      }
      return _signedInCache;
    } catch (e, st) {
      debugPrint('PlayGames signIn failed: $e\n$st');
      _signedInCache = false;
      return false;
    }
  }

  static void noteTimedPb({
    required String monthKey,
    required int keyLevel,
    required int clearMs,
  }) {
    final id = PlayLeaderboardIds.timedKeyId(monthKey);
    if (id.isEmpty || !PlayLeaderboardIds.hasBoards(monthKey)) return;
    _pendingTimedBoard = id;
    _pendingTimedScore = PlayGamesScores.encodeTimedKey(
      keyLevel: keyLevel,
      clearMs: clearMs,
    );
  }

  static void noteGauntletPb({required String monthKey, required int floor}) {
    final id = PlayLeaderboardIds.gauntletId(monthKey);
    if (id.isEmpty || !PlayLeaderboardIds.hasBoards(monthKey)) return;
    _pendingGauntletBoard = id;
    _pendingGauntletScore = floor.clamp(0, 999999);
  }

  static Future<void> flushPendingScores() async {
    if (!_signedInCache && !await refreshSignedIn()) return;
    final timed = _pendingTimedScore;
    final timedBoard = _pendingTimedBoard;
    if (timed != null && timedBoard != null && timedBoard.isNotEmpty) {
      try {
        await Leaderboards.submitScore(
          score: Score(
            androidLeaderboardID: timedBoard,
            iOSLeaderboardID: '',
            value: timed,
          ),
        );
        _pendingTimedScore = null;
        _pendingTimedBoard = null;
      } catch (e, st) {
        debugPrint('PlayGames submit timed failed: $e\n$st');
      }
    }
    final g = _pendingGauntletScore;
    final gBoard = _pendingGauntletBoard;
    if (g != null && gBoard != null && gBoard.isNotEmpty) {
      try {
        await Leaderboards.submitScore(
          score: Score(
            androidLeaderboardID: gBoard,
            iOSLeaderboardID: '',
            value: g,
          ),
        );
        _pendingGauntletScore = null;
        _pendingGauntletBoard = null;
      } catch (e, st) {
        debugPrint('PlayGames submit gauntlet failed: $e\n$st');
      }
    }
  }

  static Future<void> showTimedLeaderboard(String monthKey) async {
    final id = PlayLeaderboardIds.timedKeyId(monthKey);
    if (id.isEmpty) return;
    if (!_signedInCache && !await signIn()) return;
    try {
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: id,
        iOSLeaderboardID: '',
      );
    } catch (e, st) {
      debugPrint('PlayGames show timed board failed: $e\n$st');
    }
  }

  static Future<void> showGauntletLeaderboard(String monthKey) async {
    final id = PlayLeaderboardIds.gauntletId(monthKey);
    if (id.isEmpty) return;
    if (!_signedInCache && !await signIn()) return;
    try {
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: id,
        iOSLeaderboardID: '',
      );
    } catch (e, st) {
      debugPrint('PlayGames show gauntlet board failed: $e\n$st');
    }
  }

  /// Debounced cloud upload after local persist.
  static void scheduleCloudUpload(
    GameState state, {
    Duration delay = const Duration(seconds: 8),
  }) {
    if (!isSupported) return;
    _pendingUpload = state;
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(delay, () {
      final pending = _pendingUpload;
      _pendingUpload = null;
      if (pending != null) {
        unawaited(saveCloud(pending));
      }
    });
  }

  static Future<bool> saveCloud(GameState state) async {
    if (!isSupported) return false;
    if (!_signedInCache && !await refreshSignedIn()) return false;
    try {
      final stamped = state.copyWith(
        metaDepth: state.metaDepth.copyWith(
          cloudSaveUpdatedMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
      final data = GameLogic.exportSaveJson(stamped);
      await SaveGame.saveGame(
        data: data,
        name: snapshotName,
        description:
            'AL${stamped.ascensionLevel} · Gauntlet F${stamped.metaDepth.gauntletBestFloor}',
      );
      _lastCloudUploadAt = DateTime.now();
      unawaited(flushPendingScores());
      return true;
    } catch (e, st) {
      debugPrint('PlayGames saveCloud failed: $e\n$st');
      return false;
    }
  }

  static Future<GameState?> loadCloud() async {
    if (!isSupported) return null;
    if (!_signedInCache && !await refreshSignedIn()) return null;
    try {
      final raw = await SaveGame.loadGame(name: snapshotName);
      if (raw == null || raw.isEmpty) return null;
      return GameLogic.importSaveJson(raw);
    } catch (e, st) {
      debugPrint('PlayGames loadCloud failed: $e\n$st');
      return null;
    }
  }

  static String conflictHint(GameState s) {
    final gold = s.lifetimeGoldEarned;
    return 'AL${s.ascensionLevel} · ${gold}g life · Gauntlet F${s.metaDepth.gauntletBestFloor}';
  }
}
