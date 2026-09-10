import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:idle_party/core/audio_assets.dart';
import 'package:idle_party/core/audio_variation_bank.dart';
import 'package:idle_party/core/combat_feel.dart';
import 'package:idle_party/core/game_audio.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/spell_bolt_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio asset catalog files exist', () {
    for (final path in AudioAssets.allCatalogPaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('hit families ship five mix variants', () {
    for (final id in <String>[
      'hit_blade',
      'hit_axe',
      'hit_blunt',
      'hit_dagger',
      'hit_fist',
      'hit_bow',
    ]) {
      final variants = AudioAssets.sfxVariants[id]!;
      expect(variants, hasLength(5), reason: id);
    }
    expect(AudioAssets.sfxVariants.containsKey('hit'), isFalse);
  });

  test('spells skip material layer policy in CombatFeel wiring', () {
    // Physical uses swish; spells do not — GameAudio also skips mat_* on spells.
    expect(CombatFeel.swishIdFor('hit_blade'), 'swish_melee');
    expect(CombatFeel.swishIdFor('spell_fire'), 'swish_bow');
  });

  test('spell families ship six mix variants', () {
    for (final id in AudioAssets.spellFeelIds) {
      final variants = AudioAssets.sfxVariants[id]!;
      expect(variants, hasLength(6), reason: id);
    }
  });

  test('variation catalog covers every sfx play id', () {
    for (final id in AudioAssets.sfxVariants.keys) {
      expect(AudioVariationCatalog.banks.containsKey(id), isTrue, reason: id);
      expect(
        AudioVariationCatalog.banks[id]!.variations,
        isNotEmpty,
        reason: id,
      );
    }
  });

  test('AudioVariationBank pick respects heavy bias', () {
    final bank = AudioVariationBank([
      AudioVariation(id: 'a', path: 'p/a.wav', weight: 1.0),
      AudioVariation(id: 'b', path: 'p/b.wav', weight: 1.0),
      AudioVariation(id: 'c', path: 'p/c.wav', weight: 1.0),
      AudioVariation(id: 'd', path: 'p/d.wav', weight: 1.0),
      AudioVariation(id: 'e', path: 'p/e.wav', weight: 1.0),
      AudioVariation(id: 'f', path: 'p/f.wav', weight: 1.0),
    ]);
    final rng = Random(42);
    var heavyLast = 0;
    var normalLast = 0;
    for (var i = 0; i < 200; i++) {
      if (bank.pick(rng, heavy: true).id == 'f') heavyLast++;
      if (bank.pick(Random(i), heavy: false).id == 'f') normalLast++;
    }
    expect(heavyLast, greaterThan(normalLast));
  });

  test('swish and material layer assets exist', () {
    for (final id in <String>[
      'swish_melee',
      'swish_bow',
      'mat_flesh',
      'mat_bone',
      'mat_wet',
      'mat_stone',
    ]) {
      expect(AudioAssets.sfxVariants.containsKey(id), isTrue, reason: id);
    }
  });

  test('CombatFeel distance gain falls off with range', () {
    expect(CombatFeel.distanceGain(0), closeTo(1.0, 0.01));
    expect(CombatFeel.distanceGain(8), lessThan(0.6));
    expect(CombatFeel.distanceGain(40), closeTo(0.28, 0.01));
  });

  test('CombatFeel maps archetypes to materials', () {
    expect(
      CombatFeel.materialFor(EnemyArchetype.swarm),
      CombatHitMaterial.wet,
    );
    expect(
      CombatFeel.materialFor(EnemyArchetype.glass),
      CombatHitMaterial.bone,
    );
    expect(
      CombatFeel.materialFor(EnemyArchetype.tank),
      CombatHitMaterial.stone,
    );
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

  test('SFX warm flag starts false until remaining assets load', () {
    GameAudio.debugReset();
    expect(GameAudio.sfxReady, isFalse);
  });

  test('combat feel SFX is rate-limited per id', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    for (var i = 0; i < 20; i++) {
      GameAudio.play('hit_blade');
    }
    expect(GameAudio.debugPlayCount, 1);

    GameAudio.debugReset();
    GameAudio.play('spell_fire');
    expect(GameAudio.debugPlayCount, 1);

    for (var i = 0; i < 10; i++) {
      GameAudio.play('spell_fire');
    }
    expect(GameAudio.debugPlayCount, 1);
  });

  test('combat window caps overlapping feel clips', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    GameAudio.play('hit_blade');
    expect(GameAudio.debugPlayCount, 1);
    // Same family gap blocks a second melee immediately.
    GameAudio.play('hit_axe');
    expect(GameAudio.debugPlayCount, 1);
  });

  test('loot SFX is rate-limited (~1.2s)', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    GameAudio.loot();
    GameAudio.loot();
    expect(GameAudio.debugPlayCount, 1);
  });

  test('unlock SFX is rate-limited (~2s)', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    GameAudio.unlock();
    GameAudio.unlock();
    expect(GameAudio.debugPlayCount, 1);
  });

  test('ui SFX is debounced (~80ms) but not combat-limited', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    for (var i = 0; i < 5; i++) {
      GameAudio.ui();
    }
    expect(GameAudio.debugPlayCount, 1);
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
      AudioAssets.combatHitId(style: SpellBoltStyle.demon),
      'spell_demon',
    );
    expect(
      AudioAssets.combatHitId(style: SpellBoltStyle.poison),
      'spell_poison',
    );
    expect(
      AudioAssets.combatHitId(style: SpellBoltStyle.arrow),
      'hit_bow',
    );
  });

  test('setMuted does not restart background when mute flag is unchanged', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    // Same value as current — must not force-restart (was restarting music
    // on every UI button via _syncDevicePrefs → setMuted(false)).
    GameAudio.setMuted(false);
    expect(GameAudio.muted, isFalse);
    expect(GameAudio.debugBackgroundStartCount, 0);

    GameAudio.setMuted(true);
    expect(GameAudio.muted, isTrue);
    // Stop path only — no start while muted / engine may be offline in tests.
    expect(GameAudio.debugBackgroundStartCount, 0);

    GameAudio.setMuted(true);
    expect(GameAudio.debugBackgroundStartCount, 0);
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

  test('new save defaults use softer audio mix', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 9, 10));
    expect(state.sfxVolume, closeTo(0.45, 0.001));
    expect(state.ambienceVolume, closeTo(0.20, 0.001));
    expect(state.musicVolume, closeTo(0.22, 0.001));
  });
}
