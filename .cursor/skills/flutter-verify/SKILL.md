---
name: flutter-verify
description: >-
  Runs Idle Party's Flutter verify loop (pub get, analyze zero issues,
  tests, optional web run). Use when verifying changes, before a PR,
  after combat/kit/save edits, or when the user says verify, analyze,
  or run tests.
---

# Flutter verify (Idle Party)

## Loop

Run from repo root, in order:

```bash
flutter pub get
flutter analyze
flutter test
```

Optional live check:

```bash
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

## Rules

- **Hold `flutter analyze` to zero issues** before considering work done.
- Prefer targeted tests while iterating, then full `flutter test` before handoff:
  - kits/combat → `test/class_kits_combat_test.dart`, `test/kit_passives_test.dart`, related `*_abilities_test.dart`
  - balance iterate → `test/class_balance_share_fast_test.dart` (`--share-only` / `--focus=`); CI gate → `class_balance_gate_test`
  - changelog → `test/changelog_sync_test.dart`
  - save/meta → `test/save_load_test.dart`, `test/meta_systems_test.dart`
  - assets/dungeons → `test/asset_catalog_test.dart`, `test/custom_assets_test.dart`, `test/dungeon_environment_test.dart`
- Use `GameDirector.preview()` in new tests (no SharedPreferences / no spatial timer).
- Do not commit unless the user asks.

## Progress

```
Verify:
- [ ] flutter pub get
- [ ] flutter analyze (0 issues)
- [ ] targeted tests (if iterating)
- [ ] flutter test
- [ ] optional web run
```
