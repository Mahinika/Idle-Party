# Idle Party — Play growth (what we can do)

**Updated:** 2026-09-12 · Category stays **Role Playing** (idle fantasy RPG).  
Do **not** chase Casual / Battle Royale / sandbox search volume.

**Active program:** [`GROWTH_MANDATE.md`](GROWTH_MANDATE.md) done bar complete
**2026-09-12** (in-repo + Console look). Next plan is a new program — do not
silently restore AL20 as the batch.

Honest growth order: **crash-free → listing conversion → D1 → D7 → rating → tiny paid test**.

Paste-ready listing copy: [`STORE_LISTING.md`](STORE_LISTING.md).  
Ops status: [`PLAY_STORE.md`](PLAY_STORE.md).

---

## Already in the repo (agent-owned)

| Lever | Where |
|-------|--------|
| ASO short + full (idle RPG keywords, fair SHOP line) | `docs/STORE_LISTING.md` |
| Screenshot / feature graphic plan | `docs/STORE_LISTING.md` |
| Play preview video brief | `docs/TRAILER.md` § Play preview |
| TODAY chase clarity (claim / equip / rebuild / short phones) | `lib/core/hub_chase.dart`, `chase_dispatcher.dart`, `hub_screen.dart` |

---

## Owner-only (Play Console — cannot automate)

Do these in Console when you have 20 minutes:

1. **Paste listing** from `STORE_LISTING.md` (short + full) → submit for review.
2. **Tags** (Butiksinställningar → Hantera taggar): live set is
   **Clicker-rollspel** + **Rollspel**. Max 5. No Idle/Incremental names in
   SV picker — do not invent tags; AFK / Party / Dungeon / Ascend belong in
   description only. Keep Clicker-spel / Rogue-liknande off (dishonest).
3. **Preview video** — Cognifox Studio unlisted YT
   `https://www.youtube.com/watch?v=OMWXbgGBFMA` (relinked **2026-09-11**).
   Feed Short (public combat ad): `https://www.youtube.com/shorts/l9jWy29YwJM`
   (related video → Play preview; uploaded **2026-09-12**).
   Older listing 9:16 Short: `https://www.youtube.com/shorts/wdnrXCYLtZE`.
   Rebuild: `py -3 tool/store_listing/build_preview_video.py` → 16:9 + 9:16
   (brief in `TRAILER.md`). Confirm YT ads stay off.
4. **Reply to reviews** (templates below) — especially 1–2★.
5. **Store listing experiments** (if available): A/B short description vs previous.
6. Optional: **Google App campaigns** — see ads test plan below (start tiny).

Never point players at GitHub Releases.

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
Ads are optional: hub POWERUPS only when you choose a boost. SETTINGS → AD PRIVACY covers consent. SHOP has a cheap ad-free option if you prefer that path. Thanks for saying so.
```

**Pay-to-win worry**
```
Idle Party stays single-player and fair — SHOP is convenience (boosts / QoL), not best-in-slot for cash. Combat power still comes from play, gear, and Ascend. Appreciate you checking.
```

---

## Tiny ads test plan (optional)

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

- Re-tagging as Casual / Action / Arcade  
- Mass locale listings before EN listing + retention sit  
- Chasing Play editorial featuring (Google picks)  
- GitHub Releases as a player funnel  
