# Icon and symbol inventory (Brick Inc home shell)

Read-only audit **2026-11-05** on branch `cursor/ui-shell-polish-a824`.
Evidence: `lib/ui/game_icon.dart`, `lib/assets/custom_assets.dart`,
`lib/ui/shell/*`, `lib/ui/hub/*`, `docs/UI_THEME.md`.

## Implementation status (2026-11-05)

**Batch 1 wired (PR #50):**
- `icon_shop.png`, `icon_map.png`, `icon_menu.png`, `icon_close_tab.png`
- `icon_forge.png`, `icon_camp.png`, `icon_market.png`
- `icon_watch_ad.png`, `icon_scroll.png`, `icon_daily.png`, `icon_ticket.png`
- `icon_embers.png`, `icon_cinders.png`
- 48px hi-res masters in `assets/custom/icons/48/`
- `KenneySprite` picks 48px when `size >= 24 dp`

**Batch 2 stubs (code ready, awaiting PNG art):**
- `UiIcon.update` → `icon_update.png` (currently fallback to star)
- `UiIcon.redeem` → `icon_redeem.png` (currently fallback to star)
- `UiIcon.floors` → `icon_floors.png` (currently fallback to boots)
- `UiIcon.wispLantern` → `icon_wisp_lantern.png` (currently fallback to flask)

When Creative ships these icons, add them to `assets/custom/icons/` (and
`icons/48/` for hi-res), then update `CustomAssets` and point the `UiIcon`
constants at the new paths.

---

**Rule in code:** chrome uses `GameIcon` + `UiIcon` PNGs or `UiGlyph`
CustomPaint marks. **No Material `Icons.*`** in `lib/` (grep clean). Emoji is
also banned in chrome per `docs/UI_THEME.md`.

**Rendering:** PNGs load through `KenneySprite` (`FilterQuality.none`, optional
`tint`). Glyphs are 9×9 `#` bitmaps scaled to touch size.

**Brick Inc target (competitor note):** five bottom tabs with **distinct**
silhouettes, strong currency icons top-left, promo rails with unique marks,
center tab = fight. Idle Party’s home shell already matches **HEROES · ESSENCE ·
FIGHT · MAP · SHOP** + top **MENU**, but several tabs **reuse the same PNG**
and the **FORGE / CAMP / MARKET** dock is **text-only**.

---

## 1) Current sources and style mismatches

| Source | Path / API | Role | Coherence issues |
|--------|------------|------|------------------|
| **UiIcon PNGs** | `assets/custom/icons/*.png` (49 files) | Tabs, rails, wallets, scroll pips, chase, shop rows, gear slots | Mixed art passes; some soft edges; **star / book / boots / trophy** reused for unrelated jobs |
| **UiGlyph** | `GameIcon.glyph` in `game_icon.dart` | `add`, `close`, `prev`, `next`, `scroll`, `wisp` | Vector-pixel painted; **different weight** than PNG tabs; home **FIGHT** close tab uses red **X** glyph at 26px |
| **CustomPaint HUD** | `GodHandRing`, `RiftProgressBarPainter` | Cooldown ring, rift bar | Fist center uses **`iconFist` PNG**; ring is procedural — OK |
| **Zone marks** | `assets/custom/zones/<id>/hub_icon.png` | PATH map nodes (not `UiIcon`) | Per-zone art; separate from `icons/` set |
| **Gear / weapon icons** | `CustomAssets.iconHelm`, `iconSword`, … | Paper doll, bag slot filters, loot | Large library; **gameplay art**, not shell — only reskin if global pixel pass |
| **Relic portraits** | `iconRelicWarBanner`, etc. | ESSENCE relic list | Three bespoke relic PNGs |
| **Text-only segments** | `MenuChrome.segmented` | FORGE / CAMP / MARKET, Repeat/Next, farm 1×/2×/4× | **No icons** while tabs use icons — main Brick Inc gap |
| **Classic bar only** | `AppBottomBar` | Colored slot fills per tab | Home nav is **flat stone bar** — intentional split; icons shared with classic |

**Dead / unused chrome:** `UiIcon.power` → `iconAxe` is declared in
`game_icon.dart` but **not referenced** elsewhere in `lib/`.

**Semantic overload (same PNG, different meaning):**

| Asset | Reused for |
|-------|------------|
| `star.png` | SHOP tab, WATCH rail, UPDATE rail, REDEEM, shop packs, KEY affix chip |
| `book.png` | MORE tab, MENU top bar, INFO / PATCH NOTES menu rows |
| `boots.png` | MAP tab, DAILY rail, FLOORS menu, move-speed scroll |
| `trophy.png` | QUESTS, Ranked GR chase, supporter shop pack |
| `tome.png` | SCROLLS rail, XP scroll, GUIDES menu |
| `gold.png` | Gold currency, pouch rail, cinder shop row (wrong color read) |

---

## 2) UI surfaces that show icons

### Home shell (Robert layout)

| Surface | Widget | Icons? |
|---------|--------|--------|
| Top bar | `HomeTopBar` | `UiIcon.ascend`, `essence`, `gold`; optional `ring` (embers/cinders); `more` (MENU); KEY timer text |
| Bottom nav | `HomeNavBar` | HEROES `gear`, ESSENCE `essence`, FIGHT `sword` / close `UiGlyph.close`, MAP `boots`, SHOP `star`; MAP badge = ticket count text |
| Fight seam | `FightSeam` | `GodHandRing` → `iconFist`; party row `DungeonFlaskButton` → `flask`; rails `RailButton` → catalog icons |
| Gold dock | `HomeGoldDock` / `UpgradePanel` | **Text only:** FORGE, CAMP, MARKET |
| Sheets | `MenuSurface`, `EssenceTilesScreen`, `MapScreen` | Overlay titles text-first; content uses icons inside panels |
| MENU grid | `HomeMenuGrid` → `RailButton` | Full `HomeCatalog` icon set |
| Fight overlay | `HomeFightTools` | `ScrollBuffStack`, `BoostAdButton` (text), `WispGiftOverlay` (`UiGlyph.wisp` + lantern art) |
| Camp | `CampViewport` | Same rails as seam; ENTER is text button |

### Classic shell (still in tree)

| Surface | Widget | Icons |
|---------|--------|-------|
| Bottom bar | `AppBottomBar` | Same `UiIcon` mapping as `iconFor()` |
| Dungeon HUD | `DungeonTopHud` | Wallet `gold`/`essence`; chips; `GodHandRing`; floor menu text |
| Hub | `HubScreen`, `HubTodayCard`, `HubEndgameMap` | Chase + hunt icons per kind |

### Shared sheets / HUD

| Surface | Icons |
|---------|-------|
| `WalletStrip` / income sheet | `gold`, `essence` |
| `ScrollBuffStack` | sword, gold, tome, boots, chest, wand, campfire (by buff id) |
| `RiftProgressHud` | `skull` at bar end |
| `ShopDock` | Per-offer mapping in `_iconFor()` |
| `ChallengeToggles` / KEY | heart, skull, star on affix chips |
| `CharacterEquipPanel` | Per-slot `CustomAssets.icon*` (helm, chest, …) |
| Wipe / dialogs | Mostly text; `GameButton` only |

---

## 3) Per-icon register (shell-focused)

Status: **keep** (on-brand, keep path) · **replace** (works but wrong metaphor or overload) · **missing** (needs new art) · **generate new** (no asset today) · **glyph** (keep painted mark or optional PNG twin)

### Bottom navigation (must read at 20–26px)

| Id | Label | Where | Current asset | Status | Brick Inc notes |
|----|-------|-------|---------------|--------|-----------------|
| `nav_heroes` | HEROES | `HomeNavBar`, `AppBottomBar` gear | `helm.png` via `UiIcon.gear` | keep / **replace** | Helm reads “gear”; OK for RPG. Prefer **single-color silhouette**, 24px grid, warm gold highlight when selected |
| `nav_fight` | FIGHT | `HomeNavBar` | `sword.png` | keep / **replace** | Center-weight icon like Brick “bullet”; sword OK if bolder outline |
| `nav_close` | Close tab | `HomeNavBar` selected state | `UiGlyph.close` | **glyph** → **generate new** | Red X glyph clashes with PNG set; add **`icon_close.png`** matching tab stroke |
| `nav_essence` | ESSENCE | `HomeNavBar`, classic bar | `flask_purple.png` | keep | Distinct from red heal flask; keep purple |
| `nav_map` | MAP | `HomeNavBar`, classic `MenuRoute.map` | `boots.png` | **replace** | Boots = movement, not map; **compass / folded map / continent** |
| `nav_shop` | SHOP | `HomeNavBar`, classic SHOP | `star.png` | **replace** | Star = generic; Brick uses **shop awning / coin purse** |
| `nav_key` | KEY | Classic bar only | `key.png` | keep | Gold key PNG already shipped for jargon unlock |
| `nav_more` | MORE | Classic bar | `book.png` | **replace** for home | Home uses top MENU same book; prefer **grid / kebab** for MENU vs book for INFO |

### Top bar currencies & meta

| Id | Where | Current | Status | Notes |
|----|-------|---------|--------|-------|
| `cur_gold` | `HomeTopBar`, `WalletStrip`, rails | `coin_gold.png` | keep / refine | Primary warm currency; match dock FORGE accent |
| `cur_essence` | Top bar, wallet | `flask_purple.png` | keep | |
| `cur_al` | Top bar “AL n” chip | `crown.png` | keep | Ascend metaphor |
| `cur_embers` / `cur_cinders` | ESSENCE sheet third chip | `ring.png` | **replace** | Ring ambiguous; **ember orb / cinder shard** pair |
| `cur_tickets` | SHOP route third chip | `star.png` | **replace** | Use **ticket stub** or scroll ticket |
| `menu_top` | MENU tap | `book.png` | **replace** | See `nav_more` |

### Under-fight dock (no icons today)

| Id | Label | Where | Current | Status | Notes |
|----|-------|-------|---------|--------|-------|
| `dock_forge` | FORGE | `HomeGoldDock`, `UpgradePanel`, `ForgeOverlay` context | **none** (text segment) | **generate new** | Anvil + hammer or tongs; pairs with `cur_gold` |
| `dock_camp` | CAMP | Same | **none** | **generate new** | Distinct from `campfire.png` (Long Away shop); **tent / shrine** |
| `dock_market` | MARKET | Same | **none** | **generate new** | Stall, scales, or handshake + coin |

### Fight seam & HUD

| Id | Where | Current | Status |
|----|-------|---------|--------|
| `action_godhand` | `GodHandRing` | `fist.png` + ring paint | keep |
| `action_flask` | `DungeonFlaskButton` | `flask.png` (heal) | keep; don’t confuse with purple essence |
| `action_leave` | Classic LEAVE | `door.png` | keep |
| `hud_rift_skull` | `RiftProgressHud` | `skull.png` | keep |
| `buff_scroll_*` | `ScrollBuffStack` | sword, coin, tome, boots, chest, wand, campfire | keep set; optional **unify stroke** in one pass |
| `wisp_lantern` | `WispGiftOverlay` | `UiGlyph.wisp` + overlay paint | **glyph**; optional PNG for marketing |

### MENU grid & fight rails (`HomeCatalog`)

| Catalog id | Label | Icon constant | PNG | Status |
|------------|-------|---------------|-----|--------|
| scrolls / menu_scrolls | SCROLLS | `tome` | tome | **replace** — scroll **roll** not book |
| watch / menu_watch | WATCH | `star` | star | **generate new** — **play / film** |
| starter_pouch / menu_pouch | POUCH | `gold` | coin | keep |
| update / menu_update | UPDATE | `star` | star | **generate new** — **download arrow / Play badge** |
| quests / menu_quests | QUESTS | `quests`→trophy | trophy | keep / refine |
| vault / menu_vault | VAULT | `chest` | chest | keep |
| daily / menu_daily | DAILY | `boots` | boots | **replace** — **sun / calendar** |
| wisp / menu_wisp | WISP | `flask` | flask | **replace** — **lantern** (match overlay) |
| menu_patch | PATCH NOTES | `more`→book | book | keep |
| menu_settings | SETTINGS | `settings` | settings | keep (already PNG pass) |
| menu_guides | GUIDES | `tome` | tome | keep / share with scrolls art direction |
| menu_craft | CRAFT | `wand` | wand | keep |
| menu_redeem | REDEEM | `star` | star | **replace** — **gift tag / ticket** |
| menu_floors | FLOORS | `boots` | boots | **replace** — **stairs / floor stack** |
| rail UPDATE | UPDATE | `star` | star | same as menu_update |

### Chase & endgame (hub + MAP)

| Hunt / chase | Icon | PNG | Status |
|--------------|------|-----|--------|
| Gauntlet | `skull` | skull | **replace** optional **spire** icon |
| Ranked GR | `trophy` | trophy | keep |
| Farm Rift | `flaskBlue` | flask_blue | keep |
| Ashen | `campfire` | campfire | keep |
| Keystone | `key` | key | keep |
| PATH zones | zone `hub_icon.png` | per zone | separate art pass; align **frame size** 32×32 |

### Shop rows (`ShopDock._iconFor`)

Uses heart (ad-free), campfire (long away), trophy (supporter), flask (hours), gold (cinders), star (perm all / season), plus perm scroll icons — **keep logic**; refresh PNGs if **`icon_shop`** family gets a unified pass.

### Gear slot icons (reference only)

`iconHelm`, `iconChest`, … `iconWand` under `assets/custom/icons/` — used heavily in **GEAR** paper doll and bag filters. **Out of scope** for a shell-only pass unless Creative reskins the whole `icons/` folder at once.

---

## 4) Prioritized generation backlog

### Must-have (player sees every session)

1. **`icon_shop.png`** — SHOP tab + shop entry (stop using `star`)
2. **`icon_map.png`** — MAP tab (stop using `boots`)
3. **`icon_forge.png`** — dock segment + GOLD chase/wipe hints
4. **`icon_camp.png`** — dock segment (not campfire shop icon)
5. **`icon_market.png`** — dock segment + MARKET wipe CTA
6. **`icon_menu.png`** — top MENU (distinct from INFO book)
7. **`icon_close_tab.png`** — selected tab dismiss (replace red glyph)
8. Refine **`coin_gold.png`** + **`flask_purple.png`** as **currency pair** (16 & 24px masters)
9. Refine **`helm.png`** + **`sword.png`** for **26px** bottom nav (selected torch outline)
10. **`icon_watch_ad.png`** — WATCH rail + `BoostAdButton` optional icon

### Secondary (sheets & rails)

11. **`icon_scroll.png`** — SCROLLS rail (replace tome/star confusion)
12. **`icon_daily.png`** — DAILY (calendar)
13. **`icon_vault.png`** — optional chest refresh (badge readability)
14. **`icon_ticket.png`** — ad tickets / SHOP chip
15. **`icon_embers.png`** / **`icon_cinders.png`** — ESSENCE third chip
16. **`icon_redeem.png`**, **`icon_update.png`**, **`icon_floors.png`**
17. Optional **`icon_gauntlet.png`** (spire) vs skull for ENDGAME map
18. **`icon_wisp_lantern.png`** — WISP rail + floating gift

### Tertiary (unify or defer)

- Full **`UiGlyph` → PNG** set (`add`, `prev`, `next`, `scroll`) for tier picker arrows
- Zone **`hub_icon.png`** frame template (15 zones)
- Gear slot weapon/armor icons (only with full icon folder regen)

---

## 5) Art brief for Creative (Brick Inc–coherent pixel fantasy)

**Goal:** One readable **16×16 logical** icon set (export **32×32** and **48×48** PNG), shared stroke, that matches `GameTheme` stone panel + torch gold (`docs/UI_THEME.md`).

| Spec | Value |
|------|--------|
| Canvas | **32×32 px** master (scale to 16 / 20 / 24 / 26 in UI) |
| Color depth | Limited palette; **no anti-aliased gradients** on edges |
| Style | **Filled silhouette** + 1px highlight (top-left); optional 1px dark outline on `#2a241c` stone |
| Readability | Silhouette must read at **18px** on Samsung A56 (360dp wide) |
| Selected state | Code tints with `GameTheme.torchHot` — design **neutral parchment** base |
| Forbidden | Material Design icons, emoji, photoreal metal, thin line-art inconsistent with helm/sword |
| Naming | `assets/custom/icons/<name>.png` snake_case; add **`UiIcon` const** in `game_icon.dart` when wired |
| Dock trio | Shared **width** and **baseline** for FORGE / CAMP / MARKET segment icons (optional 20px left of label in future UI) |
| Currencies | Gold coin **round**; essence **vertical flask** purple `#9b6bd4`; tickets **rectangular stub** |
| QA | Place on `GameTheme.panel` and `GameTheme.stoneDeep`; check next to existing `helm.png` |

**Reference inside repo:** competitor shell notes
`docs/competitor_research/brick_inc_idle_breaker/UI_SHELL.md` (distinct tab shapes,
shop awning, center fight tab). **Do not copy** their art — match **Idle Party**
owned pixel heroes and Sandy cave palette.

**Implementation note (for later, not this doc):** after PNGs land, update
`UiIcon` mappings in `app_bottom_bar.dart`, `home_nav_bar.dart`,
`home_catalog.dart`, and add optional icons to `MenuChrome.segmented` rows —
no gameplay changes required.

---

## Top 15 to generate first

| # | File (proposed) | Replaces / fills |
|---|-----------------|------------------|
| 1 | `icon_shop.png` | SHOP tab (`star`) |
| 2 | `icon_map.png` | MAP tab (`boots`) |
| 3 | `icon_forge.png` | Dock FORGE (missing) |
| 4 | `icon_camp.png` | Dock CAMP (missing) |
| 5 | `icon_market.png` | Dock MARKET (missing) |
| 6 | `icon_menu.png` | Top MENU (`book`) |
| 7 | `icon_close_tab.png` | Nav close (`UiGlyph.close`) |
| 8 | `coin_gold.png` (refresh) | Currency chip + rails |
| 9 | `flask_purple.png` (refresh) | ESSENCE tab + wallet |
| 10 | `helm.png` + `sword.png` (refresh pair) | HEROES + FIGHT tabs |
| 11 | `icon_watch_ad.png` | WATCH rail / boost |
| 12 | `icon_scroll.png` | SCROLLS rail |
| 13 | `icon_daily.png` | DAILY rail |
| 14 | `icon_ticket.png` | Ticket counts / SHOP chip |
| 15 | `icon_embers.png` | ESSENCE embers/cinders chip (split cinders later) |

After those, **`icon_update.png`**, **`icon_redeem.png`**, **`icon_floors.png`**, and **`icon_wisp_lantern.png`** complete the MENU grid and rails without reusing `star` or `boots`.
