import 'dart:convert';
import 'dart:math';

import 'game_state.dart';
import 'keystone.dart';
import 'party_name_filter.dart';

/// Encode / decode seasonal Play Games scores (single int per board).
abstract final class PlayGamesScores {
  static const int _keyStride = 1000000000;
  static const int _timePad = 999999999;

  /// Higher KEY always ranks above lower KEY; same KEY → faster clear wins.
  static int encodeTimedKey({required int keyLevel, required int clearMs}) {
    final key = keyLevel.clamp(0, Keystone.maxLevel);
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

  /// Greater Rift uses the same packing as Timed KEY (tier × stride + pad−ms).
  static int encodeGreaterRift({required int tier, required int clearMs}) =>
      encodeTimedKey(keyLevel: tier, clearMs: clearMs);

  static ({int tier, int clearMs}) decodeGreaterRift(int score) {
    final d = decodeTimedKey(score);
    return (tier: d.keyLevel, clearMs: d.clearMs);
  }

  static String formatGreaterRiftLabel(int tier, int clearMs) =>
      'GR$tier · ${Keystone.formatTimer(clearMs)}';

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

  /// A brand-new party has no gold, floors, or levels yet.
  ///
  /// A newer stamp on that party must not beat a Play Games snapshot.
  static bool localSaveHasProgress(GameState state) {
    if (state.ascensionLevel > 0) return true;
    if (state.highestFloorCleared > 0) return true;
    if (state.bossVictories > 0) return true;
    if (state.highestDungeonCleared >= 0) return true;
    if (state.lifetimeGoldEarned > 0) return true;
    if (state.essence > 0) return true;
    if (state.metaDepth.gauntletBestFloor > 0) return true;
    for (final hero in state.heroRoster) {
      if (hero.level > 1) return true;
    }
    return false;
  }

  /// Conflict helper. Stamps break a tie. They never hide a rollback.
  ///
  /// Without [local] and [cloud], only the stamps are compared (older callers
  /// and tests). With both saves, durable progress wins over a wall clock
  /// that jumped or rolled back. Spendable essence is not progress.
  static CloudConflict resolveConflict({
    required int localMs,
    required int cloudMs,
    int skewMs = 60000,
    GameState? local,
    GameState? cloud,
  }) {
    final clock = clockConflict(
      localMs: localMs,
      cloudMs: cloudMs,
      skewMs: skewMs,
    );
    if (local == null || cloud == null) return clock;
    // Stamps and a partial scoreboard are not proof that one file contains
    // the other. Two real saves always ask. An untouched starter party is
    // handled by [planSignIn] / [planRestore], not here.
    switch (compareSaveProgress(local, cloud)) {
      case SaveProgressRelation.tie:
      case SaveProgressRelation.diverged:
      case SaveProgressRelation.localAhead:
      case SaveProgressRelation.cloudAhead:
        return CloudConflict.askUser;
    }
  }

  /// Stamp comparison only. A gap inside [skewMs] asks the player.
  static CloudConflict clockConflict({
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

  /// Never move a cloud stamp backwards when the phone clock does.
  static int monotonicCloudStamp({
    required int previousMs,
    required int nowMs,
  }) {
    if (nowMs > previousMs && nowMs > 0) return nowMs;
    return previousMs < 0 ? 0 : previousMs;
  }

  /// Tie only when every saved leaf matches except the wall clock and the
  /// cloud bookkeeping stamp. Anything else diverges. This does not rank one
  /// file above the other: a missing permanent upgrade must not look "behind".
  static SaveProgressRelation compareSaveProgress(
    GameState local,
    GameState cloud,
  ) {
    if (progressSeal(local) == progressSeal(cloud)) {
      return SaveProgressRelation.tie;
    }
    return SaveProgressRelation.diverged;
  }

  /// Stable identity of a save, ignoring clocks that move without play.
  static String progressSeal(GameState state) {
    final json = state.toJson();
    json.remove('lastUpdated');
    final meta = json['metaDepth'];
    if (meta is Map) {
      meta.remove('cloudSaveUpdatedMs');
      meta.remove('cloudBackupSeal');
      meta.remove('cloudBackupPreviousSeal');
    }
    return jsonEncode(json);
  }

  /// Paid ownership is not gold, tickets, or Cinders.
  static bool hasPaidOwnership(GameState state) {
    final md = state.metaDepth;
    if (md.adFree || md.paidSeasonPass || md.shopLongAway) return true;
    if (md.shopStarterClaimed || md.cinderPouchDoubled) return true;
    if (md.shopBagBonusSlots > 0 || md.shopPermScrolls != 0) return true;
    if (md.grantedShopPurchaseIds.isNotEmpty) return true;
    if (md.redeemedCoupons.isNotEmpty) return true;
    return false;
  }

  /// [chosen] keeps its gold and materials. Ownership that exists on either
  /// file is kept, so a cloud replace cannot drop Ad-free or a season pass.
  /// Consumable stacks are not added together.
  static GameState withKeptOwnership({
    required GameState chosen,
    required GameState other,
  }) {
    final a = chosen.metaDepth;
    final b = other.metaDepth;
    final ids = <String>[];
    void addIds(List<String> src) {
      for (final raw in src) {
        final id = raw.trim();
        if (id.isEmpty || ids.contains(id)) continue;
        ids.add(id);
      }
    }

    addIds(a.grantedShopPurchaseIds);
    const purchaseIdCap = 64;
    final chosenIds = ids.length > purchaseIdCap
        ? ids.sublist(ids.length - purchaseIdCap)
        : List<String>.from(ids);
    final otherIds = <String>[];
    for (final raw in b.grantedShopPurchaseIds) {
      final id = raw.trim();
      if (id.isEmpty || chosenIds.contains(id) || otherIds.contains(id)) {
        continue;
      }
      otherIds.add(id);
    }
    final room = purchaseIdCap - chosenIds.length;
    final keptOther = otherIds.length > room
        ? otherIds.sublist(otherIds.length - room)
        : otherIds;
    ids
      ..clear()
      ..addAll(keptOther)
      ..addAll(chosenIds);
    final coupons = <String>[
      ...a.redeemedCoupons,
      for (final code in b.redeemedCoupons)
        if (!a.redeemedCoupons.contains(code)) code,
    ];
    return chosen.copyWith(
      metaDepth: a.copyWith(
        adFree: a.adFree || b.adFree,
        paidSeasonPass: a.paidSeasonPass || b.paidSeasonPass,
        shopLongAway: a.shopLongAway || b.shopLongAway,
        shopStarterClaimed: a.shopStarterClaimed || b.shopStarterClaimed,
        cinderPouchDoubled: a.cinderPouchDoubled || b.cinderPouchDoubled,
        shopBagBonusSlots: max(a.shopBagBonusSlots, b.shopBagBonusSlots),
        shopPermScrolls: (a.shopPermScrolls | b.shopPermScrolls).clamp(0, 127),
        grantedShopPurchaseIds: List<String>.unmodifiable(ids),
        redeemedCoupons: List<String>.unmodifiable(coupons),
      ),
    );
  }

  /// What sign-in may do after a cloud read. Upload only when Play confirmed
  /// the snapshot is missing.
  static CloudSignInPlan planSignIn({
    required CloudRead read,
    required bool hasExistingSave,
    required GameState local,
    required bool localIsReplaceable,
  }) {
    final keepLocal = hasExistingSave && !localIsReplaceable;
    switch (read.kind) {
      case CloudReadKind.ready:
        final cloud = read.state;
        if (cloud != null && !keepLocal) {
          return const CloudSignInPlan(install: true, upload: false);
        }
        return const CloudSignInPlan(
          install: false,
          upload: false,
          toast: 'Signed in to Play Games',
        );
      case CloudReadKind.empty:
        return CloudSignInPlan(
          install: false,
          upload: true,
          optIn: true,
          toast: hasExistingSave
              ? 'Signed in to Play Games'
              : 'Signed in · no cloud save yet',
        );
      case CloudReadKind.failed:
      case CloudReadKind.unavailable:
      case CloudReadKind.signedOut:
        return const CloudSignInPlan(
          install: false,
          upload: false,
          toast: 'Could not read Play Games save. Kept this device.',
        );
    }
  }

  /// Restore choice. [force] is the player's USE CLOUD / RESTORE tap.
  static CloudRestorePlan planRestore({
    required CloudRead read,
    required GameState local,
    required bool hasExistingSave,
    required bool localIsReplaceable,
    required bool force,
  }) {
    switch (read.kind) {
      case CloudReadKind.ready:
        break;
      case CloudReadKind.empty:
        return const CloudRestorePlan(
          CloudRestoreChoice.missing,
          toast: 'No Play Games save found',
        );
      case CloudReadKind.failed:
      case CloudReadKind.unavailable:
      case CloudReadKind.signedOut:
        return const CloudRestorePlan(
          CloudRestoreChoice.unreadable,
          toast: 'Could not read Play Games save. Kept this device.',
        );
    }
    final cloud = read.state;
    if (cloud == null) {
      return const CloudRestorePlan(
        CloudRestoreChoice.unreadable,
        toast: 'Could not read Play Games save. Kept this device.',
      );
    }
    if (force || !hasExistingSave || localIsReplaceable) {
      return const CloudRestorePlan(CloudRestoreChoice.installed);
    }
    return const CloudRestorePlan(CloudRestoreChoice.needChoice);
  }
}

enum CloudConflict { preferLocal, preferCloud, askUser }

/// How two saves compare when the wall clock is not trusted.
enum SaveProgressRelation { localAhead, cloudAhead, tie, diverged }

/// Outcome of one Play Games snapshot read. A failure is not an empty file.
enum CloudReadKind { unavailable, signedOut, empty, failed, ready }

class CloudRead {
  const CloudRead._(this.kind, this.state);

  const CloudRead.unavailable() : this._(CloudReadKind.unavailable, null);

  const CloudRead.signedOut() : this._(CloudReadKind.signedOut, null);

  const CloudRead.empty() : this._(CloudReadKind.empty, null);

  const CloudRead.failed() : this._(CloudReadKind.failed, null);

  const CloudRead.ready(GameState state) : this._(CloudReadKind.ready, state);

  final CloudReadKind kind;
  final GameState? state;

  bool get blocksAutomaticUpload =>
      kind == CloudReadKind.failed ||
      kind == CloudReadKind.unavailable ||
      kind == CloudReadKind.signedOut;
}

/// Sign-in policy after [CloudRead]. [optIn] null leaves the save flag as it is.
class CloudSignInPlan {
  const CloudSignInPlan({
    required this.install,
    required this.upload,
    this.optIn,
    this.toast,
  });

  final bool install;
  final bool upload;
  final bool? optIn;
  final String? toast;
}

enum CloudRestoreChoice {
  installed,
  keptLocal,
  needChoice,
  unreadable,
  missing,
}

class CloudRestorePlan {
  const CloudRestorePlan(this.choice, {this.toast});

  final CloudRestoreChoice choice;
  final String? toast;
}

/// Which seasonal board the KEY list is showing.
enum PlayBoardKind { timedKey, gauntlet, greaterRift, partyPower }

/// One public row before player-facing labels. Tests build these without Play.
class PlayBoardRaw {
  const PlayBoardRaw({
    required this.rank,
    required this.name,
    required this.rawScore,
    this.playerId,
    this.scoreTag,
  });

  final int rank;
  final String name;
  final int rawScore;
  final String? playerId;

  /// Play Games score tag. Holds the party name when this build submitted it.
  final String? scoreTag;

  /// Rows from the Android rank channel. Skips malformed maps.
  static List<PlayBoardRaw> fromChannel(List<dynamic> raw) {
    final out = <PlayBoardRaw>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final rank = item['rank'];
      final score = item['rawScore'];
      if (rank is! num || score is! num) continue;
      final name = item['name'];
      final playerId = item['playerId'];
      final scoreTag = item['scoreTag'];
      out.add(
        PlayBoardRaw(
          rank: rank.toInt(),
          name: name is String ? name : '',
          rawScore: score.toInt(),
          playerId: playerId is String && playerId.isNotEmpty ? playerId : null,
          scoreTag: scoreTag is String && scoreTag.isNotEmpty ? scoreTag : null,
        ),
      );
    }
    return out;
  }
}

/// One row on the in-game season board.
class PlayBoardRow {
  const PlayBoardRow({
    required this.rank,
    required this.name,
    required this.scoreLabel,
    required this.isYou,
  });

  final int rank;
  final String name;
  final String scoreLabel;
  final bool isYou;
}

/// Loaded season board. [failed] means the list could not be fetched.
class PlayBoardSnapshot {
  const PlayBoardSnapshot({required this.rows, this.failed = false});

  final List<PlayBoardRow> rows;
  final bool failed;

  static const empty = PlayBoardSnapshot(rows: []);
  static const error = PlayBoardSnapshot(rows: [], failed: true);
}

/// Turns Play score numbers into the KEY board list.
abstract final class PlayBoardList {
  static String scoreLabel(PlayBoardKind kind, int rawScore) {
    switch (kind) {
      case PlayBoardKind.timedKey:
        final decoded = PlayGamesScores.decodeTimedKey(rawScore);
        if (decoded.keyLevel <= 0) return '—';
        return PlayGamesScores.formatTimedLabel(
          decoded.keyLevel,
          decoded.clearMs,
        );
      case PlayBoardKind.gauntlet:
        final floor = rawScore.clamp(0, 999999);
        if (floor <= 0) return '—';
        return 'F$floor';
      case PlayBoardKind.greaterRift:
        final decoded = PlayGamesScores.decodeGreaterRift(rawScore);
        if (decoded.tier <= 0) return '—';
        return PlayGamesScores.formatGreaterRiftLabel(
          decoded.tier,
          decoded.clearMs,
        );
      case PlayBoardKind.partyPower:
        if (rawScore <= 0) return '0';
        return '$rawScore';
    }
  }

  static String playerName(
    String name, {
    String? scoreTag,
    String? yourPartyName,
  }) {
    return PartyNameFilter.publicLabel(
      name,
      scoreTag: scoreTag,
      fallbackParty: yourPartyName,
    );
  }

  /// Every loaded row, plus your rank at the bottom when it is missing.
  static List<PlayBoardRow> rows({
    required PlayBoardKind kind,
    required List<PlayBoardRaw> scores,
    PlayBoardRaw? you,
    String? yourPartyName,
  }) {
    final youId = you?.playerId;
    bool sameYou(PlayBoardRaw row) {
      if (you == null) return false;
      if (youId != null && youId.isNotEmpty && row.playerId == youId) {
        return true;
      }
      return row.rank == you.rank && row.rawScore == you.rawScore;
    }

    final built = <PlayBoardRow>[
      for (final row in scores)
        PlayBoardRow(
          rank: row.rank,
          name: playerName(
            row.name,
            scoreTag: row.scoreTag,
            yourPartyName: sameYou(row) ? yourPartyName : null,
          ),
          scoreLabel: scoreLabel(kind, row.rawScore),
          isYou: sameYou(row),
        ),
    ];
    if (you != null && you.rawScore > 0 && !built.any((row) => row.isYou)) {
      built.add(
        PlayBoardRow(
          rank: you.rank,
          name: playerName(
            you.name,
            scoreTag: you.scoreTag,
            yourPartyName: yourPartyName,
          ),
          scoreLabel: scoreLabel(kind, you.rawScore),
          isYou: true,
        ),
      );
    }
    return built;
  }
}

/// Sample ranks for a debug playtest. Never shown on a release build.
abstract final class PlayBoardPreview {
  static const String notice = 'Preview on this device. Not live players.';

  static List<PlayBoardRow> rows(PlayBoardKind kind) {
    final you = switch (kind) {
      PlayBoardKind.timedKey => PlayBoardRaw(
        rank: 4,
        name: 'You',
        rawScore: PlayGamesScores.encodeTimedKey(keyLevel: 12, clearMs: 125000),
        playerId: 'preview-you',
      ),
      PlayBoardKind.gauntlet => const PlayBoardRaw(
        rank: 18,
        name: 'You',
        rawScore: 22,
        playerId: 'preview-you',
      ),
      PlayBoardKind.greaterRift => PlayBoardRaw(
        rank: 6,
        name: 'You',
        rawScore: PlayGamesScores.encodeGreaterRift(tier: 8, clearMs: 90000),
        playerId: 'preview-you',
      ),
      PlayBoardKind.partyPower => const PlayBoardRaw(
        rank: 11,
        name: 'You',
        rawScore: 2100,
        playerId: 'preview-you',
      ),
    };
    final scores = switch (kind) {
      PlayBoardKind.timedKey => [
        PlayBoardRaw(
          rank: 1,
          name: 'Lantern',
          rawScore: PlayGamesScores.encodeTimedKey(
            keyLevel: 20,
            clearMs: 90000,
          ),
          playerId: 'preview-1',
        ),
        PlayBoardRaw(
          rank: 2,
          name: 'Moth',
          rawScore: PlayGamesScores.encodeTimedKey(
            keyLevel: 18,
            clearMs: 110000,
          ),
          playerId: 'preview-2',
        ),
        PlayBoardRaw(
          rank: 3,
          name: 'Brass',
          rawScore: PlayGamesScores.encodeTimedKey(
            keyLevel: 15,
            clearMs: 80000,
          ),
          playerId: 'preview-3',
        ),
        you,
      ],
      PlayBoardKind.gauntlet => const [
        PlayBoardRaw(rank: 1, name: 'Lantern', rawScore: 120, playerId: 'p1'),
        PlayBoardRaw(rank: 2, name: 'Moth', rawScore: 88, playerId: 'p2'),
        PlayBoardRaw(rank: 3, name: 'Brass', rawScore: 40, playerId: 'p3'),
      ],
      PlayBoardKind.greaterRift => [
        PlayBoardRaw(
          rank: 1,
          name: 'Lantern',
          rawScore: PlayGamesScores.encodeGreaterRift(tier: 20, clearMs: 70000),
          playerId: 'preview-1',
        ),
        PlayBoardRaw(
          rank: 2,
          name: 'Moth',
          rawScore: PlayGamesScores.encodeGreaterRift(tier: 14, clearMs: 80000),
          playerId: 'preview-2',
        ),
        PlayBoardRaw(
          rank: 3,
          name: 'Brass',
          rawScore: PlayGamesScores.encodeGreaterRift(tier: 11, clearMs: 60000),
          playerId: 'preview-3',
        ),
      ],
      PlayBoardKind.partyPower => const [
        PlayBoardRaw(rank: 1, name: 'Lantern', rawScore: 4800, playerId: 'p1'),
        PlayBoardRaw(rank: 2, name: 'Moth', rawScore: 3600, playerId: 'p2'),
        PlayBoardRaw(rank: 3, name: 'Brass', rawScore: 2900, playerId: 'p3'),
      ],
    };
    return PlayBoardList.rows(kind: kind, scores: scores, you: you);
  }
}
