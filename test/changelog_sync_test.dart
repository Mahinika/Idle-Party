import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/dungeon_def.dart';

/// Keeps What’s New honest: pubspec ↔ MetaSystems ↔ shipped content tokens.
void main() {
  test('currentVersion matches pubspec versionName', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml missing version:');
    final pubVersion = match!.group(1)!;
    expect(
      MetaSystems.currentVersion,
      pubVersion,
      reason: 'Sync MetaSystems.currentVersion with pubspec versionName',
    );
  });

  test('releases newest block matches currentVersion', () {
    expect(MetaSystems.releases, isNotEmpty);
    expect(MetaSystems.releases.first.version, MetaSystems.currentVersion);
    expect(MetaSystems.releases.first.bullets, isNotEmpty);
  });

  test('current What’s New mentions shipped endgame zones', () {
    final bullets = MetaSystems.releases.first.bullets.join(' ').toLowerCase();
    final ids = DungeonCatalog.all.map((d) => d.id).toSet();
    if (ids.contains('tide')) {
      expect(
        bullets.contains('tide') || bullets.contains('tidehold'),
        isTrue,
        reason: 'tide dungeon shipped — mention Tidehold/Tide in What’s New',
      );
    }
    if (ids.contains('ember')) {
      expect(
        bullets.contains('ember') ||
            bullets.contains('ashen') ||
            bullets.contains('vault'),
        isTrue,
        reason: 'ember dungeon shipped — mention Ashen/Ember/Vault in What’s New',
      );
    }
  });
}
