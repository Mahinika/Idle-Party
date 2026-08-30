import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/audio_assets.dart';
import 'package:idle_party/core/game_audio.dart';
import 'package:idle_party/core/game_logic.dart';

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

  test('hit SFX is rate-limited', () {
    GameAudio.debugReset();
    GameAudio.muted = false;
    for (var i = 0; i < 20; i++) {
      GameAudio.hit();
    }
    expect(GameAudio.debugPlayCount, lessThan(20));
    expect(GameAudio.debugPlayCount, greaterThanOrEqualTo(1));
  });

  test('sfx and ambience volumes round-trip in save JSON', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 30))
        .copyWith(sfxVolume: 0.35, ambienceVolume: 0.15, soundMuted: false);
    final decoded = GameLogic.stateFromJson(state.toJson());
    expect(decoded.sfxVolume, closeTo(0.35, 0.001));
    expect(decoded.ambienceVolume, closeTo(0.15, 0.001));
    expect(decoded.soundMuted, isFalse);
  });
}
