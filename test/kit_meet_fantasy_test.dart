import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ascend_roadmap.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hero_identity.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/models/hero_spec.dart';

void main() {
  test('every Ascend ladder kit has meetBlurb and meetHook', () {
    final ids = <HeroSpecId>{
      for (final entry in AscendRoadmap.kitUnlocksByAl.entries)
        for (final kit in entry.value) kit.$1,
    };
    expect(ids, isNotEmpty);
    for (final id in ids) {
      expect(HeroIdentity.meetBlurb(id), isNotEmpty, reason: id.name);
      expect(HeroIdentity.meetHook(id), isNotEmpty, reason: id.name);
      expect(HeroIdentity.meetHook(id), startsWith('Watch'), reason: id.name);
      expect(HeroIdentity.meetDetail(id), contains(HeroIdentity.meetBlurb(id)));
    }
  });

  test('Meet chase detail includes fantasy hook', () {
    final now = DateTime.utc(2026, 8, 8, 12);
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        pendingHeroReveals: <String>[HeroSpecId.combat.name],
        dailyVaultClaimed: true,
      ),
      lastDailyDate: '2026-08-08',
      dailyClaimed: true,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.meetHero);
    expect(chase.detail, contains(HeroIdentity.meetBlurb(HeroSpecId.combat)));
    expect(chase.detail, contains(HeroIdentity.meetHook(HeroSpecId.combat)));
    expect(chase.detail, contains('GEAR'));
    expect(chase.detail, contains('ROSTER'));
  });

  test('nextMissingKitTeaser includes a Watch hook', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 8));
    final teaser = AscendRoadmap.nextMissingKitTeaser(state);
    expect(teaser, isNotNull);
    expect(teaser!, contains('AL'));
    expect(teaser, contains('Watch'));
  });

  test('AL ladder kits unlock at that AL with no zone clears', () {
    for (final entry in AscendRoadmap.kitUnlocksByAl.entries) {
      final al = entry.key;
      var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 13));
      state = state.copyWith(
        ascensionLevel: al,
        highestDungeonCleared: -1,
        essence: 0,
        rogueUnlocked: al >= 1,
      );
      for (final kit in entry.value) {
        expect(
          GameLogic.canUnlockSpec(state, kit.$1),
          isTrue,
          reason: '${kit.$1.name} should unlock at AL$al',
        );
      }
    }
  });

  test('Holy Paladin is on the AL1 Meet ladder', () {
    expect(AscendRoadmap.ascendLevelForKit(HeroSpecId.holyPaladin), 1);
    expect(AscendRoadmap.unlockAtAl(1), contains('Holy Paladin'));
    expect(
      HeroSpecs.def(HeroSpecId.holyPaladin).unlockHint.toLowerCase(),
      contains('al 1'),
    );
  });
}
