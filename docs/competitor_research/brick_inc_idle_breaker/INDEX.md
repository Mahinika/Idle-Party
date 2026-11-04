# Brick Inc. Idle Breaker — competitor research

**Package:** `com.seasoninggames.endlessbricks`  
**Play:** [store listing](https://play.google.com/store/apps/details?id=com.seasoninggames.endlessbricks)  
**Captured on:** Play Phone AVD (Google Play), 2026-11-03  
**Method:** Live UI (screenshots + coordinate taps + logcat). No APK decompile, no asset extraction.

**Owner rule (2026-11-03):** **No purchases** — no IAP, no gem/ticket spends, no gacha pulls, no ticket “Play”. Shop screens are view-only.

Use this folder as reference for Idle Party rebuild ideas — **do not copy art, strings, or code**.

## Files

| File | Contents |
|------|----------|
| [SESSION_LOG.md](SESSION_LOG.md) | Timestamped capture log |
| [UI_SHELL.md](UI_SHELL.md) | Navigation, HUD, sheets |
| [SCREENS.md](SCREENS.md) | Which PNG shows which system |
| [SYSTEMS.md](SYSTEMS.md) | Progression, currencies, loops |
| [MONETIZATION.md](MONETIZATION.md) | Ads, IAP, passes |
| [TECH_STACK.md](TECH_STACK.md) | Unity, Firebase, ads, backend APIs |
| [iap_product_ids.txt](iap_product_ids.txt) | 97 Play SKU ids from logcat |
| [logcat_unity_services.txt](logcat_unity_services.txt) | Raw boot log excerpt |
| [screens/](screens/) | PNG captures (`NN_topic.png`) |

## Idle Party touchpoints already

- [AD_POWERUPS_DESIGN.md](../../AD_POWERUPS_DESIGN.md) — ticket shop inspired by Brick Inc ad currency shape (not cloned).
