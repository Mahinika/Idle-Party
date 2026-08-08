---
name: grinding-until-pass
description: >-
  Keep iterating until flutter analyze / targeted tests / balance gate are
  green. Use when the user wants the agent to grind through failures autonomously.
---

# Grind until pass (Idle Party)

Loop **fix → run → check** until the goal command succeeds. Prefer **fast** targets first.

## Default goals (pick one)

| Goal | Command |
|------|---------|
| Analyze | `flutter analyze` (hold to **zero** issues in `lib`/`test`) |
| Unit / meta | `flutter test test/meta_depth_test.dart test/changelog_sync_test.dart` |
| Share iterate | `flutter test test/class_balance_share_fast_test.dart --reporter expanded` |
| Balance CI gate | `flutter test test/class_balance_gate_test.dart` |
| Full suite | `flutter test` |
| Verify loop | Follow `flutter-verify` skill |

## Loop

1. Run the goal command; capture exit code + errors.
2. On failure: read the **first** actionable error; minimal fix; don't drive-by refactor.
3. Re-run. Repeat.
4. On success: report iterations + what changed.

## Rules

- **Max 10 iterations** — then stop and report the blocker
- Fix one failure cluster at a time
- **Don't delete or gut tests** to go green; don't suppress analyzer with ignores
- For DPS `**HIGH**`: tune kits (`class_ability` / `ability_effects` / pet `atkScale`) using `--share-only --focus=…` before the full gate
- Prefer `class_balance_share_fast_test` while iterating; gate last
- Track whether error count decreases; if it rises, reassess

## Notes

- Full `flutter test` includes long sims — use targeted tests while grinding
- Output under `tool/out/` is gitignored; use `class_balance_share.json` locally for share boards
