---
name: year-roadmap
description: >-
  Rebuilds Idle Party’s 12-month owner plan from studio seats, Play paste,
  and graded web research. Use when the owner says "Uppdatera 1års roadmap",
  "1årsplan", "årsroadmap", or "100 källor". Do not use for vague "vad
  härnäst" / "gör bättre" (ask once), routine implement/analyze/commit, or
  Play AAB upload.
---

# Year roadmap (Idle Party)

Owner-only planning pass. **Not a standing program.** Next code batch starts
only when the owner names a line from the plan in a **new** chat.

Reserve slash if the phrase is missed: `/year-roadmap`.

## When not to use

- Vague “vad härnäst” / “gör bättre” → ask once; do not invent a numbered plan
- Routine implement, analyze, commit, or Play upload
- Restoring a standing program when the owner did not ask for the year plan

## Steps

1. **Read studio truth** — `docs/GROWTH_MANDATE.md`, `docs/CONTENT_CADENCE.md`,
   `docs/LEARNINGS.md`, `docs/PLAY_GROWTH.md`, `docs/CHASE_CONTRACT.md`
   (hunt order only), `.cursor/rules/studio-seats.mdc`,
   `.cursor/rules/product-locks.mdc`, and `docs/YEAR_ROADMAP.md` if present.
   Diff “done” against What’s New / changelog — do not trust the old plan
   blindly.

2. **Source sweep (subagent)** — spawn a research subagent whose prompt
   **pastes** grading rules and hard locks (subagents do not inherit user
   rules or skills). It writes `docs/YEAR_ROADMAP_SOURCES.md` with **100
   unique URLs** (no mirrors: `?hl=`, same PDF on two hosts). Return only
   counts per grade plus A-claims that can reorder **Nu**. Eight search
   axes: retention median, genre-table age, Play listing experiments,
   screenshot policy, first session, idle clocks/prestige, daily chores,
   solo cadence.

3. **Grades**
   - **A** — may reorder **Nu** (Play Help, GameAnalytics annual, CHI/Frommel,
     Pecorella, studio docs)
   - **B** — examples under *Om du namnger det* only
   - **C** — list so they are not reused (Playio, recycled AppsFlyer 2022,
     “up to 25%”, battle-pass calendars)
   - Remaining hard locks still win (Legal / IP, no exploits, no foreign dumps,
     never iOS / Apple). Gacha, a second sim, and a god-object quarter are not
     automatic stops.

4. **Rewrite** `docs/YEAR_ROADMAP.md` in Swedish. Game terms stay English
   (KEY, Gauntlet, Ranked GR, Farm Rift, Ashen Crown). No invented Console %.

5. **Handoff** — short Swedish: what must be first, what remains as themes,
   that examples and **Senare** are unbooked. **Do not ship a game batch in
   this chat.** Owner names the next slice in a new chat.

## Plan shape

- Date + “not a standing program” + link to `YEAR_ROADMAP_SOURCES.md`
- **Nu** (6–8 weeks) — 2–3 What’s New one-liners; one headline per release;
  slack for crash / analyze
- **Sen** (to month 9) — player problems / themes, no locked feature names
- **Senare** (months 9–12) — intent only; not a promise
- **Om du namnger det** — 6–10 A/B examples; each names which chair can stop it
- **Stoppas** — hard locks, rejected C-advice, vitals if red

## Studio seats (one decision)

EP locks scope. Game Director orders content (visible holes first, then
KEY → Gauntlet → Farm Rift → Ranked GR → Ashen). UX / Tech / Art / Marketing
veto only. Craft Trial stays MORE → CRAFT. New zone / class / hunt only when
the owner names them.

## Gotchas

- Three horizons, not four equal quarters
- No numeric D1/D7 targets while Console n is tiny
- Listing A/B waits for real traffic
- Same chat never starts the Nu build
