# Chase contract

One shared answer to **“what should I chase now?”** for hub TODAY, offline welcome (“Up next”), and Ascend teasers.

Source of truth for *which* chase: [`HubChase.forState`](../lib/core/hub_chase.dart).  
Facade for *all surfaces*: [`ChaseContract.fromState`](../lib/core/chase_contract.dart).

## Priority (high → low)

1. **Claimables (READY)** — daily vault, finished jobs, Meet new kit  
2. **Ascend READY** — can Ascend now  
3. **ALMOST** — one boss from Ascend, KEY+1 vault cliff, then zone / Will / Gauntlet / week almost  
4. **First hour** — no boss and no Ascend yet: **grow the party** in the recommended zone. Skip Daily / vault-start / Will grind so TODAY is not a meta list.  
5. **Progress grind** — daily run, vault start, Will, Gauntlet, week goal, push floors  

ALMOST always beats Daily / vault-start grind. First hour push beats Daily. Zone unlock is TODAY only when gold is **ALMOST** (playing the current zone is how you unlock the next). Never invent a second priority list in UI.

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
