# Chase contract

One shared answer to **“what should I chase now?”** for hub TODAY, offline welcome (“Up next”), and Ascend teasers.

Source of truth for *which* chase: [`HubChase.forState`](../lib/core/hub_chase.dart).  
Facade for *all surfaces*: [`ChaseContract.fromState`](../lib/core/chase_contract.dart).

## Priority (high → low)

1. **Claimables (READY)** — daily vault, finished jobs, Meet new kit, **equip BAG upgrade**
2. **MARKET ALMOST** — affordable UPGRADE listing on POWER → MARKET (after bag equip)
3. **Ascend READY** — can Ascend now (blocked at AL20 cap)
4. **ALMOST** — one boss from Ascend, KEY+1 vault cliff (AL20 only), then zone / Will / Gauntlet / Rift / week almost
5. **First hour** — no boss and no Ascend yet: **grow the party** in the recommended zone. Skip Daily / KEY / vault-start / Will grind so TODAY is not a meta list. Skip kit teasers (`Combat Rogue` / AL1) until after the first boss.
6. **KEY habit (AL20 only)** — chase the next KEY until preferred key is at the AL cap. When at cap or before AL20, fall through.
7. **Progress grind** — daily run, vault start, Will, Gauntlet, Rift, week goal, push floors / endgame fallback

ALMOST always beats Daily / KEY habit / vault-start grind. First hour push beats Daily and KEY. Zone unlock is TODAY only when gold is **ALMOST** (playing the current zone is how you unlock the next). Never invent a second priority list in UI.

**Endgame (AL20):** KEY, Infinity Gauntlet, and Rifts share the hub. TODAY picks the nearest ALMOST cliff among them, then week / Will, then a combined endgame fallback.

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
