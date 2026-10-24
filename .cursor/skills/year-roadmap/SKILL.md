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
the next pick (`.cursor/rules/10-what-to-build.mdc`). After a rewrite the
same chat may build the plan's first slice.

Reserve slash if the phrase is missed: `/year-roadmap`.

## When not to use

- Picking one next batch when `docs/YEAR_ROADMAP_SOURCES.md` already covers
  the hole → open a few A pages if needed, then build (`10-what-to-build`)
- Routine implement, analyze, commit, or Play upload
- Inventing a numbered program

## Steps

1. **Read studio truth** — `docs/GROWTH_MANDATE.md`, `docs/CONTENT_CADENCE.md`,
   `docs/LEARNINGS.md`, `docs/PLAY_GROWTH.md`, `docs/CHASE_CONTRACT.md`
   (hunt order only), `.cursor/rules/decide-a-fork.mdc`,
   `.cursor/rules/00-locks.mdc`, and `docs/YEAR_ROADMAP.md` if present.
   Diff “done” against What’s New / changelog — do not trust the old plan
   blindly.

2. **Source sweep (subagent)** — spawn a research subagent whose prompt
   **pastes** grading rules and hard locks (subagents do not inherit user
   rules or skills). It writes `docs/YEAR_ROADMAP_SOURCES.md` with **100
   unique URLs** (no mirrors: `?hl=`, same PDF on two hosts). Return only
   counts per grade plus A-claims that can reorder **De närmaste uppdateringarna**. Eight search
   axes: retention median, genre-table age, Play listing experiments,
   screenshot policy, first session, idle clocks/prestige, daily chores,
   solo cadence.

3. **Grades**
   - **A** — may reorder **De närmaste uppdateringarna** (Play Help, GameAnalytics annual, CHI/Frommel,
     Pecorella, studio docs)
   - **B** — examples under *Om du namnger det* only
   - **C** — list so they are not reused (Playio, recycled AppsFlyer 2022,
     “up to 25%”, battle-pass calendars)
   - Remaining hard locks still win (Legal / IP, no exploits, no foreign dumps,
     never iOS / Apple). Gacha, a second sim, and a god-object quarter are not
     automatic stops.

4. **Rewrite** `docs/YEAR_ROADMAP.md` in the plan shape below. Swedish.
   Game terms stay English (KEY, Gauntlet, Ranked GR, Farm Rift, Ashen Crown).
   No invented Console %. No fake dates.

5. **Build or hand off** — you may build the first of the 52 weeks that this build does not already do, in this chat
   and follow `10-what-to-build` (checks, local commit, stop rules). Then
   hand off in short Swedish: which week came first, and which of the 52
   are still only a headline.

## Plan shape

Player language. A person who has never read the code can follow it.
Each week says where you go, what you do, and what you bring home. Leave
out engine, files, seats, and veto. Game button names stay English
(KEY, Gauntlet, Ranked GR, Farm Rift, Ashen Crown). The file stays Swedish.

The year is **52 weeks**, from the next Monday through the same week next
year. One row per week. That row is the week's headline. The week file
turns it into 25 checks. A year of three themes cannot fill 52 weeks.

The first row this build does not already do is the slice to build.

- **Senast uppdaterad** and three sentences: this can move, Patch Notes are
  what shipped, small fixes are not rows.
- **I spelet nu** — what a player can do today. The walk, the caves, the
  one job tomorrow, Ascend, and the five hunts.
- **52 veckor** — a table: week number, dates, one sentence. Group the
  rows so the year is easy to scan. Every row is still its own week.
- **Bara om vi säger det** — wishes, outside the 52. A new cave, class,
  fight sim, or gacha waits here until the owner names it.
- **Inte i den här planen** — the hard locks in player words.

A week is one thing a player can point at. The same sentence copied on
the next week is not a new week. A cave week names that cave and its
boss. A hunt week names the hunt and the one thing that week makes easy
to see. Say who it is for when it is not everyone. Say the prize in
words (time, a drop, gold, essence). Leave out drop rates and prices.

Do not invent a cave, class, or a day inside the week. The week's Monday
and Sunday are real. Do not lead with a tool or a hire. A class that
wins too easily is trimmed inside the week you are already on. It does
not take one of the 52.

## Studio seats (one decision)

EP locks scope. Game Director orders content (visible holes first, then
KEY → Gauntlet → Farm Rift → Ranked GR → Ashen). UX / Tech / Art / Marketing
veto only. Craft Trial stays MORE → CRAFT. A new zone / class / hunt may go in
the 52 when the owner names it, or when an A source and a hole in this game
agree.

## Gotchas

- 52 week rows, not three blurry seasons
- No numeric D1/D7 targets while Console n is tiny
- Listing A/B waits for real traffic
- A source counts only if it was opened in this chat and has a URL
- Owner-facing words are session, daily, and run
  (`.cursor/rules/play-words.mdc`). Do not write natt for those
