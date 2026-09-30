import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/party_name_filter.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/play_leaderboard_ids.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  group('PlayGamesScores', () {
    test('encode prefers higher KEY over faster lower KEY', () {
      final lowFast = PlayGamesScores.encodeTimedKey(keyLevel: 5, clearMs: 1000);
      final highSlow =
          PlayGamesScores.encodeTimedKey(keyLevel: 6, clearMs: 900000);
      expect(highSlow, greaterThan(lowFast));
    });

    test('encode ranks KEY 50 above KEY 20', () {
      final cap = PlayGamesScores.encodeTimedKey(keyLevel: 20, clearMs: 1000);
      final push = PlayGamesScores.encodeTimedKey(keyLevel: 50, clearMs: 900000);
      expect(push, greaterThan(cap));
      expect(PlayGamesScores.decodeTimedKey(push).keyLevel, 50);
    });

    test('same KEY prefers faster clear', () {
      final slow = PlayGamesScores.encodeTimedKey(keyLevel: 8, clearMs: 120000);
      final fast = PlayGamesScores.encodeTimedKey(keyLevel: 8, clearMs: 60000);
      expect(fast, greaterThan(slow));
      final decoded = PlayGamesScores.decodeTimedKey(fast);
      expect(decoded.keyLevel, 8);
      expect(decoded.clearMs, 60000);
    });

    test('isBetterTimed matches encode order', () {
      expect(
        PlayGamesScores.isBetterTimed(
          newKey: 4,
          newClearMs: 90000,
          bestKey: 3,
          bestClearMs: 10000,
        ),
        isTrue,
      );
      expect(
        PlayGamesScores.isBetterTimed(
          newKey: 4,
          newClearMs: 90000,
          bestKey: 4,
          bestClearMs: 80000,
        ),
        isFalse,
      );
      expect(
        PlayGamesScores.isBetterTimed(
          newKey: 4,
          newClearMs: 70000,
          bestKey: 4,
          bestClearMs: 80000,
        ),
        isTrue,
      );
    });

    test('formatTimedLabel uses KEY + timer', () {
      expect(
        PlayGamesScores.formatTimedLabel(7, 125000),
        contains('KEY +7'),
      );
    });

    test('in-game board labels decode KEY, floor, and GR', () {
      final key = PlayGamesScores.encodeTimedKey(keyLevel: 12, clearMs: 65000);
      expect(
        PlayBoardList.scoreLabel(PlayBoardKind.timedKey, key),
        'KEY +12 · 01:05',
      );
      expect(PlayBoardList.scoreLabel(PlayBoardKind.gauntlet, 40), 'F40');
      final gr = PlayGamesScores.encodeGreaterRift(tier: 8, clearMs: 90000);
      expect(
        PlayBoardList.scoreLabel(PlayBoardKind.greaterRift, gr),
        'GR8 · 01:30',
      );
    });

    test('board keeps your rank when it is outside the top list', () {
      final top = PlayBoardList.rows(
        kind: PlayBoardKind.gauntlet,
        scores: const [
          PlayBoardRaw(rank: 1, name: 'Ada', rawScore: 80, playerId: 'a'),
          PlayBoardRaw(rank: 2, name: '  ', rawScore: 70, playerId: 'b'),
        ],
        you: const PlayBoardRaw(
          rank: 40,
          name: 'Robin',
          rawScore: 12,
          playerId: 'you',
        ),
      );
      expect(top, hasLength(3));
      expect(top[1].name, 'Player');
      expect(top[1].isYou, isFalse);
      expect(top.last.isYou, isTrue);
      expect(top.last.rank, 40);
      expect(top.last.scoreLabel, 'F12');
    });

    test('rank row prefers the party name stored on the score', () {
      final tag = PartyNameFilter.scoreTag('Ember Guard');
      final rows = PlayBoardList.rows(
        kind: PlayBoardKind.gauntlet,
        scores: [
          PlayBoardRaw(
            rank: 1,
            name: 'Google One',
            rawScore: 40,
            playerId: 'a',
            scoreTag: tag,
          ),
          const PlayBoardRaw(
            rank: 2,
            name: 'MAGA',
            rawScore: 10,
            playerId: 'b',
          ),
        ],
        you: PlayBoardRaw(
          rank: 2,
          name: 'MAGA',
          rawScore: 10,
          playerId: 'b',
        ),
        yourPartyName: 'Cave Company',
      );
      expect(rows[0].name, 'Ember Guard');
      expect(rows[1].name, 'Cave Company');
      expect(rows[1].isYou, isTrue);
    });

    test('debug preview lists differ and mark you', () {
      final key = PlayBoardPreview.rows(PlayBoardKind.timedKey);
      final gauntlet = PlayBoardPreview.rows(PlayBoardKind.gauntlet);
      final gr = PlayBoardPreview.rows(PlayBoardKind.greaterRift);
      expect(key.first.scoreLabel, 'KEY +20 · 01:30');
      expect(key[3].isYou, isTrue);
      expect(key[3].scoreLabel, 'KEY +12 · 02:05');
      expect(gauntlet.first.scoreLabel, 'F120');
      expect(gauntlet.last.isYou, isTrue);
      expect(gauntlet.last.rank, 18);
      expect(gr.first.scoreLabel, contains('GR20'));
      expect(gr.last.isYou, isTrue);
      expect(gr.last.rank, 6);
      final party = PlayBoardPreview.rows(PlayBoardKind.partyPower);
      expect(party.first.scoreLabel, '4800');
      expect(party.last.isYou, isTrue);
      expect(party.last.rank, 11);
      expect(party.last.scoreLabel, '2100');
    });

    test('board marks you inside the top list without a second row', () {
      final rows = PlayBoardList.rows(
        kind: PlayBoardKind.gauntlet,
        scores: const [
          PlayBoardRaw(rank: 1, name: 'Ada', rawScore: 80, playerId: 'a'),
          PlayBoardRaw(rank: 2, name: 'Robin', rawScore: 12, playerId: 'you'),
        ],
        you: const PlayBoardRaw(
          rank: 2,
          name: 'Robin',
          rawScore: 12,
          playerId: 'you',
        ),
      );
      expect(rows, hasLength(2));
      expect(rows[1].isYou, isTrue);
    });

    test('Greater Rift encode prefers higher tier', () {
      final low = PlayGamesScores.encodeGreaterRift(tier: 3, clearMs: 1000);
      final high = PlayGamesScores.encodeGreaterRift(tier: 4, clearMs: 500000);
      expect(high, greaterThan(low));
      expect(
        PlayGamesScores.formatGreaterRiftLabel(4, 60000),
        contains('GR4'),
      );
    });
  });

  group('cloud conflict', () {
    test('newer local wins beyond skew', () {
      expect(
        PlayGamesScores.resolveConflict(localMs: 200000, cloudMs: 100000),
        CloudConflict.preferLocal,
      );
    });

    test('newer cloud wins beyond skew', () {
      expect(
        PlayGamesScores.resolveConflict(localMs: 100000, cloudMs: 200000),
        CloudConflict.preferCloud,
      );
    });

    test('close stamps ask user', () {
      expect(
        PlayGamesScores.resolveConflict(localMs: 100000, cloudMs: 100030),
        CloudConflict.askUser,
      );
    });

    test('empty local prefers cloud', () {
      expect(
        PlayGamesScores.resolveConflict(localMs: 0, cloudMs: 50),
        CloudConflict.preferCloud,
      );
    });
  });

  group('leaderboard season', () {
    test('month rollover clears season PBs', () {
      final state = GameLogic.createInitialState().copyWith(
        metaDepth: const MetaDepthState(
          leaderboardSeasonKey: '2026-07',
          seasonBestTimedKey: 5,
          seasonBestTimedClearMs: 90000,
          seasonBestGauntletFloor: 12,
        ),
      );
      final next = GameLogic.ensureLeaderboardSeason(
        state,
        now: DateTime.utc(2026, 8, 16),
      );
      expect(next.metaDepth.leaderboardSeasonKey, '2026-08');
      expect(next.metaDepth.seasonBestTimedKey, 0);
      expect(next.metaDepth.seasonBestTimedClearMs, 0);
      expect(next.metaDepth.seasonBestGauntletFloor, 0);
    });

    test('2026-08 Play Console board IDs are wired', () {
      expect(PlayLeaderboardIds.hasBoards('2026-08'), isTrue);
      expect(PlayLeaderboardIds.timedKeyId('2026-08'), isNot(contains('XXXX')));
      expect(PlayLeaderboardIds.gauntletId('2026-08'), isNot(contains('YYYY')));
    });

    test('2026-09 reuses Aug KEY/Gauntlet; GR board is wired', () {
      expect(PlayLeaderboardIds.hasBoards('2026-09'), isTrue);
      expect(
        PlayLeaderboardIds.timedKeyId('2026-09'),
        PlayLeaderboardIds.timedKeyId('2026-08'),
      );
      expect(
        PlayLeaderboardIds.gauntletId('2026-09'),
        PlayLeaderboardIds.gauntletId('2026-08'),
      );
      expect(PlayLeaderboardIds.hasGreaterRiftBoard('2026-09'), isTrue);
      expect(
        PlayLeaderboardIds.greaterRiftId('2026-09'),
        'CgkIhuXGvNocEAIQAw',
      );
      expect(PlayLeaderboardIds.hasGreaterRiftBoard('2026-08'), isFalse);
    });

    test('party power board is an all-time Play id', () {
      expect(PlayLeaderboardIds.hasPartyPowerBoard, isTrue);
      expect(PlayLeaderboardIds.partyPowerId, 'CgkIhuXGvNocEAIQBA');
      expect(PlayLeaderboardIds.isLiveBoardId(PlayLeaderboardIds.partyPowerId), isTrue);
    });

    test('boardsAvailable needs Play support + live IDs', () {
      expect(
        PlayLeaderboardIds.boardsAvailable(
          '2026-09',
          playGamesSupported: true,
        ),
        isTrue,
      );
      expect(
        PlayLeaderboardIds.boardsAvailable(
          '2026-09',
          playGamesSupported: false,
        ),
        isFalse,
      );
      expect(
        PlayLeaderboardIds.boardsAvailable(
          '2099-01',
          playGamesSupported: true,
        ),
        isFalse,
      );
      expect(PlayLeaderboardIds.isLiveBoardId(''), isFalse);
      expect(PlayLeaderboardIds.isLiveBoardId('CgkIXXXX'), isFalse);
      expect(PlayLeaderboardIds.isLiveBoardId('CgkIhuXGvNocEAIQAA'), isTrue);
      expect(
        PlayLeaderboardIds.boardsNeedPlayMessage,
        'Boards need a Play install + sign-in',
      );
    });

    test('a month without Console ids does not pretend Play is missing', () {
      expect(PlayLeaderboardIds.hasBoards('2026-10'), isFalse);
      expect(
        PlayLeaderboardIds.unavailableMessage(
          playGamesSupported: true,
          monthKey: '2026-10',
        ),
        PlayLeaderboardIds.monthBoardsPendingMessage,
      );
      expect(
        PlayLeaderboardIds.unavailableMessage(
          playGamesSupported: false,
          monthKey: '2026-10',
        ),
        PlayLeaderboardIds.boardsNeedPlayMessage,
      );
      expect(
        PlayLeaderboardIds.unavailableMessage(
          playGamesSupported: true,
          monthKey: '2026-09',
        ),
        PlayLeaderboardIds.boardsNeedPlayMessage,
      );
    });

    test('legacy save defaults Play Games fields', () {
      final md = MetaDepthState.fromJson(<String, dynamic>{
        'gauntletBestFloor': 3,
      });
      expect(md.leaderboardSeasonKey, '');
      expect(md.seasonBestTimedKey, 0);
      expect(md.cloudSaveUpdatedMs, 0);
      expect(md.playGamesOptIn, isFalse);
    });
  });

  test('cloud snapshot round-trips and a failed sign-in keeps local gold', () async {
    final local = GameLogic.createInitialState().copyWith(
      gold: 4321,
      partyName: 'Keepers',
      essence: 17,
    );
    final raw = GameLogic.exportSaveJson(local);
    final loaded = GameLogic.importSaveJson(raw);
    expect(loaded, isNotNull);
    expect(loaded!.gold, 4321);
    expect(loaded.partyName, 'Keepers');
    expect(loaded.essence, 17);

    final director = GameDirector.preview(initialState: local);
    addTearDown(director.dispose);
    expect(await director.signInPlayGames(), isFalse);
    expect(await director.restoreFromPlayGames(), isFalse);
    expect(await director.backupToPlayGames(), isFalse);
    expect(director.state.gold, 4321);
    expect(director.state.partyName, 'Keepers');
    expect(director.state.essence, 17);
    expect(director.state.metaDepth.playGamesOptIn, isFalse);
  });
}
