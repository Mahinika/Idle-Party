import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  group('PlayGamesScores', () {
    test('encode prefers higher KEY over faster lower KEY', () {
      final lowFast = PlayGamesScores.encodeTimedKey(keyLevel: 5, clearMs: 1000);
      final highSlow =
          PlayGamesScores.encodeTimedKey(keyLevel: 6, clearMs: 900000);
      expect(highSlow, greaterThan(lowFast));
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
}
