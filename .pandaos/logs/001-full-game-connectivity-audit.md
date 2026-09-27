# Log — F-001 Full game connectivity audit

**Started:** 2026-09-27  
**Status:** batch E done — next is batch F (step 58)  
**Steps:** 119 (19 screens folded in 2026-09-27)

## Progress

| Batch | Steps | Done |
|-------|-------|------|
| A Boot & first hour | 1–11 | 11/11 |
| B First boss & chrome | 12–23 | 12/12 |
| C GEAR | 24–36 | 13/13 |
| D Combat | 37–47 | 11/11 |
| E Zones | 48–57 | 10/10 |
| F GOLD/SHOP/ESSENCE | 58–69 | 0/12 |
| G Ascend & meta | 70–82 | 0/13 |
| H Endgame | 83–96 | 0/14 |
| I Chase & return | 97–108 | 0/12 |
| J Ship bar | 109–119 | 0/11 |

## Step notes

### Batch A (2026-09-27)

1–2, 4–11: boot, new game, first hit, tips, floor 2, first-hour bar, What’s New — tests green.
3: Continue keeps the save (gold, name, Floor 2). Fixed: SETTINGS / PRIVACY / DISCORD overflowed on a 360-wide start menu.
4: First-cave button was a cut-off “Grow the party —”. It says ENTER DUNGEON again, matching the tip.
Note for batch C: starter doll logs missing gear overlays (cloak/helm/weapon). Not fixed here.

### Batch B (2026-09-27)

12–18, 21–22: boss clear returns to the hub, SHOP/KEY gates, GOLD after the first floor, hour packs stay off the shop list, guides, quests, and one redeem path — existing tests.
19–20: SOUND / DISPLAY / BAG / ACCOUNT open. Colorblind mode and text size survive a save reload.
23: CREDITS named a Kenney pack. It now says Cognifox Studio and Idle Party art.

### Batch C (2026-09-27)

24: Doll paints with crisp pixels. The “missing overlay” lines were the test not loading images; the starter files are in the game.
25–26, 28–29, 31–33, 35: bag upgrades follow the budget score, MERGE stays hidden in the first hour, locked specs say LOCKED, LOADOUTS stays hidden, auto-sell (gold) and auto-scrap (essence) are separate, wipe advice says GOLD, dungeon GEAR uses the same panels.
27: Taking a piece off into a full bag could hide it in the apex vault when the oldest bag item was an apex piece. The piece stays in the bag; the apex item goes to the vault.
30: After one Ascend, the first extra spec unlocks. A spec that needs a higher Ascend stays locked.
34: Soulbound and equipped apex survive Ascend.
36: Party name is checked at a new game. Pet rename blocks a bad name. Heroes are not renamed separately.

### Batch D (2026-09-27)

37–38: Later rooms wake after the first room dies, and the gate opens once. A boss clear counts and sends the party home.
39: Farm clear pays no repeating floor essence. The one-time first-floor achievement still pays. Push pays the floor essence on top. Switching mode mid-fight asks first.
40: Kit chips on the fight strip keep each job’s main spells.
41: God Hand smash, blast size, and cooldown match BAL / FOCUS / WIDE under ESSENCE → BLESSING. A tap steers the party.
42: Each cave’s boss has its own shout. None of them use the old generic pulse.
43: Time away inside a cave is the same fight as playing. Time away on the hub is not.
44: Hub time away pays gold (and slow essence). It does not clear floors or start a cave.
45: A wipe shows advice, then RETRY or HUB. The run is not stuck in the cave.
46: LEAVE mid-cave returns to the hub and clears the run.
47: Fast damage check: no job is too strong. Arms and Fury looked weak on a tiny sample; left alone.

### Batch E (2026-09-27)

48–50: PATH is a continent map, Sandy is open at level 1, and a pile of gold does not open the next cave. Level or a prior clear does.
51–53: Early, middle, and late caves have their own blurbs, packs, and boss shouts. Mothveil is last.
54: TODAY sends you into the open frontier cave, not a locked one.
55: Floors still follow the room plan (rooms, gates, boss shape).
56: You can jump back to a cleared floor, and one floor past the furthest clear. Not further.
57: A push boss clear names the next cave and opens it.
Copy: Crystal Spire no longer says the cave itself is endless. Hollow Grove no longer claims to sit between Tidehold and Ashen.
