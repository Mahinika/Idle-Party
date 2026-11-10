---
name: env-check
description: >-
  Checks this repo's Flutter, Dart, and package lock without installing
  them again. Use when analyze cannot start, on a new machine, or when
  the owner says "miljön" or "flutter saknas". Do not use for the test
  suite (flutter-verify) or an APK.
---

# Environment check

Diagnosis and provisioning are different. Run the diagnosis first. It
does not install Flutter, the Android SDK, or the NDK, and it does not
build an APK.

## Procedure

1. From the repo root, run `dart run tool/env_check.dart`.
2. Read the bounds from `pubspec.yaml` `environment.sdk` and from the
   `sdks:` block in `pubspec.lock`. Do not type a version from memory.
   Dart must sit inside both bounds. Flutter must sit inside the lock bound.
3. `source: ready` also means `.dart_tool/package_config.json` names this
   package and is not older than `pubspec.yaml` or `pubspec.lock`.
   Three working binaries are not enough.
4. The command prints versions and the words missing, satisfies, or
   ready. It does not print paths, `local.properties`, keystores, or
   service-account JSON.
5. Java below 17 is reported. Missing Java does not fail `flutter test`.

## Setup, only when the diagnosis says something is missing

`dart run tool/env_check.dart --setup` runs `flutter pub get` only when
the package config is stale, and writes `flutter.sdk` into the
gitignored `android/local.properties` only when that line is missing or
its directory is gone. It does not upgrade Flutter, pin a new SDK, or
call `tool/ci/install_ndk_ci.sh`.

A cloud image that already has Flutter is provisioned once, outside this
skill. Do not reinstall it on every session.

## Done when

- The diagnosis says `source: ready`, or the missing tool is named and
  left for the owner.
- No APK, emulator, or SDK reinstall was started.
