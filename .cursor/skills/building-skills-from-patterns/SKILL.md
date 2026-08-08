---
name: building-skills-from-patterns
description: >-
  When the same multi-step Idle Party workflow repeats (user corrections or
  agent redos), capture it as a new SKILL.md under .cursor/skills/.
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
description: What it does and when to use it (trigger phrases).
---
```

3. **Body** — When to use · numbered steps with real commands · Notes / when not to use.
4. **Point at repo truth** — `AGENTS.md`, `docs/CONTENT_CADENCE.md`, existing skills.
5. **Validate** — description matches Cursor skill discovery; no secrets; no machine-only paths.
6. **Tell the user** where the file lives.

## Idle Party conventions for new skills

- Prefer Flutter commands: `flutter analyze`, `flutter test …`
- Combat changes → link `spatial-combat-change`
- Art → link `assets-legal` / `zone-art-identity`
- Saves → link `save-migrate`
- Keep skills **lean**; one workflow per skill

## Skills vs rules vs hooks

| Mechanism | Use for |
|-----------|---------|
| Skill | On-demand procedure |
| Rule (`.cursor/rules/`) | Always-on conventions |
| Hook | Automate after save / stop |

## Notes

- Update an existing skill instead of duplicating
- Project skills live under `.cursor/skills/` (tracked via gitignore exceptions)
