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
- **Body** clips: `body_idle` / `body_walk` / `body_attack`.
- **Spec tint** clips: generated `body_tint_idle` / `walk` / `attack`
  grayscale masks. Only undertunic cloth has alpha; face/hair stay unchanged.
- **Overlays** (armor + weapons): idle only (`<setId>_idle.png`). Walk/attack
  in dungeon reuse those idle layers on the poser body.
- Catalog: `lib/visual/body_family.dart` + `lib/visual/owned_gear_assets.dart`
- Enemies are **not** in this pass.

Rebuild from dressed `_src/` gold master (armor extract from **idle** only).
`process_char_bodies.py` refuses to run. It used to crop body PNGs:

```bash
py tool/build_owned_gear_layers.py
py tool/check_paper_doll_facit.py
```

Inspect `tool/preview_doll_*.png` before A56. Authored overrides:
`<family>/gear/_authored/` and `char/gear/_authored/`.
