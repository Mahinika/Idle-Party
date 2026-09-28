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

  /// Top rows, plus your rank at the bottom when it sits outside that list.
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
  static const String notice =
      'Preview on this device. Not live players.';

  static List<PlayBoardRow> rows(PlayBoardKind kind) {
    final you = switch (kind) {
      PlayBoardKind.timedKey => PlayBoardRaw(
          rank: 4,
          name: 'You',
          rawScore: PlayGamesScores.encodeTimedKey(
            keyLevel: 12,
            clearMs: 125000,
          ),
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
          rawScore: PlayGamesScores.encodeGreaterRift(
            tier: 8,
            clearMs: 90000,
          ),
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
          rawScore: PlayGamesScores.encodeGreaterRift(
            tier: 20,
            clearMs: 70000,
          ),
          playerId: 'preview-1',
        ),
        PlayBoardRaw(
          rank: 2,
          name: 'Moth',
          rawScore: PlayGamesScores.encodeGreaterRift(
            tier: 14,
            clearMs: 80000,
          ),
          playerId: 'preview-2',
        ),
        PlayBoardRaw(
          rank: 3,
          name: 'Brass',
          rawScore: PlayGamesScores.encodeGreaterRift(
            tier: 11,
            clearMs: 60000,
          ),
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
