---
name: flutter-verify
description: >-
  Runs Idle Party's Flutter verify loop (pub get, analyze zero issues, tests,
  optional A56 look). Use when verifying changes, before a PR, after
  combat/kit/save edits, or when the owner says "does it work?" / "funkar
  det?" / "kör testerna" / verify / analyze. Do not use for Play Store ops
  (play-store-prep) or grinding a red balance gate (grinding-until-pass).
---

# Flutter verify (Idle Party)

## Loop

Run from repo root, in order:

```bash
flutter pub get
flutter analyze lib test --no-fatal-infos
# Before push: targeted tests + whole golden files for touched screens.
# Full suite: flutter test --exclude-tags sim (GitHub CI before merge).
```

Optional live look (UI chrome): follow **a56-playtest** (Samsung A56
emulator). Do not start a web-server for the owner.

Optional MCP shortcut when `user-idle-party` is up: `verify`.

## Rules

- **Hold `flutter analyze lib test --no-fatal-infos` to zero issues** before considering work done.
- Prefer targeted tests while iterating. Before push, run analyze plus targeted tests and whole golden files for touched screens. The full `flutter test --exclude-tags sim` suite is CI before merge (tag `sim` runs nightly):
  - kits/combat → `test/class_kits_combat_test.dart`, `test/kit_passives_test.dart`, related `*_abilities_test.dart`
  - balance iterate → `flutter test test/class_balance_share_fast_test.dart` (tagged `sim`, so run it by path; focus specs with MCP `balance_share`); CI gate → `class_balance_gate_test`
  - changelog → `test/changelog_sync_test.dart`
  - save/meta → `test/save_load_test.dart`, `test/meta_systems_test.dart`
  - assets/dungeons → `test/asset_catalog_test.dart`, `test/custom_assets_test.dart`, `test/dungeon_environment_test.dart`
- Use `GameDirector.preview()` in new tests (no SharedPreferences / no spatial timer).
- **Commit locally when analyze/tests are green** (`20-how-we-work`). Hand off on a branch and a PR. Do not merge, and do not push a `test-*` or `v*` tag, unless the owner asks in that turn.
- Windows: set process env `PROGRAMFILES(X86)` to `C:\Program Files (x86)` or `flutter test` dies. Widget `timersPending` / missing `flutter_soloud_plugin.dll` on this machine is environment noise — do not “fix” GEAR/GOLD for it.

## Progress

```
Verify:
- [ ] flutter pub get
- [ ] flutter analyze lib test --no-fatal-infos (0 issues)
- [ ] targeted tests (if iterating)
- [ ] targeted tests + whole golden files for touched screens (full suite in CI)
- [ ] optional A56 emulator look (UI only)
- [ ] commit locally when green
```

## Done when

- Analyze has zero issues; targeted tests and golden files for this batch are green (full suite green in CI before merge).
- The matching extra tests from `30-done` for this change are green.
