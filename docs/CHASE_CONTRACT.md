# Chase contract

One shared answer to **“what should I chase now?”** for hub TODAY, offline welcome (“Up next”), and Ascend teasers.

Source of truth for *which* chase: [`HubChase.forState`](../lib/core/hub_chase.dart).  
Facade for *all surfaces*: [`ChaseContract.fromState`](../lib/core/chase_contract.dart).

## Priority (high → low)

1. **Claimables (READY)** — daily vault (payday copy only; season bonus still pays on claim), finished **QUESTS**. Meet new kit and **equip BAG** wait until after the first boss (first hour keeps the cave).
2. **First hour** — no boss and no Ascend yet: **grow the party** in the recommended zone. Beats Meet kit / EQUIP / MARKET. Skip Daily / KEY / vault-start / Will grind so TODAY is not a meta list. Skip kit teasers until after the first boss.
3. **Market ALMOST** — affordable UPGRADE on GOLD → MARKET (after bag equip, after first boss). **Pre-endgame only** before KEY nights; at party Lv100 market waits until after KEY habit / endgame ladder / zone.
4. **Ascend READY** — can Ascend now (blocked at AL20 cap). **Exceptions:** on **AL0** after the first boss, TODAY stays Daily / farming; **at party Lv100**, KEY habit and the endgame ladder beat Ascend (Ascend stays on the urgent row / ESSENCE → BLESSING as optional lasting power). Confirm copy: party stays; bag, gold, forge, and floors reset.
5. **ALMOST** — one boss from Ascend (pre-endgame, not AL20 cap), then KEY+1 vault cliff (endgame only), then zone. **Month ALMOST** and Will / early week ALMOST: pre–Lv100 only before KEY. **At party Lv100:** Month ALMOST sits **after** the endgame ladder so Spire/KEY nights stay clear; Gauntlet/Rift/GR ALMOST still apply. **Party-level ALMOST** (within 5 of Lv100) beats Daily vault start.
6. **Fresh prestige re-kit** — after Ascend or optional AL20 Reborn (`metaDepth.freshPrestige` and low gear pressure): TODAY says **Rebuild your bag** with plain farm/re-equip copy + geared % progress. Skip KEY / Gauntlet / Rift until real drops land. **Reborn is never a TODAY chase.**
7. **Level the party** — after the first boss and before endgame unlock, TODAY can say **Level the party to 100** (combat XP unlocks KEY / Gauntlet / Ranked GR — not AL20). Normal urgency sits **under** Daily vault start; ALMOST (near 100) sits above it.
8. **KEY habit (endgame only)** — chase the next KEY until preferred key is at +20 (TODAY detail includes affixes + par). Higher keys stay on the KEY tab. Does **not** wait on unpaid Daily. Beats Ascend READY.
9. **Endgame ladder (party Lv100)** — after KEY +20: week ALMOST (if any) → Gauntlet (PB after F100) → Greater Rift through GR20 → Farm Rift through R20 → Ashen Crown. KEY +21 stays on the KEY tab. Ranked GR past 20 shows the **next rank on hub ENDGAME** (GR34 → GR35, no KEY dial) so weekly Ashen is not buried on TODAY. Farm Rift past 20 stays on KEY. Month ALMOST after ladder. One hunt — not Daily/Will shuffle. Gauntlet is **not** a 16th PATH cave.
10. **Done for today** — when Vault + Daily + KEY dial are settled and the ladder is quiet (PB only): soft rest with KEY · BOARDS CTA; Spire PB stays optional in the detail. **Week ALMOST / READY** still beat this soft rest (normal week progress does not).
11. **Progress grind** — **Daily Vault (one cave today)** is the day-2–7 job after the first boss (beats normal party-level). **Daily Run** waits until first Ascend, then follows a claimed vault. Then Will (CODEX CTA), leftover endgame (pre–Lv100), Shop (endgame), week goal, then **one** endgame fallback (time KEY at dial / push GR — never a stats dump)

ALMOST always beats Daily / KEY habit / vault-start grind. First hour push beats Daily and KEY. Zone unlock is TODAY only when party level is **ALMOST** (or prior clear opens the path). Never invent a second priority list in UI.

**Endgame unlock:** active party all at [`GameLogic.maxHeroLevel`](../lib/core/game_logic.dart) (**100**) via `endgameUnlocked` — not AL20 alone. AL20 remains the Ascend cap. KEY, Infinity Gauntlet, Rifts, Greater Rifts, and Ashen Crown share the hub once unlocked. At party max level the hub shows **PATH | ENDGAME**: PATH is the 15-zone World Path; **ENDGAME** is a separate map of the four hunts (not dungeon #16, not under Mothveil). At party max, TODAY prefers KEY then the ladder before Daily and before Ascend READY, then one actionable fallback (not a multi-line stats dump).

**AL20 vs party Lv100:** Ascend / Blessing / Star Nodes / REBORN are AL gates. KEY, Gauntlet, Ranked GR, Farm Rift, and Ashen Crown are party-Lv100 gates. Before party max, Daily vault start (one cave today) is the day-2–7 job; `_partyLevelChase` sits under it unless ALMOST (within 5 of Lv100).

**Daily ordlista (three systems):** Daily Vault (UTC claim) · Daily Run (+25e floor) · Quests Daily (MORE board). Never collapse them into one “daily” button.

**Rift consolidation:** TODAY chases **Ranked GR** before **Farm Rift** (`_farmRiftChaseReady` — GR1 clear or GR milestones done). Ranked GR next rank lives on hub ENDGAME; Farm Rift dial stays on KEY. Farm Rift is not deleted.

**Season clocks:** UTC day (vault/run) · ISO week (KEY affix + week goal) · calendar month (vault bonus) · Play month (boards). Hub meta pulse crumbs (`KEY +N`, `Vault n/target · not Daily Run`, `Week · …`) stay off when the hunt is already KEY / Gauntlet / Ranked GR / Farm Rift / Ashen. One hunt still wins.

**Power shelves:** GOLD tracks (run, wipe on Ascend) · Ascend Blessing (forever) · ESSENCE tracks/relics/pets (forever). Guide: MORE → INFO → POWER SHELVES.

**Naming (player-facing):**
- Hub hunt line: **READY / ALMOST** + the job (not a TODAY stamp)
- Bar / sheet / dial: **KEY** (not KEYSTONE)
- Endgame: **Gauntlet** · **Ranked GR** · **Farm Rift** · **Ashen Crown**
- Run power: **GOLD tracks** (not forge / POWER)
- Pets tab: **PETS** (not Beast Pen)
- Merge: **MERGE** (Combinator Charm can stay as item name)
- Essence buys: **lasting buys** under ESSENCE → BLESSING (not bottom-tab SHOP)

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
