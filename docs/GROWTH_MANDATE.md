# Idle Party — growth mandate (standing principles)

**Locked:** 2026-09-12 by owner. **Research-checked:** 2026-09-12.
**Updated:** 2026-09-14 — numbered programs and soft content locks removed
by owner. History: [LEARNINGS.md](LEARNINGS.md) · [PLAY_GROWTH.md](PLAY_GROWTH.md).

North star: **främlingar på Play blir spelare.**

AL20 is a **quality gate** (do not ship a broken endgame). It is **not** the
default batch driver.

Live listing ops: [PLAY_GROWTH.md](PLAY_GROWTH.md) ·
[STORE_LISTING.md](STORE_LISTING.md) · [PLAY_STORE.md](PLAY_STORE.md).
Decision policy: [`.cursor/rules/studio-seats.mdc`](../.cursor/rules/studio-seats.mdc).
Hard locks: [`.cursor/rules/product-locks.mdc`](../.cursor/rules/product-locks.mdc).

## Default work

**Owner names the work.** No standing program. Vague “gör bättre / vad härnäst”
→ ask once; do not invent a numbered program; do not restore AL20 hub polish
as the default.

## Time-to-value

Median mobile session is ~**3–3.5 min**; median D1 ~**22%**. RPG churn often
hits **day 3–7** on loop complexity. Idle best practice: hide chrome until it
matters; first victory in the **first session**.

| Target | Meaning |
|--------|---------|
| **≤60–90 s** | Core combat on screen (party walking/fighting). Not tips, not GOLD. |
| **First session** | First *reward* (loot / stronger / floor clear) — often 45 s–4 min; **instrument**, don’t guess. |
| **≤15 min** | Envelope if they stay — not the aha. First boss may be too late as the D1 win. |

## Pillars (max three)

1. **Party walks the room** — SpatialCombat is the listing hook and the ≤90 s product.
2. **Come back tomorrow** — one TODAY job; honest offline return; one day-2–7 habit a *new* player can do.
3. **One prestige loop** — Ascend / Blessing / GOLD wipe. No new spell modes.

## Hold (shipped; do not regress)

- Play-install first hour: combat ≤90 s; hide GOLD / SHOP / ESSENCE until unlock
- Tip dump ≤2 beats; TODAY grow-the-party until first boss; one cave today on day 2–7
- Funnel events live (`first_open` → … → `d1_return` + time-to-combat)
- Systems gated (KEY / endgame / advanced MORE) until unlock
- Cadence 2–3 weeks; What’s New lead for a **new** player; DPS HIGH fails CI

## Stop doing

- AL20 hub-chase / wipe polish “because a list said so”
- Second combat sim; gacha / BiS-for-cash / whale ladder
- God-object refactors as the quarter’s story
- iOS / web-as-product / GitHub Releases as a player funnel
- Teaching ESSENCE / MARKET / GOLD tracks / pets before first combat reward
- Notification permission on first launch; more than ~1–2 pings/day
- Inventing numbered “Program N” roadmaps unless the owner asks for one

## Endgame (when owner names it)

Prefer deepening the **five hunts** (KEY / Gauntlet / Farm Rift / Ranked GR /
Ashen) when the ask is “mer endgame.” New zone / class / hunt is OK when the
owner names it (ask table) — not soft-blocked. Identity slices for the five
hunts shipped **2026-09-14**; further only against play notes unless they ask
for more.

## Metrics (owner / Console — do not fake)

Honest order: crash-free → listing conversion → D1 → D7 → rating → then
tiny UA / D30. Agent cannot mark D1 “good” without a real return %.
Latest paste (**2026-09-14**): Play has no D1 metric; 2-day/D7 empty or n=1 —
see [PLAY_GROWTH.md](PLAY_GROWTH.md). Ask before scaled UA.

## Quality gate (still)

`flutter analyze` / matching tests / live-light DPS gate. Fairness first.
SpatialCombat remains the only fight sim.

## Studio seats

Six chairs only — `.cursor/rules/studio-seats.mdc`.
**EP + UX + Marketing** pick *what to build* when the owner names a goal.
Game Director vetoes a broken fight or DPS HIGH. Tech vetoes red analyze /
crash. AL20 is not a chair.
