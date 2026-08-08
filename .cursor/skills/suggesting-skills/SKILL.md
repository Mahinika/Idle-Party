---
name: suggesting-skills
description: >-
  When the user struggles with a task that an Idle Party or Cursor skill
  already covers, suggest the matching skill once (don't spam).
---

# Suggesting skills (Idle Party)

Watch for moments where an existing skill would make the work faster. Suggest it briefly; if declined, don't repeat.

## How to suggest

```
There's a skill for that — `spatial-combat-change` is the path when combat/chamber/AFK
behavior is involved. Want me to follow it?
```

## Idle Party skill map

| User is doing… | Suggest… |
|----------------|----------|
| Combat / chambers / AFK / gates | `spatial-combat-change` |
| New ability / kit wiring / HUD but no cast | `add-ability` |
| New dungeon / zone / boss unlock | `new-dungeon` + `zone-art-identity` |
| Save fields / Ascend keep-reset / migrate | `save-migrate` |
| Class / WotLK identity audit | `class-audit` |
| Analyze / test / verify before PR | `flutter-verify` |
| Art / sprites / Kenney paths | `assets-legal` |
| Playtest hub/dungeon in browser | `browser-playtest` or `hub-smoke` |
| Kit DPS HIGH / balance iterate | `grinding-until-pass` + `flutter test test/class_balance_share_fast_test.dart` |
| What’s New vs code / version drift | `screenshotting-changelog` + `test/changelog_sync_test.dart` |
| Open PR CI failures | `babysitting-pr` / `parallel-ci-triage` |
| Hard bug, don't guess | `systematic-debugging` |
| Code review of a diff | `reviewing-code` |
| Same workflow 3× | `building-skills-from-patterns` |

## Generic Cursor skills (if installed)

| User is doing… | Suggest… |
|----------------|----------|
| Creating a PR | user PR rules / `creating-pr` |
| Writing commit messages | user commit rules |

## Rules

- One suggestion per conversation unless asked
- Prefer **project** skills under `.cursor/skills/` over generic web/auth/Stripe skills
- Don't suggest analytics/auth/Tailwind skills for this Flutter offline RPG
