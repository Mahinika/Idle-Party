# Playtest memory

Read this before every `/playtest`. Update it only through
`py -3 tool/playtest_run.py` (`ok`, `good`, `learn`), so the next
round looks for what this round learned.

An OK is not a skip. Every round still opens that screen.
Baselines live in `tool/playtest_baseline/`.

## Bra

- 2026-10-04 · gear · mid · EQUIP is the one filled button and the doll sits in the card · `tool/playtest_baseline/gear__mid.png`
- 2026-10-04 · bag · mid · BAG FULL, EQUIP, and CLEAN say what to do · `tool/playtest_baseline/bag__mid.png`
- 2026-10-04 · more · mid · One quest claim on the hub matches one CLAIM on the list · `tool/playtest_baseline/more__mid.png`

## Lärt

- 2026-10-04 · A QUESTS count that includes the daily vault disagrees with CLAIM QUESTS · rule: none
- 2026-10-04 · Wipe advice that only uses the hero name disagrees with the PROT or COM row · rule: none
- 2026-10-04 · The hub shows the chase, ENTER DUNGEON, and ASCEND as three big buttons · rule: none

## OK

| Screen | Stage | Date | Commit | Streak |
| --- | --- | --- | --- | --- |
| gold | mid | 2026-10-04 | 2890e01a | 2 |
| essence | mid | 2026-10-04 | 2890e01a | 2 |
| shop | mid | 2026-10-04 | 2890e01a | 2 |
