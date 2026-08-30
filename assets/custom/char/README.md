# Owned denser character bodies (Phase 3)

Path: `assets/custom/char/<family>/body_<anim>.png`

| Family | Role affinity | Frames today |
|--------|---------------|--------------|
| `warrior` | warrior | idle, walk, attack |
| `healer` | healer | idle |
| `mage` | mage | idle |
| `rogue` | rogue | idle |

- **128×128** RGBA, transparent bg, front-facing, empty hands (gear overlays add weapons).
- Catalog: `lib/visual/body_family.dart`
- Enemies are **not** in this pass.

Reprocess after replacing source art:

```bash
py tool/process_char_bodies.py
```
