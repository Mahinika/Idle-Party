import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';

/// Custom dungeon PNGs must ship in the asset bundle — not only on disk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all custom dungeon zones list PNGs in AssetManifest', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets().toSet();
    for (final path in CustomAssets.customDungeonAssetPaths) {
      expect(
        keys,
        contains(path),
        reason: 'bundle missing $path — pubspec + flutter pub get',
      );
    }
  });

  test('all custom dungeon PNGs exist on disk', () {
    for (final zoneId in CustomAssets.customDungeonZones) {
      for (final path in CustomAssets.dungeonAssetPathsFor(zoneId)) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });
}
