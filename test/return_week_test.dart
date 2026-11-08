import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/return_week.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/hub/hub_today_card.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  GameState week(
    int day, {
    bool claimed = false,
    int gold = 0,
    int tickets = 0,
  }) {
    return GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      gold: gold,
      metaDepth: MetaDepthState(
        dailyVaultDate: MetaSystems.dailyDateKey(now),
        dailyVaultClaimed: claimed,
        checkInDay: day,
        adTickets: tickets,
      ),
    );
  }

  test('days 1–7 name a different spend shelf on the same cave', () {
    const shelves = [
      'CAMP',
      'FORGE',
      'EMBERS',
      'CINDERS',
      'SCROLLS',
      'CAMP+FORGE',
      'JACKPOT',
    ];
    final titles = <String>{};
    for (var day = 1; day <= 7; day++) {
      final state = week(day);
      expect(ReturnWeek.active(state), isTrue);
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.dailyVaultProgress);
      expect(chase.title, 'Sandy Caverns · ${shelves[day - 1]}');
      expect(chase.title.length, lessThanOrEqualTo(30));
      expect(chase.zoneId, 'sandy');
      expect(chase.detail, contains('Check-in $day/7'));
      expect(chase.detail, contains('Sandy Caverns'));
      expect(chase.detail, contains(ReturnWeek.keepsFighting));
      expect(chase.detail.toUpperCase(), isNot(contains('KEY')));
      expect(chase.detail.toUpperCase(), isNot(contains('DAILY RUN')));
      titles.add(chase.title);
      final contract = ChaseContract.fromState(state, now: now);
      expect(contract.upNextLine, 'Up next: ${chase.title}');
      expect(contract.whyLine, contains('spend'));
    }
    expect(titles, hasLength(7));
  });

  test('a claimed vault names tomorrow\'s cave, not another floor grind', () {
    final state = week(2, claimed: true);
    final chase = HubChase.forState(state, now: now);
    expect(chase.title, 'Tomorrow: Sandy Caverns');
    expect(chase.detail, contains('Check-in 2/7'));
    expect(chase.detail, contains('FORGE'));
    expect(chase.detail, contains(ReturnWeek.keepsFighting));
    expect(chase.kind, isNot(HubChaseKind.clearFloors));
    expect(
      GameLogic.checkInWelcomeLine(state),
      contains('Tomorrow: Sandy Caverns · Check-in 2/7'),
    );
    expect(ReturnWeek.coachLine(state), 'Tomorrow: Sandy Caverns');
  });

  test('the next UTC day keeps the advanced check-in shelf', () {
    final later = DateTime.utc(2026, 11, 8, 12);
    var state = GameLogic.claimDailyVault(
      week(1).copyWith(
        metaDepth: week(1).metaDepth.copyWith(
          dailyVaultClears: GameLogic.dailyVaultClearTarget,
        ),
      ),
      now: now,
    );
    expect(state.metaDepth.checkInDay, 2);
    expect(state.metaDepth.dailyVaultClaimed, isTrue);
    state = GameLogic.ensureDailyVault(state, now: later);
    expect(state.metaDepth.dailyVaultClaimed, isFalse);
    expect(state.metaDepth.checkInDay, 2);
    final chase = HubChase.forState(state, now: later);
    expect(chase.title, 'Sandy Caverns · FORGE');
    expect(chase.detail, contains('Spend the gold in FORGE'));
  });

  test('gold, essence, and tickets name the shelf that can be spent now', () {
    final broke = week(2);
    expect(ReturnWeek.readySpend(broke), isNull);
    final rich = week(5, gold: 50000, tickets: 3).copyWith(essence: 100);
    final ready = ReturnWeek.readySpend(rich);
    expect(ready, contains('FORGE'));
    expect(ready, contains('CAMP'));
    expect(ready, contains('SCROLLS'));
    expect(HubChase.forState(rich, now: now).detail, contains(ready!));
  });

  test('a missing check-in day still starts on CAMP and survives Ascend', () {
    final legacy = GameLogic.stateFromJson(
      {...GameLogic.createInitialState(now: now).toJson(), 'bossVictories': 1}
        ..remove('metaDepth'),
    );
    expect(legacy.metaDepth.checkInDay, 1);
    expect(ReturnWeek.todayTitle(legacy), 'Sandy Caverns · CAMP');
    final ascended = GameLogic.ascend(week(4).copyWith(essence: 40), now: now);
    expect(ascended.ascensionLevel, 1);
    expect(ascended.metaDepth.checkInDay, 4);
    expect(ReturnWeek.active(ascended), isFalse);
    expect(
      HubChase.forState(ascended, now: now).title,
      isNot(contains('CINDERS')),
    );
  });

  test('every cave name still fits the hunt button', () {
    for (final dungeon in DungeonCatalog.all) {
      final title = '${dungeon.name} · CAMP+FORGE';
      expect(title.length, lessThanOrEqualTo(30), reason: dungeon.name);
      final tomorrow = 'Tomorrow: ${dungeon.name}';
      expect(tomorrow.length, lessThanOrEqualTo(30), reason: dungeon.name);
    }
  });

  testWidgets('TODAY card shows the day-5 SCROLLS job', (tester) async {
    final chase = HubChase.forState(week(5), now: now);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HubTodayCard(chase: chase)),
      ),
    );
    expect(find.textContaining('Sandy Caverns · SCROLLS'), findsOneWidget);
    expect(find.textContaining('Spend the tickets on SCROLLS'), findsOneWidget);
    expect(find.textContaining('keeps fighting while closed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camp names tomorrow\'s cave after the vault is claimed', (
    tester,
  ) async {
    final state = week(3, claimed: true).copyWith(homeLayout: HomeLayout.home);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: director,
          builder: (context, _) =>
              HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Tomorrow: Sandy Caverns'), findsWidgets);
    expect(find.textContaining('keeps fighting while closed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('raw scale 2 on a short home does not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = week(6, claimed: true, gold: 50000, tickets: 2).copyWith(
      essence: 100,
      homeLayout: HomeLayout.home,
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Tomorrow: Sandy Caverns'), findsWidgets);
  });
}
