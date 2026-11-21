#!/usr/bin/env bash
# Emulator smoke for com.idleparty.app.test only. Never touch com.idleparty.app.
set -euo pipefail

PKG=com.idleparty.app.test
ACTIVITY="${PKG}/com.idleparty.app.MainActivity"
APK="${1:?usage: emulator_smoke.sh path/to.apk}"
OUT_DIR="${2:-emulator-smoke-out}"
mkdir -p "$OUT_DIR"

if adb shell pm list packages 2>/dev/null | grep -q '^package:com\.idleparty\.app$'; then
  echo "Play package com.idleparty.app must not be on the emulator." >&2
  exit 1
fi

adb logcat -c
adb logcat -v time >"$OUT_DIR/logcat.txt" &
LOGCAT_PID=$!
cleanup() {
  kill "$LOGCAT_PID" 2>/dev/null || true
}
trap cleanup EXIT

adb uninstall "$PKG" 2>/dev/null || true
adb install -r "$APK"

LAUNCH_MS=()
for i in 1 2 3; do
  adb shell am force-stop "$PKG"
  sleep 1
  raw=$(adb shell am start -W -n "$ACTIVITY" 2>&1 || true)
  ms=$(echo "$raw" | awk '/TotalTime:/ {print $2; exit}')
  ms=${ms:-0}
  LAUNCH_MS+=("$ms")
  echo "Cold start $i: ${ms} ms"
  sleep 2
done

sleep 14
adb exec-out screencap -p >"$OUT_DIR/screenshot-after-20s.png"

fail=0
if grep -E "FATAL EXCEPTION|AndroidRuntime.*FATAL" "$OUT_DIR/logcat.txt" | grep -q "$PKG"; then
  echo "FATAL EXCEPTION for $PKG in logcat." >&2
  fail=1
fi
if grep -qE "ANR in $PKG|am_anr.*$PKG" "$OUT_DIR/logcat.txt"; then
  echo "ANR for $PKG in logcat." >&2
  fail=1
fi

{
  echo "## Emulator smoke (com.idleparty.app.test)"
  echo ""
  echo "| Cold start | TotalTime (ms) |"
  echo "|------------|----------------|"
  for i in 0 1 2; do
    echo "| $((i + 1)) | ${LAUNCH_MS[$i]} |"
  done
  echo ""
  echo "APK: $(basename "$APK")"
  if [ "$fail" -ne 0 ]; then
    echo ""
    echo "**Result: failed** (FATAL or ANR)"
  else
    echo ""
    echo "**Result: passed**"
  fi
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"

exit "$fail"