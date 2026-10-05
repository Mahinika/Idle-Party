# Idle Party — Play growth (what we can do)

**Updated:** 2026-10-05 · Category stays **Role Playing** (idle fantasy RPG).

### What 5 Oct changes

Window **7 Sep–4 Oct** (Play grow page, device). **17,100** device
impressions, **279** acquisitions, **101** first opens, **98** monthly
active devices. Listing conversion **16.88%**. **0** experiments.
**+196** exploration acquisitions / 90 days. D7 retained devices: **1**.

Compared with the 2 Oct window (4 Sep–1 Oct): impressions **10,400 →
17,100**, acquisitions **242 → 279**, first opens **83 → 101**, monthly
active **90 → 98**, conversion **26.65% → 16.88%**. D7 is still **1**.
About **36%** of device acquisitions opened (101 / 279). The last days
in the window are still mostly **Explore Google Play** (often 80–100%
of that day’s installs). 2–3 Oct were **6** installs each.

Account home, users, last 30 days (updated **4 Oct**): installed
audience **72**, user acquisitions **276**, rating **3.667**, gross
**12 SEK**. Do not mix these with the device funnel above.

Play vitals through **4 Oct**: no new crashes. The only non-zero days
are still **23 Sep** version **214** (1 report, 1 user) and **30 Sep**
version **222** (1 report, 1 user). No ANR rows. Crash-rate card is
still a dash. Reviews API for the last week is empty. Rating is still
**3.667** from **6** users (DE/NL/US 5★, AR 3★, JP/UA 2★). Production
live is **1.12.194 (224)**, published **4 Oct**. AdMob was not
re-read.

Firebase, same window **7 Sep–4 Oct** (includes test runs; Play first
opens in this window were **101**): **396** active users, **173** in the
last 7 days, **27** in the last day. New users **395**, returning users
**97**. `session_start` **2.35** per user. Event users: `first_open`
**395**, `app_ready` **292**, `first_enter` **282**, `first_reward`
**268**, `first_boss` **103**, `ascend` **68** (286 events),
`party_wipe` **99** users (1,541 events). `offline_gold` **1** user.
`d1_return` is absent. `app_remove` **222** users. Boot events
(`boot_intro_shown`, `new_game_shown`) are on **2–4** users, so the
title screen is not readable for this window.

Until the owner names a different bet, the 2 Oct bets still hold: do
not buy installs. The leak is still open-after-install and day-7, and
the listing now converts worse while Explore shows the page to more
people.

### What 2 Oct changes

Window **4 Sep–1 Oct** (Play grow page, device). **10,400** device
impressions, **242** acquisitions, **83** first opens, **90** monthly
active devices. Listing conversion **26.65%**. **0** experiments.
**+154** exploration acquisitions / 90 days. D7 retained devices: **1**.
AAD/AAM **19.97%** (Play flagged, −28.9% vs the prior 28 days). User
loss **23.68%**.

Traffic source is now **Explore Google Play** (about 80–100% of each
day in the last week, 14–22 acquisitions a day). Paid-and-direct is a
handful. No campaign is running. The 18 Sep Reddit post is no longer
the engine.

Installed audience kept climbing after 22 Sep: **55** devices on 25 Sep
(US 16, Germany 4, France 4, Japan 4). First opens in that window
include Brazil, Cuba, Indonesia, and Poland.

Firebase, same 28 days: **352 / 180 / 40** active users (28d / 7d / 1d),
**26m 49s** per active user, **1.2** engaged sessions, crash-free
**100%**. Cohort week 0 100%, week 1 **12.8%**, week 2 9.7%, week 3
**0%**. Events: `first_open` 351, `app_ready` 256, `first_enter` 247,
`party_wipe` 1,187 on 89 users, `session_start` 2.09 per user.

Rating **3.667** from **6** (DE/NL/US 5★, AR 3★, JP/UA 2★). Text
reviews unchanged: gear 5★, speed request 4★, Russian “not interesting”
2★. Review notifications in Console were off on this look.

Play vitals API: two crashes in September, one user each. Version code
**214** (24 Sep) and **222** (30 Sep), both SIGABRT in Impeller on
Android 16. Crash-rate card is still a dash. One crash on 222 is
`impeller::Canvas::GetLocalCoverageLimit` during a Vulkan frame.

Download size on the app-size card is about **37 MB** against a **141 MB**
peer median. Size is not the leak. Play still recommends edge-to-edge,
bitmap downsampling, and R8 on 1.12.193.

