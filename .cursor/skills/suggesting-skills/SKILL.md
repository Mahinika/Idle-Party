---
name: suggesting-skills
description: >-
  Map tasks to Idle Party skills. Under vibe-coder mode: follow the right skill
  silently — do not ask the user which skill to use.
---

# Suggesting skills (Idle Party)

**Default for this repo:** the human vibe-codes. **Load and follow** the matching skill yourself. Do **not** ask “vill du använda skill X?”.

Only *mention* a skill name if they explicitly ask how you work, or when creating a new skill via `building-skills-from-patterns`.

## Idle Party skill map

| User is doing… | You follow… |
|----------------|-------------|
| Combat / chambers / AFK / gates | `spatial-combat-change` |
| New ability / kit wiring / HUD but no cast | `add-ability` |
| New dungeon / zone / boss unlock | `new-dungeon` + `zone-art-identity` |
| Save fields / Ascend keep-reset / migrate | `save-migrate` |
| Class / WotLK identity audit | `class-audit` |
| Analyze / test / verify before PR | `flutter-verify` |
| Art / sprites / Kenney paths | `assets-legal` |
| Playtest hub/dungeon in browser | `browser-playtest` or `hub-smoke` |
| Kit DPS too strong/weak | `grinding-until-pass` + share-fast / gate tests |
| What’s New vs code / version drift | `screenshotting-changelog` + `changelog_sync_test` |
| Open PR CI failures | `babysitting-pr` / `parallel-ci-triage` |
| Hard bug | `systematic-debugging` |
| Code review of a diff | `reviewing-code` |
| Same workflow 3× | `building-skills-from-patterns` |
| A11y / reduce motion / labels | `accessibility-auditing` |
| UI change “does it look ok?” | `verifying-in-browser` |
| Play Store / listing / privacy / IARC | `play-store-prep` |
| `/init` / resync AGENTS + rules | `init` |
| Strategi / 90 dagar / prioritering | read `docs/STRATEGY_90D.md` (silently); execute current month |
| Topplistor / varför bra spel | `docs/TOP_GAMES_RESEARCH.md` background only — don’t derail |

## Rules

- Act; don't quiz them on tooling
- Prefer **project** skills over generic web/auth/Stripe skills
- One optional tip max if they're curious — never block work on skill consent
