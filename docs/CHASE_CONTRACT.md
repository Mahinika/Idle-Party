# Chase contract

One shared answer to **“what should I chase now?”** for hub TODAY, offline welcome (“Up next”), and Ascend teasers.

Source of truth for *which* chase: [`HubChase.forState`](../lib/core/hub_chase.dart).  
Facade for *all surfaces*: [`ChaseContract.fromState`](../lib/core/chase_contract.dart).

## Priority (high → low)

1. **Claimables (READY)** — daily vault (payday copy only; season bonus still pays on claim), finished **QUESTS**, Meet new kit, **equip BAG upgrade** (`EQUIP N` CTA + slot when known)
2. **Market ALMOST** — affordable UPGRADE on GOLD → MARKET (after bag equip). **Pre-endgame only** before KEY nights; at party Lv100 market waits until after KEY habit / endgame ladder / zone.
3. **Ascend READY** — can Ascend now (blocked at AL20 cap). **Exception:** on **AL0** after the first boss, TODAY stays Daily / farming; Ascend shows on the urgent row only (not the sole big button). Confirm copy: party stays; bag, gold, forge, and floors reset.
4. **ALMOST** — one boss from Ascend, then KEY+1 vault cliff (endgame only), then zone. **Month ALMOST** and Will / early week ALMOST: pre–Lv100 only before KEY. **At party Lv100:** Month ALMOST sits **after** the endgame ladder so Spire/KEY nights stay clear; Gauntlet/Rift/GR ALMOST still apply.
5. **Fresh prestige re-kit** — after Ascend or optional AL20 Reborn (`metaDepth.freshPrestige` and low gear pressure): TODAY says **Rebuild your bag** with plain farm/re-equip copy + geared % progress. Skip KEY / Gauntlet / Rift until real drops land. **Reborn is never a TODAY chase.**
6. **Level the party** — before endgame unlock, chase active party toward **Lv100** when that is the gate
7. **First hour** — no boss and no Ascend yet: **grow the party** in the recommended zone. Skip Daily / KEY / vault-start / Will grind so TODAY is not a meta list. Skip kit teasers until after the first boss.
8. **KEY habit (endgame only)** — chase the next KEY until preferred key is at the dial cap (TODAY detail includes affixes + par). Does **not** wait on unpaid Daily.
9. **Endgame ladder (party Lv100)** — after KEY at cap: week ALMOST (if any) → Gauntlet (PB after F100) → Greater Rift → Rift → Ashen Crown. Month ALMOST after ladder. One hunt — not Daily/Will shuffle.
10. **Done for today** — when Vault + Daily + KEY dial are settled and the ladder is quiet (PB only): soft rest with KEY · BOARDS CTA; Spire PB stays optional in the detail. **Week ALMOST / READY** still beat this soft rest (normal week progress does not).
11. **Progress grind** — daily run, vault start, Will (CODEX CTA), leftover endgame (pre–Lv100), Shop (endgame), week goal, then **one** endgame fallback (time KEY at dial / push GR — never a stats dump)

ALMOST always beats Daily / KEY habit / vault-start grind. First hour push beats Daily and KEY. Zone unlock is TODAY only when party level is **ALMOST** (or prior clear opens the path). Never invent a second priority list in UI.

**Endgame unlock:** active party all at [`GameLogic.maxHeroLevel`](../lib/core/game_logic.dart) (**100**) via `endgameUnlocked` — not AL20 alone. AL20 remains the Ascend cap. KEY, Infinity Gauntlet, Rifts, Greater Rifts, and Ashen Crown share the hub once unlocked. At party max level the World Path grows an **ENDGAME act** past Mothveil (same four hunts — not dungeon #16). At AL20 + party max, TODAY prefers the endgame ladder before Daily, then one actionable fallback (not a multi-line stats dump).

**AL20 vs party Lv100:** Ascend / Blessing / Star Nodes / REBORN are AL gates. KEY, Gauntlet, Ranked GR, Farm Rift, and Ashen Crown are party-Lv100 gates. At AL20 with heroes below 100, `_partyLevelChase` owns TODAY until every active hero hits 100.

**Daily ordlista (three systems):** Daily Vault (UTC claim) · Daily Run (+25e floor) · Quests Daily (MORE board). Never collapse them into one “daily” button.

**Rift consolidation:** TODAY chases **Ranked GR** before **Farm Rift** (`_farmRiftChaseReady` — GR1 clear or GR milestones done). Both stay on KEY; Farm Rift is not deleted.

**Season clocks:** UTC day (vault/run) · ISO week (KEY affix + week goal) · calendar month (vault bonus) · Play month (boards). Hub meta pulse crumbs: `KEY +N`, `Vault n/target · not Daily Run`, `Week · …` / `Week goal READY` — one hunt still wins on TODAY.

**Power shelves:** GOLD tracks (run, wipe on Ascend) · Ascend Blessing (forever) · ESSENCE tracks/relics/pets (forever). Guide: MORE → INFO → POWER SHELVES.

**Naming (player-facing):**
- Bar / sheet / dial: **KEY** (not KEYSTONE)
- Endgame: **Gauntlet** · **Ranked GR** · **Farm Rift** · **Ashen Crown**
- Run power: **GOLD tracks** (not forge / POWER)
- Pets tab: **PETS** (not Beast Pen)
- Merge: **MERGE** (Combinator Charm can stay as item name)
- Essence buys: **Permanent buys** under KEEP (not Prestige Shop / bottom SHOP)

**Wipe advice:** proven deficits say `Upgrade ATK/DEF/STA in GOLD` or `GOLD: listing` — CTA `OPEN GOLD`, not legacy POWER naming.

**Zones:** unlock by party mean level (even steps Lv1…Lv100) or by clearing the previous zone.

## Urgency chrome

| Urgency | Player-facing | Surfaces |
|---------|---------------|----------|
| `ready` | READY / claim CTA | TODAY card; Up next uses title only |
| `almost` | ALMOST | TODAY card; Up next uses title only |
| `normal` | (none) | TODAY title only |

## Ascend teasers

Kit unlock lines come from [`AscendRoadmap`](../lib/core/ascend_roadmap.dart) and are folded into chase **detail** (already) and into `ChaseContract.ascendTeaser` for confirm/toast consistency.

## Rules

- Hub TODAY is the primary chase chrome; other hub buttons are shortcuts to the same goals.
  When TODAY suggests Ascend / Meet kit / BAG equip / a claim, **ENTER DUNGEON** (or farm ENTER) stays available as a secondary choice — never trap the player on one button.  
- Offline “Up next” **must** use `ChaseContract.fromState(summary.state)` — same title/urgency as hub.  
- No new meta loops in this contract — only packaging.
