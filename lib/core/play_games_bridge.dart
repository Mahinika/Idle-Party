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

/// Names from a Play snapshot list, plus whether that list is current.
///
/// games_services 5.3.0 `SaveGame.getSavedGames` reads `annotatedData.get()`
/// and never `annotatedData.isStale()`. A list from that plugin is not proof
/// the snapshot is missing. [fresh] is false unless the caller proved it.
class SnapshotNameList {
  const SnapshotNameList({required this.names, required this.fresh});

  final List<String>? names;
  final bool fresh;
}

/// Soft-fail Play Games auth, leaderboards, and Saved Games snapshots.
///
/// No-ops on web / missing Console IDs / plugin errors — never throws into combat.
abstract final class PlayGamesBridge {
  static const String snapshotName = PlayLeaderboardIds.cloudSaveName;

  static bool _signedInCache = false;
  static DateTime? _lastCloudUploadAt;
  static Timer? _uploadDebounce;
  static GameState? _pendingUpload;

  /// Fail closed. A write is allowed only after this process has bound a Play
  /// account to a confirmed fresh empty snapshot or a decoded save.
  static bool _explicitWriteOk = false;
  static String? _boundAccount;
  static int _readGeneration = 0;
  static String? _lastUploadedSeal;
  static int _uploadGeneration = 0;
  static int _pendingGeneration = 0;

  /// Set by the director so a successful upload can store its lineage on the
  /// save. Automatic backup after a restart uses that seal.
  static Future<void> Function(GameState uploaded)? onUploadCommitted;

  static bool get cloudWriteBlocked => !_explicitWriteOk;

  /// Test seam. Production leaves these null and uses games_services.
  @visibleForTesting
  static Future<bool> Function()? debugSignIn;

  @visibleForTesting
  static Future<CloudRead> Function()? debugLoadCloud;

  @visibleForTesting
  static Future<bool> Function(GameState state)? debugSaveCloud;

  /// Play account for this session. Null means the id could not be read.
  @visibleForTesting
  static Future<String?> Function()? debugAccountId;

  /// Runs after the commit-time read and before the upload, so a test can
  /// switch accounts or fail the read while the write is in flight.
  @visibleForTesting
  static Future<void> Function()? debugBeforeCloudCommit;

  @visibleForTesting
  static void debugResetCloudHooks() {
    debugSignIn = null;
    debugLoadCloud = null;
    debugSaveCloud = null;
    debugAccountId = null;
    debugBeforeCloudCommit = null;
    _explicitWriteOk = false;
    _boundAccount = null;
    _readGeneration = 0;
    _lastUploadedSeal = null;
    _signedInCache = false;
    _lastCloudUploadAt = null;
    _uploadGeneration++;
    cancelPendingUpload();
  }

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
    final hooked = debugSignIn;
    if (hooked != null) {
      final ok = await hooked();
      _signedInCache = ok;
      return ok;
    }
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
  static void notePartyPower({required int score, String? partyName}) {
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
    if (!isSupported) return;
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
    if (cloudWriteBlocked) return;
    // Opt-in lives in the save. A reinstall is signed in at Google and
    // opted out here, so a new party must not replace the cloud snapshot.
    if (!state.metaDepth.playGamesOptIn) return;
    final generation = _uploadGeneration;
    _pendingUpload = state;
    _pendingGeneration = generation;
    // `flutter test` must not arm this Timer. Tests flush [debugFlushPendingUpload].
    if (!isSupported) return;
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(delay, () {
      final pending = _pendingUpload;
      final scheduled = _pendingGeneration;
      _pendingUpload = null;
      if (pending == null || scheduled != _uploadGeneration) return;
      unawaited(saveCloud(pending, scheduledGeneration: scheduled));
    });
  }

  /// Drop a queued upload (director dispose / tests / a restore).
  static void cancelPendingUpload() {
    _uploadDebounce?.cancel();
    _uploadDebounce = null;
    _pendingUpload = null;
  }

  /// A restore or slot change invalidates an upload armed for the old party.
  static void invalidateUploads() {
    _uploadGeneration++;
    cancelPendingUpload();
  }

  /// Test seam. Runs the armed upload, if one is still current.
  @visibleForTesting
  static Future<bool> debugFlushPendingUpload() {
    final pending = _pendingUpload;
    final scheduled = _pendingGeneration;
    _pendingUpload = null;
    if (pending == null) return Future<bool>.value(false);
    return saveCloud(pending, scheduledGeneration: scheduled);
  }

  @visibleForTesting
  static bool get debugHasPendingUpload => _pendingUpload != null;

