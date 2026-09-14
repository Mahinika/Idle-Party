---
name: suggesting-skills
description: >-
  Maps tasks to Idle Party skills. Under vibe-coder mode: follow the matching
  skill silently — do not ask the user which skill to use.
---

# Suggesting skills (Idle Party)

**Default for this repo:** the human vibe-codes. **Load and follow** the matching skill yourself. Do **not** ask “vill du använda skill X?”.

Only *mention* a skill name if they explicitly ask how you work, or when creating a new skill via `building-skills-from-patterns`.

**Keep this table in sync with** `.cursor/rules/vibe-coder-autopilot.mdc`.

## Idle Party skill map

| User is doing… | You follow… |
|----------------|-------------|
| Combat / chambers / AFK / gates | `spatial-combat-change` |
| Enemies feel the same / fiender tråkiga / same PULSE | `spatial-combat-change` (not `zone-art-identity`) |
| New ability / kit wiring / HUD but no cast | `add-ability` |
| New dungeon / zone / boss unlock | `new-dungeon` + `zone-art-identity` |
| Save fields / Ascend keep-reset / migrate | `save-migrate` |
| Class / WotLK identity audit | `class-audit` |
| Analyze / test / verify before PR | `flutter-verify` |
| Art / sprites / Kenney paths | `assets-legal` |
| Doll / gear on body / undertunic / paper-doll | `character-paper-doll` + `assets-legal` |
| Playtest / “show me the app” | `a56-playtest` (emulator). Web: `browser-playtest` fallback |
| Hub polish checklist | `hub-smoke` on the A56 emulator |
| Kit DPS too strong/weak | `grinding-until-pass` + share-fast / gate tests |
| What’s New vs code / version drift | `screenshotting-changelog` + `changelog_sync_test` |
| Open PR CI failures | `babysitting-pr` / `parallel-ci-triage` |
| Hard bug | `systematic-debugging` |
| Code review of a diff / granska / kolla PR / innan merge | `reviewing-code` |
| Same workflow 3× | `building-skills-from-patterns` |
| A11y / reduce motion / labels | `accessibility-auditing` |
| Record web flow as Playwright test | `recording-browser-flow-as-test` |
| New menu / where does X live / UI consistency | always-on `game-ux-director` rule + `ui-theme` / `docs/UI_THEME.md` |
| UI change “does it look ok?” | `a56-playtest` / `verifying-in-browser` |
| Play Store / listing / privacy / IARC | `play-store-prep` |
| itch.io listing / community post | `play-store-prep` + `tool/store_listing/itch/PAGE.md` (no APK) |
| `/init` / resync AGENTS + rules | `init` |
| `/repo auditandcleaning` / full repo audit (no edits) | `repo-audit-and-cleaning` |
| “gör spelet bättre” / vad härnäst | ask once (`GROWTH_MANDATE.md`) — not AL20 |
| First hour / onboarding / listing / funnel | first-hour tests + `hub-smoke` + `play-store-prep` |
| Fork / two games / whose call | silent `studio-seats` |
| Strategi / 90 dagar / prioritering | `docs/GROWTH_MANDATE.md` then `docs/CONTENT_CADENCE.md` |
| Topplistor / varför bra spel | `docs/TOP_GAMES_RESEARCH.md` background only — don’t derail |

## Rules

- Act; don't quiz them on tooling
- Prefer **project** skills over generic web/auth/Stripe skills
- One optional tip max if they're curious — never block work on skill consent
