# Idle Party — studio learnings

**Dated:** 2026-09-12. Decisions live in `GROWTH_MANDATE.md` +
`.cursor/rules/studio-seats.mdc`. This file is **why** — so the next session
does not re-litigate and fall back to AL20 polish.

Do not grow this into a 500-point audit. New lessons: one bullet + date.

## 2026-09-12 — grow players, not the maker’s save

- **Feature-complete ≠ growth.** 31 specs / 15 zones / five endgame modes did
  not get strangers past D1. Median mobile D1 is ~22%; most of that call is
  the first session.
- **AL20 “allt känns bra” is a quality gate**, not the next batch. The missing
  customer is a Play install who never heard KEYSTONE.
- **A polish list is not a roadmap.** Do not hub/wipe-polish because a 10-part
  map said so.
- **Time-to-combat is ≤90 s**, not “first 15 minutes.” Median session ~3–3.5
  min. 15 min is an envelope if they stay. First *reward* in the first session;
  first boss may be too late as the D1 win.
- **Hide chrome until it matters.** Tip dumps and three “dailies” are churn.
  Idle practice: roll buttons out when they mean something.
- **Listing must be the live first minute.** Icon often swings search/browse
  more than screenshots; shots 1–2 still must be the crawl, not menus.
- **Tiny UA is not a D1 study.** ~900 installs to read D1 ±3 pts. €5–10/day
  is CPI/creative smoke only.
- **Notifications:** after a milestone, ~1–2/day, never first-launch permission,
  never mid-combat. In-game card after first loot (YES / NOT NOW); SETTINGS
  toggle afterwards. OS permission only on YES. Close the card *before* the
  OS grant sheet — a modal over that sheet traps the hub. Inexact alarms —
  no exact-alarm Play policy. Cap is UTC-day of *fire* time.
- **Persona panels don’t make better calls.** “Act as expert” changes tone.
  Six chairs + vetoes beat a 40-role org chart. Chairs: EP, Game, UX, Tech,
  Art, Marketing. No Scrum/Network/UA department.
- **`/init` must not restore AL20-default** while the growth done bar is open.
- When that done bar is fully checked, say exactly:
  `ROBBAN DET BEHÖVS GÖRAS EN NY PLAN FÖR FRAMTIDEN`

## 2026-09-12 — funnel + first session (after shipping those boxes)

- **Instrument, don’t guess TTC.** `first_open` is Firebase-reserved (SDK
  auto-logs it). We stamp install locally and send `app_ready` → `first_enter`
  (+ `time_to_combat` seconds from this process start, including intro) →
  `first_reward` / `first_boss` / `d1_return` (next UTC day). Pre-funnel
  saves backfill flags with **no events** or veterans look like new D1.
- **A bottom tip card covers ENTER.** First-run overlay must sit off the hub
  CTA (or dismiss on enter). ≤2 beats = hub job + tap-the-fight *before*
  first reward — not “delete GOLD tips forever.” Repeat/Next, GOLD tracks,
  MARKET, ESSENCE, pets wait until they mean something.
- **MORE → INFO uses `topicsFor`, not `GameGuides.topics`.** Full BASICS still
  names GOLD/ESSENCE/KEY; a new save must not see that syllabus. After the
  first boss, `topicsFor` still hid KEY / Gauntlet / Rift / Ashen until party
  max — dumping the full catalog at boss 1 taught locked meta. QUESTS is a
  MORE row after the first floor, not on a fresh save.
- **One day-2–7 job = one cave today.** After the first boss, TODAY is Daily
  Vault (clear → claim). Daily Run as a second daily is churn — it waits
  until first Ascend, then only after today's vault is claimed.
- **Welcome Back is a payday, not a syllabus.** Wow + ≤3 rows + Up next.
  AFK-assist / sanctuary / chase-detail dumps on that card are churn.
