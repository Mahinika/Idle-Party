import 'dart:math';

import 'audio_assets.dart';

/// One weighted clip entry in a combat / UI variation bank.
class AudioVariation {
  const AudioVariation({
    required this.id,
    required this.path,
    this.pitchMin = 0.97,
    this.pitchMax = 1.03,
    this.volumeMin = 0.92,
    this.volumeMax = 1.08,
    this.weight = 1.0,
  });

  final String id;
  final String path;
  final double pitchMin;
  final double pitchMax;
  final double volumeMin;
  final double volumeMax;
  final double weight;

  double rollPitch(Random rng) =>
      pitchMin + rng.nextDouble() * (pitchMax - pitchMin);

  double rollVolume(Random rng) =>
      volumeMin + rng.nextDouble() * (volumeMax - volumeMin);
}

/// Weighted pool of clips for one play id (`spell_fire`, `hit_blade`, …).
class AudioVariationBank {
  AudioVariationBank(this.variations);

  final List<AudioVariation> variations;

  /// Last index played, so the same take never fires twice in a row.
  int? _lastIndex;

  bool get isEmpty => variations.isEmpty;

  void forget() {
    _lastIndex = null;
  }

  /// Weighted random; [heavy] biases toward later (aggressiver) variants.
  /// With two or more takes, the previous take is skipped.
  AudioVariation pick(Random rng, {bool heavy = false}) {
    if (variations.isEmpty) {
      throw StateError('AudioVariationBank is empty');
    }
    if (variations.length == 1) {
      _lastIndex = 0;
      return variations.first;
    }

    var total = 0.0;
    final weights = List<double>.generate(variations.length, (i) {
      if (i == _lastIndex) return 0.0;
      final base = variations[i].weight;
      if (!heavy) return base;
      // Later letters → slightly heavier transient profile.
      final heavyBias = 1.0 + (i / variations.length) * 0.45;
      return base * heavyBias;
    });
    for (final w in weights) {
      total += w;
    }
    var chosen = 0;
    if (total <= 0) {
      chosen = (_lastIndex! + 1) % variations.length;
    } else {
      var roll = rng.nextDouble() * total;
      for (var i = 0; i < variations.length; i++) {
        if (weights[i] <= 0) continue;
        if (roll < weights[i]) {
          chosen = i;
          break;
        }
        roll -= weights[i];
        chosen = i;
      }
    }
    _lastIndex = chosen;
    return variations[chosen];
  }
}

/// Static banks built from [AudioAssets.sfxVariants] + per-index profiles.
abstract final class AudioVariationCatalog {
  static final Map<String, AudioVariationBank> banks = _buildBanks();

  static void resetMemory() {
    for (final bank in banks.values) {
      bank.forget();
    }
  }

  static Map<String, AudioVariationBank> _buildBanks() {
    final out = <String, AudioVariationBank>{};
    for (final entry in AudioAssets.sfxVariants.entries) {
      out[entry.key] = _bankFor(entry.key, entry.value);
    }
    return out;
  }

  static AudioVariationBank _bankFor(String playId, List<String> paths) {
    if (paths.isEmpty) return AudioVariationBank(const []);

    final isSpell =
        playId.startsWith('spell_') || playId.startsWith('cast_');
    final isHit = playId.startsWith('hit');
    final isSwish = playId.startsWith('swish_');

    final vars = <AudioVariation>[];
    for (var i = 0; i < paths.length; i++) {
      final letter = String.fromCharCode(97 + i);
      final t = paths.length <= 1 ? 0.0 : i / (paths.length - 1);

      // Spread pitch/volume slightly per variant index.
      final pitchSpread = isSpell ? 0.06 : (isHit ? 0.05 : 0.04);
      final volSpread = isSpell ? 0.10 : (isHit ? 0.08 : 0.06);
      final pitchCenter = isSpell ? 1.0 + (t - 0.5) * 0.04 : 1.0;
      final volCenter = isSwish ? 0.95 : 1.0;

      vars.add(
        AudioVariation(
          id: '${playId}_$letter',
          path: paths[i],
          pitchMin: (pitchCenter - pitchSpread).clamp(0.88, 1.12),
          pitchMax: (pitchCenter + pitchSpread).clamp(0.88, 1.12),
          volumeMin: (volCenter - volSpread).clamp(0.75, 1.15),
          volumeMax: (volCenter + volSpread).clamp(0.75, 1.15),
          weight: isSpell && i >= paths.length - 2 ? 1.05 : 1.0,
        ),
      );
    }
    return AudioVariationBank(vars);
  }
}