AdMob last 7 days **9.06 kr**, **438** requests, **13** impressions,
match rate **80.8%**. September **12.82 kr**. Payout identity, PIN, and
bank still open. Play IAP was **12.0 kr** on the 27 Sep look; this look
did not re-read the revenue card.

Until the owner names a different bet:

- Do not buy installs. The leak is open-after-install and day-2 return,
  not traffic.
- Next acquisition post can still be the **2026-10-18**
  `r/incremental_games` slot. Do not fill the weeks with more subs.
- Store shorts now say the game is in English. Submitted to Play
  **2026-10-02**, including `pl-PL`. `sv-SE` stayed on the 25 Sep text.
  In-game text stays English.
- The Play rating card was already after the first boss or first Ascend.
  Leave it there. Do not ask on the install. Review email notifications
  were off on the 2 Oct look; they are on for every star and for updated
  reviews as of that afternoon.

Do **not** chase Casual / Battle Royale / sandbox search volume.

**Standing principles:** [`GROWTH_MANDATE.md`](GROWTH_MANDATE.md) — no numbered
programs; owner names work. D1 is still not a Play metric.
Do not restore AL20 as the batch.

Honest growth order: **crash-free → listing conversion → D1 → D7 → rating → tiny paid test**.

### What 28 Sep changes

The 27 Sep read was lagging the 18–20 Sep wave. Fresh window **31 Aug–27
Sep**: **6,440** device impressions, **117** acquisitions, **50** first
opens, **45** monthly active devices, **42** still installed. Store
listing cards: **386** visitors, **100** unique install clicks, **26%**
click rate. D7 retained devices: **1** (19 Sep, US). The 18–20 Sep
cohort’s day-7 (25–27 Sep) is empty. Acquisitions and first opens are
both **zero** 23–27 Sep. Do not read monthly active as a return — it
still counts the install open.

One crash report on **23 Sep**, version **214** (1.12.184), one device.
ANR report empty. Crash-rate card is still a dash. Production
**1.12.187 (217)** published **28 Sep**, full rollout; it is not in this
window.

AdMob month-to-date **9.32 kr** (August **10.77 kr**). Last 7 days
**7.62 kr**, **166** requests, **9** impressions (show rate **5%** —
the app preloads a rewarded ad at boot). **27 Sep** alone was **5.04
kr** / 5 impressions. Play IAP still **12.0 kr**. Payout identity, PIN,
and bank still open. Play payment-account banner from **10 Sep** still
asks for missing info. Ignore eCPM.

The only install jump still lines up with the **18 Sep**
`r/incremental_games` post (direct-link bucket, no campaign running)
and then stops. Shorts and later posts did not start a second wave.

Until the owner names a different bet:

- Next acquisition post is the **2026-10-18** `r/incremental_games` slot.
  GIF in the post, one Play link, short body. Do not fill the weeks with
  more subs.
- Keep the listing video on the store page. Do not spend the week cutting
  another Shorts batch or sending the next 10 creator mails.
- Do not buy installs. Paid UA would buy the same leak: 117 installs, 50 opens, 1 device back on day 7.
- One listing test is no longer blocked by “~10 visitors.” It is still one
  asset, one week, and only when named. The open hole is larger than the
  store-page hole.
- Do not answer the 2★ “not interesting” review with a feature list.

Paste-ready listing copy: [`STORE_LISTING.md`](STORE_LISTING.md).  
Ops status: [`PLAY_STORE.md`](PLAY_STORE.md).

---

## Already in the repo (agent-owned)

| Lever | Where |
|-------|--------|
| ASO title + short + full (idle RPG keywords, fair SHOP line) | `docs/STORE_LISTING.md` |
| 0 kr discovery (hooks, Reddit, creator mail, gated locales) | `tool/store_listing/growth/` |
| FYP clip batch (7× 9:16 combat) | `py -3 tool/store_listing/build_hook_clips.py` → `preview/hooks/` |
| Screenshot / feature graphic checklist | `docs/STORE_LISTING.md` |
| Play preview video brief | `docs/TRAILER.md` § Play preview |
| TODAY chase clarity (claim / equip / rebuild / short phones) | `lib/core/hub_chase.dart`, `chase_dispatcher.dart`, `hub_screen.dart` |

---

## Console clicks (listing, tags, video)

