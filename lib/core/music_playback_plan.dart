import 'audio_assets.dart';
import 'music_score.dart';

/// Pure rules for whether background music playback matches [MusicScore].
/// GameAudio uses this so lifecycle, ads, and settings share one plan.
abstract final class MusicPlaybackPlan {
  static const double silentMusicVolume = 0.01;

  /// Stem that should be audible given score + user settings.
  static MusicStem targetStem({
    required MusicScore score,
    required bool muted,
    required double musicVolume,
  }) {
    if (muted || musicVolume <= silentMusicVolume) return MusicStem.none;
    return score.stem;
  }

  /// True when the engine stem/handle state matches what the score wants.
  static bool musicMatches({
    required MusicScore score,
    required MusicStem playing,
    required bool musicHandleLive,
    required ZoneMood audibleMood,
    required bool muted,
    required double musicVolume,
  }) {
    final want = targetStem(
      score: score,
      muted: muted,
      musicVolume: musicVolume,
    );
    if (want == MusicStem.none) {
      return playing == MusicStem.none && !musicHandleLive;
    }
    if (want == MusicStem.dungeon && audibleMood != score.mood) return false;
    return playing == want && musicHandleLive;
  }

  /// True when hub/dungeon air should be running (not mute / lifecycle).
  static bool shouldPlayBackground({
    required bool engineReady,
    required bool muted,
    required bool backgroundPaused,
  }) =>
      engineReady && !muted && !backgroundPaused;

  /// Whether [setAmbience] can skip a full restart (place/boss/mood unchanged).
  static bool canSkipAmbienceRestart({
    required bool forceRestart,
    required bool placeChanged,
    required bool bossChanged,
    required bool moodChanged,
    required bool sameKind,
    required bool ambienceHandleLive,
    required bool musicInSync,
  }) =>
      !forceRestart &&
      !placeChanged &&
      !bossChanged &&
      !moodChanged &&
      sameKind &&
      ambienceHandleLive &&
      musicInSync;
}