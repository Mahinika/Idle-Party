---
name: parallel-ci-triage
description: >-
  When GitHub Actions fails with multiple independent jobs, split failing jobs
  across parallel subagents. Use for multi-job CI; not for a single clear error.
---

# Parallel CI triage (Idle Party)

## Workflow

1. Identify failing run: `gh run list --limit 5` then `gh run view <ID> --log-failed`
2. Split by **job** (or independent failure clusters). One agent per job if independent.
3. Launch parallel `generalPurpose` Task subagents in **one** message; each gets:
   - Job name + failed log excerpt
   - Local verify command (`flutter analyze`, `flutter test <path>`, etc.)
   - Instruction: edit only what that job needs; report root cause + proof
4. Merge results; resolve overlapping file edits sequentially
5. Push and `gh run watch` / `gh pr checks`

## Idle Party job mapping (typical)

| Symptom | Local verify |
|---------|----------------|
| analyzer | `flutter analyze` |
| tests / balance gate | `flutter test test/class_balance_gate_test.dart` or full `flutter test` |
| changelog | `flutter test test/changelog_sync_test.dart` |

## When not to use

- Single clear error — fix in the main agent
- Flaky infra — retry or fix workflow first
- Two failures same root file — one agent owns both
