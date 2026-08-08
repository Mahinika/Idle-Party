# Idle Party — Privacy

Idle Party is a single-player idle RPG. This document describes how the app handles data and is suitable for Google Play Data safety disclosures.

## Summary

- **No accounts.** You do not sign in.
- **No ads.** The app does not show advertising.
- **No analytics servers.** The app does not send gameplay or device data to Idle Party (or third-party analytics) backends.
- **Local save only.** Progress is stored on your device (e.g. SharedPreferences / platform equivalent).

## Data the app stores locally

Typical save data may include party progress, gear, gold/meta currency, settings, and related gameplay state. This stays on the device unless you choose to move it yourself.

## Optional clipboard export / import

The app may let you **copy a save to the clipboard** or **paste a save from the clipboard** so you can back up or move progress. That is optional and user-initiated. Idle Party does not upload clipboard contents to a server.

## Network

Aside from normal OS / store behavior (install, updates), Idle Party does not require an Idle Party account or cloud save service. If a build uses platform features that contact Google or the device OS, that is outside Idle Party’s own servers.

## Children

The game is intended as a general-audience idle RPG. It does not collect personal information for profiles or ads.

## Changes

If privacy practices change (for example cloud sync), this document will be updated and Play Data safety answers should be revised to match.
