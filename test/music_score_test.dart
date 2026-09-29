import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/audio_assets.dart';
import 'package:idle_party/core/music_score.dart';

void main() {
  final t0 = DateTime(2026, 9, 26, 12);

  MusicScore hub() {
    final score = MusicScore();
    score.setPlace(MusicPlace.hub, t0);
    return score;
  }

  MusicScore cave() {
    final score = MusicScore();
    score.setPlace(MusicPlace.dungeon, t0);
    return score;
  }

  test('hub bed plays once then rests, then returns', () {
    final score = hub();
    expect(score.cue, MusicCue.bed);
    expect(score.stem, MusicStem.hub);

    expect(
      score.tick(t0.add(MusicScore.hubBed - const Duration(seconds: 1))),
      isFalse,
    );
    expect(score.tick(t0.add(MusicScore.hubBed)), isTrue);
    expect(score.cue, MusicCue.rest);
    expect(score.stem, MusicStem.none);

    final rested = t0.add(MusicScore.hubBed);
    expect(
      score.tick(rested.add(MusicScore.hubQuiet - const Duration(seconds: 1))),
      isFalse,
    );
    expect(score.tick(rested.add(MusicScore.hubQuiet)), isTrue);
    expect(score.cue, MusicCue.bed);
    expect(score.stem, MusicStem.hub);
  });

  test('a new cave mood asks the dungeon bed to change', () {
    final score = cave();
    expect(score.setMood(ZoneMood.warm), isFalse);
    expect(score.setMood(ZoneMood.ice), isTrue);
    expect(score.mood, ZoneMood.ice);
    expect(score.stem, MusicStem.dungeon);
  });

  test('cave bed uses the dungeon stem and its own clock', () {
    final score = cave();
    expect(score.stem, MusicStem.dungeon);
    expect(score.tick(t0.add(MusicScore.dungeonBed)), isTrue);
    expect(score.stem, MusicStem.none);
    final rested = t0.add(MusicScore.dungeonBed);
    expect(score.tick(rested.add(MusicScore.dungeonQuiet)), isTrue);
    expect(score.stem, MusicStem.dungeon);
  });

  test('boss holds through the rest clock', () {
    final score = cave();
    expect(
      score.syncBoss(
        active: true,
        floor: 5,
        now: t0.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
    expect(score.stem, MusicStem.boss);
    expect(score.tick(t0.add(const Duration(minutes: 10))), isFalse);
    expect(score.cue, MusicCue.boss);
  });

  test('clear on a boss floor resolves and does not snap back', () {
    final score = cave();
    score.syncBoss(active: true, floor: 5, now: t0);
    final cleared = t0.add(const Duration(seconds: 40));
    expect(score.noteClear(5, cleared), isTrue);
    expect(score.stem, MusicStem.resolve);
    expect(
      score.syncBoss(
        active: true,
        floor: 5,
        now: cleared.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(score.cue, MusicCue.resolve);

    expect(
      score.noteClear(5, cleared.add(const Duration(seconds: 2))),
      isFalse,
    );
    expect(score.anchor, cleared);
  });

  test('next trash floor keeps the resolution, then quiet, then the bed', () {
    final score = cave();
    score.syncBoss(active: true, floor: 5, now: t0);
    final cleared = t0.add(const Duration(seconds: 20));
    score.noteClear(5, cleared);
    expect(
      score.syncBoss(
        active: false,
        floor: 6,
        now: cleared.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(score.cue, MusicCue.resolve);

    expect(score.tick(cleared.add(MusicScore.resolveCue)), isTrue);
    expect(score.cue, MusicCue.rest);
    final quiet = cleared.add(MusicScore.resolveCue);
    expect(score.tick(quiet.add(MusicScore.clearQuiet)), isTrue);
    expect(score.stem, MusicStem.dungeon);
  });

  test('walking onto a boss floor cuts the resolution', () {
    final score = cave();
    score.noteClear(4, t0.add(const Duration(seconds: 10)));
    expect(score.cue, MusicCue.resolve);
    expect(
      score.syncBoss(
        active: true,
        floor: 5,
        now: t0.add(const Duration(seconds: 11)),
      ),
      isTrue,
    );
    expect(score.stem, MusicStem.boss);
  });

  test('wipe falls, stays quiet longer, and a retry boss interrupts', () {
    final score = cave();
    score.syncBoss(active: true, floor: 5, now: t0);
    final wiped = t0.add(const Duration(seconds: 15));
    expect(score.noteWipe(wiped), isTrue);
    expect(score.stem, MusicStem.down);
    expect(
      score.syncBoss(
        active: false,
        floor: 5,
        now: wiped.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(score.cue, MusicCue.down);

    expect(score.tick(wiped.add(MusicScore.downCue)), isTrue);
    expect(score.cue, MusicCue.rest);
    final quiet = wiped.add(MusicScore.downCue);
    expect(score.tick(quiet.add(MusicScore.clearQuiet)), isFalse);
    expect(score.tick(quiet.add(MusicScore.wipeQuiet)), isTrue);
    expect(score.stem, MusicStem.dungeon);

    final again = cave();
    again.noteWipe(t0);
    expect(
      again.syncBoss(
        active: true,
        floor: 5,
        now: t0.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
    expect(again.stem, MusicStem.boss);
  });

  test('a boss that ends without stairs still resolves', () {
    final score = cave();
    score.syncBoss(active: true, floor: 3, now: t0);
    expect(
      score.syncBoss(
        active: false,
        floor: 3,
        now: t0.add(const Duration(seconds: 8)),
      ),
      isTrue,
    );
    expect(score.stem, MusicStem.resolve);
  });

  test('leaving for the hub starts the hub bed', () {
    final score = cave();
    score.syncBoss(active: true, floor: 5, now: t0);
    expect(
      score.setPlace(MusicPlace.hub, t0.add(const Duration(seconds: 4))),
      isTrue,
    );
    expect(score.stem, MusicStem.hub);
    expect(score.holdFloor, isNull);
  });
}
