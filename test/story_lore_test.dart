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
    expect(StoryLore.studioName, 'Cognifox Studio');
    expect(StoryLore.introBeats, hasLength(1));
    expect(StoryLore.introBeats.first.title, 'IDLE PARTY');
    expect(StoryLore.introBeats.first.body.toLowerCase(), contains('fight'));
    expect(StoryLore.introBeats.first.body.toLowerCase(), isNot(contains('boss')));
    final body = StoryLore.ascendConfirmBody(
      rewardEssence: 7,
      nextAl: 1,
      milestoneBonus: 2,
      godHandLevel: 3,
    );
    expect(body, contains('+7e'));
    expect(body, contains('AL1'));
    expect(body, contains('+5 ATK'));
    expect(body, contains('forever'));
    expect(body, contains('caves stay'));
    expect(body, isNot(contains('AL power')));
    expect(body.length, lessThan(520));
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
    expect(body.toLowerCase(), contains('rebuild'));
    expect(body, isNot(contains('Keep: hero')));
  });
}
