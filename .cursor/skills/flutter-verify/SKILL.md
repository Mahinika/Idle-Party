---
name: flutter-verify
description: >-
  Runs Idle Party's Flutter verify loop (pub get, analyze zero issues, tests,
  optional A56 look). Use when verifying changes, before a PR, after
  combat/kit/save edits, or when the owner says "does it work?" / verify /
  analyze / run tests. Do not use for Play Store ops (play-store-prep).
---

# Flutter verify (Idle Party)

## Loop

Run from repo root, in order:

```bash
flutter pub get
flutter analyze lib test --no-fatal-infos
flutter test
```

Optional live look (UI chrome): follow **a56-playtest** (Samsung A56
emulator). Do not start a web-server for the owner.

Optional MCP shortcut when `user-idle-party` is up: `verify`.

## Rules

- **Hold `flutter analyze lib test --no-fatal-infos` to zero issues** before considering work done.
- Prefer targeted tests while iterating, then full `flutter test` before handoff:
  - kits/combat → `test/class_kits_combat_test.dart`, `test/kit_passives_test.dart`, related `*_abilities_test.dart`
  - balance iterate → `test/class_balance_share_fast_test.dart` (`--share-only` / `--focus=`); CI gate → `class_balance_gate_test`
  - changelog → `test/changelog_sync_test.dart`
  - save/meta → `test/save_load_test.dart`, `test/meta_systems_test.dart`
  - assets/dungeons → `test/asset_catalog_test.dart`, `test/custom_assets_test.dart`, `test/dungeon_environment_test.dart`
- Use `GameDirector.preview()` in new tests (no SharedPreferences / no spatial timer).
- **Commit locally when analyze/tests are green** (`owner-preferences`). Ask before push / PR / tag / Play.

## Progress

```
Verify:
- [ ] flutter pub get
- [ ] flutter analyze lib test --no-fatal-infos (0 issues)
- [ ] targeted tests (if iterating)
- [ ] flutter test
- [ ] optional A56 emulator look (UI only)
- [ ] commit locally when green
```
