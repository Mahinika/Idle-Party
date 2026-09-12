# Idle Party — growth mandate (save + grow players)

**Locked:** 2026-09-12 by owner. **Research-checked:** 2026-09-12
(GameAnalytics 2025–26, Play ASO experiments, idle FTUE, persona-prompt papers).
**Program 1** (time-to-combat + Play funnel) shipped **2026-09-12**.
**Default work now:** [Program 2](#program-2--hide-until-unlock--play-smoke)
done bar below. Why: [LEARNINGS.md](LEARNINGS.md).

North star: **främlingar på Play blir spelare.** AL20 is a quality gate
(do not ship a broken endgame). It is **not** the batch driver.

Live listing ops: [PLAY_GROWTH.md](PLAY_GROWTH.md) ·
[STORE_LISTING.md](STORE_LISTING.md) · [PLAY_STORE.md](PLAY_STORE.md).
Decision policy: [`.cursor/rules/studio-seats.mdc`](../.cursor/rules/studio-seats.mdc).

## Time-to-value (do not treat “15 min” as the hook)

Median mobile session is ~**3–3.5 min**; median D1 ~**22%**. RPG churn often
hits **day 3–7** on loop complexity. Idle best practice: hide chrome until it
matters; first victory in the **first session**.

| Target | Meaning |
|--------|---------|
| **≤60–90 s** | Core combat on screen (party walking/fighting). Not tips, not GOLD. |
| **First session** | First *reward* (loot / stronger / floor clear) — often 45 s–4 min in published idle/FTUE notes; **instrument**, don’t guess. |
| **≤15 min** | Envelope if they stay — not the aha. First boss may be too late as the D1 win. |

## Pillars (max three)

1. **Party walks the room** — SpatialCombat is the listing hook and the ≤90 s product.
2. **Come back tomorrow** — one TODAY job; honest offline return; one day-2–7 habit a *new* player can do.
3. **One prestige loop** — Ascend / Blessing / GOLD wipe. No new spell modes.

## Stop doing

- AL20 hub-chase / wipe polish “because the old list said so”
- New zone #16, new class/spec, God Hand redesign, second combat sim
- Gacha / BiS-for-cash / whale ladder
- God-object refactors as the quarter’s story
- iOS / web-as-product / GitHub Releases as a player funnel
- Scaled paid UA before D1 is known (median games cannot pay back UA)
- Teaching ESSENCE / MARKET / GOLD tracks / pets before first combat reward
- Notification permission on first launch; more than ~1–2 pings/day

## 90-day phases

### Days 1–14 — store + funnel

- Listing: **icon** (highest search/browse swing) + screenshots **1–2** = live
  combat crawl (benefit, not menus). Honesty: the ad/listing must be the first
  minute. Run **Store Listing Experiments** when traffic exists (owner Console).
- Funnel: `first_open` → `app_ready` → `first_enter` → `first_reward` →
  `first_boss` → `d1_return`. Also log **seconds to combat**. First boss is a
  later FTUE step, not the only win.
- Day-1 TODAY = grow the party / first cave. Not vault / KEY / ESSENCE.
- Crashes and 1★ reviews outrank features.

### Days 15–45 — stranger → player

- Cut the tip dump. ≤2 first-run beats. Contextual hints, not a syllabus.
- One player-facing day-2–7 job.
- Welcome Back = reward, not three system names.
- Opt-in **local** notifications after a milestone (first reward/boss), never
  at install, never mid-combat, cap ~1–2/day. Track opt-out if possible.

### Days 45–90 — habit + visible updates

- Patch every 2–3 weeks. Play What’s New in one sentence a new player understands.
- Tiny UA (€5–10/day) is a **CPI/creative smoke**, not a D1 verdict (~900
  installs needed to read D1 ±3 pts). Do not scale.

## Done bar (say the phrase)

Check boxes only when **shipped** (or owner confirmed for Console-only).

**In-repo**

- [x] Funnel live: `first_open`, `app_ready`, `first_enter`, `first_reward`,
      `first_boss`, `d1_return` + time-to-combat (`AppAnalytics` + tests)
- [x] First session: tip dump cut (≤2 beats); combat on screen in ≤90 s on a
      new save; no MARKET / GOLD-tracks / pets / ESSENCE coaching before first reward
- [x] Systems gated (KEY / endgame / advanced MORE) until unlock
- [x] One player-facing day-2–7 job
- [x] Offline Welcome Back = short reward (wow + ≤3 highlights + one Up next)
- [x] Opt-in local notifications after a milestone; never install-prompt; never combat; ~1–2/day cap
- [x] Listing pack: icon + shots 1–2 = new-save first minute of **combat**
      (`docs/STORE_LISTING.md`)
- [x] At least one What’s New line aimed at a **new** player
- [x] Dead chrome stays hidden (LOADOUTS / Sell junk / Scrap / GEAR Sell)

**Owner / Console**

- [x] Play listing icon + screenshots + preview updated to match live first-minute combat
- [x] Owner looked at Play conversion + crashes + reviews once after the in-repo bar
- [x] Store Listing Experiment started **or** owner deferred (too little traffic)

Program 1 completed **2026-09-12**. The Robban line for *this* bar was said.
Do not repeat it. Default work is **Program 2**.

## Program 2 — hide-until-unlock + Play smoke

**Locked:** 2026-09-12 (owner confirmed the plan). North star unchanged:
strangers on Play become players. AL20 stays a quality gate, not the batch.
Endgame copy and GEAR follow-up only when play notes say they lie.

Check boxes only when **shipped** (or owner confirmed for Console-only).

**In-repo**

- [x] First-hour bottom bar: GOLD until first reward; SHOP after first boss;
      ESSENCE when essence exists (or first Ascend). BAG Shop-chip off in the
      first hour. Flat nav — tabs return at unlock; no second nav.
- [x] TODAY: grow-the-party beats EQUIP / MARKET until the first boss
      (claimables still win). `first_hour_plain_test`.
- [x] First-hour MetaPulse stays empty — no “KEY off” crumbs.
- [x] Starter kits (Protection / Discipline / Fire): HUD chips keep the job
      (identity reserve + Shield/Healer/Damage line).
- [x] Cadence: tag every 2–3 weeks; What’s New lead for a new player;
      live-light balance gate stays the CI veto (`docs/CONTENT_CADENCE.md`).

**Owner / Console**

- [ ] Google publish complete (listing shows Updated + live version)
- [ ] SHOP + POWERUPS smoked on a **Play-installed** build (AD PRIVACY path too)
- [ ] D1 read when traffic exists; Store Listing Experiment when visitors
      suffice. No scaled UA.

When **every Program 2** box above is `[x]`, the next user-facing message
starts with **exactly**:

```
ROBBAN DET BEHÖVS GÖRAS EN NY PLAN FÖR FRAMTIDEN
```

Do not paraphrase. Do not say it early. Do not restore AL20 as the batch.

**Quality gates (not the batch)**

- Endgame copy (KEY loot line, Gauntlet wipe→hub, GR “no mid-run gear”) only
  when an AL12 / AL20 save’s play notes say the hunt lies.
- GEAR follow-up (BiS jargon in tips, Shop-chip, two EQUIP buttons) only
  against play notes from the current save.
- Tag cadence **2–3 weeks** — `docs/CONTENT_CADENCE.md`. Balance gate stays the
  CI veto. No new zone / class.

## Metrics (owner / Console — do not fake)

Crash-free → listing conversion → D1 (~22% median all-mobile; Android top
quartile ~25–27%) → D7 → rating → then D30 / UA / iOS.
Agent cannot mark D1 “good” without owner numbers.

## Quality gate (still)

`flutter analyze` / matching tests / live-light DPS gate. Fairness first.
SpatialCombat remains the only fight sim.

## Studio seats

Six chairs only — `.cursor/rules/studio-seats.mdc`. Not a theatrical panel.
**EP + UX + Marketing** pick *what to build* while this mandate is open.
Game Director vetoes a broken fight or DPS HIGH. Tech vetoes red
analyze / crash. AL20 is not a chair.
