import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  test('advancing ticks progresses battle and gold', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.advance(initial, steps: 4);

    expect(progressed.gold, greaterThan(initial.gold));
    expect(progressed.battleNumber, greaterThan(initial.battleNumber));
    expect(
      progressed.enemy.currentHp,
      inInclusiveRange(0, progressed.enemy.maxHp),
    );
  });

  test('offline progress is tracked and applied', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.applyOfflineProgress(
      initial,
      const Duration(seconds: 30),
    );

    expect(progressed.offlineSecondsRecovered, 30);
    expect(progressed.gold, greaterThanOrEqualTo(initial.gold));
  });

  test('training spends gold and levels up the party', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.partyTrainingCostFor(seeded),
    );

    final trained = GameLogic.trainParty(initial);

    expect(trained.gold, 0);
    expect(trained.heroes.first.level, initial.heroes.first.level + 1);
    expect(trained.heroes.first.currentHp, trained.heroes.first.maxHp);
  });

  test('loot rolls after battle victories', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.advance(initial, steps: 200);

    expect(progressed.recentLoot, isNotEmpty);
    expect(progressed.recentLoot.first.amount, greaterThan(0));
    expect(progressed.essence, greaterThan(0));
  });

  test('upgrade paths spend gold and change bonuses', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack),
    );

    final attackUpgraded = GameLogic.upgradeAttack(initial);
    final defenseUpgraded = GameLogic.upgradeDefense(initial);
    final vitalityUpgraded = GameLogic.upgradeVitality(initial);

    expect(attackUpgraded.attackBonus, 2);
    expect(defenseUpgraded.defenseBonus, 1);
    expect(vitalityUpgraded.vitalityBonus, 6);
    expect(attackUpgraded.gold, 0);
  });

  test('boss battles appear and increase boss victory count', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          battleNumber: 10,
          enemy: GameLogic.createEnemy(10).copyWith(currentHp: 1),
        );

    final progressed = GameLogic.advance(initial);

    expect(progressed.bossVictories, greaterThan(0));
    expect(GameLogic.isBossBattle(10), isTrue);
    expect(GameLogic.createEnemy(10).name, 'Gate Warden');
  });

  test('enemy scaling stays smooth across elite and boss thresholds', () {
    final wave9 = GameLogic.createEnemy(9);
    final wave10 = GameLogic.createEnemy(10);
    final wave11 = GameLogic.createEnemy(11);

    expect(wave10.maxHp, greaterThan(wave9.maxHp));
    expect(wave10.maxHp, lessThan(220));
    expect(wave11.maxHp, lessThan(wave10.maxHp));
  });

  test('essence can unlock relic bonuses', () {
    final initial = GameLogic.createInitialState(
      now: DateTime(2026, 7, 4),
    ).copyWith(essence: GameLogic.relicCosts[GameLogic.warBannerRelic]);

    final unlocked = GameLogic.unlockRelic(initial, GameLogic.warBannerRelic);

    expect(unlocked.hasRelic(GameLogic.warBannerRelic), isTrue);
    expect(unlocked.essence, 0);
    expect(unlocked.totalAttackBonus, 4);
  });
}
