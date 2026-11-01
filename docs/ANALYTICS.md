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

Collection is off in the manifest until the existing Google UMP check says
ads can be requested (`ConsentInformation.canRequestAds`). That is the same
prompt as rewarded ads. **SETTINGS → AD PRIVACY** runs the check again and
turns Analytics and Crashlytics on or off together.

Outside the EU/EEA, Google may allow collection without a form. Web, Flutter
tests, and a build with no `google-services.json` send nothing.

No Idle Party user id is attached. Events do not include the save file.

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
| Purchase | `store_purchase` | A new Play grant. `product_id`. Restores are not purchases. |
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
| `offline_gold` | Welcome Back paid gold. `gold`. The funnel mark is once; the event repeats. |
| `offline_hold` | First Welcome Back with no gold. Once. |
| `review_prompt` | Rating card. `source` is `card` or `settings`. |
| `notify_opt_in` / `notify_opt_out` | Away-reminder choice. |
| `remote_tune` | A Remote Config fetch applied. Lantern numbers only. |

## Crashlytics

Fatal Flutter errors and uncaught async errors are recorded. Collection uses
the same on/off switch as Analytics. A crash report shows up after the next
cold start. There is no crash button in the game.

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
4. Play Data safety already lists Diagnostics. Crash stack traces are crash logs. If that row is off, turn **Crash logs** on (collected, shared with Google Firebase, purpose Analytics) before the next Play upload. This change does not upload an AAB.
5. No new consent form. **SETTINGS → AD PRIVACY** remains the switch.

DebugView, on a `com.idleparty.app` build:

```bash
adb shell setprop debug.firebase.analytics.app com.idleparty.app
```
