# Idle Party — Privacy

Idle Party is a single-player idle RPG. This document describes how the app handles data and is suitable for Google Play Data safety disclosures.

**Last updated:** 2026-09-12.

## Summary

- **No Idle Party account.** You do not create a username or password with us.
- **Optional Google Play Games.** You may sign in with Play Games for seasonal leaderboards and cloud save. This is opt-in and not required to play.
- **Optional rewarded ads.** On the Android app you may choose to watch a short ad (hub **POWERUPS**) for an **Ad Ticket**. You spend tickets on timed boosts (Sharp Edge, Gold Rush, Full Boost, Away Bonus). Ads do not play unless you start them. Ad serving uses Google AdMob.
- **Analytics (Firebase).** On Android builds that include Firebase configuration, the app may send anonymous usage events to **Google Firebase Analytics** (for example: app open, first dungeon enter, first combat reward, first boss, returning the next day, entering/leaving a dungeon, Ascend, party wipe). This helps Cognifox Studio understand what works. In the **EU/EEA**, collection follows the Google UMP consent prompt (same path as ads; **SETTINGS → AD PRIVACY**). Outside regions where that form is required, Google may allow collection without a separate prompt. Web playtest and builds without Firebase config do not send analytics.
- **Local save by default.** Progress is stored on your device (e.g. SharedPreferences / platform equivalent).

## Data the app stores locally

Typical save data may include party progress, gear, gold/meta currency, settings, and related gameplay state. That stays on the device unless you choose to move it.

**Optional local session notes:** in **MORE → SETTINGS** you may turn on a short on-device session log and copy it to the clipboard. That log is **not** uploaded to Idle Party or Firebase; it stays on your device until you clear app storage or uninstall.

**Optional away reminders:** after your first combat loot, the app may ask if you want a quiet local ping when gold is waiting or a cave is ready (at most a couple a day, never during a fight). That uses the Android notification permission **only if you tap YES**. Reminders stay on the device; Idle Party does not send them through a server. Turn them off in **MORE → SETTINGS → ACCOUNT**. Declining or turning them off may log an anonymous `notify_opt_out` analytics event (same Firebase path as other optional events).

## Optional Play Games (leaderboards + cloud save)

If you sign in with **Google Play Games**:

- **Leaderboards:** the app may submit opt-in seasonal scores (best timed KEY + clear time, best Infinity Gauntlet floor for the calendar month) to Google’s leaderboard service.
- **Cloud save:** the app may upload a progress snapshot to Google Play Games **Saved Games** so you can restore after reinstall or on another device signed into the same Play Games profile.
- Google hosts that data under Play Games / your Google account. Idle Party does not run its own cloud save or leaderboard server.

You can keep using the game fully offline without signing in. Clipboard export/import remains available as a manual backup.

## Optional clipboard export / import

The app may let you **copy a save to the clipboard** or **paste a save from the clipboard** so you can back up or move progress. That is optional and user-initiated. Idle Party does not upload clipboard contents to a server.

## Network

Aside from normal OS / store behavior (install, updates), optional Play Billing
when you buy from SHOP, optional Play Games calls when you opt in, optional
Firebase Analytics on Android (see below), and optional AdMob when you use
POWERUPS, Idle Party does not require an Idle Party account or Idle Party
cloud service.

On **Google Play installs** (Android), the app may ask Google Play whether a newer Idle Party is available and show an in-app notice. That check goes to Google, not to an Idle Party server. Sideloaded APKs skip it.

On **Android**, if you tap hub **POWERUPS** and watch an ad, Google AdMob may load an ad over the network. That can include an advertising ID and a consent prompt (EU/EEA). Skipping POWERUPS means those ad calls are not started by you. Web playtest builds do not show real ads.

## Analytics (Firebase Analytics)

On **Android** builds that include Firebase configuration (`google-services.json`):

- Google **Firebase Analytics** may receive **anonymous** app events (device/app identifiers under Google’s policies; not an Idle Party login).
- The SDK may initialize when the app starts (not only when you open POWERUPS). Typical events: session start, first time the game is playable, first dungeon enter (including seconds until combat), first combat gold, first boss, first return on a later UTC day, enter/leave dungeon, Ascend, party wipe, and (if you answer the reminder card) whether away reminders were turned on or off. Events do **not** include your save file or clipboard backups.
- In the **EU/EEA**, the Google consent form (UMP) also gates analytics collection. You can change or withdraw that consent later in **SETTINGS → AD PRIVACY**.
- Analytics is not sent from web playtest builds, Flutter tests, or Android builds that lack Firebase config.

Idle Party does not run its own analytics server; Google hosts Firebase.

## Optional real-money SHOP (Android / Google Play)

Bottom-tab **SHOP** may offer cheap convenience packs (timed Full Boost, ad-free,
small QoL). Purchases go through **Google Play Billing**. Google processes the
payment; Idle Party does not run its own payment server. Purchase ownership for
one-time packs is stored in your local save (and optional Play Games cloud save
if you opt in). Sideloaded APKs cannot complete Play Billing buys.

## Optional rewarded ads (Android)

Hub **POWERUPS** is opt-in:

- You choose when to watch. Combat is never interrupted by an ad.
- One finished ad grants **1 Ad Ticket**. Spend tickets on Sharp Edge (+25% ATK 60m), Gold Rush (×2 gold 60m), Full Boost (both for 3h), or Away Bonus (next offline gold ×2). Timers stack per buff up to 24h.
- Google AdMob serves the ad. Idle Party does not run its own ad server.
- In the **EU/EEA**, a Google consent form (UMP) may appear before ads can be requested (and the same consent path gates Firebase Analytics).
- You can change or withdraw that consent later in **SETTINGS → AD PRIVACY** (Android).
- AdMob may be **linked** to the same Firebase / Google Analytics project so Cognifox Studio can see aggregated ad performance and (when enabled) impression-level revenue alongside analytics. That sharing stays inside Google’s products under their policies.

## Delete your data / sign-out

Idle Party does not create its own username or password. Optional Play Games sign-in uses your Google account.

To stop sharing progress or scores with Play Games:

1. In the app, open **MORE → SETTINGS** (Play Games) and stop using cloud/boards; you can also revoke access in Google Account.
2. On the web, open your [Google Account third-party apps](https://myaccount.google.com/permissions) and remove Idle Party / Play Games access.
3. You can also delete Play Games activity from your Google Account.

To limit or stop Firebase Analytics / AdMob identifiers in the EU/EEA, use **SETTINGS → AD PRIVACY**, or clear app storage / uninstall. Google may retain aggregated analytics under their policies.

Local save on the device is removed when you clear the app’s storage or uninstall. Clipboard backups you made yourself stay on your device until you delete them.

## Children

The game is intended as a general-audience idle RPG. It does not collect personal information for profiles. Optional Play Games, optional rewarded ads (AdMob), and Firebase Analytics may process identifiers under Google’s policies when those features run. The game is not directed at children.

## Changes

If privacy practices change, this document will be updated and Play Data safety answers should be revised to match.

## Contact

Questions about this privacy policy or Idle Party data practices:
**cognifoxstudio@gmail.com** (Cognifox Studio).
