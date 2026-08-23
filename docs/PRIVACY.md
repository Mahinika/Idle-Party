# Idle Party — Privacy

Idle Party is a single-player idle RPG. This document describes how the app handles data and is suitable for Google Play Data safety disclosures.

## Summary

- **No Idle Party account.** You do not create a username/password with us.
- **Optional Google Play Games.** You may sign in with Play Games for seasonal leaderboards and cloud save. This is opt-in and not required to play.
- **Optional rewarded ads.** On the Android app you may choose to watch a short ad (hub **POWERUPS**) for a timed gold and attack boost. Ads do not play unless you start them. Ad serving uses Google AdMob.
- **No analytics servers.** The app does not send gameplay or device data to Idle Party (or third-party analytics) backends.
- **Local save by default.** Progress is stored on your device (e.g. SharedPreferences / platform equivalent).

## Data the app stores locally

Typical save data may include party progress, gear, gold/meta currency, settings, and related gameplay state. That stays on the device unless you choose to move it.

## Optional Play Games (leaderboards + cloud save)

If you sign in with **Google Play Games**:

- **Leaderboards:** the app may submit opt-in seasonal scores (best timed KEY + clear time, best Infinity Gauntlet floor for the calendar month) to Google’s leaderboard service.
- **Cloud save:** the app may upload a progress snapshot to Google Play Games **Saved Games** so you can restore after reinstall or on another device signed into the same Play Games profile.
- Google hosts that data under Play Games / your Google account. Idle Party does not run its own cloud save or leaderboard server.

You can keep using the game fully offline without signing in. Clipboard export/import remains available as a manual backup.

## Optional clipboard export / import

The app may let you **copy a save to the clipboard** or **paste a save from the clipboard** so you can back up or move progress. That is optional and user-initiated. Idle Party does not upload clipboard contents to a server.

## Network

Aside from normal OS / store behavior (install, updates) and optional Play Games calls when you opt in, Idle Party does not require an Idle Party account or Idle Party cloud service.

On **Google Play installs** (Android), the app may ask Google Play whether a newer Idle Party is available and show an in-app notice. That check goes to Google, not to an Idle Party server. Sideloaded APKs skip it.

On **Android**, if you tap hub **POWERUPS** and watch an ad, Google AdMob may load an ad over the network. That can include an advertising ID and a consent prompt (EU/EEA). Skipping POWERUPS means those ad calls are not started by you. Web playtest builds do not show real ads.

## Optional rewarded ads (Android)

Hub **POWERUPS** is opt-in:

- You choose when to watch. Combat is never interrupted by an ad.
- One finished ad grants 3 hours of double gold and +25% attack. Further ads add more time (capped).
- Google AdMob serves the ad. Idle Party does not run its own ad server.
- In the EU/EEA, a Google consent form (UMP) may appear before ads can be requested.
- You can change or withdraw that consent later in **SETTINGS → AD PRIVACY** (Android).

## Delete your data / sign-out

Idle Party does not create its own username or password. Optional Play Games sign-in uses your Google account.

To stop sharing progress or scores with Play Games:

1. In the app, open **META → SETTINGS** (Play Games) and stop using cloud/boards; you can also revoke access in Google Account.
2. On the web, open your [Google Account third-party apps](https://myaccount.google.com/permissions) and remove Idle Party / Play Games access.
3. You can also delete Play Games activity from your Google Account.

Local save on the device is removed when you clear the app’s storage or uninstall. Clipboard backups you made yourself stay on your device until you delete them.

## Children

The game is intended as a general-audience idle RPG. It does not collect personal information for profiles. Optional Play Games and optional rewarded ads (AdMob) may process identifiers under Google’s policies when you use those features. The game is not directed at children.

## Changes

If privacy practices change, this document will be updated and Play Data safety answers should be revised to match.
