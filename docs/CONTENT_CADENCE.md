# Idle Party — monthly content cadence

Operational rhythm for solo / small-time shipping. Ties to the yearly plan in [ROADMAP.md](ROADMAP.md) (Q4 “Månadsrytm”).

## Cadence (every 2–4 weeks; aim monthly)

Each tagged `1.x.y` release should include:

1. **Balance pass** — run live + mid sims (`tool/sim_class_balance.dart`, `MODE=live` / mid-band) before kit nerfs/buffs; keep share within the live light band when practical; document mid-caster risk if left HIGH.
2. **Content slice** — one player-visible piece: dungeon beat, kit identity, meta sink, Weekly/Gauntlet beat, or a11y/save polish. Prefer one hero feature per quarter (see ROADMAP).
3. **Release notes** — What’s New bullets in `lib/core/meta_systems.dart` (`MetaSystems.releases` + `currentVersion`); keep tag ↔ `pubspec.yaml` ↔ GitHub Release in sync.

## Checklist before tagging

- [ ] `flutter analyze` clean; `flutter test` green (CI on push).
- [ ] Kit / combat changes exercised via SpatialCombat path (live + offline share the same step).
- [ ] Changelog entry for this version; `seenChangelogVersion` will auto-prompt What’s New.
- [ ] If Android: AAB/APK from tag workflow or local `flutter build appbundle` (see [PLAY_STORE.md](PLAY_STORE.md)).

## Out of cadence

Do not couple rewrites of SpatialCombat, new account servers, or commercial art dumps to the monthly train. Stretch (Windows zip, score-share image) stays optional per ROADMAP Q4.
