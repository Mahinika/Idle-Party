# Character paper-doll — reference (read on demand)

Read when baking layers, a facit gate fails, or tuning authored overrides.

## Must

- Base = family undertunic (cloth + hair + face, never naked). Mage base has **no** wizard hat
- Equipped cape / legs / chest / gloves / helm / off-hand / main-hand all paint, **including common**
- Mage/healer helm = **extracted** hat/hood from `_src`
- Warrior/rogue: `_src` has **no helm** → use `gear/_authored/helm_t0_*.png`
  when present (already shipped). Do **not** invent a metal stamp/ellipse
- Cape = extracted pixels only (rogue/mage cape from `_src` / authored). Empty
  extract → transparent or authored — not a drawn trapezoid. Live thicken for
  readability must **not** overwrite `_authored` masters
- Owned cape paints **behind** the body (gold-master order). The sides show.
  Do not move it in front of the chest — that covers the armor and fails the
  idle diff
- 2H hides off-hand. Legs win over boots (BAG boots icon = foot-band crop).
  Shoulders/waist fold into chest+legs (`pathFor` null)
- Own **body** PNG per idle/walk/attack. **Armor/weapon overlays** ship
  **idle-only** live PNGs (`OwnedGearAssets.pathFor` → `*_idle.png`). Do not
  regenerate live `*_walk` / `*_attack` overlays. Missing body clip → idle
  fallback, never Kenney on owned
- `hit` uses the **idle** body + painter recoil — not the walk stride
- Motion for the single clips lives in `ownedStepOffset` /
  `mainHandExtraRotation`, not in new PNGs
- Draw the body PNG as authored. Spec color is a modulate of
  `body_tint_*.png` only (`pose.bodyTint` + `bodyTintAsset`). Never wash the
  whole sprite — that crushed skin and filled the transparent corners.
  Gear overlays keep their authored palette and only paint when that slot
  is filled.
- Armor t2 may thicken/clarify t0 alpha but must keep its palette. Never apply
  a global gold/orange transform; `_authored/*_t2` is archive, not a live win.
- Four cuts per slot: t0, t2 (grown t0), and the drawn styles short and broad.
  Short/broad are their own silhouettes, not another t2 and not a rescale.
  No hue-only copies per slot (the old 20 `vNN` cuts are gone; old saves map
  onto the four).
- Base body owns face, eyes, and haircut on every anim. Armor overlays never
  carry them; helm = face window. Rarity wash only on t0.
- Materials take the donor family's piece by landmarks (chin/feet, helm by
  face), never stretched to the body box.
- Grips must sit on **opaque** pixels (handle centroid; bows mid-shape).
  Never hand-edit `owned_gear_grips.dart` — regenerate it
- Dungeon precache uses `dollOverlayPaths`, not `allAssetPaths` (icons are
  GEAR/BAG only)
- Leftover walk/attack under `gear/_authored/` may exist as art archive — not
  shipped live overlays

## Authored overrides

Optional hand pixels (win over extract):

- `assets/custom/char/<family>/gear/_authored/<setId>_<anim>.png`
- `assets/custom/char/<family>/gear/_authored/<slot>_<material>_<tier>_<anim>.png`
  (cross-material masters — mail helm first)
- `assets/custom/char/<family>/gear/_authored/<slot>_<short|broad>_idle.png`
  (style masters, required for every family and slot)
- `assets/custom/char/<family>/gear/_authored/<helm|chest>_<mark>_mark_idle.png`
  (class emblem on the family canvas: paladin, deathknight, warlock)
- `assets/custom/char/gear/_authored/<setId>_<anim>.png` (shared weapons)

**Material matrix** (native → no suffix): warrior plate · rogue leather · mage/healer
cloth. Non-native needs PNG + `OwnedGearAssets.materialSuffix` in the same
commit. Silent native fallback for an allowed cross-material type is a bug.

## A56 (both surfaces) — only after preview + facit OK

- Unequipped chest = undertunic. Equip common chest → silhouette changes
- Helm covers hair; mage hat only when a helm is equipped
- Dungeon walk/attack heroes match GEAR gear (idle overlays on poser body)
