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
    expect(StoryLore.introSubline.toLowerCase(), contains('help'));
    expect(StoryLore.introBeats, hasLength(3));
    expect(StoryLore.introBeats.first.title, 'IDLE PARTY');
    expect(StoryLore.introBeats[1].body.toLowerCase(), contains('dungeon'));
    final body = StoryLore.ascendConfirmBody(
      rewardEssence: 7,
      nextAl: 1,
      milestoneBonus: 2,
      godHandLevel: 3,
    );
    expect(body, contains('+7e'));
    expect(body, contains('milestone'));
    expect(body, contains('God Hand'));
    expect(body, contains('Lv3'));
    expect(body, contains('levels/XP'));
    expect(body, contains('Your party stays'));
    expect(body, contains('Apex stays'));
    expect(body, contains('Reset: wallet'));
    expect(body, isNot(contains('your run stays')));
  });

  test('reborn confirm matches prestige wipe without extra Blessing', () {
    final body = StoryLore.rebornConfirmBody(
      rewardEssence: 64,
      godHandLevel: 4,
      blessings: 20,
    );
    expect(body, contains('Your party stays'));
    expect(body, contains('Apex stays'));
    expect(body, contains('AL stays'));
    expect(body, contains('No extra Blessing'));
    expect(body, contains('+64e'));
    expect(body, contains('constellation'));
    expect(body, contains('Rebuild your bag'));
  });
}
