import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ascend_roadmap.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/ui/hub_screen.dart';

/// Fast honesty checks: world path, unlock rules, guides, release version.
void main() {
  test('world path ships fifteen named zones including mothveil', () {
    expect(DungeonCatalog.all.length, 15);
    final ids = DungeonCatalog.all.map((d) => d.id).toList();
    expect(ids, <String>[
      'sandy',
      'goblin',
      'king',
      'underworld',
      'dead',
      'hell',
      'crystal',
      'tide',
      'ember',
      'grove',
      'storm',
      'rime',
      'fen',
      'brass',
      'veil',
    ]);
    expect(DungeonCatalog.byId('tide').name, 'Sunken Tidehold');
    expect(DungeonCatalog.byId('ember').name, 'Ashen Vault');
    expect(DungeonCatalog.byId('grove').name, 'Hollow Grove');
    expect(DungeonCatalog.byId('storm').name, 'Stormwake Hollow');
    expect(DungeonCatalog.byId('rime').name, 'Rimeglass Rift');
    expect(DungeonCatalog.byId('fen').name, 'Blightfen Mire');
    expect(DungeonCatalog.byId('brass').name, 'Brassvault Deep');
    expect(DungeonCatalog.byId('veil').name, 'Mothveil Hollow');
  });

  test('World Path map markers match dungeon catalog length and order', () {
    expect(HubScreen.worldPathMarkerCount, DungeonCatalog.all.length);
    expect(HubScreen.worldPathMarkerCount, 15);
    // First / last anchors stay in the painted path corridor.
    final first = HubScreen.worldPathMarkerNorm.first;
    final last = HubScreen.worldPathMarkerNorm.last;
    expect(first.dx, inInclusiveRange(0.35, 0.65));
    expect(first.dy, lessThan(0.12));
    expect(last.dx, inInclusiveRange(0.35, 0.65));
    expect(last.dy, greaterThan(0.90));
    for (var i = 1; i < HubScreen.worldPathMarkerNorm.length; i++) {
      expect(
        HubScreen.worldPathMarkerNorm[i].dy,
        greaterThan(HubScreen.worldPathMarkerNorm[i - 1].dy),
        reason: 'markers must descend sandy→veil',
      );
    }
  });

  test('zone unlock uses lifetime gold or prior clear, not wallet gold', () {
    expect(DungeonCatalog.isUnlocked('sandy', 0, -1), isTrue);
    expect(DungeonCatalog.isUnlocked('goblin', 0, -1), isFalse);
    expect(DungeonCatalog.isUnlocked('goblin', 5000, -1), isTrue);
    expect(DungeonCatalog.isUnlocked('goblin', 0, 0), isTrue);

    expect(DungeonCatalog.isUnlocked('tide', 749999, 5), isFalse);
    expect(DungeonCatalog.isUnlocked('tide', 750000, 5), isTrue);
    expect(DungeonCatalog.isUnlocked('tide', 0, 6), isTrue);

    expect(DungeonCatalog.isUnlocked('ember', 1199999, 6), isFalse);
    expect(DungeonCatalog.isUnlocked('ember', 1200000, 6), isTrue);
    expect(DungeonCatalog.isUnlocked('ember', 0, 7), isTrue);

    expect(DungeonCatalog.isUnlocked('grove', 1799999, 7), isFalse);
    expect(DungeonCatalog.isUnlocked('grove', 1800000, 7), isTrue);
    expect(DungeonCatalog.isUnlocked('grove', 0, 8), isTrue);

    expect(DungeonCatalog.isUnlocked('storm', 2599999, 8), isFalse);
    expect(DungeonCatalog.isUnlocked('storm', 2600000, 8), isTrue);
    expect(DungeonCatalog.isUnlocked('storm', 0, 9), isTrue);

    expect(DungeonCatalog.isUnlocked('rime', 3599999, 9), isFalse);
    expect(DungeonCatalog.isUnlocked('rime', 3600000, 9), isTrue);
    expect(DungeonCatalog.isUnlocked('rime', 0, 10), isTrue);

    expect(DungeonCatalog.isUnlocked('fen', 4999999, 10), isFalse);
    expect(DungeonCatalog.isUnlocked('fen', 5000000, 10), isTrue);
    expect(DungeonCatalog.isUnlocked('fen', 0, 11), isTrue);

    expect(DungeonCatalog.isUnlocked('brass', 6999999, 11), isFalse);
    expect(DungeonCatalog.isUnlocked('brass', 7000000, 11), isTrue);
    expect(DungeonCatalog.isUnlocked('brass', 0, 12), isTrue);

    expect(DungeonCatalog.isUnlocked('veil', 9999999, 12), isFalse);
    expect(DungeonCatalog.isUnlocked('veil', 10000000, 12), isTrue);
    expect(DungeonCatalog.isUnlocked('veil', 0, 13), isTrue);
  });

  test('guides cover World Path endgame zones and LOADOUTS vs armor sets', () {
    final world = GameGuides.topics.firstWhere((t) => t.id == 'world_path');
    expect(world.body.toLowerCase(), contains('tidehold'));
    expect(world.body.toLowerCase(), contains('ashen'));
    expect(world.body.toLowerCase(), contains('hollow grove'));
    expect(world.body.toLowerCase(), contains('stormwake'));
    expect(world.body.toLowerCase(), contains('rimeglass'));
    expect(world.body.toLowerCase(), contains('blightfen'));
    expect(world.body.toLowerCase(), contains('brassvault'));
    expect(world.body.toLowerCase(), contains('mothveil'));
    expect(world.body.toLowerCase(), contains('lifetime gold'));

    final loadouts = GameGuides.topics.firstWhere((t) => t.id == 'loadouts');
    expect(loadouts.title, 'LOADOUTS');
    expect(loadouts.body, contains('LOADOUTS'));

    final armor = GameGuides.topics.where((t) => t.id == 'armor_sets');
    if (armor.isNotEmpty) {
      expect(armor.first.body.toLowerCase(), contains('loadouts'));
    }
  });

  test('Gauntlet gate stays AL10+ and What’s New version is non-empty', () {
    expect(GameLogic.gauntletMinAscension, 10);
    expect(MetaSystems.currentVersion, isNotEmpty);
    expect(MetaSystems.releases.first.version, MetaSystems.currentVersion);
    expect(MetaSystems.releases.first.bullets, isNotEmpty);
  });

  test('guides and Ascend roadmap stay honest for TODAY chase', () {
    final vault = GameGuides.topics.firstWhere((t) => t.id == 'weekly');
    expect(vault.title.toUpperCase(), contains('DAILY'));
    expect(vault.body.toUpperCase(), contains('TODAY'));
    expect(vault.body.toUpperCase(), contains('READY'));

    expect(AscendRoadmap.unlockAtAl(1), contains('Combat Rogue'));
    expect(AscendRoadmap.unlockAtAl(1), contains('Holy Paladin'));
    expect(AscendRoadmap.unlockAtAl(2), contains('Beast Mastery'));
    expect(AscendRoadmap.unlockAtAl(2), contains('5th party slot'));
    expect(AscendRoadmap.unlockAtAl(2), contains('Forge'));
    expect(GameLogic.partySlot5EssenceCost, 80);
    expect(AscendRoadmap.unlockAtAl(5), contains('Blood DK'));
    expect(AscendRoadmap.unlockAtAl(10), contains('Gauntlet'));
    expect(AscendRoadmap.chaseTeaser(0), contains('AL1'));
    expect(AscendRoadmap.kitUnlockSummary(4), isNotNull);

    final classes = GameGuides.topics.firstWhere((t) => t.id == 'classes');
    expect(classes.body, contains('AL2'));
    expect(classes.body, contains('Beast Mastery'));
    expect(classes.body, contains('Holy Paladin'));
    expect(classes.body, contains('Forge KEEP'));

    final forge = GameGuides.topics.firstWhere((t) => t.id == 'forge');
    expect(forge.body, contains('Blessing'));
    expect(forge.body, contains('5th party'));
    expect(forge.body, contains('KEEP'));

    final sanctuary = GameGuides.topics.firstWhere((t) => t.id == 'sanctuary');
    expect(sanctuary.body, contains('CAMP'));
    expect(sanctuary.body, contains('+3% gold'));
    expect(sanctuary.body, contains('+1 ATK'));
    expect(sanctuary.body, contains('Lv0'));

    final shop = GameGuides.topics.firstWhere((t) => t.id == 'prestige_shop');
    expect(shop.body, contains('KEEP'));
    expect(shop.body.toLowerCase(), contains('vault'));
    expect(shop.body.toLowerCase(), contains('merge gold'));

    final pets = GameGuides.topics.firstWhere((t) => t.id == 'pets');
    expect(pets.body.toLowerCase(), contains('same rarity'));
    expect(pets.body.toLowerCase(), contains('looks only'));

    final combinator = GameGuides.topics.firstWhere((t) => t.id == 'combinator');
    expect(combinator.body.toLowerCase(), contains('charm'));
    expect(combinator.body.toLowerCase(), contains('gold'));

    final bag = GameGuides.topics.firstWhere((t) => t.id == 'bag_equip');
    expect(bag.body.toLowerCase(), contains('weapons are a hard gate'));
    expect(bag.body.toLowerCase(), contains('no daggers'));
  });

  test('fresh TODAY chase is grow-the-party, not Daily', () {
    final now = DateTime.utc(2026, 8, 8, 12);
    final state = GameLogic.createInitialState(now: now);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.title.toLowerCase(), contains('grow'));
    expect(GameLogic.showDailyChase(state), isFalse);
  });
}