Service account `play-console@idle-party-505709.iam.gserviceaccount.com`
is **Active** in Console as of **2026-09-23** (owner invite; an earlier
browser invite failed with `78F28198`). Key stays outside the repo at
`%USERPROFILE%\.config\idle-party\play-console.json`. Reviews list works
(about the last week). Do not mint another key.
`cognifoxstudio@gmail.com` is a person login, not that key.

Do these in Console when you have 20 minutes:

1. **Paste listing** from `STORE_LISTING.md` (app name **Idle Party: Idle RPG**, short + full) → submit for review. Do **not** paste `growth/LOCALES.md` until you say yes.
2. **Tags** (Butiksinställningar → Hantera taggar): live set is
   **Clicker-rollspel** + **Rollspel**. Max 5. No Idle/Incremental names in
   SV picker — do not invent tags; AFK / Party / Dungeon / Ascend belong in
   description only. Keep Clicker-spel / Rogue-liknande off (dishonest).
3. **Preview video** — Cognifox Studio public YT
   `https://www.youtube.com/watch?v=cyBlN3HCR48` (set **2026-10-04**).
   Feed Short (public combat ad): `https://www.youtube.com/shorts/l9jWy29YwJM`
   (related video → Play preview; uploaded **2026-09-12**).
   Older listing 9:16 Short: `https://www.youtube.com/shorts/wdnrXCYLtZE`.
   Rebuild: `py -3 tool/store_listing/build_preview_video.py` → 16:9 + 9:16
   (brief in `TRAILER.md` — **combat first 10 s**). Confirm YT ads stay off.
4. **Reply to reviews** (templates below) — especially 1–2★.
5. **Store listing experiments** — traffic is no longer the blocker (look
   **2026-09-27**). Still one asset, one week, only when the owner names the
   test. The open-after-install hole is the larger one.
6. **Google App campaigns** — do not start. 28 Sep read: 117 installs, 50
   first opens, 1 device back on day 7. Checklist below stays for later.

Never point players at GitHub Releases.

### Play smoke (closed 2026-09-13)

Owner confirmed on a **Play-installed** build: listing Updated, SHOP SKUs
visible, SCROLLS + AD PRIVACY path. D1 / listing A/B still deferred
(too little traffic — Console look **2026-09-12**).

### Console look (2026-09-27)

Last **28 days** (30 Aug–26 Sep) unless noted. Play still has no D1 metric.
D7 retained devices: **—**. No tiny UA.

| Surface | What we saw |
|---------|-------------|
| Funnel (Öka, Enhet) | **4,910** device impressions, **107** acquisitions, **32** first opens, **30** MAU. Listing conversion **25.48%**. **0** experiments. **+48** exploration acquisitions / 90d. |
| Installed audience | **9–16** devices through 17 Sep, then **29** (18 Sep), **39**, **43**, then about **42** through 22 Sep (latest day in that table). 22 Sep: US 13, France 5, Netherlands 4, Australia 2, other 18. |
| Acquisition source (11–20 Sep, 101 of 107) | Explore **42**, paid-and-direct **50**, none **9**. Paid-and-direct mixes ads and direct links. No campaign was running. |
| Crashes / ANR | Reporting API through **26 Sep**: no crash rows, no ANR rows. Översikt shows a dash, not a measured 0%. Firebase overview: crash-free. |
| Reviews | Average **3.50** from **4** ratings (NL 5, US 5, JP 2, UA 2). Latest text is 2★ on 1.12.172, Russian “not interesting”, already replied. |
| Revenue | Play IAP **12.0 kr** (same as the 14 Sep look). AdMob month-to-date **5.87 kr** (August **10.77 kr**). Last 7 days: **2.58 kr**, **170** requests, **4** impressions. Payout identity, PIN, and bank still open. Ignore eCPM. |
| YouTube | `@CognifoxStudio`: **2** subscribers, **4** videos. Best public Short **57** views. Live listing preview `UHLG28lHmPs`: **1** view (unlisted, 26 Sep). |
| Reddit | `r/incremental_games` still score **0**, **31%** upvotes, 1 comment. `r/IndieGaming` (25 Sep) score **0**, **40%**. `r/indiegames` removed by a mod. `r/SideProject` removed by Reddit. No second install wave after 20 Sep. |
| Firebase | Overview **218 / 123 / 23** active users (28d / 7d / 1d), **14m 20s** per active user. Includes owner test runs. Standalone Google Analytics still says this account lacks permission. Production track at the look: **1.12.186**, 100%. |

### Console D1 paste (2026-09-14)

D1 / D7 pasted from a Console look **2026-09-14**. Play has no D1 metric;
2-day and D7 are empty or n=1. Listing A/B was deferred then. No tiny UA.

