# Firebase Analytics events (Idle Party)

Same consent gate as [ANALYTICS.md](ANALYTICS.md): UMP / **SETTINGS → AD PRIVACY**.
Web, Flutter tests, and builds without `google-services.json` send nothing.

Implementation: [`lib/core/app_analytics.dart`](../lib/core/app_analytics.dart),
names and buckets in [`lib/core/analytics_events.dart`](../lib/core/analytics_events.dart),
once-per-install funnel in [`lib/core/funnel_analytics.dart`](../lib/core/funnel_analytics.dart).

## Automatic (Firebase)

| Event | Notes |
|---|---|
| `first_open` | Firebase only. Local stamp in funnel; do not log manually. |
| `session_start` | Firebase session. App also logs `app_cold_start` per process boot. |

## Session

| Event | Params | When |
|---|---|---|
| `app_cold_start` | `days_since_install` (optional) | Once per process after a save loads (boot, slot load, new game). |
| `session_length` | `seconds` | App backgrounds after ≥15s foreground. |

## First-session funnel

| Event | Params | When |
|---|---|---|
| `boot_intro_shown` | — | Boot intro once per install (prefs). |
| `start_menu_shown` | — | Title once per install. |
| `new_game_shown` | — | New game picker once per install. |
| `new_game_confirmed` | — | START on new game once per install. |
| `app_ready` | — | New game ready once per install. |
| `first_enter` | `dungeon_id`, `seconds_to_combat` | First dungeon enter. |
| `time_to_combat` | `seconds` | With first enter when timing known. |
| `first_reward` | — | First combat gold. |
| `first_boss` | — | First boss clear. |
| `first_upgrade` | — | First forge gold spend. |
| `d1_return` | `days_since_install` | First open on a later UTC day. |
| `coach_step` | `tip_id` | First-session coach tip completed (`dismissTip`). |

## Welcome Back & rewarded ads

| Event | Params | When |
|---|---|---|
| `welcome_back` | `where`, `seconds`, `gold`, `seconds_bucket`, `gold_bucket` | Every Welcome Back card. |
| `welcome_back_ad_offer` | — | WATCH visible on card. |
| `welcome_back_ad_tap` | — | WATCH tapped. |
| `welcome_back_ad` | `gold`, `essence` | Watch finished; loot doubled. |
| `welcome_back_ad_skip` | — | User closed ad early. |
| `rewarded_offer` | `placement` | Preload when offer UI shows. |
| `rewarded_tap` | `placement` | User started a rewarded watch. |
| `rewarded_complete` | `placement` | Full watch. |
| `rewarded_skip` | `placement` | Dismissed before reward. |
| `rewarded_load_fail` | `placement` | SDK load/show failed. |

Placements: `welcome_back`, `wisp_gift`, `powerups`, `scroll_well`, `quest_reroll`, `wipe_retry`, `wipe_revive`.

| Event | Params | When |
|---|---|---|
| `scroll_well_free` | — | SCROLLS Daily Well: free Ad Ticket claimed (UTC day). |
| `scroll_well_ad` | `step` (1–2) | Well bonus ad finished (+1 ticket). |
| `wipe_revive_cinders` | `cost`, `dungeon_id`, `floor`, `gauntlet` | Wipe revive paid with Cinders. |
| `quest_reroll` | `slot`, `left_today` | Daily or Side quest rerolled. |

## SHOP (Play Billing)

| Event | Params | When |
|---|---|---|
| `store_view` | — | SHOP tab opened. |
| `store_product_view` | `product_id` | Each product row first shown that visit. |
| `ad_free_nudge_view` | `product_id` (`ad_free`) | SCROLLS showed the one-time Ad-free line. Once per save. |
| `ad_free_nudge_tap` | `product_id` (`ad_free`) | Player tapped that line. SHOP opens after. |
| `store_purchase_start` | `product_id` | Buy sheet opened. |
| `store_purchase` | `product_id`, and `value` + `currency` when Play has listed that pack | New grant (not restore). |
| `store_purchase_cancel` | `product_id` | Sheet error, cancel, or Play error. |

## Meta & dungeon

| Event | Params | When |
|---|---|---|
| `ascend` | `from_al`, `to_al` | Ascend. |
| `enter_dungeon` | `dungeon_id`, `key_level`, `floor` | Enter. |
| `leave_dungeon` | `dungeon_id`, `floor` | Leave. |
| `party_wipe` | `dungeon_id`, `floor`, `streak` | Wipe. |
| `offline_gold` | `gold` | Welcome Back paid gold (repeat). |
| `offline_hold` | `gold` | First empty Welcome Back. |
| `notify_open` | `channel` (`away_ping`, `chest_tray`) | Local notification opened. |
| `notify_opt_in` / `notify_opt_out` | `source`, optional `reason` | Away reminders. |
| `review_prompt` | `source` | Rating ask. |
| `remote_tune` | (lantern keys) | Remote Config applied. |

## Welcome Back buckets

| Param | Values |
|---|---|
| `seconds_bucket` | `lt_1m`, `1_5m`, `5_15m`, `15_60m`, `1_4h`, `4_8h`, `8h_cap` |
| `gold_bucket` | `0`, `1_49`, `50_199`, `200_999`, `1k_5k`, `5k_plus` |

## Crashlytics custom keys

| Key | Value |
|---|---|
| `zone_id` | `hub` or current `dungeon_id` |
| `app_version` | `ChangelogCatalog.currentVersion` (+ git SHA on test APKs) |

## DebugView (test APK)

```bash
adb shell setprop debug.firebase.analytics.app com.idleparty.app.test
```

Rebuild with repo `google-services.json` that includes `com.idleparty.app.test`;
see [ANALYTICS.md](ANALYTICS.md).
