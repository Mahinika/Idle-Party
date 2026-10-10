---
name: parallel-ci-triage
description: >-
  When GitHub Actions fails with multiple independent jobs, split failing jobs
  across parallel subagents. Use when two or more workflows or jobs are red
  at once (for example ci.yml and sim-nightly.yml). Do not use for one red
  job or one clear error (babysitting-pr).
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
| analyzer | `flutter analyze lib test --no-fatal-infos` |
| tests / balance gate | `flutter test test/class_balance_gate_test.dart` or `flutter test --exclude-tags sim` |
| changelog | `flutter test test/changelog_sync_test.dart` |
| paper-doll facit | `py -3 tool/paper_doll_classify.py` then `py -3 tool/check_paper_doll_facit.py` |

`ci.yml` is one job (`analyze-test`: facit, analyze, test). Several red steps
inside that one job are usually one agent's work, not a split.

## When not to use

- Single clear error — fix in the main agent
- Flaky infra — retry or fix workflow first
- Two failures same root file — one agent owns both

## Done when

- Every split job is green on the re-run (`gh pr checks`), or the blocker per job is reported.
