import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'game_logic.dart';
import 'game_state.dart';
import 'party_name_filter.dart';
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
  static int? _pendingGreaterRiftScore;
  static String? _pendingGreaterRiftBoard;
  static int? _pendingPartyPower;
  static String? _pendingPartyBoard;
  static int _lastSubmittedPartyPower = -1;
  static String _partyScoreTag = PartyNameFilter.scoreTag('') ?? '';

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

  static void _rememberParty(String? partyName) {
    final tag = PartyNameFilter.scoreTag(partyName ?? '');
    if (tag != null && tag.isNotEmpty) _partyScoreTag = tag;
  }

  static void noteTimedPb({
    required String monthKey,
    required int keyLevel,
    required int clearMs,
    String? partyName,
  }) {
    _rememberParty(partyName);
    final id = PlayLeaderboardIds.timedKeyId(monthKey);
    if (id.isEmpty || !PlayLeaderboardIds.hasBoards(monthKey)) return;
    _pendingTimedBoard = id;
    _pendingTimedScore = PlayGamesScores.encodeTimedKey(
      keyLevel: keyLevel,
      clearMs: clearMs,
    );
  }

  static void noteGauntletPb({
    required String monthKey,
    required int floor,
    String? partyName,
  }) {
    _rememberParty(partyName);
    final id = PlayLeaderboardIds.gauntletId(monthKey);
    if (id.isEmpty || !PlayLeaderboardIds.hasBoards(monthKey)) return;
    _pendingGauntletBoard = id;
    _pendingGauntletScore = floor.clamp(0, 999999);
  }

  static void noteGreaterRiftPb({
    required String monthKey,
    required int tier,
    required int clearMs,
    String? partyName,
  }) {
    _rememberParty(partyName);
    final id = PlayLeaderboardIds.greaterRiftId(monthKey);
    if (id.isEmpty || !PlayLeaderboardIds.hasGreaterRiftBoard(monthKey)) {
      return;
    }
    _pendingGreaterRiftBoard = id;
    _pendingGreaterRiftScore = PlayGamesScores.encodeGreaterRift(
      tier: tier,
      clearMs: clearMs,
    );
  }

  /// Current party power. Play keeps the higher score.
  static void notePartyPower({
    required int score,
    String? partyName,
  }) {
    _rememberParty(partyName);
    final id = PlayLeaderboardIds.partyPowerId;
    if (!PlayLeaderboardIds.hasPartyPowerBoard) return;
    if (score <= 0) return;
    if (score == _lastSubmittedPartyPower && _pendingPartyPower == null) {
      return;
    }
    _pendingPartyBoard = id;
    _pendingPartyPower = score;
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
            token: _partyScoreTag,
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
            token: _partyScoreTag,
          ),
        );
        _pendingGauntletScore = null;
        _pendingGauntletBoard = null;
      } catch (e, st) {
        debugPrint('PlayGames submit gauntlet failed: $e\n$st');
      }
    }
    final gr = _pendingGreaterRiftScore;
    final grBoard = _pendingGreaterRiftBoard;
    if (gr != null && grBoard != null && grBoard.isNotEmpty) {
      try {
        await Leaderboards.submitScore(
          score: Score(
            androidLeaderboardID: grBoard,
            iOSLeaderboardID: '',
            value: gr,
            token: _partyScoreTag,
          ),
        );
        _pendingGreaterRiftScore = null;
        _pendingGreaterRiftBoard = null;
      } catch (e, st) {
        debugPrint('PlayGames submit greater rift failed: $e\n$st');
      }
    }
    final party = _pendingPartyPower;
    final partyBoard = _pendingPartyBoard;
    if (party != null && partyBoard != null && partyBoard.isNotEmpty) {
      try {
        await Leaderboards.submitScore(
          score: Score(
            androidLeaderboardID: partyBoard,
            iOSLeaderboardID: '',
            value: party,
            token: _partyScoreTag,
          ),
        );
        _lastSubmittedPartyPower = party;
        _pendingPartyPower = null;
        _pendingPartyBoard = null;
      } catch (e, st) {
        debugPrint('PlayGames submit party power failed: $e\n$st');
      }
    }
  }

  static const MethodChannel _ranksChannel = MethodChannel('idle_party/ranks');

  /// Full public board for the in-game list. Never opens the Play screen.
  /// Play returns 25 scores per page; Android keeps paging until the board ends.
  static Future<PlayBoardSnapshot> loadBoard({
    required PlayBoardKind kind,
    required String monthKey,
    String? yourPartyName,
  }) async {
    if (!isSupported) return PlayBoardSnapshot.error;
    final id = switch (kind) {
      PlayBoardKind.timedKey => PlayLeaderboardIds.timedKeyId(monthKey),
      PlayBoardKind.gauntlet => PlayLeaderboardIds.gauntletId(monthKey),
      PlayBoardKind.greaterRift => PlayLeaderboardIds.greaterRiftId(monthKey),
      PlayBoardKind.partyPower => PlayLeaderboardIds.partyPowerId,
    };
    if (!PlayLeaderboardIds.isLiveBoardId(id)) return PlayBoardSnapshot.error;
    if (!_signedInCache && !await refreshSignedIn()) {
      return PlayBoardSnapshot.error;
    }
    try {
      final loaded = await _ranksChannel.invokeMethod<List<dynamic>>(
        'loadAll',
        <String, String>{'id': id},
      );
      if (loaded == null) return PlayBoardSnapshot.error;
      final scores = PlayBoardRaw.fromChannel(loaded);
      PlayBoardRaw? you;
      try {
        final mine = await Leaderboards.getPlayerScoreObject(
          androidLeaderboardID: id,
          scope: PlayerScope.global,
          timeScope: TimeScope.allTime,
        );
        if (mine != null && mine.rawScore > 0) {
          you = PlayBoardRaw(
            rank: mine.rank,
            name: mine.scoreHolder.displayName,
            rawScore: mine.rawScore,
            playerId: mine.scoreHolder.playerID,
            scoreTag: mine.token,
          );
        }
      } catch (e, st) {
        debugPrint('PlayGames player rank skipped: $e\n$st');
      }
      return PlayBoardSnapshot(
        rows: PlayBoardList.rows(
          kind: kind,
          scores: scores,
          you: you,
          yourPartyName: yourPartyName,
        ),
      );
    } catch (e, st) {
      debugPrint('PlayGames load board failed: $e\n$st');
      return PlayBoardSnapshot.error;
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

  /// Drop a queued upload (director dispose / tests).
  static void cancelPendingUpload() {
    _uploadDebounce?.cancel();
    _uploadDebounce = null;
    _pendingUpload = null;
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
    return 'AL${s.ascensionLevel} · ${gold}g life · Gauntlet F${s.metaDepth.gauntletBestFloor} · GR${s.metaDepth.grBestTier}';
  }
}
