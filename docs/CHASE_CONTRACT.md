# Chase contract

One shared answer to **“what should I chase now?”** for hub TODAY, offline welcome (“Up next”), and Ascend teasers.

Source of truth for *which* chase: [`HubChase.forState`](../lib/core/hub_chase.dart).  
Facade for *all surfaces*: [`ChaseContract.fromState`](../lib/core/chase_contract.dart).

## Priority (high → low)

1. **Claimables (READY)** — daily vault, finished **QUESTS**, Meet new kit, **equip BAG upgrade**
2. **MARKET ALMOST** — affordable UPGRADE listing on POWER → MARKET (after bag equip)
3. **Ascend READY** — can Ascend now (blocked at AL20 cap)
4. **ALMOST** — one boss from Ascend, KEY+1 vault cliff (endgame only), then zone / Will / Gauntlet / Rift / week almost
5. **Level the party** — before endgame unlock, chase active party toward **Lv100** when that is the gate
6. **First hour** — no boss and no Ascend yet: **grow the party** in the recommended zone. Skip Daily / KEY / vault-start / Will grind so TODAY is not a meta list. Skip kit teasers until after the first boss.
7. **KEY habit (endgame only)** — chase the next KEY until preferred key is at the dial cap. When at cap or before party max level, fall through.
8. **Progress grind** — daily run, vault start, Will, Gauntlet, Rift, week goal, push floors / single endgame fallback

ALMOST always beats Daily / KEY habit / vault-start grind. First hour push beats Daily and KEY. Zone unlock is TODAY only when party level is **ALMOST** (or prior clear opens the path). Never invent a second priority list in UI.

**Endgame unlock:** active party all at [`GameLogic.maxHeroLevel`](../lib/core/game_logic.dart) (**100**) via `endgameUnlocked` — not AL20 alone. AL20 remains the Ascend cap. KEY, Infinity Gauntlet, Rifts, and Greater Rifts share the hub once unlocked. TODAY picks the nearest ALMOST cliff among them, then week / Will, then one actionable fallback (not a stats dump).

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
