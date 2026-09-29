---
name: ads-and-rewards
description: >-
  Idle Party ads and rewards: AdMob rewarded ads, the gold WISP lantern,
  SCROLLS Ad Tickets, ad-free / supporter entitlements, and UMP consent.
  Use when the owner talks about lyktan, WISP, reklam, ad tickets, SCROLLS,
  ad-free, AdMob, or "belöning". Do not use for Play Console listing or
  AdMob revenue reads (play-store-prep) or SHOP prices alone.
---

# Ads and rewards (Idle Party)

Ads are opt-in. The player always starts them. A reward is granted only
after the ad is fully watched and dismissed.

## Where things live

| Piece | Path |
|-------|------|
| Unit ids (test in debug, live in release) | `lib/core/ad_config.dart` `AdConfig` |
| Show / warm up / privacy form | `lib/core/ad_rewarded.dart` (+ `_io` Android, `_stub` web/tests) |
| WISP rules and gold math | `lib/core/wisp_gift.dart` `WispGift` |
| WISP runtime | `GameDirector.tickWisp` / `tapWispGift` / `watchWispGiftAd` |
| WISP look + choice sheet | `lib/ui/shell/wisp_gift_overlay.dart` (mounted in `play_shell.dart`, hub and dungeon) |
| Tickets and buffs | `lib/core/ad_boost.dart` `AdBoost`, `AdBuffCatalog` |
| SCROLLS sheet | `lib/ui/hub/hub_powerups.dart`; chips `lib/ui/shell/scroll_buff_stack.dart` |
| SKUs | `lib/core/shop_catalog.dart`, `ShopBilling.applyPurchase` |
| Design / privacy | `docs/AD_POWERUPS_DESIGN.md`, `docs/PRIVACY.md`, `docs/SHOP_MONETIZATION.md` |

Save fields sit on `metaDepth` and survive Ascend: `adTickets`, `ad*UntilMs`,
`adFree`, `adFreeDailyClaimUtc`, `shopPermScrolls`, `wisp*`. New fields
follow `save-migrate`.

## Landed decisions (do not re-litigate without the owner)

- **Lantern:** `Alignment(0.84, -0.58)` on the open map, clear of the header.
  48×48 touch box, 36×46 pixel cage glyph with a hard black outline, bright
  flame, and one tip. Hard pixel colors, no blur. Spot stays
  `Alignment(0.84, -0.58)`. New size or spot is still a big look change —
  show a before and after on the A56 first (`owner-preferences`).
- **Where the WISP ad runs:** where the lantern was tapped, hub or dungeon.
- **SCROLLS:** never start an ad mid-fight. Hub FAB shows with SHOP
  (`MenuTabs.showScrolls`). One ad = +1 ticket. Magnitudes do not stack;
  time extends up to 24 h.
- **Ad-free:** hide WATCH, one free ticket per UTC day, WISP gives the big
  gold pile on tap (no time boost).
- **WISP choice:** WATCH AD = bigger gold only. NO THANKS = keep the small
  pile. No 1h ×2 gold from WISP.
- **WISP amounts:** best cleared zone (+ ~4% wallet soft floor for WATCH),
  not the current farm floor.
- **WISP cadence (release):** first after 90 s, then every 10 min, visible
  10 s, max 6 taps per UTC day. Debug builds run every 20 s.

## Test it

1. `flutter test test/ad_boost_test.dart test/wisp_gift_test.dart test/shop_billing_test.dart`
2. On the A56 (debug build = Google test ads, safe to tap): enter a cave once
   to unlock WISP, wait ~20 s, tap the lantern, try KEEP and WATCH, open
   SCROLLS on the hub. Never tap live ads on a release build.
3. Tests cannot load a real ad (`realAdsAvailable` is false). Say so in the
   handoff when only the phone proves a change.

## Gotchas

- Skip or failed ad on WISP drops the pending watch pile for that tap.
- SCROLLS and WISP share one rewarded unit and one preload.
- Warmup starts ~2 s after boot; the first WATCH may say loading.
- `docs/PLAY_STORE.md` still has old "POWERUPS / 1 ad = 3 hours" wording.
  Fix it when you touch that doc.
- Pet `xp_wisp` and the frost wisp enemy are unrelated to the lantern.
