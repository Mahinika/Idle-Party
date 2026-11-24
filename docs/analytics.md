# Analytics funnels (Firebase, free tier)

Spark plan only. Do not link BigQuery. Do not upgrade to Blaze.
Project and consent: [ANALYTICS.md](ANALYTICS.md). Event catalog:
[analytics_events.md](analytics_events.md).

Nothing here changes prices, rewards, or the save format. Install flags
are SharedPreferences (`idle_party_onboarding_funnel`,
`idle_party_install_ms`).

Flutter tests do not send events. Debug and emulator builds of
`com.idleparty.app` do. In every exploration below, add a filter
**exclude** `build_mode` = `debug` when you want Play installs only.
`build_mode` = `release` is the Play build.

`first_open` and `session_start` are automatic. The app does not log
those names. Do not add a second `session_start`.

## User properties

They show up after the first sessions on this build. No console
registration is required for collection. For an exploration filter,
create a custom definition only if the picker does not list them yet.

| Property | Use |
|---|---|
| `install_cohort` | UTC day `YYYYMMDD`. Audience and cohort breakdown. |
| `days_since_install` | Latest UTC day count. Updated when the app resumes. |
| `ad_free` | `true` / `false`. |
| `season_pass` | `true` / `false`. |
| `build_mode` | `debug` / `profile` / `release`. |

For a save that already existed, `install_cohort` is the first launch
of this build, not the original install day. New phones with no save
get the real first launch.

## 1. Onboarding (trust this one)

Firebase console → **Explore** → **Funnel exploration** → **Open funnel**.
Date range: last 28 days. Filter: `build_mode` exactly matches `release`
(drop the filter while checking DebugView).

Steps, in order. Where a step says `step_index`, add a parameter filter
**equals** that number. That drops later saves and later Welcome Back cards.

| Step | Event | Filter |
|---|---|---|
| 1 First launch | `onboarding_launch` | `step_index` = 1 |
| 2 First fight | `first_enter` | `step_index` = 2 |
| 3 First TRAIN | `first_upgrade` | `step_index` = 3 |
| 4 First boss | `first_boss` | `step_index` = 4 |
| 5 First craft | `first_craft` | `step_index` = 5 |
| 6 First return | `welcome_back` | `step_index` = 6 |

Open, not closed. TRAIN is allowed after the first boss, and a closed
funnel in this order would drop those players before craft and return.

Name it **Onboarding (install)**.

## 2. Happy path (closed)

Same place → **Closed funnel**. Same release filter.

| Step | Event | Filter |
|---|---|---|
| 1 | `onboarding_launch` | `step_index` = 1 |
| 2 | `first_enter` | `step_index` = 2 |
| 3 | `first_boss` | `step_index` = 4 |
| 4 | `first_craft` | `step_index` = 5 |
| 5 | `welcome_back` | `step_index` = 6 |

This is the order the cave actually forces (craft opens after the first
boss). Keep TRAIN as its own card: event `first_upgrade`, `step_index` = 3.
Name the funnel **Onboarding happy path**.

The older exploration **Första sessionen** (`first_open` → `first_enter` →
`first_boss` → `first_reward` → `in_app_purchase`) can stay until
`onboarding_launch` has volume. Do not add `store_purchase` value on top
of `in_app_purchase`.

## 3. Retention

No new session event.

- **Events:** automatic `session_start` (one per Firebase session) and
  `app_cold_start` (one per process, param `days_since_install`).
- **Cohort:** user property `install_cohort`. Breakdown of `session_start`
  or `app_cold_start` by that property.
- **Day-N:** user property `days_since_install`, or the same param on
  `app_cold_start`. `d1_return` is still the first later UTC day on that
  save (once per save, not per install).

Card: **Explore** → **Free form**. Rows: `install_cohort`. Values: event
count of `session_start`. Filter `build_mode` = `release`.

## 4. Rewarded ads

**Closed funnel**, breakdown dimension `placement`.

| Step | Event |
|---|---|
| Offer shown | `rewarded_offer` |
| Accepted | `rewarded_tap` |
| Completed | `rewarded_complete` |

Fail card, same breakdown: `rewarded_load_fail` with `reason`
(`preload`, `load`, `show`, `not_ready`, `timeout`). Preload fails are
not taps.

Placements: `welcome_back`, `wisp_gift`, `powerups`, `camp_ad`,
`scroll_well`, `quest_reroll`, `wipe_retry`, `wipe_revive`.

The Welcome Back card also logs `welcome_back_ad_offer`,
`welcome_back_ad_tap`, `welcome_back_ad`, and `welcome_back_ad_skip`.
Those are the card twins of the placement events. Use the `rewarded_*`
funnel above. Do not add the two completed counts together.

## 5. Shop

**Closed funnel.**

| Step | Event | Notes |
|---|---|---|
| Shop opened | `store_view` | |
| Product seen | `store_product_view` | breakdown `product_id` |
| Buy started | `store_purchase_start` | `product_id` |
| Granted | `store_purchase` | `product_id`, and `value` + `currency` when Play listed the pack |

Beside it, two counts by `product_id`:

- `store_purchase_cancel` — the player dismissed the sheet
- `store_purchase_fail` — `reason` is `sheet_unavailable`, `play_error`, or `save_failed`

`in_app_purchase` (automatic, after the Play link) is the revenue row.
Do not add `store_purchase` value to it.

Audience for payers who own a pack: `ad_free` = `true`, or
`season_pass` = `true`.

## DebugView

```bash
adb shell setprop debug.firebase.analytics.app com.idleparty.app
```

A new phone with no save should show `onboarding_launch` (`step_index` 1),
then `first_enter` (`step_index` 2) on the first cave. TRAIN, the first
boss, the first Apex craft, and the first Welcome Back card follow with
steps 3–6. A second Welcome Back has no `step_index`.
