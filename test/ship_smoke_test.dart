import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ascend_roadmap.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/hub_endgame_act.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/zone_art.dart';
import 'package:idle_party/spatial/tile_map.dart';
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

  test('World Path markers sit on continent clusters', () {
    expect(HubScreen.worldPathMarkerCount, DungeonCatalog.all.length);
    expect(HubScreen.worldPathMarkerCount, 15);
    final marks = HubScreen.worldPathMarkerNorm;
    for (final o in marks) {
      expect(o.dx, inInclusiveRange(0.06, 0.94));
      expect(o.dy, inInclusiveRange(0.06, 0.94));
    }
    Offset at(String id) => marks[DungeonCatalog.byId(id).number];
    double dist(Offset a, Offset b) {
      final dx = a.dx - b.dx;
      final dy = a.dy - b.dy;
      return dx * dx + dy * dy;
    }

    // Dunes together; veil is a far eastern land.
    expect(dist(at('sandy'), at('goblin')), lessThan(dist(at('sandy'), at('veil'))));
    // Frost is north of the dune coast.
    expect(at('crystal').dy, lessThan(at('sandy').dy));
    expect(at('rime').dy, lessThan(at('sandy').dy));
    // Veil sits east of the crownlands.
    expect(at('veil').dx, greaterThan(at('king').dx));
    // Ash isles sit south.
    expect(at('hell').dy, greaterThan(at('king').dy));
  });

  test('endgame map is four hunts on a separate board', () {
    expect(HubEndgameAct.nodes.length, 4);
    expect(HubScreen.endgameMapMarkerCount, 4);
    expect(HubScreen.endgameMapMarkerCount, HubEndgameAct.nodes.length);
    final ys = HubScreen.endgameMapMarkerNorm.map((o) => o.dy).toList()
      ..sort();
    expect(
      ys.last - ys.first,
      greaterThan(0.4),
      reason: 'ENDGAME nodes spread on their own map, not a footer row',
    );
    expect(
      HubEndgameAct.nodes.map((n) => n.hunt).toSet(),
      {
        HubEndgameHunt.gauntlet,
        HubEndgameHunt.rankedGr,
        HubEndgameHunt.farmRift,
        HubEndgameHunt.ashen,
      },
    );
    expect(
      HubEndgameAct.nodes.map((n) => n.portraitDungeonId).toSet(),
      {'crystal', 'veil', 'storm', 'ember'},
    );
    expect(HubEndgameAct.huntForChase(HubChaseKind.riftMilestone), HubEndgameHunt.farmRift);
    expect(HubEndgameAct.huntForChase(HubChaseKind.keystone), isNull);
    expect(HubEndgameAct.pathTabLabel, 'PATH');
    expect(HubEndgameAct.mapTitle, 'ENDGAME');
    expect(HubEndgameAct.mapUnlockLine.toUpperCase(), contains('PATH'));
    expect(HubEndgameAct.mapUnlockLine.toUpperCase(), contains('KEY'));
    expect(HubEndgameAct.mapUnlockLine.toLowerCase(), contains('harder'));
    expect(HubEndgameAct.mapUnlockLine.toLowerCase(), contains('not a 16th cave'));
    expect(
      HubEndgameAct.nodeFor(HubEndgameHunt.gauntlet).blurb.toLowerCase(),
      contains('not a 16th cave'),
    );
  });

  test('zone unlock uses party level or prior clear', () {
    expect(DungeonCatalog.unlockHeroLevel(DungeonCatalog.byId('sandy')), 1);
    expect(DungeonCatalog.isUnlocked('sandy', 1, -1), isTrue);

    final goblinNeed = DungeonCatalog.unlockHeroLevel(
      DungeonCatalog.byId('goblin'),
    );
    expect(goblinNeed, 8);
    expect(DungeonCatalog.isUnlocked('goblin', 1, -1), isFalse);
    expect(DungeonCatalog.isUnlocked('goblin', goblinNeed, -1), isTrue);
    expect(DungeonCatalog.isUnlocked('goblin', 1, 0), isTrue);

    for (final id in [
      'tide',
      'ember',
      'grove',
      'storm',
      'rime',
      'fen',
      'brass',
      'veil',
    ]) {
      final def = DungeonCatalog.byId(id);
      final need = DungeonCatalog.unlockHeroLevel(def);
      expect(
        DungeonCatalog.isUnlocked(id, need - 1, def.number - 2),
        isFalse,
        reason: '$id should stay locked below Lv$need without prior clear',
      );
      expect(
        DungeonCatalog.isUnlocked(id, need, def.number - 2),
        isTrue,
        reason: '$id unlocks at party Lv$need',
      );
      expect(
        DungeonCatalog.isUnlocked(id, 1, def.number - 1),
        isTrue,
        reason: '$id unlocks after clearing previous zone',
      );
    }

    expect(
      DungeonCatalog.unlockHeroLevel(DungeonCatalog.byId('veil')),
      100,
    );
  });

  test('guides cover World Path endgame zones and Ashen Crown honesty', () {
    final world = GameGuides.topics.firstWhere((t) => t.id == 'world_path');
    expect(world.body.toLowerCase(), contains('tidehold'));
    expect(world.body.toLowerCase(), contains('ashen'));
    expect(world.body.toLowerCase(), contains('hollow grove'));
    expect(world.body.toLowerCase(), contains('stormwake'));
    expect(world.body.toLowerCase(), contains('rimeglass'));
    expect(world.body.toLowerCase(), contains('blightfen'));
    expect(world.body.toLowerCase(), contains('brassvault'));
    expect(world.body.toLowerCase(), contains('mothveil'));
    expect(world.body.toLowerCase(), contains('endgame'));
    expect(world.body.toLowerCase(), contains('tab'));
    expect(world.body.toLowerCase(), contains('party mean level'));
    expect(world.body.toLowerCase(), contains('gold does not unlock'));
    expect(world.body.toLowerCase(), isNot(contains('lifetime gold')));

    expect(GameGuides.topics.any((t) => t.id == 'loadouts'), isFalse);
    expect(GameGuides.topics.any((t) => t.id == 'constellation'), isTrue);

    final ashen = GameGuides.topics.firstWhere((t) => t.id == 'ashen_crown');
    expect(ashen.body.toLowerCase(), contains('practice'));
    expect(ashen.body.toLowerCase(), contains('ticket'));

    final keystone = GameGuides.topics.firstWhere((t) => t.id == 'hardmode');
    expect(keystone.body.toLowerCase(), contains('ashen'));
    expect(keystone.body.toLowerCase(), contains('farm rift'));
    expect(keystone.body.toLowerCase(), contains('pack'));

    final ascend = GameGuides.topics.firstWhere((t) => t.id == 'ascend');
    expect(ascend.body, contains('AL20'));
    expect(ascend.body, contains('${GameLogic.maxHeroLevel}'));
    expect(ascend.body.toLowerCase(), contains('not from al20 alone'));

    final gates = GameGuides.topics.firstWhere((t) => t.id == 'gates');
    expect(gates.body, contains('${GameLogic.maxHeroLevel}'));
    expect(gates.body.toLowerCase(), contains('daily vault'));
    expect(gates.body.toLowerCase(), contains('daily run'));
    expect(gates.body.toLowerCase(), contains('quests daily'));

    final armor = GameGuides.topics.where((t) => t.id == 'armor_sets');
    if (armor.isNotEmpty) {
      expect(armor.first.body.toLowerCase(), isNot(contains('loadouts')));
    }

    final market = GameGuides.topics.firstWhere((t) => t.id == 'market');
    expect(market.body.toLowerCase(), contains('listings'));
    expect(market.body.toLowerCase(), contains('hub hunt'));
    expect(market.body.toLowerCase(), contains('clean bag'));
    expect(market.body.toLowerCase(), isNot(contains('sell junk')));
  });

  test('Gauntlet / KEY / Rift gates use party max level and What’s New version is non-empty', () {
    expect(GameLogic.maxHeroLevel, 100);
    expect(GameLogic.endgameUnlocked(GameLogic.createInitialState()), isFalse);
    expect(MenuTabs.showKey(GameLogic.createInitialState()), isFalse);
    final maxed = GameLogic.createInitialState().copyWith(
      heroRoster: [
        for (final h in GameLogic.createInitialState().heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    expect(GameLogic.endgameUnlocked(maxed), isTrue);
    expect(MenuTabs.showKey(maxed), isTrue);
    expect(Keystone.maxForState(maxed), Keystone.campaignCap);
    expect(MetaSystems.currentVersion, isNotEmpty);
    expect(MetaSystems.releases.first.version, MetaSystems.currentVersion);
    expect(MetaSystems.releases.first.bullets, isNotEmpty);
    expect(
      MetaSystems.releases.first.bullets.join(' ').toUpperCase(),
      contains('GREATER'),
    );
    expect(
      MetaSystems.releases.first.bullets.join(' '),
      contains('Rebuild your bag'),
    );
    expect(
      MetaSystems.releases.first.bullets.join(' ').toUpperCase(),
      contains('REBORN'),
    );
  });

  test('guides and Ascend roadmap stay honest for TODAY chase', () {
    final vault = GameGuides.topics.firstWhere((t) => t.id == 'weekly');
    expect(vault.title.toUpperCase(), contains('DAILY'));
    expect(vault.body.toUpperCase(), contains('HUB HUNT'));
    expect(vault.body.toUpperCase(), contains('READY'));

    expect(AscendRoadmap.unlockAtAl(1), contains('Combat Rogue'));
    expect(AscendRoadmap.unlockAtAl(1), contains('Holy Paladin'));
    expect(AscendRoadmap.unlockAtAl(2), contains('Beast Mastery'));
    expect(AscendRoadmap.unlockAtAl(2), contains('5th party slot'));
    expect(AscendRoadmap.unlockAtAl(2), contains('ESSENCE'));
    expect(GameLogic.partySlot5EssenceCost, 80);
    expect(AscendRoadmap.unlockAtAl(5), contains('Blood DK'));
    expect(AscendRoadmap.unlockAtAl(20), contains('Ascension cap'));
    expect(AscendRoadmap.unlockAtAl(20), contains('${GameLogic.maxHeroLevel}'));
    expect(AscendRoadmap.unlockAtAl(20), contains('KEY'));
    expect(AscendRoadmap.chaseTeaser(0), contains('AL1'));
    expect(AscendRoadmap.kitUnlockSummary(4), isNotNull);

    final rift = GameGuides.topics.firstWhere((t) => t.id == 'rift');
    expect(rift.title.toUpperCase(), contains('RIFT'));
    expect(rift.body, contains('${GameLogic.maxHeroLevel}'));
    expect(rift.body.toLowerCase(), contains('farm'));

    final gr = GameGuides.topics.firstWhere((t) => t.id == 'greater_rift');
    expect(gr.title.toUpperCase(), contains('RANKED'));
    expect(gr.body.toUpperCase(), contains('BOARDS'));

    final classes = GameGuides.topics.firstWhere((t) => t.id == 'classes');
    expect(classes.body, contains('AL2'));
    expect(classes.body, contains('Beast Mastery'));
    expect(classes.body, contains('Holy Paladin'));
    expect(classes.body, contains('ESSENCE BLESSING'));

    final forge = GameGuides.topics.firstWhere((t) => t.id == 'forge');
    expect(forge.body, contains('ESSENCE'));
    expect(forge.body.toLowerCase(), contains('reset when you ascend'));
    expect(forge.body.toUpperCase(), isNot(contains('REBORN')));

    final ascendGuide = GameGuides.topics.firstWhere((t) => t.id == 'ascend');
    expect(ascendGuide.body.toLowerCase(), contains('empty bag'));
    expect(ascendGuide.body.toUpperCase(), contains('REBORN'));
    expect(ascendGuide.body.toLowerCase(), contains('wallet gold'));

    final sanctuary = GameGuides.topics.firstWhere((t) => t.id == 'sanctuary');
    expect(sanctuary.body.toLowerCase(), contains('essence'));
    expect(sanctuary.title, 'ESSENCE');
    expect(sanctuary.body, contains('CAMP'));
    expect(sanctuary.body, contains('BLESSING'));
    expect(sanctuary.body, contains('God Hand'));
    expect(sanctuary.body.toUpperCase(), contains('REBORN'));
    expect(sanctuary.body, isNot(contains('PRESTIGE')));

    final shop = GameGuides.topics.firstWhere((t) => t.id == 'prestige_shop');
    expect(shop.title, 'PERMANENT BUYS');
    expect(shop.body, contains('BLESSING'));
    expect(shop.body.toLowerCase(), contains('vault'));
    expect(shop.body.toLowerCase(), contains('merge gold'));
    expect(shop.body.toLowerCase(), contains('bottom-tab shop'));
    expect(shop.body.toLowerCase(), contains('one door'));

    final pets = GameGuides.topics.firstWhere((t) => t.id == 'pets');
    expect(pets.body.toLowerCase(), contains('same rarity'));
    expect(pets.body.toLowerCase(), contains('looks only'));

    final combinator = GameGuides.topics.firstWhere((t) => t.id == 'combinator');
    expect(combinator.body.toLowerCase(), contains('charm'));
    expect(combinator.body.toLowerCase(), contains('gold'));

    final bag = GameGuides.topics.firstWhere((t) => t.id == 'bag_equip');
    expect(bag.body.toLowerCase(), contains('weapons are a hard gate'));
    expect(bag.body.toLowerCase(), contains('no daggers'));

    final powerups = GameGuides.topics.firstWhere((t) => t.id == 'powerups');
    expect(powerups.title, 'SCROLLS');
    expect(powerups.body.toLowerCase(), contains('ad ticket'));
    expect(powerups.body.toLowerCase(), contains('camera'));
    expect(powerups.body.toLowerCase(), contains('scroll of battle'));
    expect(powerups.body.toLowerCase(), contains('24 hours'));
  });

  test('late zones tide brass veil have distinct layout identity', () {
    final tide = ZoneArt.byId('tide');
    final brass = ZoneArt.byId('brass');
    final veil = ZoneArt.byId('veil');
    for (final z in [tide, brass, veil]) {
      expect(z.customDungeonArt, isTrue);
      expect(z.clutterDensity, lessThan(0.12));
    }
    expect(tide.preferChoke, isTrue);
    expect(brass.preferTreasureAlcove, isTrue);
    expect(brass.treasureAlcoveChance, greaterThanOrEqualTo(0.40));
    expect(veil.preferChoke, isTrue);
    expect(veil.landmarkPerChamber, greaterThanOrEqualTo(2));
  });

  test('mid zones ember grove storm have distinct layout identity', () {
    final ember = ZoneArt.byId('ember');
    final grove = ZoneArt.byId('grove');
    final storm = ZoneArt.byId('storm');
    expect(ember.preferChoke, isTrue);
    expect(ember.landmarks, contains(MapPropKind.lava));
    expect(grove.landmarks.where((l) => l == MapPropKind.fence).length, 2);
    expect(storm.landmarkPerChamber, 2);
    expect(storm.landmarks, contains(MapPropKind.trap));
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
