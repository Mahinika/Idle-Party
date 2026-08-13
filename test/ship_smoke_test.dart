import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ascend_roadmap.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/dungeon_def.dart';

/// Fast honesty checks: world path, unlock rules, guides, release version.
void main() {
  test('world path ships twelve named zones including rime', () {
    expect(DungeonCatalog.all.length, 12);
    final ids = DungeonCatalog.all.map((d) => d.id).toList();
    expect(
      ids,
      <String>[
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
      ],
    );
    expect(DungeonCatalog.byId('tide').name, 'Sunken Tidehold');
    expect(DungeonCatalog.byId('ember').name, 'Ashen Vault');
    expect(DungeonCatalog.byId('grove').name, 'Hollow Grove');
    expect(DungeonCatalog.byId('storm').name, 'Stormwake Hollow');
    expect(DungeonCatalog.byId('rime').name, 'Rimeglass Rift');
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
  });

  test('guides cover World Path endgame zones and LOADOUTS vs armor sets', () {
    final world = GameGuides.topics.firstWhere((t) => t.id == 'world_path');
    expect(world.body.toLowerCase(), contains('tidehold'));
    expect(world.body.toLowerCase(), contains('ashen'));
    expect(world.body.toLowerCase(), contains('hollow grove'));
    expect(world.body.toLowerCase(), contains('stormwake'));
    expect(world.body.toLowerCase(), contains('rimeglass'));
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
    expect(AscendRoadmap.unlockAtAl(2), contains('Beast Mastery'));
    expect(AscendRoadmap.unlockAtAl(2), contains('5th party slot'));
    expect(AscendRoadmap.unlockAtAl(5), contains('Blood DK'));
    expect(AscendRoadmap.unlockAtAl(10), contains('Gauntlet'));
    expect(AscendRoadmap.chaseTeaser(0), contains('AL1'));
    expect(AscendRoadmap.kitUnlockSummary(4), isNotNull);

    final classes = GameGuides.topics.firstWhere((t) => t.id == 'classes');
    expect(classes.body, contains('AL2'));
    expect(classes.body, contains('Beast Mastery'));
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
