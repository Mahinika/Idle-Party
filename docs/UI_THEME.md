# Idle Party UI theme (GEAR look)

**Device target:** **portrait phone only** (~360–430 CSS px). Shipping UI is
Android phone (owner reference: **Samsung Galaxy A56** → 360×780 CSS);
Flutter web is a playtest harness (always emulate that phone viewport).
Do not design for desktop/tablet as the product. Prefer tap / long-press over
hover-only interactions.

**Reference surface:** the GEAR inventory sheet. On phone width, GEAR is the
hero doll + actions (bag lives on the **BAG** tab). Wider playtest layouts may
still show doll + ITEMS BAG side-by-side. When adding or restyling menus, match
this chrome — don’t invent a new palette.

Code sources of truth:

| Piece | File |
|-------|------|
| Colors, radii, type | `lib/ui/game_theme.dart` |
| Panels, tabs, cards, sheets | `lib/ui/menu_chrome.dart` |
| Primary actions | `lib/ui/kenney_button.dart` |
| Reference layout | `lib/ui/character_equip_panel.dart`, inventory dock in `is2_shell.dart` |

---

## Surfaces

- **Sheet / overlay shell:** `MenuChrome.panel()` — charcoal gradient, warm gold `borderLit` edge, soft torch glow.
- **Scrim:** `MenuChrome.scrim`
- **Bottom sheets:** `MenuChrome.sheetRadius` + `sheetHandle()` + `menuTitle` + hairline gold rule.
- **Dialogs:** `MenuChrome.dialog(...)` + `KenneyButton` actions (not Material `TextButton`).

Avoid flat `GameTheme.menuCard` boxes with radius 4–6. Prefer:

```dart
decoration: MenuChrome.cardBox()           // raised card
decoration: MenuChrome.cardBox(inset: true)
decoration: MenuChrome.cardBox(selected: true)
decoration: MenuChrome.listCard(borderColor: ...)  // missions / shop rows
```

Radii: `GameTheme.radiusSm` (8) / `radiusMd` (12) / `radiusLg` (18).

---

## Typography

| Role | API | Font |
|------|-----|------|
| Sheet / overlay titles | `GameTheme.menuTitle(...)` | Cinzel |
| Body, tabs, readable copy | `GameTheme.body(...)` | VT323 |
| Section headers | `MenuChrome.sectionLabel('FOO')` | VT323 info tint |
| Buttons | `GameTheme.button` via KenneyButton | VT323 |
| Tiny tags only (iLvl chips, combat HUD) | `GameTheme.pixel(...)` | Press Start |

**Do not** use Press Start for menu titles or list row names.

---

## Tabs

Use the GEAR inset rail everywhere (Forge, inventory, …):

```dart
MenuChrome.tabRail(
  controller: _tabs,
  tabs: const [
    Tab(text: 'FORGE'),
    Tab(text: 'META'),
  ],
)
```

Selected tab = torch wash + `torchHot` label. No Material underline + pixel labels.

---

## Buttons

| Intent | Style |
|--------|--------|
| Primary / buy / equip | `KenneyButtonStyle.brown` (or default) |
| Secondary / cancel / clear | `KenneyButtonStyle.grey` |
| Destructive / merge commit | `KenneyButtonStyle.red` + `primary: true` when needed |

Always wire `Semantics` / `WebClickScope` (KenneyButton already does).

---

## Color tokens (quick)

- Ink / deep: `ink`, `stoneDeep`, `stone`, `panel`, `panelInset`
- Text: `parchment`, `parchmentDim`
- Accent: `torch`, `torchHot`, `borderLit`
- Good / bad: `clear` / `mossLit`, `bloodLit`
- Info / warn: `accentInfo`, `accentWarn`

Item rarity (tooltips only): `itemRarityColor` / `itemRarityBorder` in `item_tooltip.dart`.

---

## Checklist for a new menu

1. Shell = `MenuChrome.panel` / `showMenuSheet` / `_OverlayPanel` pattern.
2. Title = `menuTitle`; sections = `sectionLabel`.
3. Lists = `listCard` / `cardBox`, not raw `menuCard`.
4. Tabs = `tabRail` if multi-page.
5. Actions = `KenneyButton` only.
6. English copy; combat HUD stays pixel on purpose.

---

## Intentionally different (skip)

- Combat / dungeon HUD (FARM/PUSH, God Hand, party bars) — pixel HUD chrome.
- Bottom nav bar.
- Start menu / intro / new-game picker — brand surfaces.
- Item tooltips — warm rarity panels (`item_tooltip.dart`): **long-press** on
  phone (centered card + scrim); hover OK for web playtest only. Bag selection
  compare stays **compact** so the grid remains usable.
- Hub world-path scene cards — adjacent forge palette, not the inventory sheet.

---

## Anti-patterns

- Pixel titles on MORE overlays (“WHAT’S NEW”, “ACTIVE”, shop names).
- Hard-coded brown borders (`0xFF5A5040`) — use `GameTheme.border` / `panelInset`.
- Mixing `TextButton` into forge dialogs.
- Full-width overlay tooltips without `UnconstrainedBox` / measured layout.
