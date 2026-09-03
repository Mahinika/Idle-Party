# Owned denser character bodies (Phase 3)

Path: `assets/custom/char/<family>/body_<anim>.png`

| Family | Role affinity | Frames today |
|--------|---------------|--------------|
| `warrior` | warrior | idle, walk, attack |
| `healer` | healer | idle, walk, attack |
| `mage` | mage | idle, walk, attack |
| `rogue` | rogue | idle, walk, attack |

- **128×128** RGBA, transparent bg, front-facing. Body is an **undertunic**
  (skin + hair + simple cloth). Equipped gear is overlays — including common.
- Overlays: `<family>/gear/<setId>_<anim>.png` and shared `char/gear/` weapons.
  Full 128 canvas, never bbox-cropped.
- Catalog: `lib/visual/body_family.dart` + `lib/visual/owned_gear_assets.dart`
- Enemies are **not** in this pass.

Rebuild from dressed `_src/` gold master (extract only — no invented helms).
Do not run `process_char_bodies` on gear — it crops:

```bash
py tool/build_owned_gear_layers.py
py tool/check_paper_doll_facit.py
```

Inspect `tool/preview_doll_*.png` before A56. Authored overrides:
`<family>/gear/_authored/` and `char/gear/_authored/`.
