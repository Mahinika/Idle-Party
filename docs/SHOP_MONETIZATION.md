# SHOP monetization (real-money store)

**Status:** Catalog + UI shell shipped; buttons say **COMING LATER**. Grant math lives in
`lib/core/shop_billing.dart` (`ShopBilling.applyPurchase`) + `metaDepth.adFree` /
`shopStarterClaimed` / `shopBagBonusSlots`. **`in_app_purchase` not in pubspec yet** —
flip `ShopBilling.billingReady` when Console SKUs + package wire.

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

## Billing wave checklist (post-production)

1. Create Play Console IAP products matching `ShopCatalog` ids (consumable boosts + non-consumable `ad_free` / `supporter_qol`).
2. Add `in_app_purchase` to `pubspec.yaml`; wire buy / restore → `ShopBilling.applyPurchase`.
3. Set `ShopBilling.billingReady = true`; change SHOP buttons from COMING LATER to BUY.
4. Update Data safety + Privacy for IAP; listing full description may mention cheap SHOP.
5. Sandbox purchase smoke on a Play-installed build (not sideload).

## Persist fields (already on metaDepth)

| Field | Meaning |
|-------|---------|
| `adFree` | Hide POWERUPS ads permanently |
| `shopStarterClaimed` | One-time starter pack used |
| `shopBagBonusSlots` | Extra bag slots from supporter QoL |

See also: [CONTENT_CADENCE.md](CONTENT_CADENCE.md), owner preferences (cheap
convenience store OK; fairness first).
