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
- **First reward belongs in the first session.** Median session is about
  3–3.5 min. First boss may be too late as the D1 win. ≤90 s to combat is
  guidance only; the owner removed it as a hard lock on 2026-09-14.
- **Hide chrome until it matters.** Tip dumps and three “dailies” are churn.
  Idle practice: roll buttons out when they mean something.
- **Listing must be the live first minute.** Icon often swings search/browse
  more than screenshots; shots 1–2 still must be the crawl, not menus.
  Do not wipe the owner’s A56 save to get a new-save shot. The paste steps
  live in `play-store-prep` reference, not here.
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
- **`/init` must not restore AL20-default.** Owner names work
  (`GROWTH_MANDATE.md`) — no standing “next plan.”
- **What’s New lead is for a stranger.** First bullet = party fights / tap ENTER.
  Keep KEY / GREATER / Mastery in later bullets. Do not teach removed
  LOADOUTS / Sell junk / Scrap buttons by naming them.
- Funnel / hide-until-unlock / stranger-stays work shipped across
  **2026-09-12…14** (Play D1 still not readable). History only — not a
  standing program. Do not restore AL20 as the batch (`GROWTH_MANDATE.md`).

## 2026-09-14 — owner removed numbered plans

- Owner: **ta bort alla planer.** Growth mandate is standing principles only;
  no Program N / done bar / Robban phrase / “wait for next plan.” Default:
  owner names the work; vague → ask once.
- Same day: archived feel/polish/endgame-eval lists under `docs/archive/`
  (not agent default work). Generators → `tool/archive/`.
  Later same day: class/VFX/floor audit snapshots → `docs/archive/audits/`;
  August class batch → `docs/archive/CLASS_AUDITS_2026-08.md`.
  Living template stays `docs/CLASS_AUDIT_TEMPLATE.md`.
- Soft content locks removed (zone / class / God Hand / UA-default). Hard
  locks stay.
- Later same day: owner removed **ask-first** for zone/class/God Hand/UA/
  git push/wipe-save, and UX hard rules (flat nav / hide-until-unlock /
  ≤90 s). Then clarified: **never upload Google Play AAB without ask.**
  Placement map stays guidance. Hard locks + CI DPS gate stay.

## 2026-09-14 — /init resync after plan/lock cleanup

- Version **1.12.168** sync OK. AGENTS: Ashen weekly cave kit, Play AAB
  never-without-ask, UX placement guidance (not hard flat-nav), `docs/archive/`
  pointer. changelog_sync + ship_smoke green.

## 2026-09-14 — Craft Trial / STAR NODES honesty + 1.12.170

- STAR NODES points from Ashen / Craft Trial must bank before AL20 (spend
  still waits for KEEP). What’s New names Craft Trial + STAR NODES. Ship
  **1.12.170 / 200** — Production AAB submitted for review **2026-09-14**.

## 2026-09-14 — Console D1 is not a number yet

- Agent opened Play Console (Cognifox Studio / Idle Party production).
  Play has **no D1** (earliest return is 2 days). 2-day = two days with
  1 returner each; D7 empty. ~4 first opens / 15 acquisitions / 9 listing
  visitors. Paste that — do not invent a % vs 22% median.

## 2026-09-13 — seats; Play smoke; endgame identity

- EP + UX + Marketing: strangers on Play matter more than AL20 polish;
  crawl feel without zone #16. Game Director may freshen packs/tells against
  play notes. Endless KEY / Rift / GR is quality, not the story.
- Owner confirmed Play publish + SHOP/POWERUPS smoke **2026-09-13**. D1 /
  Store Listing Experiment deferred (too little traffic).
- Owner asked for more endgame (six chairs). Deepen the five hunts, **not**
  zone #16. Identity slices shipped the same week (Ashen week kit, Gauntlet
  tells, KEY week cave).

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

## 2026-09-23 — Play replies, and the robot login

- **Reply like a person, only on the review they name.** Angel (20 Sep, 3★,
  Russian “не интересно”, realme 11, **1.12.172**) is boredom, not a bug.
  Live reply is conversational and includes the in-game Discord invite
  `https://discord.gg/YMz5ZMkEG9`. The polished first draft was rejected the
  same day. Brendan’s 5★ speed note also has a human reply with the same
  Discord invite — do not answer it again.
- **Read the review back before saying it posted.** Typing in the box does
  not send. Update stays disabled until the field gets a real input event.
  A page script cannot POST the reply (blocked). Re-read the published text.
- **The robot login works after the owner invites it.** Browser invite of
  `play-console@idle-party-505709.iam.gserviceaccount.com` failed
  (`78F28198`). Owner invite the same day stuck: Active, no expiry. Key
  stays outside git (`%USERPROFILE%\.config\idle-party\play-console.json`).
  How to call it, and what it cannot see (downloads, first opens, rating),
  lives in `play-store-prep` reference § Play API — not a second skill.
  `cognifoxstudio@gmail.com` is still just a person login. Do not mint
  another key.

## 2026-09-24 — first Discord bug

- **#bugs is the report. The picture is the bug.** Just vin (23 Sep, Play)
  set text scale to max and the boss banner sat on the boss panel. Reply on
  that message in English. Do not say the Play build is fixed until the owner
  asks for an AAB. What’s New waits for the version bump — no unreleased
  notes list. Not a new skill; this happened once.
- **The bug form is two lines.** What I did / What went wrong, plus a
  screenshot. Version is optional. Do not put back the five-step form
  (expected, version, GitHub APK vs closed test).
