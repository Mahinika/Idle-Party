# UI shell — Brick Inc. Idle Breaker

Observed on Play emu, save **Super God 9** / **Field 90** (owner account). Screens in `screens/`.

## Research rule

**No purchases:** navigation and screenshots only — no IAP, no gem/ticket spends, no gacha pulls, no paid “Play” that consumes tickets. Shop screens are **read-only** reference (`06`, `08`, `10`, `11`).

## Global chrome (always visible)

| Zone | Elements | Notes |
|------|-----------|--------|
| Top-left | Rank title (e.g. **Super God 9**) | Prestige / rank ladder label |
| Top bar | Gold star soft currency, **pink gems** (premium), extra counters (cards, diamonds, lightning **power**) | Many currencies; magnifying glass = detail popup |
| Top-right | **×2** speed toggle (red dot when boost available), **hamburger** menu | Speed is core idle UX |
| Left rail | **Booster**, **Piggy Bank**, **Growth Center** | Floating promo / meta entry (opens overlays) |
| Right rail | **Mission**, **Event**, gift boxes | Timed events + missions |
| Bottom nav (5) | See table below | Center tab = main loop |

### Bottom navigation (1080×2400 emu)

| Slot | Icon read | Screen | Screenshot |
|------|-----------|--------|------------|
| 1 | Green star / box | **Card** collection (`Card` / `Mythic Card` sub-tabs) | `02_nav_star.png` |
| 2 | Purple hex | **Meta hub** — Epic, System Admin, Soul, Science Foundation, Dimension, Art Society + **Wheel of Life** | `03_nav_hex.png` |
| 3 | Large bullet (center) | **Main battle** — brick field, unit row, upgrade list | `01_main_gameplay.png`, `14_upgrade_panel.png` |
| 4 | Stone portal + timer | **Challenge hub** — Leaderboard, Preset, ticket shop banner, Wall of Eternity, Golden Altar; sub-tabs **Challenge** / **New World** | `05_nav_portal.png`, `06_nav_shop.png` (mis-tap: same hub) |
| 5 | Pink shop awning | Opens **real-money / gem shop** overlay (Summons & Money) | `08_booster.png`, `10_mission.png`, `11_event.png` (opened via left/right rail taps landing on shop) |

Close shop overlay: red **X** on bottom-left of shop (`11_event.png`).

## Main battle tab (core loop)

**Field:** numeric stage (**Field: 90**). Side-scrolling brick breaker: projectiles, brick HP, loot bursts.

**Mid screen — unit / skill row:** Five slots with icon + **soft cost** (gi/fy notation). **Assist** row below (weapon badges, “A” markers).

**Stats strip:** ATK / crit / secondary / **182/182** active count (units or projectiles cap).

**Upgrade list (scroll):** Rows like **Double Axe +875 MAX**, **Bee Missile +875 MAX**, drill upgrades with costs. **MAX** = at cap; pink **Max** on field edge = buy-max toggle.

**Footer on battle:** **175.3gi/s** fire-rate readout.

## Meta hub (hex tab)

Six large tiles → separate progression systems (names only observed):

- **Epic**, **System Admin**, **Soul**, **Science Foundation**, **Dimension** (shows **100**), **Art Society**

**Wheel of Life:** Converts **power (li)** → blue swirl (**oz/s**), swirl → purple gear (**ad/s**); storage **af**; **Acceleration Off** toggle.

## Challenge hub (portal tab)

Stacked full-width buttons:

- **Leaderboard**, **Preset**
- **Challenge Ticket Exchange Shop** + **Claim All Free Tickets** (not tapped — would spend/claim)
- **Wall of Eternity** — distance **125,100m**, bonus **+32.2e%**, ticket count, **Free** / **Play (1 ticket)**
- **Golden Altar** — high score **49.6ev**

Sub-header: **Challenge** vs **New World** (timer **71h:21** on portal icon).

## Shop overlay (gem / gacha — view only)

Tabs: **Special Offer** (not opened — IAP risk), **Summons & Money** (documented).

Sections:

- **Card** gacha: ad pull, ticket pull (3/1), **900 gem ×10**; pity **9/50**; Quick Summon checkbox
- **Item**: gem-priced briefcases **100 / 200 / 400** gems, **1/1** limit
- **Prism Shop** entry bar (not opened)

## UX patterns (for Idle Party comparison)

| Pattern | Brick Inc | Idle Party today (short) |
|---------|-----------|---------------------------|
| Primary loop | One screen: field + infinite upgrade list | Hub + dungeon floor combat |
| Nav depth | 5 bottom tabs + 6 meta tiles + rails | 5 bottom bar + hub map |
| Notification | Red dots on shop, portal, ×2, free buttons | Hub TODAY, red badges on tabs |
| Number format | Letter suffix stack (gi, ev, li, ds…) | Standard idle abbreviations in places |
| Monetization surface | Shop on dedicated tab + rails + popups (logcat) | SHOP + SCROLLS tickets |

## Capture tooling

`py -3 tool/brick_inc_capture.py <file.png> [--tap X Y] [--note "..."]` — logs to `SESSION_LOG.md`.

Unity does **not** expose gameplay in Android accessibility tree (only `SurfaceView`); exploration is screenshot + coordinate taps.
