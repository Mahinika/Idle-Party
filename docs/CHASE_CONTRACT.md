# Chase contract

One shared answer to **“what should I chase now?”** for hub TODAY, offline welcome (“Up next”), and Ascend teasers.

Source of truth for *which* chase: [`HubChase.forState`](../lib/core/hub_chase.dart).  
Facade for *all surfaces*: [`ChaseContract.fromState`](../lib/core/chase_contract.dart).

## Priority (high → low)

1. **Claimables (READY)** — daily vault, finished **QUESTS**, Meet new kit, **equip BAG upgrade**
2. **MARKET ALMOST** — affordable UPGRADE listing on POWER → MARKET (after bag equip)
3. **Ascend READY** — can Ascend now (blocked at AL20 cap). **Exception:** on **AL0** after the first boss, TODAY stays Daily / farming; Ascend shows on the urgent row only (not the sole big button). Confirm copy: party stays; bag, gold, forge, and floors reset.
4. **ALMOST** — one boss from Ascend, then KEY+1 vault cliff (endgame only), then zone / Will / Gauntlet / Rift / week almost
5. **Fresh prestige re-kit** — after Ascend or optional AL20 Reborn (`metaDepth.freshPrestige` and low gear pressure): TODAY says **Rebuild your bag** / farm floor 1. Skip KEY / Gauntlet / Rift until real drops land. **Reborn is never a TODAY chase.**
6. **Level the party** — before endgame unlock, chase active party toward **Lv100** when that is the gate
7. **First hour** — no boss and no Ascend yet: **grow the party** in the recommended zone. Skip Daily / KEY / vault-start / Will grind so TODAY is not a meta list. Skip kit teasers until after the first boss.
8. **KEY habit (endgame only)** — chase the next KEY until preferred key is at the dial cap. When at cap or before party max level, fall through.
9. **Endgame ladder (party Lv100)** — after KEY at cap: Greater Rift → Gauntlet → Rift → Ashen Crown (ticket week). One hunt — not Daily/Will shuffle.
10. **Progress grind** — daily run, vault start, Will, leftover endgame (pre–Lv100), week goal, then **one** endgame fallback (time KEY at dial / push GR — never a stats dump)

ALMOST always beats Daily / KEY habit / vault-start grind. First hour push beats Daily and KEY. Zone unlock is TODAY only when party level is **ALMOST** (or prior clear opens the path). Never invent a second priority list in UI.

**Endgame unlock:** active party all at [`GameLogic.maxHeroLevel`](../lib/core/game_logic.dart) (**100**) via `endgameUnlocked` — not AL20 alone. AL20 remains the Ascend cap. KEY, Infinity Gauntlet, Rifts, Greater Rifts, and Ashen Crown share the hub once unlocked. At AL20 + party max, TODAY prefers the endgame ladder before Daily, then one actionable fallback (not a multi-line stats dump).

**Zones:** unlock by party mean level (even steps Lv1…Lv100) or by clearing the previous zone.

## Urgency chrome

| Urgency | Player-facing | Surfaces |
|---------|---------------|----------|
| `ready` | READY / claim CTA | TODAY card, Up next — ready |
| `almost` | ALMOST | TODAY card, Up next — almost |
| `normal` | (none) | TODAY title only |

## Ascend teasers

Kit unlock lines come from [`AscendRoadmap`](../lib/core/ascend_roadmap.dart) and are folded into chase **detail** (already) and into `ChaseContract.ascendTeaser` for confirm/toast consistency.

## Rules

- Hub TODAY is the primary chase chrome; other hub buttons are shortcuts to the same goals.  
- Offline “Up next” **must** use `ChaseContract.fromState(summary.state)` — same title/urgency as hub.  
- No new meta loops in this contract — only packaging.
