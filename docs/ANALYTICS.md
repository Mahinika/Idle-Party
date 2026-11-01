# Idle Party — measurement

Firebase project in `android/app/google-services.json`: **`idle-party-4a2e9`**
(Android app `com.idleparty.app`). Analytics and Crashlytics only. Both are
on the free Spark plan. Do not link BigQuery. Do not upgrade the project to
Blaze for this.

The sideload test package `com.idleparty.app.test` needs its own client in
the same `google-services.json` (register it in Firebase; see below). Without
that client, test APK builds fail in CI. Play release uses `com.idleparty.app`
only.

## Consent

The manifest keeps Analytics and Crashlytics collection off, and the four
Consent Mode signals denied, until Dart finishes the Google UMP check
(`ConsentInformation.canRequestAds`). That is the same prompt as rewarded
ads. **SETTINGS → AD PRIVACY** runs the check again.

After the check, Analytics collection turns on. A yes sets all four signals
to granted (`analytics_storage`, `ad_storage`, `ad_user_data`,
`ad_personalization`). A no, or a check that times out, leaves them denied.
Denied Analytics may still send limited consent-mode pings without an
advertising ID so Google can model aggregated measurement. Crashlytics and
Remote Config stay off on a no.

Outside the EU/EEA, Google may allow collection without a form. Web, Flutter
tests, and a build with no `google-services.json` send nothing.

No Idle Party user id is attached. Events do not include the save file.
`store_purchase` carries `product_id`, plus `value` and `currency` when Play
has listed that pack. That is the funnel price. The automatic
`in_app_purchase` event, after Google Play is linked in the Firebase console,
is the Monetization row. Do not add those two amounts together.

## Event plan

Full catalog with params: [analytics_events.md](analytics_events.md).

Firebase also auto-collects `first_open`, `session_start`, and engagement
time when collection is on. The app does not log `first_open` itself
(Firebase rejects that name). The local funnel still stamps it so the rest
of the chain has an install day.

| Moment | Event | When |
|---|---|---|
| First open | `first_open` | Firebase automatic. Not sent by our code. |
| Tutorial | `boot_intro_shown`, `start_menu_shown`, `new_game_shown`, `new_game_confirmed` | Once per install, before a save exists. |
| Playable | `app_ready` | Once, when a new game is ready. |
| First fight | `first_enter`, `time_to_combat` | Once. `seconds` on `time_to_combat`. `first_enter` also carries `seconds_to_combat` and `dungeon_id`. |
| First gold | `first_reward` | Once. |
| First boss | `first_boss` | Once, the first boss clear on that install. |
| Next day | `d1_return` | Once, the first later UTC day. |
| Welcome Back shown | `welcome_back` | Every return card. `where` is `hub` or `dungeon`, plus `seconds` and `gold`. |
| Ad offered | `welcome_back_ad_offer` | The watch button is on that card. Hidden before the first boss, when gold is already ×3, and for ad-free or Forever Rest. |
| Ad watched | `welcome_back_ad` | The watch finished and gold was granted. `gold` is the extra amount. |
| SHOP viewed | `store_view` | Each time SHOP is opened. |
| Purchase | `store_purchase` | A new Play grant. `product_id`, plus `value` and `currency` when Play has listed that pack. Restores are not purchases. |
| Ascend | `ascend` | `from_al`, `to_al`. |
| Session length | `session_length` | App goes to the background after at least 15 seconds in the foreground. `seconds` is that stint. |

## Also sent

These were already in the app. Same consent gate.

| Event | When |
|---|---|
| `enter_dungeon` | Enter. `dungeon_id`, `key_level`, `floor`. |
| `leave_dungeon` | Leave. `dungeon_id`, `floor`. |
| `party_wipe` | Wipe. `dungeon_id`, `floor`, `streak`. |
| `wipe_revive_ad` | Rewarded revive after wipe. `dungeon_id`, `floor`, `gauntlet` (bool). |
| `scroll_well_free` | Free Well step. `step` (1). |
| `scroll_well_ad` | Well ad step. `step` (2 or 3). |
| `wipe_revive_cinders` | Cinder revive after wipe. `dungeon_id`, `floor`, `gauntlet`, `cost`. |
| `quest_reroll` | Quest reroll after ad or Ad-free. `slot` (`daily`/`side`), `left_today`. |
| `offline_gold` | Welcome Back paid gold. `gold`. The funnel mark is once; the event repeats. |
| `offline_hold` | First Welcome Back with no gold. Once. |
| `review_prompt` | Rating card. `source` is `card` or `settings`. |
| `notify_opt_in` / `notify_opt_out` | Away-reminder choice. |
| `remote_tune` | A Remote Config fetch applied. Lantern numbers only. |

