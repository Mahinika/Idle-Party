import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/models/dungeon_def.dart';

void main() {
  test('every dungeon has a hub blurb', () {
    for (final def in DungeonCatalog.all) {
      expect(def.blurb, isNotEmpty, reason: def.id);
      expect(StoryLore.dungeonBlurb(def.id), def.blurb);
      expect(StoryLore.enterDungeon(def.id), isNotEmpty);
      expect(StoryLore.dungeonCleared(def.id), isNotEmpty);
      expect(StoryLore.dungeonCleared(def.id).length, lessThan(80));
    }
  });

  test('intro and ascend copy stay short and present', () {
    expect(StoryLore.introTagline, contains('party'));
    expect(StoryLore.introSubline.toLowerCase(), contains('offline'));
    expect(StoryLore.introSubline.toLowerCase(), contains('hub afk'));
    expect(StoryLore.introSubline.toLowerCase(), contains('essence'));
    expect(StoryLore.introSubline.toLowerCase(), contains('mid-dungeon'));
    expect(StoryLore.introBeats.first.body.toLowerCase(), contains('help'));
    expect(StoryLore.studioName, 'Cognifox Studio');
    expect(StoryLore.introBeats, hasLength(1));
    expect(StoryLore.introBeats.first.title, 'IDLE PARTY');
    expect(StoryLore.introBeats.first.body.toLowerCase(), contains('fight'));
    expect(StoryLore.introBeats.first.body.toLowerCase(), isNot(contains('boss')));
    expect(StoryLore.loreTipBody.toLowerCase(), contains('party mean level'));
    final body = StoryLore.ascendConfirmBody(
      rewardEssence: 7,
      nextAl: 1,
      milestoneBonus: 2,
      godHandLevel: 3,
      emberGain: 5,
    );
    expect(body, contains('+7e'));
    expect(body, contains('AL1'));
    expect(body, contains('+5 ATK'));
    expect(body, contains('forever'));
    expect(body, contains('starter'));
    expect(body, contains('Keep:'));
    expect(body, contains('essence'));
    expect(body, contains('Embers'));
    expect(body, contains('Cinders'));
    expect(body, contains('CAMP'));
    expect(body, contains('unlocked specs'));
    expect(body, contains('relics'));
    expect(body, contains('pets'));
    expect(body, contains('soulbound'));
    expect(body, contains('Apex'));
    expect(body, contains('Embers stay'));
    expect(body, contains('+5 Embers'));
    expect(body, contains('GOLD tracks'));
    expect(body, contains('floor progress'));
    expect(body, isNot(contains('AL power')));
    expect(body.length, lessThan(820));
  });

  test('Daily Run lore uses the actual reward essence', () {
    expect(
      StoryLore.dailyRun('sandy', floor: 3, rewardEssence: 30),
      contains('+30e'),
    );
    expect(
      StoryLore.dailyRun('sandy', floor: 3, rewardEssence: 30),
      isNot(contains('+25e')),
    );
  });

  test('AL2 Ascend confirm names the 80e ESSENCE 5th slot', () {
    final body = StoryLore.ascendConfirmBody(
      rewardEssence: 12,
      nextAl: 2,
      unlockCombatRogue: false,
    );
    expect(body, contains('80e'));
    expect(body, contains('ESSENCE'));
  });

  test('reborn confirm matches prestige wipe without extra Blessing', () {
    final body = StoryLore.rebornConfirmBody(
      rewardEssence: 64,
      godHandLevel: 4,
      blessings: 20,
    );
    expect(body, contains('AL stays'));
    expect(body, contains('Blessing stays'));
    expect(body, contains('+64e'));
    expect(body, contains('STAR NODES'));
    expect(body, contains('floor progress'));
    expect(body, contains('Embers'));
    expect(body, contains('Cinders'));
    expect(body, contains('CAMP'));
    expect(body, contains('unlocked specs'));
    expect(body, contains('relics'));
    expect(body, contains('pets'));
    expect(body.toLowerCase(), contains('rebuild'));
    expect(body, isNot(contains('Keep: hero')));
  });
}
