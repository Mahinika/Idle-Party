# Monetization — Brick Inc. Idle Breaker

Documented from **UI observation** and **IAP product list in logcat** (Play Billing catalog fetch). **No purchases were made** during research.

## Surfaces (UI)

| Surface | What sells | Screenshot |
|---------|------------|------------|
| Bottom **shop** tab / pink awning | Gem packs, gacha, items | `08_booster.png`, `10_mission.png` |
| **Summons & Money** tab | Card gacha (ad / ticket / 900 gems×10), gem item briefcases | same |
| **Special Offer** tab | Real-money bundles (not opened — IAP) | — |
| **Prism Shop** bar | Subscription / prism pass (not opened) | — |
| Left **Piggy Bank** | `piggy_bank_*` SKUs (logcat) | — |
| **Challenge Ticket Exchange Shop** | Ticket meta (portal tab) | `05_nav_portal.png` |
| **×2** speed | Likely ad or `ms_*` memberships | top bar |
| Card summon **Watch ad** | Rewarded video → 1 pull | shop overlay |
| Popups | Many `popup_*` SKUs (logcat) | not triggered |

## Prices seen (SEK, not bought)

Gem shop, Special Offer (`104_devteam.png`):

| Pack | Price |
|------|--------|
| 30 gems | Free (ad badge) |
| 100 | 13.00 kr |
| 550 | 65.00 kr |
| 1,150 | 129.00 kr |
| 2,400 | 255.00 kr |
| 6,250 | 639.00 kr |

Spellbook row sits under the gem grid (3/3, bonus badges). Prism Shop (`105_news.png`) sells a pass (shown Disabled), an attendance track, and a separate summon. Nothing on those screens was pressed.

## Booster and membership (not bought)

Booster (`179_rail_2.png`): three buffs, 50 points each, 30 minutes of time in the app. Point shop sells 100 points for an ad (5/5 used), 250 for 100 gems, 1,500 for 500 gems.

Membership (`181_booster_closed.png`): no expiry, effects stack. Ad Removal is already Purchased on this save (remove ads and 1,000 gems). Booster Membership is the next row. Mileage is an ad currency for a separate exchange shop.

Frontier's Pass (`189_pass2.png`, `232_pass_try.png`) is a check-in plus rank goals. Rank (`233_pass_rank.png`) and Field (`234_pass_field.png`) each show a free column and a **189.00 kr** column, tiers I–VI. Tooltips name Epic Rank Pass I and Epic Field Pass I. Not bought.

Daily Mission (`193_mission.png`) pays stars toward a 20–100 track. Epic Mission and Achievements sit beside it. Claim and Claim All were not pressed.

Piggy Bank (`217_piggy.png`): the large bank charges 20 gems per 10 mission points, showed 6,940/7,500, and a **65.00 kr** break-open (“Maximum x15 Value!”). The mini bank charges 5 gems per 10 points and showed 20/100. Neither button was pressed.

Beginner Step-Up Pack (`220_stepup.png` through `222_stepup_end.png`) is 8 steps. Seen prices: step 1 **12.00 kr**, steps 3 and 5 **47.00 kr**, step 7 **95.00 kr**. Other steps are marked Free and stay locked until the previous step is bought. Nothing was bought.

Epic Shop (`297_epic_shop.png`) sells permanent packs for gems: 2,500 or 5,000 each (Tachyon, Dimensional Fuel, Dial, Destiny). Two tiles unlock at Super God 10 and Super God 13. Nothing was bought. Garden Reset shows 108 gems and was not pressed. Ship's Log upgrades show a cost of 5 or 10 and were not pressed.

## Gacha (soft currency + ads)

- **Card** banner: 1× ad, 1× green ticket, 10× for **900 gems**
- Pity meter **9/50** toward red ticket
- **Quick Summon** skips animation
- Separate **Mythic Card** tab on card nav

## IAP catalog (from logcat, not prices)

Full id list: [`iap_product_ids.txt`](iap_product_ids.txt).

Grouped by prefix (meaning inferred from ids only):

| Group | Example ids | Likely purpose |
|-------|-------------|----------------|
| `gem_1` … `gem_5` | gem packs | Premium currency |
| `ms_*` | ms_ads, ms_booster, ms_mission, ms_power, ms_soul, ms_science, ms_quantum | **Membership** / ad removal / auto features |
| `rank_pass_epic_*` / `field_pass_epic_*` | 6 tiers each | Battle pass–style tracks |
| `main_super_basic_*`, `main_special_*` | bundles | Starter / special packs |
| `pr_*` | pr_science_pkg, pr_prism_pass_new_*, pr_challenge_pkg | Promotional packages |
| `piggy_bank_*` | 1, 2, 3, smart | Piggy bank break-open |
| `popup_*` | blessing, scroll, map, prism… | Contextual IAP popups |
| `event_*` | event_pass, event_point_new… | Limited-time event shop |
| `beginner_step_up_*` | 1,3,5,7 | Step-up offer ladder |
| `daily_cat` | — | Daily deal |
| `item_legend_*`, `item_epic_*` | — | Direct item SKUs |

Ads stack (logcat): **LevelPlay** (IronSource) + **Google Mobile Ads**; Unity `[Environment] Ads service : LevelPlayAdsService`.

IAP: **Unity IAP** → Play Billing.

## Idle Party lens (from `SHOP_MONETIZATION.md` / locks)

| Brick Inc habit | IP stance |
|-----------------|-----------|
| Many currencies + passes + popups | IP already limits ticket shop rows; keep honesty |
| Gacha cards | IP allows gacha per SHOP lock — but don’t clone Brick UI clutter |
| Membership per system (`ms_science`, etc.) | Consider one **Ad-free** + supporter, not six memberships |
| Rewarded → summon | IP: tickets → **same** buff shop for F2P and payers |

## Research constraint (owner 2026-11-03)

Do **not** tap Buy, Play (ticket), Claim, Summon, or Special Offer while extending this folder. Screenshots of storefronts are enough.
