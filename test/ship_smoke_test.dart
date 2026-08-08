import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/dungeon_def.dart';

/// Fast honesty checks: world path, unlock rules, guides, release version.
void main() {
  test('world path ships nine named zones including tide and ember', () {
    expect(DungeonCatalog.all.length, 9);
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
      ],
    );
    expect(DungeonCatalog.byId('tide').name, 'Sunken Tidehold');
    expect(DungeonCatalog.byId('ember').name, 'Ashen Vault');
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
  });

  test('guides cover World Path endgame zones and LOADOUTS vs armor sets', () {
    final world = GameGuides.topics.firstWhere((t) => t.id == 'world_path');
    expect(world.body.toLowerCase(), contains('tidehold'));
    expect(world.body.toLowerCase(), contains('ashen'));
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
}