## Crashlytics

Fatal Flutter errors and uncaught async errors are recorded. Crashlytics
turns on only when the UMP check says ads can be requested. A decline keeps
crash reports off. A crash report shows up after the next cold start. There
is no crash button in the game.

`FirebaseInitProvider` is removed in the Android manifest. That provider
called `FirebaseApp.initializeApp` on the main thread before the first
frame, and Crashlytics plus Firebase Sessions start inside that call. On
1.13.6 that blocked cold start (Play icon, then “Idle Party svarar inte”).
`Firebase.initializeApp` runs after the Cognifox frame, on the plugin
background pool. Dart errors that happen before that attach are queued and
sent once Crashlytics is up. Saves are unchanged.

## Already in this Firebase project

Not added here. Do not grow them for measurement.

- Remote Config (lantern timing and the featured SHOP id), after the same consent check.
- Anonymous Auth and Cloud Firestore for the optional friend invite. Spark free quotas apply. This change does not add reads or writes.

## What the owner turns on

In the Firebase console for **`idle-party-4a2e9`**:

1. Open **Crashlytics**. If it asks to get started, enable it. Stay on Spark. Do not link **BigQuery**. Do not upgrade to Blaze.
2. Google Analytics is already the destination for the events above. Leave it linked. Do not add a second analytics product.
3. Play Android app is `com.idleparty.app`. For sideload QA APKs, also register **`com.idleparty.app.test`** (nickname e.g. Idle Party Test), download `google-services.json`, and commit it when it lists **both** package names under `client[]`. That test app is not on Play; it only enables Analytics/Crashlytics on test APKs. Optional until committed: GitHub secret **`GOOGLE_SERVICES_JSON`** (full file) or **`FIREBASE_TOKEN`** from `firebase login:ci` so the test APK workflow can register the app and merge the test client automatically (`tool/ci/firebase_register_test_app.sh` locally).
4. Play Data safety already lists Diagnostics. Crash stack traces are crash logs. If that row is off, turn **Crash logs** on (collected, shared with Google Firebase, purpose Analytics) before the next Play upload. This change does not upload an AAB. Before the next upload, re-read the Analytics row that says collection is optional via UMP: a decline can still send limited consent-mode pings.
5. No new consent form. **SETTINGS → AD PRIVACY** remains the switch.
6. **Google Play.** Project settings → Integrations → Google Play. Link the account that owns `com.idleparty.app`. Revenue then shows as `in_app_purchase` and in Monetization, often within a couple of days. Leave the AdMob link from 2026-09-10 as it is. If `in_app_purchase` is still missing after a real purchase on a Play-installed build, that is a later code change.
7. **Funnel.** Analytics → Admin → Events: mark `first_boss`, `d1_return`, and `store_purchase` as key events. Explore → Funnel: `first_open` → `first_enter` → `first_boss` → `rewarded_complete` → `store_purchase`. `in_app_purchase` is the revenue row, not an extra funnel step.
8. **Crashlytics email.** Settings → Alerts → Crashlytics. Turn on email for a new fatal, a new ANR, and velocity. Velocity needs at least 10 users in 30 minutes, and the default threshold is 1% of sessions and 25 users, so it stays quiet until more people play. A new fatal is the alert that helps now. Source: [Crashlytics alerts](https://firebase.google.com/docs/crashlytics/velocity-alerts), updated 2026-10-28.

DebugView, on a `com.idleparty.app` build:

```bash
adb shell setprop debug.firebase.analytics.app com.idleparty.app
```
