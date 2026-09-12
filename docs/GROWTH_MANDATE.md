# Idle Party — growth mandate (save + grow players)

**Locked:** 2026-09-12 by owner. This is the **only** default work program
until the done bar below is complete.

North star: **främlingar på Play blir spelare.** AL20 is a quality gate
(do not ship a broken endgame). It is **not** the batch driver.

Full plan origin: first 15 minutes + store funnel, not more endgame systems.
Live listing ops: [PLAY_GROWTH.md](PLAY_GROWTH.md) ·
[STORE_LISTING.md](STORE_LISTING.md) · [PLAY_STORE.md](PLAY_STORE.md).

## Pillars (max three)

1. **Party walks the room** — SpatialCombat is the product on the listing and in minute 1.
2. **Come back tomorrow** — one job on TODAY; honest offline return; one day-2–7 habit a *new* player can do.
3. **One prestige loop** — Ascend / Blessing / GOLD wipe. No new spell modes.

## Stop doing

- AL20 hub-chase / wipe polish “because the old list said so”
- New zone #16, new class/spec, God Hand redesign, second combat sim
- Gacha / BiS-for-cash / whale ladder
- God-object refactors as the quarter’s story
- iOS / web-as-product / GitHub Releases as a player funnel
- Tiny paid UA until D1 is known and not junk
- Teaching ESSENCE / MARKET / GOLD tracks / pets in the first minutes

## 90-day phases

### Days 1–14 — store + funnel

- Listing screenshots 1–2 and preview video match the **first two minutes** of a new save (party fighting in a room), not menus.
- Funnel events: `first_open` → `party_picked` → `first_enter` → `first_boss` → `d1_return`.
- Day-1 TODAY = grow the party / first boss. Not vault / KEY / ESSENCE.
- Crashes and 1★ reviews outrank features. Reply templates stay in PLAY_GROWTH.

### Days 15–45 — stranger → player

- First 15 minutes is its own game: New Game → crawl like the trailer → visible loot → “you got stronger.”
- Cut the first-session tip dump. Market / forge / pets / essence after first boss (or later unlock).
- Welcome Back is a reward, not three system names.
- **One** player-facing reason to open on day 2–7 (vault / daily run / quests may exist internally — new players see one job).
- Opt-in local notifications for idle return / vault. Never mid-combat. Never spam.

### Days 45–90 — habit + visible updates

- Patch every 2–3 weeks. Play What’s New in **one sentence a new player understands**.
- Week/season only if a day-2 player can feel it. KEY jargon still waits for party Lv100.
- Tiny UA (€5–10/day, 7 days) only if D1 is not junk. Creative = crawl, not GEAR.
- iOS only after Android D1/listing conversion hold.

## Done bar (say the phrase)

Check boxes only when **shipped in repo** (or owner confirmed for Console-only).
Do **not** check from intent.

**In-repo**

- [ ] Funnel events live: `first_open`, `party_picked`, `first_enter`, `first_boss`, `d1_return` (`AppAnalytics` + tests)
- [ ] First 15 min: tip dump cut; day-1 TODAY is cave / first boss; no MARKET / GOLD-tracks / pets / ESSENCE coaching before first boss
- [ ] Systems stay gated (KEY / endgame chrome / advanced MORE) until their unlock — new save does not look like AL20
- [ ] One player-facing day-2–7 job (copy + hub CTA; no three competing “daily” buttons for new players)
- [ ] Offline Welcome Back is a short reward (wow + ≤3 highlights + one Up next) — not a meta syllabus
- [ ] Opt-in local notifications: idle return and/or vault; never during combat
- [ ] Listing pack in `docs/STORE_LISTING.md` + screenshot/preview brief: first two shots = first two minutes of a new save
- [ ] At least one What’s New / Play notes line aimed at a **new** player (not Gauntlet F200)
- [ ] Dead chrome stays hidden (LOADOUTS / Sell junk / Scrap / GEAR Sell)

**Owner / Console (agent asks once, owner confirms)**

- [ ] Play listing screenshots + preview video updated to match the new-save first two minutes
- [ ] Owner looked at Play conversion + crashes + reviews once after the in-repo bar
- [ ] Tiny UA **not** scaled (still optional; only if D1 is not junk)

When **every** box above is `[x]`, the agent’s next user-facing message must be
**exactly** this line, nothing else before it:

```
ROBBAN DET BEHÖVS GÖRAS EN NY PLAN FÖR FRAMTIDEN
```

Do not paraphrase. Do not say it early. After that line, a short Swedish
handoff of leftover Console notes is OK.

## Metrics (owner / Console — do not fake)

Crash-free → listing conversion → D1 → D7 → rating → then D30 / UA / iOS.
Agent cannot mark D1 “good” without owner numbers.

## Quality gate (still)

`flutter analyze` / matching tests / live-light DPS gate. Fairness first.
SpatialCombat remains the only fight sim.
