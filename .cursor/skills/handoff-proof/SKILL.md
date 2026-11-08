---
name: handoff-proof
description: >-
  States the exact commit and what was proved before handoff.
  Use when the owner asks if a branch is ready, or before any tag,
  or when they say "redo" or "bevis". Do not use for a source review
  (reviewing-code) or a Play upload (play-store-prep).
---

# Handoff proof

## Procedure

1. `git rev-parse HEAD` and the base branch. Write those SHAs.
2. Name the tests that ran. A count is real only when it is copied from
   that job's log for that SHA.
3. A sim step proves the sim. It does not prove the phone. Say which
   one the tests covered.
4. Read the upload lock on `20-how-we-work.mdc`. A source push or PR
   does not allow a `test-*` tag, a `v*` tag, an APK workflow, or Play.
   Those start only when the owner asks in that turn.
5. Before pushing, read the workflow `on:` for the branch. A `cursor/**`
   push runs CI. A `test-*` or `v*` tag starts a build. Do not create
   those tags here.
6. Do not install over another candidate package. A signature mismatch
   stops. Do not uninstall or wipe an existing save to clear it.

## Done when

- The handoff names the SHA, the tests, and what was not proved.
- No tag, APK, or Play workflow was started unless the owner asked.
