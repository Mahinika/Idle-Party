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
  Capture via Playwright + web `:8080` (`capture_first_minute.py`) — do not
  wipe the owner’s A56 save to get a new-save shot. Console paste is a
  separate owner box; in-repo pack is `STORE_LISTING.md` + `out/` / icon.
  Play library dump-all sorts by recency/dedupe — attach **one shot at a
  time**. Assets tagged “Behöver beskäras” need **9:16 stående** → Spara som
  kopia → **Lägg till** (default crop is 16:9 landscape). CORS on **9888**,
  not poisoned 9877. Appikon is **1/1**: attach the new 512 from the library
  first, then **Ta bort** the old icon — never save with an empty icon slot.
  Do not 9:16-crop a 1∶1 512 icon.
- **Tiny UA is not a D1 study.** ~900 installs to read D1 ±3 pts. €5–10/day
  is CPI/creative smoke only. **Store Listing Experiments** need real listing
  traffic — ~10 visitors / 28 days (2026-09-12 look) is defer, not an A/B.
- **Notifications:** after a milestone, ~1–2/day, never first-launch permission,
  never mid-combat. In-game card after first loot (YES / NOT NOW); SETTINGS
  toggle afterwards. OS permission only on YES. Close the card *before* the
  OS grant sheet — a modal over that sheet traps the hub. Inexact alarms —
  no exact-alarm Play policy. Cap is UTC-day of *fire* time.
- **Persona panels don’t make better calls.** “Act as expert” changes tone.
  Six chairs + vetoes beat a 40-role org chart. Chairs: EP, Game, UX, Tech,
  Art, Marketing. No Scrum/Network/UA department.
- **`/init` must not restore AL20-default.** After Program 3, wait for the
  next plan (`GROWTH_MANDATE.md`).
- **What’s New lead is for a stranger.** First bullet = party fights / tap ENTER.
  Keep KEY / GREATER / Mastery in later bullets. Do not teach removed
  LOADOUTS / Sell junk / Scrap buttons by naming them.
- Program 1 done bar complete **2026-09-12** (Robban line said). Program 2
  closed **2026-09-13**. Program 3 closed **2026-09-14** (D1 paste: Play
  has no D1; 2-day/D7 empty or n=1). The Robban line for Program 3 is
  said. Do not repeat it. Wait for the next plan — not AL20 as the batch
  (`GROWTH_MANDATE.md`).

## 2026-09-14 — Console D1 is not a number yet

- Agent opened Play Console (Cognifox Studio / Idle Party production).
  Play has **no D1** (earliest return is 2 days). 2-day = two days with
  1 returner each; D7 empty. ~4 first opens / 15 acquisitions / 9 listing
  visitors. Paste that — do not invent a % vs 22% median. Program 3
  Console bar closes on the paste, not on a “good D1”.

## 2026-09-13 — seats drafted Program 3; Play smoke closed it the same day

- Owner asked for a future plan with all six chairs. EP + UX + Marketing
  picked **stranger stays** (D1→D7 on Play, crawl feel without zone #16).
  Game Director may freshen packs/tells against play notes. Tech/Art do not
  pick the batch. Endless KEY / Rift / GR is quality, not the story.
- Owner confirmed Play publish + SHOP/POWERUPS smoke **2026-09-13**. D1 / Store
  Listing Experiment stay deferred from the **2026-09-12** look (too little
  traffic). Program 2 Console is `[x]`. Program 3 clock starts.
- Program 3 in-repo + crashes / experiment / no-UA boxes closed **2026-09-13**.
  D1 paste closed **2026-09-14** from a Console look — not a readable %;
  do not invent one vs 22% median.
- Owner asked for more endgame (six chairs). EP + UX + Marketing: deepen the
  five hunts, **not** zone #16. First slice = Ashen Crown weekly kit.

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
