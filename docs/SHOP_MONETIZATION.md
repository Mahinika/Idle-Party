# SHOP monetization (real-money store)

**Status:** Catalog + UI + Play Billing client shipped (`in_app_purchase`).
Grant math: `lib/core/shop_billing.dart` (`ShopBilling.applyPurchase`) +
`metaDepth.adFree` / `shopStarterClaimed` / `shopBagBonusSlots`.
**Play Console (2026-09-10):** all five SKUs **activated** (one active purchase
option each). Smoke on a **Play-installed** build (license testers OK). Draft
SKUs do not appear in `queryProductDetails` — that was why SHOP said
“not in Play Console yet”.

**POWERUPS path:** Ad Tickets → buff shop — see [AD_POWERUPS_DESIGN.md](AD_POWERUPS_DESIGN.md).

## Why other games charge high prices

Studios that chase top-grossing charts often run a **whale ladder**:

- Top ~1–5% of spenders pay most of IAP revenue.
- Packs climb `$0.99 → $4.99 → … → $99.99`; the **largest** pack has the best
  currency-per-dollar (“gift ratio”) so high spenders buy big once.
- **Progress anxiety** (after wipes) and **gacha / loot boxes** push repeat top-ups.
- A visible `$99` **anchor** makes a `$9.99` mid pack feel “reasonable.”
- Heavy **user-acquisition** spend needs fast payback from whoever will pay.

Idle Party does **not** need that model: fairness-first, no PvP paywall, small
Alpha / GitHub installs first. Prefer many **cheap** convenience buys over few
expensive power packs.

## Idle Party principles

1. **Same power as F2P can already get** — paid Full Boost time matches POWERUPS
   ticket buffs (`×2` gold + `+25%` ATK). Buyers skip watching; they do not unlock
   a stronger combat class.
2. **Cheap ladder** — v1 ceiling **`$4.99`**. No `$49`/`$99` whale packs.
   Larger packs beat smaller ones on $/hour.
3. **No gacha / loot boxes** for real money.
4. **No BiS gear, kit unlocks, or zone skips** for cash.
5. **Clear IA:** GOLD = gold buys · ESSENCE = essence buys · SHOP = real money ·
   hub POWERUPS = optional ads → Ad Tickets → same buffs.

**Dev take-home:** Play Billing ~**15%** under $1M/yr (EEA/US/UK: 10% service +
5% billing). A `$0.99` sale ≈ `$0.84` net — still far above one rewarded ad.

## v1 catalog (USD Play tiers)

| SKU id | Play type | Price | Offer | Notes |
|--------|-----------|-------|--------|-------|
| `starter_boost_6h` | Non-consumable | $0.99 | +6h Full Boost | One-time starter (~$0.17/h) |
| `boost_12h` | Consumable | $1.49 | +12h Full Boost | Repeatable; ~$0.12/h |
| `ad_free` | Non-consumable | $2.99 | Ad-free + +2 tickets once | Hide WATCH; daily CLAIM TICKET (UTC). Priced at/above a day boost so forever is not the cheap impulse next to timed packs. |
| `day_boost_24h` | Consumable | $2.99 | +24h Full Boost | Best boost $/h (~$0.12/h) |
| `supporter_qol` | Non-consumable | $4.99 | +4 bag slots + 12h + thank-you | Ceiling; **no extra combat class** |

Boost duration still caps at **24h** remaining (`AdBoost.maxStackMs`), same as tickets.

## Relation to existing systems

| Surface | Currency | Role |
|---------|----------|------|
| Hub POWERUPS | Ad Ticket (from ad / playtest / ad-free daily) | Free path to the same buffs |
| Bottom SHOP | Real money | Full Boost hours / ad-free / small QoL |
| GOLD | Gold | Forge tracks + market |
| ESSENCE → KEEP | Essence | AL-gated permanent prestige buys |

## Play Console checklist (owner)

0. Merchant / betalningsprofil — keep payout/tax healthy so Activate stays allowed.
1. ~~Create each SKU id~~ — done 2026-09-10 (purchase type **Köp**).
2. ~~Activate~~ — done 2026-09-10 (all five show **1** active purchase option).
3. Add license testers (Settings → License testing) for sandbox buys.
4. Smoke on a **Play-installed** build — sideload / `flutter run` debug often
   cannot finish a real purchase even when the sheet opens.
5. Data safety / Privacy already mention IAP — keep Console form honest.

App code path: `ShopStore` → `ShopBilling.applyPurchase` → toast + save.
SHOP UI: **BUY** / **OWNED** + **RESTORE PURCHASES**.

## Persist fields (already on metaDepth)

| Field | Meaning |
|-------|---------|
| `adTickets` | Banked Ad Tickets |
| `adAtkUntilMs` / `adGoldUntilMs` | Sharp Edge / Gold Rush timers |
| `adOfflineMulPending` | Away Bonus ready |
| `adFree` | Hide POWERUPS ads permanently |
| `adFreeDailyClaimUtc` | Last UTC day of ad-free daily ticket |
| `shopStarterClaimed` | One-time starter pack used |
| `shopBagBonusSlots` | Extra bag slots from supporter QoL |

See also: [AD_POWERUPS_DESIGN.md](AD_POWERUPS_DESIGN.md),
[CONTENT_CADENCE.md](CONTENT_CADENCE.md), owner preferences (cheap convenience
store OK; fairness first).
