# POWERUPS design — Ad Tickets → buff shop (Variant B)

**Status:** Shipped in code (Ad Tickets → buff shop).  
**Research base:** Brick Inc–style ad currency → shop (see session research /
plan *Ad-valuta research*).  
**Related:** [SHOP_MONETIZATION.md](SHOP_MONETIZATION.md) (real-money ladder).

## Goal

Replace today’s **direct** loop (watch ad → fixed ×2 gold +25% ATK for 3h) with:

1. Watch a rewarded ad → earn **Ad Tickets** (soft currency).
2. Spend tickets in a small **POWERUPS shop** on the buff you want, when you want it.

Same principles as SHOP: opt-in only, never interrupt combat, F2P and payers get
the **same** buffs (payers skip watching / buy tickets).

## Why this shape

| Need | Choice |
|------|--------|
| Player agency | Tickets bank; shop has a few clear rows |
| Avoid Brick Inc currency clutter | **One** new currency + ≤4 shop rows |
| Fairness first | Buffs stay near today’s power — **not** +100% ATK |
| Hub calm / AL20 chase | Entry is a small hub FAB; TODAY stays primary |
| IAP honesty | SHOP sells tickets or time on the **same** buffs |

## Player-facing names (English UI)

| Term | Meaning |
|------|---------|
| **Ad Ticket** | Soft currency from watching one ad (or from SHOP) |
| **POWERUPS** | Sheet / shop title (keep existing label) |
| **WATCH** | Earn +1 Ad Ticket |
| **USE** / row buttons | Spend tickets on a buff |

No second jargon name (“ad coins”, “video points”). One word: **Ticket**.

## Loop

```mermaid
flowchart LR
  fab[Hub_FAB]
  sheet[POWERUPS_sheet]
  watch[WATCH_ad]
  tickets[Ad_Tickets]
  buy[USE_buff_row]
  active[Buff_timer]

  fab --> sheet
  sheet --> watch --> tickets
  tickets --> buy --> active
```

## Hub entry (UX)

- **Floating camera overlay** on the hub World Path (portrait, bottom-trailing
  of the map, clear of the hunt card / ENTER and the header Settings cog).
- FAB shows:
  - Film-camera glyph (`UiGlyph.film`) at 48dp.
  - Ticket count badge when tickets > 0.
  - Short status under the icon: `WATCH`, `N TICKETS`, or `ATK 42m`.
  - Dim when idle; torch-lit when tickets or a buff is active.
- **No dungeon FAB** in v1 (combat chrome stays clean; ads never mid-fight).
- Tap FAB → bottom sheet with two blocks:
  1. **Earn** — WATCH AD · +1 Ticket (playtest: PREVIEW +1).
  2. **Spend** — catalog rows (below).

Visibility gates:

- First hour (plain chrome): hide FAB unless a buff is active **or**
  tickets > 0 (so banked tickets stay reachable).
- Otherwise always show on hub (phone, READY claims, endgame KEY hunts).
- `adFree`: hide WATCH; keep Spend + claim-without-video if we grant a free
  daily tap (see IAP). Hide FAB when nothing to claim and no tickets/buff.

## Economy numbers (v1)

| Knob | Value |
|------|-------|
| Tickets per finished ad | **1** |
| Soft earn cap | **None** per day in v1 (revisit if AL20 feels mandatory) |
| Ticket persist | Survives Ascend / REBORN (with other meta) |
| Max stack per buff | **24h** remaining (same as `AdBoost.maxStackMs`) |

Migration from current saves:

- Convert remaining `adBoostUntilMs` into the new **bundled** buff timers
  (gold ×2 + ATK +25% both set to the same `untilMs`), tickets start at **0**.
- Old field can stay as legacy or be cleared after migrate once.

## Buff catalog (exactly 4 rows)

Effects stay **near current** power. Do **not** ship +100% ATK in v1.

| Id | Label | Effect | Duration | Cost | Notes |
|----|-------|--------|----------|------|-------|
| `atk` | Sharp Edge | **+25% ATK** | **60 min** | **1** ticket | Combat push |
| `gold` | Gold Rush | **×2 gold** (combat + hub AFK) | **60 min** | **1** ticket | Same ×2 as today |
| `bundle` | Full Boost | **+25% ATK** and **×2 gold** | **3 hours** | **2** tickets | Matches today’s “one ad” value (3h both) |
| `offline` | Away Bonus | Next offline / Welcome Back gold claim **×2** (one shot) | Until claimed or **24h** expiry | **1** ticket | Convenience; not combat |