### Console look (2026-09-14)

Opened after Play smoke. Last **28 days** unless noted. Numbers are
too small to call D1 good or bad vs ~22% median.

| Surface | What we saw |
|---------|-------------|
| Funnel (Öka, Enhet) | **433** device impressions, **15** acquisitions, **4** first opens, **4** MAU. D7 retained devices: **—** (no data). Grow-page listing conversion **72,73%**. +9 exploration acquisitions / 90d. **0** listing experiments. |
| Listing (Butiksuppgifter) | Data lags (through **8 Sep**). Last 28d: **9** visitors, **6** unique install clicks, **67%** CTR. Standard listing table also shows **39** visitors / **25,6%** conversion (longer / different window — do not mix with the 9). |
| Retention (Statistik) | No “after 1 day”. 2-day: **1** returner on 23 Aug and **1** on 28 Aug. D7: no data. |
| Crashes / ANR | Still none on Översikt. Rating **5,00**. Production **4** installed users. Revenue **12,0 kr**. |
| Store Listing Experiment | **Still deferred** — ~9 listing visitors / 28 days. |

### Console look (2026-09-12)

Opened after the in-repo bar. Last **28 days** unless noted (listing window
11 Aug–7 Sep). Numbers are too small to call D1 good or bad.

| Surface | What we saw |
|---------|-------------|
| Listing conversion | **11** visitors, **8** unique install clicks, **73%** CTR. Default listing **9** visitors / **66.7%**. |
| Crashes / ANR | User-perceived last 28 days: **none** (`Inga resultat`). |
| Reviews | **5★**, 1 rating, 1 review (12 Sep, gear “beroendeframkallande”, already replied). No 1–2★. |
| Store Listing Experiment | **Deferred** — ~10 listing visitors / 28 days. A/B would not finish. Revisit when traffic exists. |

---

## Review reply templates (en-US)

Keep replies short, English, no defensiveness. Fix bugs in-app when real.
**2026-09-23:** owner wants a human voice, not these lines pasted as-is.
Reply only to the review they name. Discord link, when used, is the in-game
invite in `lib/core/community_links.dart`.

**Thanks (4–5★)**
```
Thanks for playing Idle Party — glad the party crawl is landing. If something feels unclear on TODAY or KEY, tell us and we’ll tighten it.
```

**Confused / “what do I do?” (2–3★)**
```
Sorry the next step felt fuzzy. On the hub, TODAY is the one goal to chase first — claim, equip, or enter. Tap MORE → INFO if you want a short guide. Thanks for the note; we’re polishing that path.
```

**Bug / crash (1–2★)**
```
Sorry that broke your run. Please update to the latest version from Play if you haven’t. If it still happens, reply with what you tapped (hub / dungeon / GEAR) and your phone model — we’ll dig in.
```

**Ads complaint**
```
Ads are optional: hub SCROLLS only when you choose a scroll. SETTINGS → AD PRIVACY covers consent. SHOP has a cheap ad-free option if you prefer that path. Thanks for saying so.
```

**Pay-to-win worry**
```
Idle Party stays single-player and fair — SHOP is convenience (boosts / QoL), not best-in-slot for cash. Combat power still comes from play, gear, and Ascend. Appreciate you checking.
```

---

## Tiny ads checklist (optional)

Do **not** start this on the 28 Sep read. 117 installs became 50 first
opens, and 1 device came back on day 7. Revisit only after an organic
return is known and not junk.

Only if you want paid installs after listing + retention feel OK.

| Field | Start value |
|-------|-------------|
| Budget | Cap **€5–10/day** for 7 days, then stop and read |
| Goal | Installs → then optimize toward **D1 open** / retention if Console allows |
| Keywords / audiences | idle RPG, AFK RPG, idle adventure, party RPG — **not** puzzle / BR / Roblox |
| Creative | Feature graphic + first 2 screenshots + preview video if ready |
| Kill rule | Stop if D1 retention is junk or CPI >> value of a curious idle player |

Do **not** scale spend until organic D1 on a **new save** is known and not junk.

---

## Skip for now

- Another Shorts / TikTok / Reels batch (the public clips stayed under 60 views)
- The next 10 creator mails (no creator-shaped spike on the 27 Sep look)
- Paid UA / App campaigns
- Re-tagging as Casual / Action / Arcade
- Mass locale listings before EN listing + retention sit
- Chasing Play editorial featuring (Google picks)
- GitHub Releases as a player funnel  
