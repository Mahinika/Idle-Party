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
