import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/models/zone_art.dart';
import 'package:idle_party/spatial/zone_layout_kit.dart';
import 'package:idle_party/ui/custom_assets.dart';
import 'package:idle_party/ui/dungeon_environment.dart';
import 'package:idle_party/ui/kenney_assets.dart';

/// A zone is only a place if it looks like one. These guard the promise in
/// `lib/models/zone_art.dart`: every zone owns art nobody else uses, and the
/// old per-zone switches keep reading from the one manifest.
void main() {
  test('every catalog zone has a manifest entry', () {
    for (final def in DungeonCatalog.all) {
      final art = ZoneArt.byId(def.id);
      expect(art.id, def.id, reason: '${def.name} falls back to a plain cave');
    }
    expect(ZoneArt.all.length, DungeonCatalog.all.length);
  });

  test('every zone owns a boss sprite no other zone uses', () {
    final owners = <String, List<String>>{};
    for (final def in DungeonCatalog.all) {
      owners
          .putIfAbsent(ZoneArt.byId(def.id).enemies.boss, () => <String>[])
          .add(def.id);
    }
    for (final entry in owners.entries) {
      expect(
        entry.value,
        hasLength(1),
        reason: 'shared boss art: ${entry.value.join(", ")} → ${entry.key}',
      );
    }
  });

  test('every zone owns at least one enemy sprite no other zone spawns', () {
    for (final def in DungeonCatalog.all) {
      final mine = ZoneArt.byId(def.id).enemies.all;
      final others = <String>{
        for (final other in DungeonCatalog.all)
          if (other.id != def.id) ...ZoneArt.byId(other.id).enemies.all,
      };
      expect(
        mine.difference(others),
        isNotEmpty,
        reason: '${def.name} spawns only sprites other zones already use',
      );
    }
  });

  test('zone art files exist on disk', () {
    for (final def in DungeonCatalog.all) {
      final art = ZoneArt.byId(def.id);
      for (final path in <String>{
        art.portrait,
        art.backdrop,
        ...art.enemies.all,
      }) {
        expect(File(path).existsSync(), isTrue, reason: '${def.id}: $path');
      }
    }
  });

  test('pets have their own art — no borrowed dungeon monsters', () {
    for (final species in PetCatalog.all) {
      final art = CustomAssets.petForTemplateId(species.id);
      expect(
        art,
        startsWith('assets/custom/pets/'),
        reason: '${species.name} wears an enemy sprite',
      );
      expect(File(art).existsSync(), isTrue, reason: art);
    }
    for (final path in CustomAssets.petPortraitPaths) {
      expect(path, startsWith('assets/custom/pets/'));
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('zone-scoped helpers read from the manifest', () {
    for (final def in DungeonCatalog.all) {
      final art = ZoneArt.byId(def.id);
      expect(KenneyAssets.floorForDungeon(def.id), art.floor);
      expect(KenneyAssets.wallVariantsForDungeon(def.id), art.wallVariants);
      expect(KenneyAssets.propPoolForDungeon(def.id), art.props);
      expect(KenneyAssets.dungeonIconFor(def.id), art.hubIcon);
      expect(DungeonEnvironment.ambient(def.id), art.ambient);
      expect(DungeonEnvironment.atmosphereWash(def.id), art.wash);
      expect(DungeonEnvironment.projectileTint(def.id), art.projectileTint);
      expect(ZoneLayoutKit.forId(def.id).landmarks, art.landmarks);
      expect(ZoneLayoutKit.forId(def.id).preferChoke, art.preferChoke);
      for (final archetype in EnemyArchetype.values) {
        expect(
          KenneyAssets.enemySpriteForArchetype(archetype, dungeonId: def.id),
          art.enemies.forArchetype(archetype),
        );
      }
    }
  });

  test('codex art matches what the zone actually spawns', () {
    for (final def in DungeonCatalog.all) {
      expect(
        KenneyAssets.enemySpriteForCodexName(def.bossName),
        ZoneArt.byId(def.id).enemies.boss,
        reason: '${def.bossName} looks different in the codex',
      );
    }
  });

  test('unknown zone ids still paint instead of throwing', () {
    final art = ZoneArt.byId('not-a-zone');
    expect(art.floorVariants, isNotEmpty);
    expect(art.wall, isNotEmpty);
    expect(art.enemies.forArchetype(EnemyArchetype.swarm), isNotEmpty);
  });
}
