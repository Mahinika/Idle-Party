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
    final gates = topics.firstWhere((t) => t.id == 'gates');
    expect(gates.body, contains('AL20'));
    expect(gates.body, contains('Daily Vault'));
    expect(gates.body, contains('Daily Run'));
    expect(gates.body.toLowerCase(), contains('not the same'));
    expect(gates.body, contains('Gauntlet clear'));
    expect(gates.body, contains('+25e base'));
    expect(gates.body, contains('every hero Lv'));
    final sanctuary = topics.firstWhere((t) => t.id == 'sanctuary');
    expect(sanctuary.body, contains('boss damage'));
    expect(sanctuary.body.toUpperCase(), isNot(contains('ATK / DEF / STA / LOOT')));
    final bag = topics.firstWhere((t) => t.id == 'bag_equip');
    expect(bag.body, contains('Dual-wield is Rogue / Fury / Enhancement / Frost DK'));
    expect(bag.body, isNot(contains('Survival')));
    expect(bag.body, contains('FILTERS matches'));
    expect(bag.body.toLowerCase(), contains('bis'));
    final godHand = topics.firstWhere((t) => t.id == 'god_hand');
    expect(godHand.body.toLowerCase(), contains('long-press'));
    expect(godHand.body.toLowerCase(), contains('fist'));
    expect(godHand.body.toLowerCase(), isNot(contains('tap the dungeon floor')));
    final hardmode = topics.firstWhere((t) => t.id == 'hardmode');
    expect(hardmode.body, contains('KEY timer keeps running'));
    expect(hardmode.body, contains('Glass foes hit harder'));
    expect(hardmode.body, contains('Fortified makes trash tougher'));
    expect(hardmode.body.toLowerCase(), isNot(contains('armor stacks')));
    final world = topics.firstWhere((t) => t.id == 'world_path');
    expect(world.body, contains('every hero is ≥Lv80'));
    final constellation = topics.firstWhere((t) => t.id == 'constellation');
    expect(constellation.body, contains('3 points'));
    expect(constellation.body, contains('Ashen Crown'));
    final gr = topics.firstWhere((t) => t.id == 'greater_rift');
    expect(gr.body, contains('≥25%'));
    final daily = topics.firstWhere((t) => t.id == 'daily');
    expect(daily.body, contains('first Ascend'));
    expect(daily.body, contains('+25e base'));
    expect(daily.body, contains('Dawn Tithe'));
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
        isNot(contains('SELL JUNK')),
        reason: '${t.id} should not teach a Sell junk button',
      );
      expect(
        t.body.toUpperCase(),
        isNot(contains('GEAR SELL')),
        reason: '${t.id} should not teach GEAR Sell',
      );
    }
    final basics = topics.firstWhere((t) => t.id == 'basics');
    expect(basics.body, contains('GEAR'));
    expect(basics.body, contains('GOLD'));
    expect(basics.body, contains('SHOP'));
    expect(basics.body, contains('ESSENCE'));
    expect(basics.body.toUpperCase(), isNot(contains('META (')));
  });
}
