import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('ChaseContract matches HubChase selection', () {
    final state = GameLogic.createInitialState(now: now);
    final hub = HubChase.forState(state, now: now);
    final contract = ChaseContract.fromState(state, now: now);
    expect(contract.kind, hub.kind);
    expect(contract.title, hub.title);
    expect(contract.urgency, hub.urgency);
    expect(contract.ascendTeaser, isNull);
  });

  test('claimable vault is READY and beats grind', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
        weeklyModifier: 'fortune',
      ),
    );
    final contract = ChaseContract.fromState(state, now: now);
    expect(contract.kind, HubChaseKind.claimDailyVault);
    expect(contract.isReady, isTrue);
    expect(contract.isClaimable, isTrue);
    expect(contract.upNextLine, startsWith('Up next — ready:'));
    expect(contract.readyActionLabel, 'CLAIM VAULT');
  });

  test('almost Ascend surfaces ALMOST Up next', () {
    // AL1 needs 2 bosses — bank 1 so one remains (same as hub_chase_test).
    var state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
      bossVictories: 1,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            dailyVaultClaimed: true,
          ),
    );
    expect(GameLogic.bossesRequiredForAscension(1), 2);
    final contract = ChaseContract.fromState(state, now: now);
    expect(contract.kind, HubChaseKind.clearFloors);
    expect(contract.isAlmost, isTrue);
    expect(contract.upNextLine, startsWith('Up next — almost:'));
    expect(contract.ascendTeaser, isNotNull);
  });

  test('offline Up next title equals hub TODAY title', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    final hub = ChaseContract.fromState(state, now: now);
    // Simulate offline dialog reading the same post-AFK state.
    final offline = ChaseContract.fromState(state, now: now);
    expect(offline.title, hub.title);
    expect(offline.upNextLine, hub.upNextLine);
    expect(offline.kind, hub.kind);
  });

  test('after first Ascend, Daily is Up next (KEY waits for AL20)', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
    );
    final contract = ChaseContract.fromState(state, now: now);
    expect(contract.kind, HubChaseKind.dailyRun);
    expect(contract.kind, isNot(HubChaseKind.keystone));
    expect(contract.upNextLine, startsWith('Up next:'));
  });
}
