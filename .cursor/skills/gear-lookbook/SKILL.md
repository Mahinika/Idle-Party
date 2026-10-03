---
name: gear-lookbook
description: >-
  Renders the Idle Party gear lookbook to PNGs and reads them to see if
  gear sits on each body. Use for a broad doll audit or when the owner says
  "hur sitter gear", "sitter fel på kroppen", "kolla dockan", or "lookbook".
  Do not use to correct weapon grips (weapon-grip-placement), draw pixels
  (gear-art), judge the owner's phone look (a56-playtest), or edit enemies
  (enemy-art).
---

# Gear lookbook (Idle Party)

Same dolls as MORE → SETTINGS → DEV: GEAR LOOKBOOK. Pictures plus one
count file. No emulator and no browser.

## Workflow

1. `py -3 tool/gear_lookbook.py` (about 25 s). Add `--all` only for a
   full pass of the detail sheets. `--weapons`, `--armor`, or
   `--body warrior` (healer, mage, rogue) render just that slice. The
   counts always cover every model. Outfits live in
   `tool/lookbook_outfits.json`.
2. Read `tool/out/lookbook/measure.txt` from the top:
   - Line 1 says `bättre`, `sämre`, `oförändrat`, or that there was no
     previous run, per piece and mark.
   - Line 2 counts the dolls measured and the pieces flagged.
   - Line 3 says how many doll pictures changed since the last run
     (`diff.png`).
   - Then one block per mark, listing the pieces and the poses where it
     fires. No pose in brackets means idle only.
3. If line 3 names changed pictures, read `diff.png` (before | after).
   If a piece is flagged, read only `flags/<family>_<piece>.png`: one cell
   per flagged pose, red dots on the fists. Do not open a wide sheet to
   find it.
4. Read `fit_summary.png` for worn sets (rows warrior, healer, mage,
   rogue; columns bare, armor, layers, armed, pair) and `fit_poses.png`
   for the same armed and pair outfits in idle, walk, windup, strike, and
   cast. Read `fit_classes.png` for all ten classes in their armor,
   holding the weapon that spec starts with. Specs that share a body,
   armor, and weapons are one doll. Druid and Shadow are drawn as the
   person with gear on, because their fight picture hides the clothes.
   Read `fit_races_<family>.png` (warrior, healer, mage, rogue) for all
   twelve races, male on the first row and female on the second, in that
   body's full kit.
5. Open a detail sheet only when the change needs it (`--weapons`,
   `--armor`, `--body`, or `--all`):
   - `{family}_armor.png`: helm, chest, legs, cloak
   - `{family}_snap.png`: hands, then shoulder
   - `{family}_weapons_a.png`: sword, staff, dagger, mace, axe
   - `{family}_weapons_b.png`: bow, shield, frill, wand, gun, crossbow,
     polearm, fist, thrown
   - `fit_weapons.png`: helm, chest, and hands, then one weapon each
   - `fit_kit.png`: one full kit per body
   - `fit_materials.png`: chest in each material a body may wear
   Staff, polearm, bow, gun, and crossbow are two-hand, so an off-hand
   worn with them is hidden.
6. Every doll is also a 128 px PNG in `dolls/`. Crop or open one of those
   instead of guessing from a whole sheet.

## How it measures

The Dart test paints each doll with `paintOwnedHero`, once whole and once
per layer, and counts pixels on those pictures. Nothing re-implements the
painter. `tool/measure_lookbook.py` only judges the numbers.

What is measured:

- **Outfits:** the rows of `fit_summary.png` and `fit_weapons.png`.
- **Weapons:** every weapon model on a dressed body.
- **Armor:** every armor model in every material that body may wear.
  Pauldrons are measured on top of `chest_t0`.
- **Poses:** outfits and weapons in all five poses. Armor in idle, walk,
  and strike.

The head is the biggest patch of skin and hair (body pixels outside the
cloth tint mask) near the top of each clip. Hair is its crown. The face is
the middle band.

| Mark | Meaning |
|---|---|
| FACE | weapon over the face while standing or walking (> 12 px) |
| SWING | weapon over the face in windup, strike, or cast (> 40 px) |
| SHIELD | shield or tome over the face (> 40 px) |
| HAND / OFF | grip misses the hand (< 6 px inside an 8 px disk). Bare skin uses the fist. Worn gloves use the painted palm |
| COVERED | helm leaves < 35% of the face showing |
| LIFT | helm touches the head with < 8 px |
| FLOAT | > 50% of the pauldron has nothing under it |
| SPILL | armor sits > 20% farther off the body than its t0 cut |

A hat may sit on the hair, and plate may be drawn bulkier than the
undertunic. Neither is a mark by itself.

## Do not

- Start the emulator or a web server for this check.
- Treat `tool/out/lookbook/` as source. It is rewritten every run and is
  not committed.
- Publish art, or lower a threshold in `tool/gear_style.py`, from this look.
  Drawing and the facit stay in skill `gear-art`.
- Raise a mark limit in `tool/measure_lookbook.py` to make a flag go away.
  Fix the art or the grip, or tell the owner what the flag shows.
