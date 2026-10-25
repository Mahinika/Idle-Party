import 'audio_assets.dart';

/// Where the party is. Picks the bed, not the fight cue.
enum MusicPlace { none, hub, dungeon }

/// What the score is doing. A bed stays on while you stay in that place
/// and hands off to the next song when the file ends. Boss holds until the
/// fight ends. Resolve and down are one-shots, then the bed returns.
enum MusicCue { rest, bed, boss, resolve, down }

/// Which file should be audible. [none] means ambience only.
enum MusicStem { none, hub, dungeon, boss, resolve, down }

/// Adaptive score clock. Pure — no audio engine. Hub and cave music do not
/// go quiet between songs. A boss interrupts immediately and does not
/// resolve until the fight ends.
class MusicScore {
  MusicPlace place = MusicPlace.none;
  ZoneMood mood = ZoneMood.warm;
  MusicCue cue = MusicCue.rest;

  /// Floor whose clear is still resolving. Boss sync will not snap back
  /// while the party is still standing on that floor.
  int? holdFloor;

  DateTime anchor = DateTime.fromMillisecondsSinceEpoch(0);

  /// How long the current song should be heard. Set from the file length.
  /// Null uses [hubBed] / [dungeonBed].
  Duration? bedLimit;

  static const hubBed = Duration(seconds: 32);
  static const dungeonBed = Duration(seconds: 48);
  static const resolveCue = Duration(milliseconds: 6500);
  static const downCue = Duration(milliseconds: 4800);

  MusicStem get stem => switch (cue) {
    MusicCue.rest => MusicStem.none,
    MusicCue.bed => switch (place) {
      MusicPlace.hub => MusicStem.hub,
      MusicPlace.dungeon => MusicStem.dungeon,
      MusicPlace.none => MusicStem.none,
    },
    MusicCue.boss => MusicStem.boss,
    MusicCue.resolve => MusicStem.resolve,
    MusicCue.down => MusicStem.down,
  };

  void reset() {
    place = MusicPlace.none;
    mood = ZoneMood.warm;
    cue = MusicCue.rest;
    holdFloor = null;
    anchor = DateTime.fromMillisecondsSinceEpoch(0);
    bedLimit = null;
  }

  /// Length of the song that just started, from the beginning of the file.
  void setBedLimit(Duration value) {
    bedLimit = value < const Duration(seconds: 4)
        ? const Duration(seconds: 4)
        : value;
  }

  /// Scene change (hub ↔ cave). Starts that place's bed.
  bool setPlace(MusicPlace next, DateTime now) {
    if (next == place) return false;
    place = next;
    holdFloor = null;
    bedLimit = null;
    if (next == MusicPlace.none) {
      _enter(MusicCue.rest, now);
    } else {
      _enter(MusicCue.bed, now);
    }
    return true;
  }

  /// Cave family. True when the audible dungeon bed should change.
  bool setMood(ZoneMood next) {
    if (next == mood) return false;
    mood = next;
    bedLimit = null;
    return place == MusicPlace.dungeon;
  }

  /// [active] while a boss, rift guardian, greater-rift guardian, or
  /// Ashen fight is up. Same-floor clears keep their resolution.
  bool syncBoss({
    required bool active,
    required int floor,
    required DateTime now,
  }) {
    if (place != MusicPlace.dungeon) return false;
    if (holdFloor != null) {
      if (floor == holdFloor) return false;
      holdFloor = null;
    }
    if (cue == MusicCue.down && !active) return false;
    if (active && cue != MusicCue.boss) {
      _enter(MusicCue.boss, now);
      return true;
    }
    if (!active && cue == MusicCue.boss) {
      _enter(MusicCue.resolve, now);
      return true;
    }
    return false;
  }

  /// Stairs opened on [floor]. One resolution, then the bed.
  bool noteClear(int floor, DateTime now) {
    if (place != MusicPlace.dungeon) return false;
    if (cue == MusicCue.resolve) {
      holdFloor = floor;
      return false;
    }
    holdFloor = floor;
    _enter(MusicCue.resolve, now);
    return true;
  }

  /// Party wiped. Falling phrase, then the bed.
  bool noteWipe(DateTime now) {
    holdFloor = null;
    if (cue == MusicCue.down) return false;
    _enter(MusicCue.down, now);
    return true;
  }

  /// Advance bed and sting clocks. A finished bed stays on the same stem
  /// so the next song can start. Boss does not advance itself.
  bool tick(DateTime now) {
    if (place == MusicPlace.none || cue == MusicCue.boss) return false;
    final elapsed = now.difference(anchor);
    switch (cue) {
      case MusicCue.bed:
        final limit =
            bedLimit ?? (place == MusicPlace.hub ? hubBed : dungeonBed);
        if (elapsed < limit) return false;
        bedLimit = null;
        _enter(MusicCue.bed, now);
        return true;
      case MusicCue.rest:
        return false;
      case MusicCue.resolve:
        if (elapsed < resolveCue) return false;
        holdFloor = null;
        bedLimit = null;
        _enter(MusicCue.bed, now);
        return true;
      case MusicCue.down:
        if (elapsed < downCue) return false;
        bedLimit = null;
        _enter(MusicCue.bed, now);
        return true;
      case MusicCue.boss:
        return false;
    }
  }

  void _enter(MusicCue next, DateTime now) {
    cue = next;
    anchor = now;
  }
}