### Stack / interact rules

- **Same buff again:** extend remaining time from current end (or from now if
  expired), cap 24h. Effects do **not** stack in magnitude (still +25%, not +50%).
- **`atk` + `gold` both active:** both apply (same as today’s bundle split).
- **`bundle` while split buffs active:** extends **both** timers by 3h (capped).
- **`offline`:** one pending flag; watching another Away Bonus while pending
  refreshes expiry only — does not double-stack the multiplier.
- Bundle and split are the **same** ATK%/gold mult — no extra power from owning
  both labels.

### Why not +100% / 30 min

Brick Inc–style spike buffs feel great in clickers; in Idle Party they skew
wipe advice, KEY timing, and “same power as SHOP”. Start at **+25% / ×2**;
revisit only after AL20 play notes.

## Persist fields (future `metaDepth`)

| Field | Meaning |
|-------|---------|
| `adTickets` | int ≥ 0 |
| `adAtkUntilMs` | Sharp Edge end |
| `adGoldUntilMs` | Gold Rush end |
| `adOfflineMulPending` | bool — Away Bonus ready |
| `adOfflineMulExpiresMs` | expiry if unclaimed |
| `adFree` | unchanged — hide WATCH |
| *(legacy)* `adBoostUntilMs` | migrate → both untilMs, then ignore |

Combat / gold readers use the new until fields (ATK% if `adAtkUntilMs` active;
gold ×2 if `adGoldUntilMs` active). Away Bonus applies only on the next
eligible offline claim path.

## SHOP bridge (real money)

Keep cheap ladder; retarget grants to **tickets** and/or **same buffs**:

| SKU (keep ids) | New grant |
|----------------|-----------|
| `starter_boost_6h` | +**2** tickets **or** +6h Full Boost (prefer **+6h bundle** once for clarity) |
| `boost_12h` | +12h Full Boost (both timers) |
| `day_boost_24h` | +24h Full Boost |
| `ad_free` | Permanent hide WATCH + **+2 tickets** once (welcome) + Brick Inc rule: optional **CLAIM TICKET** without video once every **UTC day** while ad-free (same +1 as WATCH) |
| `supporter_qol` | +4 bag slots + 12h Full Boost (unchanged spirit) |

**Locked rule:** no SHOP SKU grants a stronger combat mult than ticket shop rows.

Update [SHOP_MONETIZATION.md](SHOP_MONETIZATION.md) when coding starts so tables
match this doc.

## Copy (sheet, English)

- Earn blurb: *Watch a short ad for 1 Ad Ticket. Spend tickets on timed boosts.
  Optional — fights never pause for an ad.*
- Cap blurb: *This boost is stacked to 24h — wait for time to burn, then buy
  again.*
- Empty tickets: *WATCH an ad to earn a ticket.*

## Out of scope (v1)

- Dungeon floating icon
- Daily ad impression hard cap
- Extra currencies / gacha / random buff chests
- Progressive “watch more → stronger forever” (Legend of Slime style)
- Changing God Hand / essence / KEY with ads

## Implementation map (when coding is approved)

1. `save-migrate`: new meta fields + migrate `adBoostUntilMs`.
2. Replace / extend `AdBoost` helpers for per-buff timers + ticket math.
3. `GameLogic` spend/earn APIs; wire `GameDirector` WATCH → +ticket; USE → spend.
4. Rebuild [lib/ui/hub/hub_powerups.dart](../lib/ui/hub/hub_powerups.dart) FAB + sheet.
5. Combat/gold/offline readers; What’s New one-liner; tests for migrate / spend /
   cap / Ascend keep / `adFree` daily claim.
6. Sync SHOP catalog strings + billing grants.

## Acceptance (owner AL20 phone)

1. Hub shows a camera overlay on the World Path; hunt card / ENTER still read first.
2. WATCH → +1 ticket; USE Sharp Edge → +25% ATK for ~60m visible in combat feel.
3. USE Full Boost → both gold ×2 and +25% for ~3h (old “one ad” feel).
4. No ad during an open dungeon fight.
5. Ascend keeps tickets and remaining buff time.
6. SHOP copy still says same power as tickets / ads.
