import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/audio_assets.dart';
import 'package:idle_party/core/game_audio.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/spell_bolt_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio asset catalog files exist', () {
    for (final path in AudioAssets.allCatalogPaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('mute blocks GameAudio play counting', () {
    GameAudio.debugReset();
    GameAudio.muted = true;
    GameAudio.hit();
    GameAudio.ui();
    expect(GameAudio.debugPlayCount, 0);

    GameAudio.muted = false;
    GameAudio.ui();
    expect(GameAudio.debugPlayCount, 1);
  });

  test('combat feel SFX is rate-limited per id (~3s)', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    for (var i = 0; i < 20; i++) {
      GameAudio.play('hit_blade');
    }
    expect(GameAudio.debugPlayCount, 1);

    GameAudio.play('spell_fire');
    expect(GameAudio.debugPlayCount, 2);

    for (var i = 0; i < 10; i++) {
      GameAudio.play('spell_fire');
    }
    expect(GameAudio.debugPlayCount, 2);
  });

  test('ui SFX is not combat-feel rate-limited', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    for (var i = 0; i < 5; i++) {
      GameAudio.ui();
    }
    expect(GameAudio.debugPlayCount, 5);
  });

  test('combatHitId maps weapons and spell schools', () {
    expect(
      AudioAssets.combatHitId(weaponType: WeaponType.sword),
      'hit_blade',
    );
    expect(AudioAssets.combatHitId(weaponType: WeaponType.axe), 'hit_axe');
    expect(AudioAssets.combatHitId(weaponType: WeaponType.mace), 'hit_blunt');
    expect(
      AudioAssets.combatHitId(weaponType: WeaponType.dagger),
      'hit_dagger',
    );
    expect(AudioAssets.combatHitId(weaponType: WeaponType.fist), 'hit_fist');
    expect(AudioAssets.combatHitId(weaponType: WeaponType.bow), 'hit_bow');
    expect(
      AudioAssets.combatHitId(style: SpellBoltStyle.fire),
      'spell_fire',
    );
    expect(
      AudioAssets.combatHitId(style: SpellBoltStyle.frost),
      'spell_frost',
    );
    expect(
      AudioAssets.combatHitId(style: SpellBoltStyle.lightning),
      'spell_lightning',
    );
    expect(
      AudioAssets.combatHitId(style: SpellBoltStyle.arrow),
      'hit_bow',
    );
  });

  test('sfx, ambience, and music volumes round-trip in save JSON', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 30))
        .copyWith(
          sfxVolume: 0.35,
          ambienceVolume: 0.15,
          musicVolume: 0.65,
          soundMuted: false,
        );
    final decoded = GameLogic.stateFromJson(state.toJson());
    expect(decoded.sfxVolume, closeTo(0.35, 0.001));
    expect(decoded.ambienceVolume, closeTo(0.15, 0.001));
    expect(decoded.musicVolume, closeTo(0.65, 0.001));
    expect(decoded.soundMuted, isFalse);
  });
}
