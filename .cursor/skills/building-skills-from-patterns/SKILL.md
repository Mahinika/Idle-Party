---
name: building-skills-from-patterns
description: >-
  Captures a repeated Idle Party workflow as a new SKILL.md under
  .cursor/skills/. Use when the same multi-step sequence happens 3+ times or
  the agent re-derives the same steps every task. Do not use for always-on style
  (use a .cursor/rules/ rule instead).
---

# Building skills from patterns

Promote repeated muscle memory into a named skill so future sessions load it automatically.

## When to trigger

- Same sequence asked **3+ times** (e.g. “share-only focus then gate then commit”)
- Agent re-derives the same steps every task (e.g. “how we bump What’s New”)
- A correction sounds like a **procedure** with steps (use a **rule** if always-on style)

## Workflow

1. **Name** — short slug: `releasing-android-tag`, `tuning-dps-share`, etc.
2. **Draft** `.cursor/skills/<slug>/SKILL.md` with frontmatter:

```yaml
---
name: <slug>
description: WHAT it does. Use when [triggers + 1–2 Swedish phrases]. Do not use when [sibling skill].
---
```

3. **Body** — When to use · numbered steps with real commands · Notes / when not to use.
4. **Point at repo truth** — `AGENTS.md`, `docs/CONTENT_CADENCE.md`, existing skills. Do not duplicate version numbers.
5. **Validate** — description is third person, WHAT + WHEN + Do not use when; no secrets; no machine-only paths; no Windows backslashes.
6. **Tell the user** where the file lives.

## 2026 conventions (Idle Party)

- **Description** is the only catalog text — write third person, WHAT + Use when + Do not use when; include Swedish trigger phrases the owner actually says.
- **`disable-model-invocation: true`** only for slash commands (`/init`, `/repo auditandcleaning`). Domain skills auto-load.
- **No `paths`** in this repo — the owner vibe-codes without opening specific files.
- **Body** under ~120 lines when possible; one default command path (not a menu of equals).
- **Over ~120 lines of detail** → `reference.md` one hop away with “Read when …”.
- **Gotchas** beat textbook filler — only what the agent would get wrong without the skill.
- Prefer Flutter commands: `flutter analyze lib test --no-fatal-infos`, `flutter test …`
- Combat → link `spatial-combat-change`; art → `assets-legal` / `zone-art-identity`; saves → `save-migrate`
- Keep skills **lean**; one workflow per skill

## Skills vs rules vs hooks

| Mechanism | Use for |
|-----------|---------|
| Skill | On-demand procedure |
| Rule (`.cursor/rules/`) | Always-on conventions |
| Hook | Automate after save / stop |

## Notes

- Update an existing skill instead of duplicating
- Keep `suggesting-skills` and `vibe-coder-autopilot` skill maps in sync
- Project skills live under `.cursor/skills/` (tracked via gitignore exceptions)
