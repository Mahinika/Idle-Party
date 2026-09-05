---
name: repo-audit-and-cleaning
description: >-
  /repo auditandcleaning — complete repository-wide technical audit (architecture,
  dead/orphaned code, performance, coupling, tests). Analysis only; do not modify
  code. Use when the user types /repo auditandcleaning, /repo-auditandcleaning,
  or asks for a full repo audit / cleanup audit without requesting changes yet.
disable-model-invocation: true
---

# /repo auditandcleaning — repository audit

When the user runs **`/repo auditandcleaning`** (or **`/repo-auditandcleaning`**),
do this job immediately:

1. Read **[PROMPT.md](PROMPT.md)** in this skill folder.
2. Follow that master prompt **verbatim** — every phase and the final report structure.
3. Return **only** the completed audit report.
4. **Do not modify** the repository (no edits, refactors, deletes, installs).

## Idle Party context (do not weaken the prompt)

- Flutter idle RPG; combat authority is `SpatialCombat`.
- Prefer evidence from `lib/`, `test/`, `tool/`, `.github/`, `docs/`, assets helpers.
- Old saves / JSON fields may look unused — classify carefully (`save-migrate` mindset).
- `@Deprecated` helpers with zero callers may still be intentional until cleaned later.
- This slash is **explicit**; it is not the default for vague “gör spelet bättre”.

## Done when

- Final report matches the structure in `PROMPT.md`
- DEAD vs SUSPICIOUS vs ORPHANED distinctions are evidence-based
- No files were changed
