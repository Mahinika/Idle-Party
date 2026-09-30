import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/equipment_model_catalog.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

/// The Python facit and the loot catalog must list the same active models.
void main() {
  final catalog = jsonDecode(
    File('tool/active_gear_models.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('active model list matches the loot catalog', () {
    final shared = (catalog['shared'] as Map).cast<String, dynamic>();
    final family = (catalog['family'] as Map).cast<String, dynamic>();
    final planned = (catalog['planned'] as List).cast<String>();
    for (final entry in shared.entries) {
      expect(
        EquipmentModelCatalog.variants[entry.key],
        (entry.value as List).cast<String>(),
        reason: entry.key,
      );
    }
    for (final entry in family.entries) {
      expect(
        EquipmentModelCatalog.variants[entry.key],
        (entry.value as List).cast<String>(),
        reason: entry.key,
      );
    }
    for (final stem in planned) {
      expect(EquipmentModelCatalog.variants.containsKey(stem.split('_').first), isFalse);
    }
  });

  test('each active model has its own icon and overlay path', () {
    // shoulder_t2 still paints shoulder_t0 until that cut is real art.
    const shoulderDebt = {'shoulder_t0', 'shoulder_t2'};
    final shared = (catalog['shared'] as Map).cast<String, dynamic>();
    final family = (catalog['family'] as Map).cast<String, dynamic>();

    void expectUnique(Map<String, List<String>> pairs, {required bool familyArt}) {
      final grouped = <String, List<String>>{};
      for (final entry in pairs.entries) {
        grouped.putIfAbsent(entry.value.join('|'), () => []).add(entry.key);
      }
      for (final ids in grouped.values) {
        if (ids.length < 2) continue;
        if (familyArt && ids.toSet().containsAll(shoulderDebt) && ids.length == 2) {
          continue;
        }
        fail('models share one picture: ${ids.join(', ')}');
      }
    }

    final sharedPairs = <String, List<String>>{};
    for (final ids in shared.values) {
      for (final id in (ids as List).cast<String>()) {
        final overlay = OwnedGearAssets.pathFor(
          visualSetId: id,
          family: BodyFamily.warrior,
          anim: HeroAnimKind.idle,
        );
        expect(overlay, isNotNull, reason: id);
        sharedPairs[id] = [overlay!, overlay.replaceFirst('_idle.png', '_icon.png')];
      }
    }
    expectUnique(sharedPairs, familyArt: false);

    for (final familyId in BodyFamily.values) {
      final pairs = <String, List<String>>{};
      for (final entry in family.entries) {
        for (final id in (entry.value as List).cast<String>()) {
          final overlay = OwnedGearAssets.pathFor(
            visualSetId: id,
            family: familyId,
            anim: HeroAnimKind.idle,
          );
          expect(overlay, isNotNull, reason: '$familyId $id');
          pairs['$familyId:$id'] = [
            overlay!,
            overlay.replaceFirst('_idle.png', '_icon.png'),
          ];
        }
      }
      expectUnique(pairs, familyArt: true);
    }
  });
}
