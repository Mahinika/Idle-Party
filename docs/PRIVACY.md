# Idle Party — Privacy

Idle Party is a single-player idle RPG. This document describes how the app handles data and is suitable for Google Play Data safety disclosures.

## Summary

- **No Idle Party account.** You do not create a username/password with us.
- **Optional Google Play Games.** You may sign in with Play Games for seasonal leaderboards and cloud save. This is opt-in and not required to play.
- **No ads.** The app does not show advertising.
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

## Children

The game is intended as a general-audience idle RPG. It does not collect personal information for profiles or ads beyond what Google Play Games may process when you opt in.

## Changes

If privacy practices change, this document will be updated and Play Data safety answers should be revised to match.
