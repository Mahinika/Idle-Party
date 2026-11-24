import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/audio_assets.dart';
import 'package:idle_party/core/music_playback_plan.dart';
import 'package:idle_party/core/music_score.dart';

void main() {
  final t0 = DateTime(2026, 11, 24, 10);

  test('target stem rests when muted or music volume is zero', () {
    final score = MusicScore()..setPlace(MusicPlace.hub, t0);
    expect(
      MusicPlaybackPlan.targetStem(score: score, muted: true, musicVolume: 0.5),
      MusicStem.none,
    );
    expect(
      MusicPlaybackPlan.targetStem(score: score, muted: false, musicVolume: 0),
      MusicStem.none,
    );
    expect(
      MusicPlaybackPlan.targetStem(score: score, muted: false, musicVolume: 0.5),
      MusicStem.hub,
    );
  });

  test('music matches only when stem, mood, and live handle align', () {
    final score = MusicScore()..setPlace(MusicPlace.dungeon, t0);
    score.setMood(ZoneMood.ice);
    expect(
      MusicPlaybackPlan.musicMatches(
        score: score,
        playing: MusicStem.dungeon,
        musicHandleLive: true,
        audibleMood: ZoneMood.ice,
        muted: false,
        musicVolume: 0.22,
      ),
      isTrue,
    );
    expect(
      MusicPlaybackPlan.musicMatches(
        score: score,
        playing: MusicStem.dungeon,
        musicHandleLive: true,
        audibleMood: ZoneMood.warm,
        muted: false,
        musicVolume: 0.22,
      ),
      isFalse,
    );
    expect(
      MusicPlaybackPlan.musicMatches(
        score: score,
        playing: MusicStem.hub,
        musicHandleLive: true,
        audibleMood: ZoneMood.ice,
        muted: false,
        musicVolume: 0.22,
      ),
      isFalse,
    );
    expect(
      MusicPlaybackPlan.musicMatches(
        score: score,
        playing: MusicStem.dungeon,
        musicHandleLive: false,
        audibleMood: ZoneMood.ice,
        muted: false,
        musicVolume: 0.22,
      ),
      isFalse,
    );
  });

  test('skip ambience restart only when air and music are in sync', () {
    expect(
      MusicPlaybackPlan.canSkipAmbienceRestart(
        forceRestart: false,
        placeChanged: false,
        bossChanged: false,
        moodChanged: false,
        sameKind: true,
        ambienceHandleLive: true,
        musicInSync: true,
      ),
      isTrue,
    );
    expect(
      MusicPlaybackPlan.canSkipAmbienceRestart(
        forceRestart: false,
        placeChanged: false,
        bossChanged: false,
        moodChanged: false,
        sameKind: true,
        ambienceHandleLive: false,
        musicInSync: true,
      ),
      isFalse,
    );
    expect(
      MusicPlaybackPlan.canSkipAmbienceRestart(
        forceRestart: false,
        placeChanged: false,
        bossChanged: true,
        moodChanged: false,
        sameKind: true,
        ambienceHandleLive: true,
        musicInSync: true,
      ),
      isFalse,
    );
  });

  test('shouldPlayBackground respects mute, pause, and engine readiness', () {
    expect(
      MusicPlaybackPlan.shouldPlayBackground(
        engineReady: true,
        muted: false,
        backgroundPaused: false,
      ),
      isTrue,
    );
    expect(
      MusicPlaybackPlan.shouldPlayBackground(
        engineReady: false,
        muted: false,
        backgroundPaused: false,
      ),
      isFalse,
    );
    expect(
      MusicPlaybackPlan.shouldPlayBackground(
        engineReady: true,
        muted: true,
        backgroundPaused: false,
      ),
      isFalse,
    );
    expect(
      MusicPlaybackPlan.shouldPlayBackground(
        engineReady: true,
        muted: false,
        backgroundPaused: true,
      ),
      isFalse,
    );
  });
}