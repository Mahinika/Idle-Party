# Systems map — Brick Inc. Idle Breaker

Inferred from UI + boot logcat (`logcat_unity_services.txt`). Not authoritative game design docs.

## Core combat / idle

| System | Player-facing | Behavior (observed) |
|--------|---------------|---------------------|
| **Field** | Field: N | Brick wall stage; breaking bricks drops rewards; projectiles auto-fire |
| **Fire rate** | e.g. 175.3gi/s | Global DPS cadence display |
| **Units / cards** | 5 slots + Assist | Each slot has upgrade cost; icons = themed “helpers” (snail, eye, mouse, etc.) |
| **Equipment upgrades** | Double Axe, Bee Missile, drills… | Linear levels (+875), **MAX** at cap; list is main moment-to-moment interaction |
| **Active cap** | 182/182 | Limits simultaneous entities or DPS sources |
| **×2 speed** | Top-right | Game speed multiplier (engagement / ad hook) |

## Progression layers

| Layer | Entry | Purpose |
|-------|--------|---------|
| **Rank** | Super God 9 | Long prestige / title ladder |
| **Power** | Lightning **li** | Primary power score; feeds Wheel of Life |
| **Soft gold** | Star counter **ev** scale | Main incremental currency |
| **Gems** | Pink diamonds | Premium + shop pulls |
| **Cards** | Nav tab 1 | Card / Mythic Card collection (gacha-linked) |
| **Meta hex** | Nav tab 2 | Epic, Soul, Science, Dimension, Art, System Admin |
| **Wheel of Life** | Under hex tab | Cross-currency generators (li → pb → ad) |
| **Challenge** | Portal tab | Wall of Eternity (distance), Golden Altar (score), tickets |
| **New World** | Portal sub-tab | **World Ablaze** this week: weapon bonuses also scale gold (exponent 0.2). Normal / Hard / Extreme. ~3 days left on the shot |
| **Missions / Event** | Right rail | Task lists + limited events |
| **Booster / Growth / Piggy** | Left rail | Boosters, growth bundle, piggy bank IAP hooks |

## Online / backend (logcat)

Boot sequence shows live service game:

| API / service | Role |
|---------------|------|
| `ApiGetSystemStatus` | Version, maintenance windows |
| `ApiGetSystemMasterDataAll` | Master data blob |
| `ApiGetUserStatus` | Ban, save id, sequence |
| `ApiUserDataFind` | Cloud save load |
| `ApiGetSystemConfig`, `ApiGetEvents`, `ApiGetEventResources` | Live ops config |
| Firebase Remote Config | `Remote Config fetch completed` |
| Unity Authentication | Player id + **Google Play Games** link |

Save metadata example: `saveId`, `saveSequence` 1815 — server-authoritative progression.

## Content delivery

- **Unity Addressables** (errors for missing `Sound/sfx_IBB_*` on partial emu install)
- **Play Asset Delivery** packs: `UnityDataAssetPack`, `UnityStreamingAssetsPack` (log at boot)
- **Unity 6000.3.21f1**, IL2CPP **arm64** on device

## Challenge economy (UI only)

- **Challenge tickets** — count 49 on Wall of Eternity row
- **Free** entry button (red dot) vs **Play** costing 1 ticket
- **Challenge Ticket Exchange Shop** — separate from gem shop

## Mapped this pass

Details and shot names: [SCREENS.md](SCREENS.md).

- **Epic** permanent gem upgrades (combat caps) plus a per-weapon damage track.
- **Soul Altar** five global multipliers. Upgrade and Enhancement tabs exist; interiors not opened.
- **Science** Innovation Lab (idle producer) plus Weapon, Brick, and Corruption tracks, almost all at cap on this save (Lv.1500 or Lv.250).
- **Dimension** four activities plus a gear inventory (combine / dismantle).
- **Art** Garden of Truth node web (0/297 on this page).
- **Cards** rarity collection and a per-card level-up priced in gems.
- **Challenge** Wall of Eternity (distance) and Golden Altar (score), ticket entry, leaderboard (power / wall / altar).
- **New World** rotating world with a difficulty and a move button.
- **Settings** local save plus optional cloud link. AutoSave is on. Play Games is already linked on this emu.

## Still closed (on purpose or missed)

Mission, Event, Booster, Piggy, Growth, Preset editor, Soul Upgrade / Enhancement, Decay, Curse, Ragnarok / Warframe / Oracle / Nexus, Garden sub-tabs, and hamburger pages other than Settings. Shop prices were only looked at.

## Idle Party rebuild prompts (ideas, not copy)

1. **Single-screen upgrade scroll** next to combat keeps hands busy — IP already splits hub vs dungeon; could borrow “upgrade list beside fight” for early game only.
2. **One ticket currency** for side modes beats Brick’s currency sprawl — aligns with `AD_POWERUPS_DESIGN.md`.
3. **Rank title + field number** = double readable progression (IP: zone + floor).
4. **Server save** — IP is local-first; Brick’s cloud is retention for reinstall, not a feature to clone blindly.
