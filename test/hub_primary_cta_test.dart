import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_dispatcher.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/hub_endgame_act.dart';
import 'package:idle_party/core/hub_primary_cta.dart';
import 'package:idle_party/ui/hub/hub_today_card.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22);

  test('endgame hunt owns primary — not ENTER DUNGEON', () {
    const chase = HubChase(
      kind: HubChaseKind.gauntletMilestone,
      title: 'Climb Infinity Gauntlet',
      detail: 'Boss every 5 floors.',
      urgency: HubChaseUrgency.normal,
    );
    final plan = ChaseDispatcher.plan(
      chase,
      state: GameLogic.createInitialState(now: now),
    );
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: plan.label,
      hasChaseAction: true,
      unlockedSelected: true,
      hardmodeLevel: 10,
      showKeystoneJargon: true,
      endgameUnlocked: true,
    );
    expect(cta.primaryLabel, 'GAUNTLET');
    expect(cta.secondaryLabel, 'ENTER DUNGEON');
    expect(cta.hideInlineChaseAction, isTrue);
    expect(cta.showKeyDial, isFalse);
  });

  test('map Farm Rift pick owns primary even when TODAY is KEY', () {
    const chase = HubChase(
      kind: HubChaseKind.keystone,
      title: 'Run KEY +12',
      detail: 'Affixes · par',
      keyLevel: 12,
      urgency: HubChaseUrgency.normal,
    );
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: 'ENTER KEY +12',
      hasChaseAction: true,
      unlockedSelected: true,
      hardmodeLevel: 12,
      showKeystoneJargon: true,
      endgameUnlocked: true,
      mapHunt: HubEndgameHunt.farmRift,
    );
    expect(cta.primaryLabel, 'FARM RIFT');
    expect(cta.secondaryLabel, isNull);
    expect(cta.showKeyDial, isFalse);
  });

  test('READY vault still owns primary when a map hunt is selected', () {
    const chase = HubChase(
      kind: HubChaseKind.claimDailyVault,
      title: 'Claim Daily Vault',
      detail: 'Claim +e.',
      urgency: HubChaseUrgency.ready,
    );
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: 'CLAIM VAULT',
      hasChaseAction: true,
      unlockedSelected: true,
      hardmodeLevel: 10,
      showKeystoneJargon: true,
      endgameUnlocked: true,
      mapHunt: HubEndgameHunt.rankedGr,
    );
    expect(cta.primaryLabel, 'CLAIM VAULT');
    expect(cta.secondaryLabel, 'RANKED GR');
    expect(cta.showKeyDial, isFalse);
  });

  test('week goal GAUNTLET owns primary (not buried as chip)', () {
    const chase = HubChase(
      kind: HubChaseKind.weekGoal,
      title: 'Week · Gauntlet',
      detail: 'Push Spire for the week goal.',
      urgency: HubChaseUrgency.almost,
    );
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: 'GAUNTLET',
      hasChaseAction: true,
      unlockedSelected: true,
      hardmodeLevel: 5,
      showKeystoneJargon: true,
      endgameUnlocked: true,
    );
    expect(cta.primaryLabel, 'GAUNTLET');
    expect(cta.secondaryLabel, 'ENTER DUNGEON');
  });

  test('KEY chase folds into ENTER KEY primary', () {
    const chase = HubChase(
      kind: HubChaseKind.keystone,
      title: 'Run KEY +12',
      detail: 'Affixes · par',
      keyLevel: 12,
      urgency: HubChaseUrgency.normal,
    );
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: 'ENTER KEY +12',
      hasChaseAction: true,
      unlockedSelected: true,
      hardmodeLevel: 12,
      showKeystoneJargon: true,
      endgameUnlocked: true,
    );
    expect(cta.primaryLabel, 'ENTER KEY +12');
    expect(cta.secondaryLabel, isNull);
    expect(cta.showKeyDial, isTrue);
  });

  test('claim READY owns primary with ENTER secondary', () {
    const chase = HubChase(
      kind: HubChaseKind.claimDailyVault,
      title: 'Claim Daily Vault',
      detail: 'Claim +e.',
      urgency: HubChaseUrgency.ready,
    );
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: 'CLAIM VAULT',
      hasChaseAction: true,
      unlockedSelected: true,
      hardmodeLevel: 0,
      showKeystoneJargon: false,
      endgameUnlocked: false,
    );
    expect(cta.primaryLabel, 'CLAIM VAULT');
    expect(cta.secondaryLabel, 'ENTER DUNGEON');
  });

  testWidgets('READY claim card has chip without ready progress echo', (
    tester,
  ) async {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      ascensionLevel: 20,
      highestDungeonCleared: 14,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.progressLabel, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HubTodayCard(chase: chase),
        ),
      ),
    );

    expect(find.text('READY'), findsOneWidget);
    expect(find.textContaining('ready'), findsNothing);
    expect(find.text('Claim Daily Vault'), findsOneWidget);
  });

  testWidgets('large text scale keeps TODAY title visible', (tester) async {
    const chase = HubChase(
      kind: HubChaseKind.clearFloors,
      title: 'Grow the party in Sandy Caverns',
      detail: 'Clear floors for XP.',
      urgency: HubChaseUrgency.normal,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.55)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: HubTodayCard(chase: chase),
            ),
          ),
        ),
      ),
    );
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.textContaining('Grow the party'), findsOneWidget);
  });

  testWidgets('first-hour MetaPulse has zero height', (tester) async {
    final state = GameLogic.createInitialState(now: now);
    expect(GameLogic.showDailyChase(state), isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HubMetaPulse(
            state: state,
            chaseKind: HubChaseKind.clearFloors,
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(HubMetaPulse));
    expect(size.height, 0);
  });
}
