import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/relics.dart';

void main() {
  test('old relic tier loads and discover stays in order', () {
    final seeded = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 1));
    final json = seeded.toJson();
    (json['metaDepth'] as Map<String, dynamic>)['relicTiers'] = {
      'war_banner': 3,
    };
    json['unlockedRelics'] = ['war_banner'];
    final loaded = GameLogic.stateFromJson(json);
    expect(loaded.relicTierOf('war_banner'), 3);
    expect(loaded.metaDepth.embers, 0);
    expect(loaded.metaDepth.cinders, 0);
    expect(loaded.relicBossDamageMul, closeTo(1.12, 0.001));

    final skipped = GameLogic.unlockRelic(loaded, 'hoard_jar');
    expect(skipped.hasRelic('hoard_jar'), isFalse);
  });

  test('salvage refunds half and the weekly trade caps at 3', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 2));
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(embers: 100, cinders: 20),
    );
    state = GameLogic.discoverNextRelic(state);
    final spent = RelicCatalog.discoverCost(0);
    expect(state.metaDepth.embers, 100 - spent);
    state = GameLogic.salvageRelic(state, GameLogic.warBannerRelic);
    expect(state.hasRelic(GameLogic.warBannerRelic), isFalse);
    expect(state.metaDepth.embers, 100 - spent + spent ~/ 2);
    expect(state.metaDepth.cinders, 18);

    final week = DateTime.utc(2026, 9, 7);
    for (var i = 0; i < 3; i++) {
      state = GameLogic.exchangeCinders(state, now: week);
    }
    final capped = GameLogic.exchangeCinders(state, now: week);
    expect(capped.metaDepth.embers, state.metaDepth.embers);
    expect(GameLogic.cinderExchangesUsed(capped, now: week), 3);
  });
}
