import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/session_telemetry.dart';
import 'package:idle_party/ui/hub/hub_today_card.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22);

  testWidgets('HubTodayCard shows READY chip for claim chase', (tester) async {
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
    final chase = ChaseContract.fromState(state).chase;
    expect(chase.urgency, HubChaseUrgency.ready);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HubTodayCard(
            chase: chase,
            actionLabel: 'CLAIM VAULT',
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.text('READY'), findsOneWidget);
    expect(find.text('CLAIM VAULT'), findsOneWidget);
  });

  testWidgets('HubMetaPulse hides crumbs when chase is READY', (tester) async {
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
    final chase = ChaseContract.fromState(state).chase;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HubMetaPulse(
            state: state,
            chaseKind: chase.kind,
            chaseUrgency: chase.urgency,
          ),
        ),
      ),
    );

    expect(find.textContaining('Vault'), findsNothing);
    expect(find.textContaining('KEY'), findsNothing);
  });

  test('session telemetry stays local until opt-in', () {
    var state = GameLogic.createInitialState(now: now);
    state = SessionTelemetry.append(state, 'wipe', 'test');
    expect(state.sessionTelemetryLog, isEmpty);

    state = SessionTelemetry.setOptIn(state, true);
    state = SessionTelemetry.append(state, 'hub_chase', 'keystone|ready');
    expect(state.sessionTelemetryLog.length, 2);
    expect(SessionTelemetry.exportText(state), contains('hub_chase'));
  });

  test('offline Up next uses same chase title as hub', () {
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
    final hub = HubChase.forState(state, now: now);
    final contract = ChaseContract.fromState(state, now: now);
    expect(contract.title, hub.title);
    expect(contract.upNextLine.toLowerCase(), contains('up next'));
  });
}
