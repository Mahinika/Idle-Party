# Playtest memory

Read this before every `/playtest`. Update it only through
`py -3 tool/playtest_run.py` (`ok`, `good`, `learn`), so the next
round looks for what this round learned.

An OK is not a skip. Every round still opens that screen.
Baselines live in `tool/playtest_baseline/`.

## Bra

- 2026-10-04 · gear · mid · EQUIP is the one filled button and the doll sits in the card · `tool/playtest_baseline/gear__mid.png`
- 2026-10-04 · bag · mid · BAG FULL, EQUIP, and CLEAN say what to do · `tool/playtest_baseline/bag__mid.png`
- 2026-10-04 · more · mid · Contract CLAIM sits whole above the bar · `tool/playtest_baseline/more__mid.png`

## Lärt

- 2026-10-04 · A QUESTS count that includes the daily vault disagrees with CLAIM QUESTS · rule: none
- 2026-10-04 · Wipe advice that only uses the hero name disagrees with the PROT or COM row · rule: none
- 2026-10-04 · The hub shows the chase, ENTER DUNGEON, and ASCEND as three big buttons · rule: none
- 2026-10-04 · A k gold suffix glued to g reads as kilograms · rule: none
- 2026-10-04 · A full-bag toast that does not name EQUIP leaves the upgrades sitting there · rule: none
- 2026-10-04 · a claim button sliced by the bottom bar · rule: clipped_by_nav
- 2026-10-04 · the first dungeon paint waited on hero portraits · rule: none

## OK

| Screen | Stage | Date | Commit | Streak |
| --- | --- | --- | --- | --- |
| gold | mid | 2026-10-04 | 2b337844 | 3 |
| essence | mid | 2026-10-04 | 2890e01a | 2 |
| shop | mid | 2026-10-04 | 2890e01a | 2 |
| market | mid | 2026-10-04 | 35f3139a | 1 |
| hub | mid | 2026-10-04 | 2b337844 | 1 |
| gear | mid | 2026-10-04 | 2b337844 | 1 |
| bag | mid | 2026-10-04 | 2b337844 | 1 |
