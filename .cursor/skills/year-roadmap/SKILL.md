---
name: year-roadmap
description: >-
  Rebuilds Idle Party’s 12-month owner plan from studio seats, Play paste,
  and graded web research. Use when the owner says "Uppdatera 1års roadmap",
  "1årsplan", "årsroadmap", or "100 källor", or when the direction of the
  next months is the decision. Do not use to pick one next batch when the
  sources on disk cover the hole, for routine implement/analyze/commit, or
  for Play AAB upload.
---

# Year roadmap (Idle Party)

Planning pass. **Not a standing program.** The sources file is evidence for
the next pick (`.cursor/rules/independent-calls.mdc`). After a rewrite the
same chat may build the plan's first slice.

Reserve slash if the phrase is missed: `/year-roadmap`.

## When not to use

- Picking one next batch when `docs/YEAR_ROADMAP_SOURCES.md` already covers
  the hole → open a few A pages if needed, then build (`independent-calls`)
- Routine implement, analyze, commit, or Play upload
- Inventing a numbered program

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

5. **Build or hand off** — you may build the first **Nu** slice in this chat
   and follow `independent-calls` (checks, local commit, stop rules). Then
   hand off in short Swedish: what came first, what remains as themes, and
   that examples and **Senare** are unbooked.

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
veto only. Craft Trial stays MORE → CRAFT. A new zone / class / hunt may go in
**Nu** when the owner names it, or when an A source and a hole in this game
agree.

## Gotchas

- Three horizons, not four equal quarters
- No numeric D1/D7 targets while Console n is tiny
- Listing A/B waits for real traffic
- A source counts only if it was opened in this chat and has a URL
