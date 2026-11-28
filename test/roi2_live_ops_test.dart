import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/local_season.dart';
import 'package:idle_party/core/play_leaderboard_ids.dart';

void main() {
  test('GameState defaults to home layout (R2-062)', () {
    expect(GameLogic.createInitialState().homeLayout, HomeLayout.home);
    expect(HomeLayout.fromJson(null), HomeLayout.home);
    expect(HomeLayout.fromJson('home'), HomeLayout.home);
    final json = GameLogic.createInitialState().toJson()..remove('homeLayout');
    expect(GameLogic.stateFromJson(json).homeLayout, HomeLayout.home);
  });

  group('PlayLeaderboardIds fallback (R2-005)', () {
    test('current and next calendar months resolve to live board ids', () {
      final now = DateTime.now().toUtc();
      final current =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final nextMonth = DateTime.utc(now.year, now.month + 1);
      final next =
          '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}';

      expect(PlayLeaderboardIds.hasBoards(current), isTrue);
      expect(PlayLeaderboardIds.hasBoards(next), isTrue);
      expect(PlayLeaderboardIds.isLiveBoardId(PlayLeaderboardIds.timedKeyId(current)), isTrue);
      expect(PlayLeaderboardIds.isLiveBoardId(PlayLeaderboardIds.timedKeyId(next)), isTrue);
    });

    test('fallback month notice is player-facing', () {
      final notice = PlayLeaderboardIds.reusedBoardNotice('2030-01');
      expect(notice, isNotNull);
      expect(notice!, isNot(contains('Console')));
    });
  });

  group('LocalSeason calendar (R2-050)', () {
    test('2027 ISO weeks rotate without year-close copy', () {
      for (var w = 1; w <= 52; w++) {
        final key = '2027-W${w.toString().padLeft(2, '0')}';
        final week = LocalSeasonCatalog.forWeekKey(key);
        expect(week.name, isNotEmpty);
        expect(week.blurb.toLowerCase(), isNot(contains('last week')));
        expect(week.id, isNot('year_close'));
      }
    });

    test('2027-01 month resolves from rotation pool', () {
      final month = LocalSeasonCatalog.forMonthKey('2027-01');
      expect(month.name, isNotEmpty);
      expect(month.hasPassGoal, isTrue);
    });

    test('pinned 2026-W53 stays year close finale', () {
      final week = LocalSeasonCatalog.forWeekKey('2026-W53');
      expect(week.id, 'year_close');
      expect(week.blurb, contains('Season finale'));
    });

    test('weekly contract still resolves for far-future keys', () {
      final now = DateTime.utc(2027, 6, 15);
      final key = GameLogic.isoWeekKey(now);
      final week = LocalSeasonCatalog.forWeekKey(key);
      expect(week.hasGoal, isTrue);
    });
  });
}