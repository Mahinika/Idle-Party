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

1. `py -3 tool/gear_lookbook.py`
2. Read `tool/out/lookbook/measure.txt` first. Each doll is scored on
   face, hand, off, hair, and open in that one pass. A mark means that
   count is off: FACE (blade on the face), HAND or OFF (nothing in that
   hand), HAIR (helm misses the hair), COVERED (helm hides the face).
   A dash means that piece is not worn. Then read the PNGs. Start with
   `fit_compare.png` and `fit_weapons.png` when several pieces are worn
   together. Then `fit_kit.png` and `fit_materials.png`.
3. Open the family sheet that matches the change:
   - `{family}_armor.png` — helm, chest, legs, cloak
   - `{family}_snap.png` — hands, then shoulder
   - `{family}_weapons_a.png` — sword, staff, dagger, mace, axe
   - `{family}_weapons_b.png` — bow, shield, frill, wand, gun, crossbow, polearm, fist, thrown
4. Cells run left to right in `EquipmentModelCatalog.variants` order.
   Bodies in `fit_kit.png` are warrior, healer, mage, rogue.
   `fit_compare.png` rows are the same four bodies. Columns are bare,
   armor (helm chest legs), layers (armor plus shoulder cloak hands),
   armed (layers plus that body's weapon), pair (layers plus sword and
   shield, wand and book, or two daggers).
   `fit_weapons.png` is the same four bodies in helm, chest, and hands,
   then one weapon per column: sword, dagger, staff, bow, wand, gun,
   polearm, shield, frill. Staff, polearm, bow, gun, and crossbow are
   two-hand, so an off-hand worn with them is hidden.
   `fit_materials.png` top row is warrior native, warrior leather, rogue
   native, rogue mail, mage native, mage leather. Bottom row is healer
   cloth, leather, mail, plate.
5. If a sheet is too wide to judge one piece, crop that cell and read the
   crop. Do not guess from a thumbnail of the whole sheet.

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
