# Log — F-001 Full game connectivity audit

**Started:** 2026-09-27  
**Status:** batch J done — phone smoke left the save alone  
**Steps:** 119 (19 screens folded in 2026-09-27)

## Progress

| Batch | Steps | Done |
|-------|-------|------|
| A Boot & first hour | 1–11 | 11/11 |
| B First boss & chrome | 12–23 | 12/12 |
| C GEAR | 24–36 | 13/13 |
| D Combat | 37–47 | 11/11 |
| E Zones | 48–57 | 10/10 |
| F GOLD/SHOP/ESSENCE | 58–69 | 12/12 |
| G Ascend & meta | 70–82 | 13/13 |
| H Endgame | 83–96 | 14/14 |
| I Chase & return | 97–108 | 12/12 |
| J Ship bar | 109–119 | 11/11 |

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

### Batch F (2026-09-27)

58–60: GOLD forge spends gold on ATK, DEF, and STA. MARKET buy follows what you can afford. Ascend clears gold and forge tracks and keeps essence and relics.
61–62: Ad-free and supporter stay owned after a reload. Forever scrolls in SHOP match the bonus they describe. Hour packs stay off the buy list.
63: Hub SCROLLS is the timed ticket list. It no longer says those are the same scrolls as SHOP.
64: The income sheet names relic gold and star gold that the hub rate uses. When gold-find is softened, the line says the percent that is actually used.
65–67: CAMP prices match the buy. God Hand modes are BAL, FOCUS, and WIDE. Relics level with Embers and survive Ascend.
68: Cinders match What’s New: one from the daily vault, one per two Ad Tickets, or the pouch. They salvage or trade a few Embers a week.
69: Pets live under ESSENCE → PETS. No Beast Pen label.

### Batch G (2026-09-27)

70–72: Ascend and REBORN now name the same wipe: gold, bag, GOLD tracks, and floor progress. Party levels, open caves, essence, relics, and lit star nodes stay. Forge tracks and the wallet clear. A fresh climb starts after.
73–75: Blessing stacks on each Ascend. Star nodes are a separate spend and stay lit. The lasting-buy list says it is not the bottom-tab SHOP.
76: REBORN is an optional button at AL20. It is never the night's job on the hub.
77–80: Daily Vault, Quests, and Daily Run stay three different things. The vault names the month bonus when it is included. Daily Run waits until the first Ascend. Week goals that need endgame stay quiet until then.
81–82: Welcome Back uses the same next step as the hub. The small gold line on the hub is not that screen.

### Batch H (2026-09-27)

83–84: The five hunts open when every active hero is level 100. Ascend 20 alone does not open them. ENDGAME is four pins on its own map. KEY stays on the KEY tab.
85: Tonight's KEY line names the week's twist and the clock. KEY +21 stays on the dial, not as the hub's night job.
86: Boss Rush was labeled "bosses only". Trash packs still spawn; they fight as elites. The label now says elite-heavy pulls. No Flask still blocks a healing flask.
87–88: Gauntlet is the endless Spire, boss every 5 floors. After floor 100 the hub can push the personal best. The extra Spire rule shows on those floors and changes the fight.
89–91: Ranked GR is timed on Mothveil and records a local season best. Running out of time fails the rift and does not count as a clear. A last hit after the clock still counts. Farm Rift on Stormwake has a clock and does not fail when it runs long. The hub asks for Ranked GR before Farm Rift.
92: Ashen Crown is a weekly ticket. Each week it visits a cave that already exists.
93–94: Craft Trial lives under MORE → CRAFT. It is not a fifth pin. Finishing the named craft goal makes that piece.
95–96: After KEY +20 the night order is Gauntlet, Ranked GR, Farm Rift, then Ashen. When the vault, the daily, and the KEY dial are settled, the hub says done for today.

### Batch I (2026-09-27)

97–98: When the night's job is a hunt, that hunt owns the brown button. A ready claim stays on top, and ENTER stays underneath so you are not stuck on one button.
99: The first hour stays on the cave. Meet a hero and equip-from-bag wait until after the first boss.
100–101: Right after Ascend, the hub says rebuild the bag and skips KEY and Gauntlet until gear lands. Leveling the party to 100 is the job before the hunts open, and it waits under the daily unless you are almost there.
102: The hub button labeled CODEX opened the guide. It now opens the discovered list. A monster you have met shows up there.
103: Trophies list the real feats. A feat you have met says AWARDED.
104: Away reminders stay off until the first loot. The line says quiet pings, a couple a day, never during a fight.
105: A brand-new save never asks for a Play rating. The card says there is no reward.
106: A new install stamps first open, then the app is ready, then the first cave, then how long until the first hit.
107: GET UPDATE and the update wall point at Google Play. They do not send anyone to a download page.
108: The screens in this pass stay in English.

### Batch J (2026-09-27)

109: Analyzer is clean aside from the four notes it already reports.
110–112: The game tests, the hub smoke, and the version line match. The doll picture lock was refreshed after the looks check passed. Arcane's bolts were trimmed so the short damage check is under the line again.
113–115: Goblin slingers use the goblin picture from the fight, not a bat. No iPhone project. The Play package is still com.idleparty.app. Version 1.12.187 matches.
116–118: A save export loads back. A failed Play Games sign-in keeps the gold on the device. Ascend still wipes gold and floors and keeps the party.
119: The phone save was not wiped. First hit, a mid-game claim, and KEY are already covered by tests. No new look on the phone.
