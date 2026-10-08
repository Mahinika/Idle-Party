import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/comeback_chest.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';

const _bat = Pet(
  id: 'cave_bat_1',
  name: 'Cave Bat',
  attackBonus: 3,
  speciesId: 'cave_bat',
);

const _batTwo = Pet(
  id: 'cave_bat_2',
  name: 'Cave Bat',
  attackBonus: 3,
  speciesId: 'cave_bat',
);

void main() {
  test('one pet goes out, a second wait, merge is blocked, claim pays once', () {
    final now = DateTime.utc(2026, 10, 1, 8);
    var state = GameLogic.createInitialState(now: now).copyWith(
      ownedPets: const [_bat, _batTwo],
      activePet: _bat,
    );
    final sent = GameLogic.sendPetErrand(state, _bat.id, 4, now: now);
    expect(sent.metaDepth.petErrandPetId, _bat.id);
    expect(sent.metaDepth.petErrandHours, 4);
    expect(sent.activePet, isNull);
    expect(
      sent.metaDepth.petErrandGold,
      GoldIncome.hubGoldPerMinute(state) * 15 * 4,
    );
    expect(sent.metaDepth.petErrandEssence, 15);
    expect(sent.metaDepth.petErrandEmbers, 0);
    expect(
      GameLogic.sendPetErrand(sent, _batTwo.id, 8, now: now).metaDepth.petErrandHours,
      4,
    );
    expect(GameLogic.canMergePets(sent, _bat.id, _batTwo.id), isFalse);
    expect(identical(GameLogic.claimPetErrand(sent, now: now), sent), isTrue);

    final later = now.add(const Duration(hours: 4));
    final claimed = GameLogic.claimPetErrand(sent, now: later);
    expect(claimed.metaDepth.petErrandPetId, isEmpty);
    expect(claimed.gold, sent.gold + sent.metaDepth.petErrandGold);
    expect(claimed.essence, sent.essence + 15);
    expect(
      GameLogic.claimPetErrand(claimed, now: later).gold,
      claimed.gold,
    );

    final long = GameLogic.sendPetErrand(state, _bat.id, 12, now: now);
    expect(long.metaDepth.petErrandEmbers, 2);
    expect(long.metaDepth.petErrandEssence, 80);
  });

  test('legacy save omits errand and comeback, Ascend keeps both', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{'weeklyProgress': 1});
    expect(md.petErrandPetId, isEmpty);
    expect(md.comebackTier, 0);

    final now = DateTime.utc(2026, 10, 1, 8);
    var state = GameLogic.createInitialState(now: now).copyWith(
      ownedPets: const [_bat],
      bossVictories: 1,
    );
    state = GameLogic.sendPetErrand(state, _bat.id, 8, now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(comebackTier: 7),
    );
    final risen = GameLogic.ascend(state, now: now);
    expect(risen.metaDepth.petErrandPetId, _bat.id);
    expect(risen.metaDepth.comebackTier, 7);
    expect(risen.ownedPets, isNotEmpty);
  });

  test('14 days is one chest, 2 days is none, claim pays once', () {
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 10, 1));
    expect(
      ComebackChest.noteAbsence(base, 2 * 86400).metaDepth.comebackTier,
      0,
    );
    final three = ComebackChest.noteAbsence(base, ComebackChest.day3Sec);
    expect(three.metaDepth.comebackTier, 3);
    expect(
      ComebackChest.noteAbsence(three, ComebackChest.day14Sec).metaDepth.comebackTier,
      3,
    );
    final fortnight = ComebackChest.noteAbsence(base, ComebackChest.day14Sec);
    expect(fortnight.metaDepth.comebackTier, 14);
    final paid = ComebackChest.claim(fortnight, sanctuaryCost: 0);
    expect(paid.metaDepth.comebackTier, 0);
    expect(paid.metaDepth.embers, 16);
    expect(paid.metaDepth.cinders, 4);
    expect(paid.gold, greaterThan(base.gold));
    expect(paid.essence, greaterThan(base.essence));
    expect(ComebackChest.claim(paid, sanctuaryCost: 0).gold, paid.gold);

    final away = OfflineProgress.applyOfflineProgress(
      base,
      const Duration(days: 14),
    );
    expect(away.state.metaDepth.comebackTier, 14);
    final short = OfflineProgress.applyOfflineProgress(
      base,
      const Duration(hours: 30),
    );
    expect(short.state.metaDepth.comebackTier, 0);
  });

  test('welcome lead names floors, rares, and gold', () {
    final lead = OfflineProgressResult(
      state: GameLogic.createInitialState(),
      secondsApplied: 3600,
      goldGained: 1200,
      essenceGained: 0,
      roomsCleared: 6,
      highestFloorDelta: 0,
      bossDelta: 0,
      rareFinds: 2,
    ).lootLead;
    expect(lead, '6 floors cleared · 2 rare in the bag · 1,200 gold');
  });

  testWidgets('CLAIM pays a waiting chest', (tester) async {
    final base = GameLogic.createInitialState();
    final state = base.copyWith(
      metaDepth: base.metaDepth.copyWith(comebackTier: 14),
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: state,
        secondsApplied: 3600,
        goldGained: 40,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Away 14 days'), findsOneWidget);
    expect(find.text('CLAIM'), findsOneWidget);
    await tester.tap(find.text('CLAIM'));
    await tester.pumpAndSettle();
    expect(director.state.metaDepth.comebackTier, 0);
    expect(director.state.gold, greaterThan(state.gold));
    expect(director.state.metaDepth.cinders, 4);
  });
}
