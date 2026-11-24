# Firebase Analytics events (Idle Party)

Same consent gate as [ANALYTICS.md](ANALYTICS.md): UMP / **SETTINGS → AD PRIVACY**.
Web, Flutter tests, and builds without `google-services.json` send nothing.
Install funnel and the Firebase explorations: [analytics.md](analytics.md).

Flutter tests set `FLUTTER_TEST`, so the Android SDK is never created.
`debugSink` in tests records names locally only. A debug or emulator build
of `com.idleparty.app` does send. Filter those with the `build_mode` user
property (`debug` / `profile` / `release`).

Implementation: [`lib/core/app_analytics.dart`](../lib/core/app_analytics.dart),
names and buckets in [`lib/core/analytics_events.dart`](../lib/core/analytics_events.dart),
once-per-install funnel in [`lib/core/funnel_analytics.dart`](../lib/core/funnel_analytics.dart).

## Automatic (Firebase)

| Event | Notes |
|---|---|
| `first_open` | Firebase only. Local stamp in the save funnel; the SDK call is dropped. |
| `session_start` | Firebase session. The app does not log this name. `app_cold_start` is one process boot. |

## Session

| Event | Params | When |
|---|---|---|
| `app_cold_start` | `days_since_install` (optional) | Once per process after a save loads (boot, slot load, new game). |
| `session_length` | `seconds` | App backgrounds after ≥15s foreground. |

## Install onboarding (prefs, once)

Flags: `idle_party_onboarding_funnel` and `idle_party_install_ms` in
SharedPreferences. Not save fields. An existing save with an empty flag
list is marked done and emits nothing.

| Step | Event | Params | When |
|---|---|---|---|
| 1 | `onboarding_launch` | `step_index` | First launch with no save. |
| 2 | `first_enter` | `step_index`, plus the per-save params | First dungeon enter this install. Later saves still log `first_enter` without `step_index`. |
| 3 | `first_upgrade` | `step_index` | First TRAIN (forge gold) spend this install. |
| 4 | `first_boss` | `step_index` | First boss clear this install. |
| 5 | `first_craft` | `step_index`, `slot` | First successful Apex craft. Once. |
| 6 | `welcome_back` | `step_index` plus the card params | First Welcome Back card. Later cards omit `step_index`. |

## First-session funnel (per save)

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
| `welcome_back` | `where`, `seconds`, `gold`, `seconds_bucket`, `gold_bucket`, and `step_index` on the first card this install | Every Welcome Back card. |
| `welcome_back_ad_offer` | — | WATCH visible on card. |
| `welcome_back_ad_tap` | — | WATCH tapped. |
| `welcome_back_ad` | `gold`, `essence` | Watch finished; loot doubled. |
| `welcome_back_ad_skip` | — | User closed ad early. |
| `rewarded_offer` | `placement` | Preload when offer UI shows. |
| `rewarded_tap` | `placement` | User started a rewarded watch. |
| `rewarded_complete` | `placement` | Full watch. |
| `rewarded_skip` | `placement` | Dismissed before reward. |
| `rewarded_load_fail` | `placement`, `reason` (`preload`, `load`, `show`, `not_ready`, `timeout`) | One failure. A preload fail is not a second event. |

Placements: `welcome_back`, `wisp_gift`, `powerups`, `camp_ad`, `scroll_well`, `quest_reroll`, `wipe_retry`, `wipe_revive`.

| Event | Params | When |
|---|---|---|
| `scroll_well_free` | — | SCROLLS Daily Well: free Ad Ticket claimed (UTC day). |
| `scroll_well_ad` | `step` (2 or 3) | Well bonus ad finished (+1 ticket). Free claim is step 1. |
| `wipe_revive_cinders` | `cost`, `dungeon_id`, `floor`, `gauntlet` (0/1) | Wipe revive paid with Cinders. |
| `quest_reroll` | `slot`, `left_today` | Daily or Side quest rerolled. |

## SHOP (Play Billing)

| Event | Params | When |
|---|---|---|
| `store_view` | — | SHOP tab opened. |
| `store_product_view` | `product_id` | Each product row first shown that visit. |
| `ad_free_nudge_view` | `product_id` (`ad_free`) | SCROLLS or CAMP showed the one-time Ad-free line. Once per save. |
| `ad_free_nudge_tap` | `product_id` (`ad_free`) | Player tapped that line. SHOP opens after. |
| `store_purchase_start` | `product_id` | Buy sheet opened. |
| `store_purchase` | `product_id`, and `value` + `currency` when Play has listed that pack | New grant (not restore). |
| `store_purchase_cancel` | `product_id` | User dismissed the sheet (`PurchaseStatus.canceled`, or a Play error whose code is user-cancel). |
| `store_purchase_fail` | `product_id`, `reason` (`sheet_unavailable`, `play_error`, `save_failed`) | Sheet did not open, Play error, or the grant did not save. |

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

## User properties

Set on cold start, on resume, and after a Play grant saves. `first_open` and
`session_start` stay automatic.

| Property | Value |
|---|---|
| `install_cohort` | UTC `YYYYMMDD` of the prefs install clock. For a save that already existed, that is the first launch of this build. |
| `days_since_install` | Whole UTC days since that clock. Updated on resume. |
| `ad_free` | `true` or `false`. |
| `season_pass` | `true` or `false` (`paidSeasonPass`). |
| `build_mode` | `debug`, `profile`, or `release`. |

## Limits

Event and param names: 40 characters, start with a letter. String values: 100.
At most 25 params. User property names: 24. User property values: 36.
Bool params are sent as 0/1. `gauntlet` is 0/1.

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
