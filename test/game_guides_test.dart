import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_guides.dart';

void main() {
  test('guides cover core systems with unique ids', () {
    final topics = GameGuides.topics;
    expect(topics.length, greaterThanOrEqualTo(12));
    final ids = topics.map((t) => t.id).toSet();
    expect(ids.length, topics.length);
    expect(ids, containsAll([
      'basics',
      'dailies',
      'god_hand',
      'ascend',
      'hardmode',
      'gates',
      'power_shelves',
    ]));
    final dailies = topics.firstWhere((t) => t.id == 'dailies');
    expect(dailies.title, 'THREE DAILIES');
    expect(dailies.body, contains('Daily Vault'));
    expect(dailies.body, contains('Daily Run'));
    expect(dailies.body, contains('Quests'));
    expect(dailies.body.toLowerCase(), contains('not the same'));
    final shelves = topics.firstWhere((t) => t.id == 'power_shelves');
    expect(shelves.body.toLowerCase(), contains('gold tracks'));
    expect(shelves.body.toLowerCase(), contains('ascend blessing'));
    expect(shelves.body.toLowerCase(), contains('wipes on ascend'));
    expect(shelves.body.toLowerCase(), contains('embers'));
    expect(shelves.body.toLowerCase(), contains('cinders'));
    expect(shelves.body.toLowerCase(), contains('not essence buys'));
    final gates = topics.firstWhere((t) => t.id == 'gates');
    expect(gates.body, contains('AL20'));
    expect(gates.body, contains('Daily Vault'));
    expect(gates.body, contains('Daily Run'));
    expect(gates.body.toLowerCase(), contains('not the same'));
    expect(gates.body, contains('Gauntlet clear'));
    expect(gates.body, contains('+25e base'));
    expect(gates.body, contains('every active hero Lv'));
    expect(gates.body, contains('Level every active hero to'));
    expect(gates.body.toLowerCase(), contains('+ 1 cinder'));
    final sanctuary = topics.firstWhere((t) => t.id == 'sanctuary');
    expect(sanctuary.body, contains('boss damage'));
    expect(sanctuary.body.toUpperCase(), isNot(contains('ATK / DEF / STA / LOOT')));
    expect(sanctuary.body.toLowerCase(), contains('embers'));
    expect(sanctuary.body.toLowerCase(), contains('cinders'));
    expect(sanctuary.body.toLowerCase(), contains('not essence buys'));
    final bag = topics.firstWhere((t) => t.id == 'bag_equip');
    expect(bag.body, contains('Dual-wield is Rogue / Fury / Enhancement / Frost DK'));
    expect(bag.body, isNot(contains('Survival')));
    expect(bag.body, contains('FILTERS matches'));
    expect(bag.body.toLowerCase(), contains('bis'));
    expect(bag.body.toLowerCase(), contains('soft-cap'));
    expect(bag.body.toLowerCase(), contains('global'));
    final godHand = topics.firstWhere((t) => t.id == 'god_hand');
    expect(godHand.body.toLowerCase(), contains('long-press'));
    expect(godHand.body.toLowerCase(), contains('fist'));
    expect(godHand.body.toLowerCase(), isNot(contains('tap the dungeon floor')));
    expect(godHand.body.toLowerCase(), contains('mastery'));
    expect(godHand.body, contains('Hand of Embers'));
    final combat = topics.firstWhere((t) => t.id == 'combat');
    expect(combat.body.toUpperCase(), contains('CLEAR'));
    expect(combat.body.toUpperCase(), contains('HOLD'));
    expect(combat.body.toUpperCase(), isNot(contains('GO MARKS')));
    expect(combat.body.toLowerCase(), isNot(contains('go marks the exit')));
    final hardmode = topics.firstWhere((t) => t.id == 'hardmode');
    expect(hardmode.body, contains('KEY timer keeps running'));
    expect(hardmode.body, contains('Glass foes hit harder'));
    expect(hardmode.body, contains('Fortified makes trash tougher'));
    expect(hardmode.body.toLowerCase(), isNot(contains('armor stacks')));
    final world = topics.firstWhere((t) => t.id == 'world_path');
    expect(world.body, contains('every hero is ≥Lv80'));
    expect(world.body.toLowerCase(), contains('party mean level'));
    expect(world.body.toLowerCase(), contains('every active hero at lv'));
    expect(world.body.toLowerCase(), contains('mean alone is not enough'));
    final constellation = topics.firstWhere((t) => t.id == 'constellation');
    expect(constellation.body, contains('3 points'));
    expect(constellation.body, contains('Ashen Crown'));
    final gr = topics.firstWhere((t) => t.id == 'greater_rift');
    expect(gr.body, contains('≥25%'));
    final daily = topics.firstWhere((t) => t.id == 'daily');
    expect(daily.body, contains('first Ascend'));
    expect(daily.body, contains('+25e base'));
    expect(daily.body, contains('Dawn Tithe'));
    final weekly = topics.firstWhere((t) => t.id == 'weekly');
    expect(weekly.body.toLowerCase(), contains('+ 1 cinder'));
    final ascend = topics.firstWhere((t) => t.id == 'ascend');
    expect(ascend.body, contains('Embers'));
    expect(ascend.body, contains('Cinders'));
    expect(ascend.body, contains('CAMP'));
    final shopBits = topics.where((t) => t.body.toLowerCase().contains('shop'));
    expect(
      shopBits.any((t) => t.body.toLowerCase().contains('cinder')),
      isTrue,
    );
    for (final t in topics) {
      expect(t.title, isNotEmpty);
      expect(t.body.length, greaterThan(40));
      expect(
        t.body.toUpperCase(),
        isNot(contains('LOADOUTS')),
        reason: '${t.id} should not teach the hidden LOADOUTS tab',
      );
      expect(
        t.body.toUpperCase(),
        t.id == 'bag_equip' || t.id == 'market'
            ? contains('SELL JUNK')
            : isNot(contains('SELL JUNK')),
        reason: '${t.id} names SELL JUNK only on the bag button',
      );
      expect(
        t.body.toUpperCase(),
        isNot(contains('GEAR SELL')),
        reason: '${t.id} should not teach GEAR Sell',
      );
      expect(
        t.body.toLowerCase(),
        isNot(contains('convenience only')),
        reason: '${t.id} should not claim SHOP is convenience only',
      );
      expect(
        t.body.toLowerCase(),
        isNot(contains('real-money convenience store')),
        reason: '${t.id} should not call SHOP a convenience-only store',
      );
    }
    final basics = topics.firstWhere((t) => t.id == 'basics');
    expect(basics.body, contains('GEAR'));
    expect(basics.body, contains('GOLD'));
    expect(basics.body, contains('SHOP'));
    expect(basics.body, contains('ESSENCE'));
    expect(basics.body, contains('Cinder'));
    expect(basics.body.toUpperCase(), isNot(contains('META (')));
  });
}
