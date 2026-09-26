/// Where the party is. Picks the resting bed, not the fight cue.
enum MusicPlace { none, hub, dungeon }

/// What the score is doing. Boss holds until the fight ends. Bed and rest
/// trade off so a short loop is not the whole session. Resolve and down are
/// one-shots: a floor clear lands, a wipe falls, then the ear gets quiet.
enum MusicCue { rest, bed, boss, resolve, down }

/// Which file should be audible. [none] means ambience only.
enum MusicStem { none, hub, dungeon, boss, resolve, down }

/// Adaptive score clock. Pure — no audio engine. Times are long enough that
/// hub (~34s) and cave beds are heard once, then sit out, so they do not
/// grind. A boss interrupts immediately and does not resolve until the
/// fight ends.
class MusicScore {
  MusicPlace place = MusicPlace.none;
  MusicCue cue = MusicCue.rest;

  /// Floor whose clear is still resolving. Boss sync will not snap back
  /// while the party is still standing on that floor.
  int? holdFloor;

  DateTime anchor = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _quietFor = hubQuiet;

  static const hubBed = Duration(seconds: 32);
  static const hubQuiet = Duration(seconds: 46);
  static const dungeonBed = Duration(seconds: 48);
  static const dungeonQuiet = Duration(seconds: 44);
  static const resolveCue = Duration(milliseconds: 6500);
  static const downCue = Duration(milliseconds: 4800);
  static const clearQuiet = Duration(seconds: 18);
  static const wipeQuiet = Duration(seconds: 28);

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
    cue = MusicCue.rest;
    holdFloor = null;
    anchor = DateTime.fromMillisecondsSinceEpoch(0);
    _quietFor = hubQuiet;
  }

  /// Scene change (hub ↔ cave). Starts that place's bed so the new room
  /// is heard, then the rest cycle takes over.
  bool setPlace(MusicPlace next, DateTime now) {
    if (next == place) return false;
    place = next;
    holdFloor = null;
    if (next == MusicPlace.none) {
      _enter(MusicCue.rest, now, quiet: hubQuiet);
    } else {
      _enter(MusicCue.bed, now);
    }
    return true;
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

  /// Stairs opened on [floor]. One resolution, then quiet.
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

  /// Party wiped. Falling phrase, then a longer quiet than a clear.
  bool noteWipe(DateTime now) {
    holdFloor = null;
    if (cue == MusicCue.down) return false;
    _enter(MusicCue.down, now);
    return true;
  }

  /// Advance bed / quiet / sting clocks. Boss does not advance itself.
  bool tick(DateTime now) {
    if (place == MusicPlace.none || cue == MusicCue.boss) return false;
    final elapsed = now.difference(anchor);
    switch (cue) {
      case MusicCue.bed:
        final limit = place == MusicPlace.hub ? hubBed : dungeonBed;
        if (elapsed < limit) return false;
        _enter(
          MusicCue.rest,
          now,
          quiet: place == MusicPlace.hub ? hubQuiet : dungeonQuiet,
        );
        return true;
      case MusicCue.rest:
        if (elapsed < _quietFor) return false;
        _enter(MusicCue.bed, now);
        return true;
      case MusicCue.resolve:
        if (elapsed < resolveCue) return false;
        holdFloor = null;
        _enter(MusicCue.rest, now, quiet: clearQuiet);
        return true;
      case MusicCue.down:
        if (elapsed < downCue) return false;
        _enter(MusicCue.rest, now, quiet: wipeQuiet);
        return true;
      case MusicCue.boss:
        return false;
    }
  }

  void _enter(MusicCue next, DateTime now, {Duration? quiet}) {
    cue = next;
    anchor = now;
    if (quiet != null) _quietFor = quiet;
  }
}
