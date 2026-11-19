---
name: small-runs
description: >-
  How to split Idle Party agent work into cheap, resumable batches.
  Use when starting a multi-step job, launching a cloud agent, or
  picking a model. Do not use for the verify loop (flutter-verify) or
  a Play upload (play-store-prep).
---

# Small runs

Long agent sessions get interrupted. Keep each run small enough to
finish, and leave the next run a git checkout it can resume from.

## Procedure

1. Write a short plan before coding. Prefer a checked-in file on the
   branch (for example `docs/` only when the owner asked for a plan
   doc) or a `/tmp` plan file. The plan lists the batches and the
   current one.
2. Do **one batch per run**. A batch is one reviewable change: one
   workflow point, one screen, one bug, or one commit-sized slice.
   Related fixes that make that batch true belong in it. Do not start
   the next batch in the same run.
3. When analyze and the matching tests are green, **commit**. Push the
   branch when that is part of the handoff. Do not merge, and do not
   push a `test-*` or `v*` tag, unless the owner asks in that turn.
4. The next run **resumes from git state**: `git status`, `git log`,
   and the plan file. Do not rely on chat memory for what landed.

## Models

- **Default:** Composer 2.5 with `fast: false`.
- **Step up** to Grok 4.7 at medium effort with `fast: false` only when
  the batch needs deeper reasoning (a hard bug, a dense design fork, or
  a failed cheaper pass).
- **No Fast mode.** Fast costs more and is not the default for this
  repo.
- **No third-party models.**

## Done when

- The run did one batch, committed it when green, and left a plan the
  next run can pick up from git.
- The model choice stayed on the cheap default unless a step-up was
  needed.
