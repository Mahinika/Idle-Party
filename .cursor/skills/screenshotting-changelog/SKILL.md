---
name: screenshotting-changelog
description: >-
  Writes Idle Party Patch Notes (MORE → INFO → PATCH NOTES) and checks they
  match the build. Use on a version bump, release notes, "patch notes",
  "what's new", or "versionsnotering". Do not use for a combat-only number
  tweak with no version bump (still run changelog_sync_test if the version
  changed).
---

# Patch notes (Idle Party)

Player-facing name is **PATCH NOTES**. English in the game. Edit the newest
block in `lib/core/changelog.dart` and keep `pubspec.yaml` `version:` in sync.
Do not hardcode the version in `AGENTS.md`.

## Shape of a new release

Use sections on the **current** release only. Leave older releases as a flat
`bullets` list. Empty sections stay hidden — do not invent them.

```dart
ChangelogRelease(
  version: currentVersion,
  date: 'Sep 28, 2026', // month day, year — the day this version ships
  summary: '…',          // 1–2 sentences. This is the first-hour lead.
  added: <String>[],     // NEW — systems, areas, bosses, UI that did not exist
  changed: <String>[],   // CHANGES — balance, UI, economy, loot, rules that already exist
  fixed: <String>[],     // FIXES — bugs, stability, performance. Omit the arg if none.
  technical: <String>[], // TECHNICAL — refactors, tools. Omit if none.
  known: <String>[],     // KNOWN ISSUES — broken or watched. Omit if none.
)
```

Short bullets. One fact each. Summary states what this patch is for.

## First hour (easy to get wrong)

`summary` is the only line a new save sees until the first boss. It must:

- Start with `Your party fights on its own. Tap ENTER DUNGEON`
- Mention the party fighting
- Stay free of KEY, GREATER, GAUNTLET, REBORN, and MASTERY

Put endgame, KEY, and zone recap in `changed` (or another section), not in `summary`.

## Honesty the tests already lock

The newest release, summary included, must still mention:

- Shipped zone names (Tidehold, Ashen, Hollow Grove, Stormwake, Rimeglass, Blightfen, Brassvault, Mothveil)
- Craft Trial
- Race still locks after New Game START (and must not say GEAR LOOK)
- GREATER, `Rebuild your bag`, and REBORN

Those lines are the world as it is, not a claim that this patch invented them.

## Check

```bash
flutter test test/changelog_sync_test.dart test/ship_smoke_test.dart test/first_hour_plain_test.dart
```

Must hold:

- `MetaSystems.currentVersion` == `pubspec.yaml` versionName
- Newest release version == `currentVersion`
- Newest release uses `summary`, `date`, and at least one section
- First-hour focus is the summary only

## Look

Live look on the Samsung A56 emulator ([a56-playtest](../a56-playtest/SKILL.md)).

1. A save past the first boss (a brand-new game hides the sections).
2. MORE → INFO → **PATCH NOTES**. Same button in SETTINGS.
3. Title **PATCH NOTES**, version and date, summary, then only the sections that have lines.
4. Scroll **CHANGES**. **Older versions** stays a plain list.
5. Unseen notes: a star on **MORE**, banner `Patch Notes unread`.

## Skip when

- No player-facing change and no version bump.
- Do not rewrite old releases into sections.
- Do not bump the version only to rename the screen.
