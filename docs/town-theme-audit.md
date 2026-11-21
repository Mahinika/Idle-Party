# Town theme audit

**Date:** 2026-11-21  
**Harness:** golden widget harness (`test/shell_golden_harness.dart`). Samsung A56, physical 1080×2340, device pixel ratio 3, logical 360×780. Town is HomeShell out of the cave (AL1, Minimal VFX, Sandy Caverns). The fight is the same HomeShell in Sandy Caverns (`fightHitGoldenDirector`, Minimal VFX).

Shots: `docs/town-theme/before.png` (town, text scale 1, before), `docs/town-theme/after.png` (same, after), `docs/town-theme/after_145.png` (after, text scale 1.45).

## Before

Measured on `test/goldens/town/home_shell_town_a56.png` and `test/goldens/after/fight_hit_a56.png` (the harness writes those at 360×780; the phone shots are the same widgets at pixel ratio 3).

| Sample | Mean RGB | Notes |
|---|---|---|
| Town chrome | 31, 23, 25 | Mode `(20, 13, 17)` is `GameTheme.stoneDeep` |
| Town sky | 125, 174, 193 | Mode `(118, 168, 196)`, daylight cyan |
| Town grass | 89, 163, 68 | Mode `(86, 186, 64)`. Relative luminance about 0.38 |
| Fight chrome | 23, 15, 18 | Same plum-black family |
| Fight floor, lit | 180, 154, 90 | Sandy sand, luminance about 0.36 |
| Fight surround | 78, 56, 33 | Dark warm brown, luminance about 0.03 |

The chrome already matched the dusk UI. The town picture did not. The sky was a noon cyan, the lawn a high-key spring green, the clouds near white, and a sun sat in the upper left. Windows were amber but dimmer than the wall, so they did not read as lamps. Outlines were already the hero ink `(32, 22, 18)`, one pixel, and both scenes are nearest-neighbor (`FilterQuality.none`). The mismatch was value and hue, not pixel density: the cave keeps color in the torchlit floor and lets the surround fall to brown and plum. The town lit the whole world.

Building names are `GameTheme.hint` at 12 px in parchment `(236, 232, 223)`. On the old plaque fill `(148, 102, 62)` that pair is about **4.1:1**, short of 4.5:1 for text this size. Header and button text on the plum chrome is well above 4.5. Hit targets stay on the building boxes (44 dp) and the buttons (48 dp).

## After

The lawn, sky, stone, plaster, and windows are regenerated from `tool/generate_town_art.py`. A static radial vignette and a sky mist sit on the square (`GameTheme.townVignette`, `GameTheme.townFog`). No blur, no ticker, no per-frame shader. Name chips paint above that wash. When `dungeonId` is `hell`, a 14% blood wash (`GameTheme.townHellWash`) tints the square under the chips. Sandy does not.

Measured on the 1080×2340 after frame:

| Sample | Mean RGB | Notes |
|---|---|---|
| Sky | 33, 24, 48 | Plum. Was cyan `(118, 168, 196)` |
| Grass | 41, 94, 29 | Luminance about 0.10, was 0.38. Saturation `(G-min)/G` about 0.69, was 0.66 on `(86, 186, 64)` |
| Window glass | 220, 108, 32 | `EMBER` lamp, inside the timber frame so the ink outline stays the building edge |

The plaque fill is now `(132, 88, 52)`, about **5.0:1** with the same parchment, so the 12 px names clear AA. Label style, button faces, and hit boxes are unchanged. `typeScaleMax` stays 1.45. Text is not shrunk with `FittedBox`.

The fight frame from the same pass is still the dark cave: plum chrome, brown surround, sand floor lit in the middle, heroes with the same ink outline. The town now uses that lighting idea outdoors: dark saturated ground, plum sky, warm light only in the windows and on the horizon.
