---
name: gear-lookbook
description: >-
  Renders the Idle Party gear lookbook to PNGs and reads them to see if
  gear sits on each body. Use when gear looks loose, a weapon misses the
  hand, or the owner says "hur sitter gear", "sitter fel på kroppen",
  "kolla dockan", or "lookbook". Do not use for drawing pixels (gear-art),
  the owner's phone look (a56-playtest), or enemy sprites (enemy-art).
---

# Gear lookbook (Idle Party)

Same dolls as MORE → SETTINGS → DEV: GEAR LOOKBOOK. Pictures plus one
count file. No emulator and no browser.

## Workflow

1. `py -3 tool/gear_lookbook.py` for the summary. Add `--all` only for a
   full pass. `--weapons`, `--armor`, or `--body warrior` (healer, mage,
   rogue) render just that slice. Outfits live in `tool/lookbook_outfits.json`.
2. Read the first line of `tool/out/lookbook/measure.txt`. It says
   `bättre`, `sämre`, `oförändrat`, or that there was no previous run.
   Each doll is scored on face, hand, off, hair, and open. A mark means
   that count is off: FACE (blade on the face), HAND or OFF (nothing in
   that hand), HAIR (helm misses the hair), COVERED (helm hides the face).
   A dash means that piece is not worn.
3. If any doll is flagged, read only `tool/out/lookbook/flags/*.png`.
   Those are the small pictures. Do not open a wide sheet to find them.
4. Read `fit_summary.png` for the worn sets. Rows are warrior, healer,
   mage, rogue. Columns are bare, armor (helm chest legs), layers
   (armor plus shoulder cloak hands), armed (layers plus that body's
   weapon), pair (layers plus sword and shield, wand and book, or two
   daggers).
5. Open a detail sheet only when the change needs it (`--weapons`,
   `--armor`, `--body`, or `--all`):
   - `{family}_armor.png` — helm, chest, legs, cloak
   - `{family}_snap.png` — hands, then shoulder
   - `{family}_weapons_a.png` — sword, staff, dagger, mace, axe
   - `{family}_weapons_b.png` — bow, shield, frill, wand, gun, crossbow, polearm, fist, thrown
   - `fit_weapons.png` — helm, chest, and hands, then sword, dagger,
     staff, bow, wand, gun, polearm, shield, frill
   - `fit_kit.png` — one full kit per body
   - `fit_materials.png` — top row warrior native, warrior leather, rogue
     native, rogue mail, mage native, mage leather. Bottom row healer
     cloth, leather, mail, plate
   Cells run left to right in `EquipmentModelCatalog.variants` order.
   Staff, polearm, bow, gun, and crossbow are two-hand, so an off-hand
   worn with them is hidden.
6. If a detail sheet is too wide to judge one piece, crop that cell and
   read the crop. Do not guess from a thumbnail of the whole sheet.

## What "sits" means

- Helm covers the hair and leaves the face visible.
- Chest, legs, and cloak stay on the torso and the legs.
- Shoulders rest on the shoulder, not beside the head.
- A weapon's grip is in the hand. An off-hand item is in the off hand.
- One piece at a time can look looser than the same piece in `fit_kit.png`
  or `fit_compare.png`. Judge the single piece and the worn set.

The gold marks above each doll are labels. In a test run they can draw as
blocks. Trust the file name and the row order above.

## Do not

- Start the emulator or a web server for this check.
- Treat `tool/out/lookbook/` as source. It is rewritten every run and is
  not committed.
- Publish art, or lower a threshold in `tool/gear_style.py`, from this look.
  Drawing and the facit stay in skill `gear-art`.