  /// [explicit] is the player's BACKUP tap. Automatic uploads re-read at
  /// commit and refuse a snapshot this device did not last write, unless the
  /// file is confirmed missing or the progress is identical.
  static Future<bool> saveCloud(
    GameState state, {
    bool explicit = false,
    int? scheduledGeneration,
  }) async {
    if (scheduledGeneration != null &&
        scheduledGeneration != _uploadGeneration) {
      return false;
    }
    final stamped = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        cloudSaveUpdatedMs: PlayGamesScores.monotonicCloudStamp(
          previousMs: state.metaDepth.cloudSaveUpdatedMs,
          nowMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      ),
    );
    final read = await loadCloud();
    final generation = _readGeneration;
    final account = _boundAccount;
    if (!_commitAllowed(read, explicit: explicit, local: stamped)) return false;
    final outgoing = read.state == null
        ? stamped
        : PlayGamesScores.withKeptOwnership(
            chosen: stamped,
            other: read.state!,
          );
    final pending = debugBeforeCloudCommit;
    if (pending != null) await pending();
    final nowAccount = await _currentAccount();
    if (account == null ||
        nowAccount != account ||
        _readGeneration != generation ||
        _boundAccount != account) {
      _denyWrites();
      return false;
    }
    if (scheduledGeneration != null &&
        scheduledGeneration != _uploadGeneration) {
      return false;
    }
    if (!_commitAllowed(read, explicit: explicit, local: stamped)) return false;
    final hooked = debugSaveCloud;
    if (hooked != null) {
      final ok = await hooked(outgoing);
      if (ok) await _rememberUpload(outgoing);
      return ok;
    }
    if (!isSupported) return false;
    if (!_signedInCache && !await refreshSignedIn()) {
      _denyWrites();
      return false;
    }
    final afterAuth = await _currentAccount();
    if (afterAuth != account || _readGeneration != generation) {
      _denyWrites();
      return false;
    }
    if (scheduledGeneration != null &&
        scheduledGeneration != _uploadGeneration) {
      return false;
    }
    try {
      final data = GameLogic.exportSaveJson(outgoing);
      await SaveGame.saveGame(
        data: data,
        name: snapshotName,
        description:
            'AL${outgoing.ascensionLevel} · Gauntlet F${outgoing.metaDepth.gauntletBestFloor}',
      );
      _lastCloudUploadAt = DateTime.now();
      await _rememberUpload(outgoing);
      unawaited(flushPendingScores());
      return true;
    } catch (e, st) {
      debugPrint('PlayGames saveCloud failed: $e\n$st');
      return false;
    }
  }

  static bool _commitAllowed(
    CloudRead read, {
    required bool explicit,
    required GameState local,
  }) {
    if (_boundAccount == null) return false;
    if (read.kind == CloudReadKind.empty) return true;
    if (read.kind != CloudReadKind.ready || read.state == null) return false;
    if (explicit) return true;
    final cloudSeal = PlayGamesScores.progressSeal(read.state!);
    final localSeal = PlayGamesScores.progressSeal(local);
    if (cloudSeal == localSeal) return true;
    if (_lastUploadedSeal != null && cloudSeal == _lastUploadedSeal) {
      return true;
    }
    final known = local.metaDepth.cloudBackupSeal;
    if (known.isNotEmpty && cloudSeal == known) return true;
    final previous = local.metaDepth.cloudBackupPreviousSeal;
    return previous.isNotEmpty && cloudSeal == previous;
  }

  static Future<void> _rememberUpload(GameState state) async {
    _lastUploadedSeal = PlayGamesScores.progressSeal(state);
    final hook = onUploadCommitted;
    if (hook != null) await hook(state);
  }

  static void _denyWrites() {
    _explicitWriteOk = false;
    _boundAccount = null;
    _lastUploadedSeal = null;
    _readGeneration++;
  }

  static Future<CloudRead> loadCloud() async {
    final hooked = debugLoadCloud;
    if (hooked != null) {
      final account = await _currentAccount();
      if (account == null || account.isEmpty) {
        const read = CloudRead.failed();
        _noteCloudRead(read, account: null);
        return read;
      }
      final read = await hooked();
      _noteCloudRead(read, account: account);
      return read;
    }
    if (!isSupported) {
      const read = CloudRead.unavailable();
      _noteCloudRead(read, account: null);
      return read;
    }
    if (!_signedInCache && !await refreshSignedIn()) {
      const read = CloudRead.signedOut();
      _noteCloudRead(read, account: null);
      return read;
    }
    final account = await _currentAccount();
    if (account == null || account.isEmpty) {
      const read = CloudRead.failed();
      _noteCloudRead(read, account: null);
      return read;
    }
    try {
      final read = await readSnapshot(
        listNames: _listSnapshotNames,
        loadPayload: () => SaveGame.loadGame(name: snapshotName),
      );
      _noteCloudRead(read, account: account);
      return read;
    } catch (e, st) {
      debugPrint('PlayGames loadCloud failed: $e\n$st');
      const read = CloudRead.failed();
      _noteCloudRead(read, account: null);
      return read;
    }
  }

  /// games_services 5.3.0 opens with `createIfNotFound = false`. Android then
  /// fails the task for a missing snapshot and for a network or auth error,
  /// and the plugin reports both as `failed_to_load_game` plus the exception
  /// text. That string is not a not-found signal. Absence is only a fresh
  /// snapshot list that does not contain [snapshotName]. A stale list, a
  /// listed name whose open throws, or a blank body stays a failed read.
  @visibleForTesting
  static Future<CloudRead> readSnapshot({
    required Future<SnapshotNameList> Function() listNames,
    required Future<String?> Function() loadPayload,
  }) async {
    final SnapshotNameList listed;
    try {
      listed = await listNames();
    } catch (e, st) {
      debugPrint('PlayGames list snapshots failed: $e\n$st');
      return const CloudRead.failed();
    }
    final names = listed.names;
    if (!listed.fresh || names == null) return const CloudRead.failed();
    if (!names.contains(snapshotName)) return const CloudRead.empty();
    try {
      final raw = await loadPayload();
      final decoded = decodeCloudPayload(raw);
      if (decoded.kind == CloudReadKind.empty) return const CloudRead.failed();
      return decoded;
    } catch (e, st) {
      debugPrint('PlayGames open snapshot failed: $e\n$st');
      return const CloudRead.failed();
    }
  }

  static const MethodChannel _snapshotsChannel = MethodChannel(
    'idle_party/snapshots',
  );

  /// A missing or non-bool `stale` field is not a fresh list.
  @visibleForTesting
  static SnapshotNameList snapshotListFromChannel(
    Map<Object?, Object?> raw, {
    List<String>? names,
  }) {
    final listed =
        names ??
        (raw['names'] is List
            ? [for (final name in raw['names'] as List) name.toString()]
            : null);
    final stale = raw['stale'];
    if (listed == null || stale is! bool) {
      return SnapshotNameList(names: listed, fresh: false);
    }
    return SnapshotNameList(names: listed, fresh: !stale);
  }

  /// Android channel reads `AnnotatedData.isStale()`. The games_services list
  /// does not. `load(true)` only requests a server fetch; a successful result
  /// can still be stale, and a stale empty list is not a missing snapshot.
  static Future<SnapshotNameList> _listSnapshotNames() async {
    if (!isSupported) {
      return const SnapshotNameList(names: null, fresh: false);
    }
    try {
      final raw = await _snapshotsChannel.invokeMapMethod<Object?, Object?>(
        'list',
      );
      if (raw == null) {
        return const SnapshotNameList(names: null, fresh: false);
      }
      final namesRaw = raw['names'];
      if (namesRaw is! List) {
        return const SnapshotNameList(names: null, fresh: false);
      }
      final names = [for (final name in namesRaw) name.toString()];
      return snapshotListFromChannel(raw, names: names);
    } catch (e, st) {
      debugPrint('PlayGames snapshot list failed: $e\n$st');
      return const SnapshotNameList(names: null, fresh: false);
    }
  }

  static Future<String?> _currentAccount() async {
    final hooked = debugAccountId;
    if (hooked != null) return hooked();
    if (debugLoadCloud != null || debugSaveCloud != null) {
      return 'debug-account';
    }
    if (!isSupported) return null;
    try {
      final id = await Player.getPlayerID();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (e, st) {
      debugPrint('PlayGames player id failed: $e\n$st');
      return null;
    }
  }

  /// Empty string and null are a confirmed missing body only when no snapshot
  /// was listed. [readSnapshot] turns that into a failed read if the name exists.
  static CloudRead decodeCloudPayload(String? raw) {
    if (raw == null || raw.isEmpty) return const CloudRead.empty();
    final state = GameLogic.importSaveJson(raw);
    if (state == null) return const CloudRead.failed();
    return CloudRead.ready(state);
  }

  /// A caller that already holds a decoded snapshot (no second network read).
  static void noteConfirmedCloudRead(CloudRead read) {
    final account =
        _boundAccount ??
        ((debugLoadCloud != null || debugSaveCloud != null)
            ? 'debug-account'
            : null);
    _noteCloudRead(read, account: account);
  }

  static void _noteCloudRead(CloudRead read, {required String? account}) {
    _readGeneration++;
    final bound = account != null && account.isNotEmpty;
    final trusted =
        bound &&
        (read.kind == CloudReadKind.empty || read.kind == CloudReadKind.ready);
    _explicitWriteOk = trusted;
    _boundAccount = trusted ? account : null;
    if (!trusted) _lastUploadedSeal = null;
  }

  static String conflictHint(GameState s) {
    final gold = s.lifetimeGoldEarned;
    return 'AL${s.ascensionLevel} · ${gold}g life · Gauntlet F${s.metaDepth.gauntletBestFloor} · GR${s.metaDepth.grBestTier}';
  }
}
