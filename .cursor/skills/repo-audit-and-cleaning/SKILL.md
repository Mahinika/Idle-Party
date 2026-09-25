---
name: repo-audit-and-cleaning
description: >-
  /repo auditandcleaning — Idle Party repository audit (save fields, kit
  wiring, SpatialCombat authority, dead non-save code, copy/version drift).
  Analysis only. Use when the user types /repo auditandcleaning,
  /repo-auditandcleaning, /repo audit and cleaning, or asks for a full repo
  audit without requesting changes yet.
disable-model-invocation: true
---

# /repo auditandcleaning — repository audit

When the user runs **`/repo auditandcleaning`** (or **`/repo-auditandcleaning`**
or **`/repo audit and cleaning`**):

1. Read **[PROMPT.md](PROMPT.md)** in this skill folder.
2. Follow that prompt. It is the whole job.
3. Return the report in the shape `PROMPT.md` specifies.
4. Do not modify the repository.

This slash is explicit. Vague "gör spelet bättre" or "cleanup" is not this job.

## Done when

- The report matches `PROMPT.md` (Swedish, no empty sections, no padded action list)
- DEAD is only high-confidence non-save code
- Save JSON keys are never called dead
- No files were changed
