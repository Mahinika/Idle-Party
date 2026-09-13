import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/hub/hub_header.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10);

  test('AL-cap pill teases hunt — never MAX', () {
    final label = HubHeader.alCapPillLabel(
      ascensionLevel: GameLogic.maxAscensionLevel,
      huntHint: 'to Lv${GameLogic.maxHeroLevel}',
      blessingStacks: 3,
    );
    expect(label, 'AL ${GameLogic.maxAscensionLevel} · to Lv${GameLogic.maxHeroLevel} · Asc B×3');
    expect(label.contains('MAX'), isFalse);
  });

  test('AL-cap pill fallback is next hunt not endgame MAX', () {
    final label = HubHeader.alCapPillLabel(
      ascensionLevel: GameLogic.maxAscensionLevel,
    );
    expect(label, 'AL ${GameLogic.maxAscensionLevel} · next hunt');
    expect(label.contains('MAX'), isFalse);
  });

  test('AL20 sub-max chase detail skips done wording', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      bossVictories: 99,
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      metaDepth: base.metaDepth.copyWith(dailyVaultClaimed: true),
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: 88, xp: 0),
      ],
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.detail.toUpperCase(), contains('KEY'));
    expect(chase.detail, isNot(contains('AL20')));
    expect(chase.detail.toLowerCase().contains('done'), isFalse);
    expect(chase.title, contains('${GameLogic.maxHeroLevel}'));
  });
}
