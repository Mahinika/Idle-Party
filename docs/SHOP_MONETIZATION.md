# SHOP monetization (real-money store)

**Status:** Catalog + UI shell shipped; **Play Billing not wired yet** (Buy buttons show
*BUY SOON*). Source of truth for offered SKUs: `lib/core/shop_catalog.dart`.

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

1. **Same power as F2P can already get** — paid POWERUPS time matches hub ads
   (`×2` gold + `+25%` ATK). Buyers skip watching; they do not unlock a stronger
   combat class.
2. **Cheap ladder** — v1 ceiling **`$4.99`**. No `$49`/`$99` whale packs.
   Larger packs beat smaller ones on $/hour.
3. **No gacha / loot boxes** for real money.
4. **No BiS gear, kit unlocks, or zone skips** for cash.
5. **Clear IA:** GOLD = gold buys · ESSENCE = essence buys · SHOP = real money ·
   hub POWERUPS = optional ads for the same boost.

**Dev take-home:** Play Billing ~**15%** under $1M/yr (EEA/US/UK: 10% service +
5% billing). A `$0.99` sale ≈ `$0.84` net — still far above one rewarded ad.

## v1 catalog (USD Play tiers)

| SKU id | Price | Offer | Notes |
|--------|-------|-------|--------|
| `starter_boost_6h` | $0.99 | +6h POWERUPS | One-time starter (~$0.17/h) |
| `boost_12h` | $1.49 | +12h POWERUPS | Repeatable; ~$0.12/h |
| `ad_free` | $1.99 | Ad-free + +6h once | Permanent hide POWERUPS ads |
| `day_boost_24h` | $2.99 | +24h POWERUPS | Best boost $/h (~$0.12/h) |
| `supporter_qol` | $4.99 | +4 bag slots + 12h + thank-you | Ceiling; **no extra combat class** |

Boost duration still caps at **24h** remaining (`AdBoost.maxStackMs`), same as ads.

## Relation to existing systems

| Surface | Currency | Role |
|---------|----------|------|
| Hub POWERUPS | Ad (or playtest grant) | Free path to the same boost |
| Bottom SHOP | Real money | Convenience / ad-free / small QoL |
| GOLD | Gold | Forge tracks + market |
| ESSENCE → KEEP | Essence | AL-gated permanent prestige buys |

## Later (not this pass)

- Google Play Billing product IDs + purchase / restore
- Persist `adFree` / one-time starter claimed on `metaDepth`
- Apply boost hours / bag slots on successful purchase
- Privacy / Play Console IAP declarations

See also: [CONTENT_CADENCE.md](CONTENT_CADENCE.md), owner preferences (cheap
convenience store OK; fairness first).
