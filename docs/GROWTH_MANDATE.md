# Idle Party — growth mandate (standing principles)

**Locked:** 2026-09-12 by owner. **Research-checked:** 2026-09-12.
**Updated:** 2026-09-14 — numbered programs, soft locks, ask-first (zone /
class / God Hand / UA / git push / wipe-save), and UX hard rules (flat
nav / hide-until-unlock / ≤90 s) removed by owner. **Play AAB upload still
requires owner ask.**
History: [LEARNINGS.md](LEARNINGS.md) · [PLAY_GROWTH.md](PLAY_GROWTH.md).

North star: **främlingar på Play blir spelare.**

AL20 is a **quality gate** (do not ship a broken endgame). It is **not** the
default batch driver.

Live listing ops: [PLAY_GROWTH.md](PLAY_GROWTH.md) ·
[STORE_LISTING.md](STORE_LISTING.md) · [PLAY_STORE.md](PLAY_STORE.md).
Decision policy: [`.cursor/rules/studio-seats.mdc`](../.cursor/rules/studio-seats.mdc).
Hard locks: [`.cursor/rules/product-locks.mdc`](../.cursor/rules/product-locks.mdc).

## Default work

**Owner names the work** (or a clear batch). No standing program. Vague
“gör bättre / vad härnäst” → ask once; do not invent a numbered program; do
not restore AL20 hub polish as the default.

## Time-to-value (guidance, not a hard lock)

Median mobile session is ~**3–3.5 min**; median D1 ~**22%**. Prefer combat
early and hide chrome until it matters when it does not fight the named goal.

## Pillars (max three)

1. **Party walks the room** — SpatialCombat is the listing hook.
2. **Come back tomorrow** — one useful TODAY job; honest offline return.
3. **One prestige loop** — Ascend / Blessing / GOLD wipe.

## Hold (shipped; prefer not to regress)

- Funnel events live (`first_open` → … → `d1_return` + time-to-combat)
- Cadence 2–3 weeks; What’s New lead for a **new** player; DPS HIGH fails CI

## Stop doing

- iOS / Apple release (never, even if a plan names it); web-as-product; GitHub Releases as a player funnel
- Inventing numbered “Program N” roadmaps unless the owner asks for one

Owner **2026-09-26** removed these stops: AL20 polish as a forbidden default,
a second fight sim, gacha / BiS-for-cash / whale, and god-object work as
something the quarter may not be.

## Year roadmap (owner ask only)

When the owner says **Uppdatera 1års roadmap**, follow
`.cursor/skills/year-roadmap/`. Output lives in
[YEAR_ROADMAP.md](YEAR_ROADMAP.md) (sources:
[YEAR_ROADMAP_SOURCES.md](YEAR_ROADMAP_SOURCES.md)). That file does **not**
pick the next code batch — the owner names a line first.

## Endgame (when owner names it)

Prefer deepening the **five hunts** (KEY / Gauntlet / Farm Rift / Ranked GR /
Ashen) when the ask is “mer endgame.” New zone / class / hunt OK when named.
Monthly **Craft Trial** (MORE → CRAFT) is not a sixth ENDGAME hunt.

## Metrics (owner / Console — do not fake)

Honest order: crash-free → listing conversion → D1 → D7 → rating → then
tiny UA / D30. Latest paste (**2026-09-14**): Play has no D1 metric —
see [PLAY_GROWTH.md](PLAY_GROWTH.md).

## Quality gate (still)

`flutter analyze` / matching tests / live-light DPS gate. Fairness first.
SpatialCombat is the current fight sim. A second sim is not forbidden.

## Studio seats

Six veto domains, one decider — `.cursor/rules/studio-seats.mdc`.
Owner if they named the goal, otherwise EP. No chair vote.
