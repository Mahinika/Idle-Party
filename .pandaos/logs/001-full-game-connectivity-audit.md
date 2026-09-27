# Log — F-001 Full game connectivity audit

**Started:** 2026-09-27  
**Status:** batch C done — next is batch D (step 37)  
**Steps:** 119 (19 screens folded in 2026-09-27)

## Progress

| Batch | Steps | Done |
|-------|-------|------|
| A Boot & first hour | 1–11 | 11/11 |
| B First boss & chrome | 12–23 | 12/12 |
| C GEAR | 24–36 | 13/13 |
| D Combat | 37–47 | 1/11 |
| E Zones | 48–57 | 0/10 |
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

### Batch D (started)

39: Farm clear pays no repeating floor essence. The one-time first-floor achievement still pays. Push pays the floor essence on top.
