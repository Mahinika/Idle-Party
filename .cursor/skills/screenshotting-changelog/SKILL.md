---
name: screenshotting-changelog
description: >-
  Visual and copy honesty for What's New: screenshot MORE flow and confirm
  MetaSystems bullets match shipped features. Use before a release PR, version
  bump, or when release notes feel wrong. Do not use for pure logic-only changes
  without a version bump (still run changelog_sync_test if version changed).
---

# Screenshot changelog (Idle Party)

Use when preparing a release or polish PR that touches UI or player-facing systems.

## Honesty checks (code)

```bash
flutter test test/changelog_sync_test.dart
```

Must hold:

- `MetaSystems.currentVersion` == `pubspec.yaml` versionName
- Newest `releases` block == `currentVersion`
- Shipped zones (tide/ember) mentioned in current bullets
- Newest bullets joined uppercase contain `GREATER` (`ship_smoke_test` — World Path boilerplate is not enough)

## Visual capture

1. Live look on **Samsung A56 emulator** ([a56-playtest](../a56-playtest/SKILL.md)).
   Web `:8080` only if the emulator cannot run.
2. Fresh or returning save so What’s New can appear (`seenChangelogVersion` older than current).
3. Screenshot:
   - Auto What’s New dialog (if shown)
   - Hub with `★` on **MORE** badge
   - Guides / World Path if zones changed
4. Optional: compare base branch vs feature branch (stash/checkout) for hub weekly row / GEAR tab labels.

## PR body snippet

```markdown
## What’s New / visual
- Version: x.y.z — bullets cover: …
- Screenshots: (attach hub What’s New + MORE badge)
```

## Skip when

- Pure combat coeff / no UI or changelog impact — still run `changelog_sync_test` if version bumped
