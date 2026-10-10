---
name: grinding-until-pass
description: >-
  Keeps iterating until flutter analyze, targeted tests, or the balance gate
  are green. Use when a kit feels too strong or too weak ("för stark",
  "för svag", "obalanserad"), when share-fast or the gate is red, or when
  the agent should grind through failures alone. Do not use for a first
  verify pass (flutter-verify) or a red PR on GitHub (babysitting-pr).
---

# Grind until pass (Idle Party)

Loop **fix → run → check** until the goal command succeeds. Prefer **fast** targets first.

## Default goals (pick one)

| Goal | Command |
|------|---------|
| Analyze | `flutter analyze lib test --no-fatal-infos` (hold to **zero** issues) |
| Unit / meta | `flutter test test/meta_depth_test.dart test/changelog_sync_test.dart` |
| Share iterate | `flutter test test/class_balance_share_fast_test.dart --reporter expanded` |
| Balance CI gate | `flutter test test/class_balance_gate_test.dart` |
| Full suite | `flutter test --exclude-tags sim` |
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
- For DPS `**HIGH**`: tune kits (`class_ability` / `ability_effects` / pet `atkScale`); focus the share run on the touched specs with MCP `balance_share` before the full gate
- Prefer `class_balance_share_fast_test` while iterating; gate last
- Track whether error count decreases; if it rises, reassess

## Notes

- Plain `flutter test` also runs the long `sim` tags — use targeted tests while grinding
- Output under `tool/out/` is gitignored; use `class_balance_share.json` locally for share boards

## Done when

- The goal command exits 0, or 10 rounds passed and the blocker is reported.
- No test was deleted or weakened and no analyzer ignore was added.
