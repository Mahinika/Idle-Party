#!/usr/bin/env bash
# CI helper: ensure com.idleparty.app.test exists in Firebase and merge google-services.json.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PROJECT=idle-party-4a2e9
TEST_PKG=com.idleparty.app.test
FB="npx --yes firebase-tools@14.2.0"

if [ -z "${FIREBASE_TOKEN:-}" ]; then
  echo "FIREBASE_TOKEN unset; skip Firebase sync."
  exit 0
fi

$FB apps:create ANDROID "$TEST_PKG" \
  --project "$PROJECT" \
  --display-name "Idle Party Test" \
  --non-interactive 2>/dev/null || true

TEST_APP_ID="$(
  $FB apps:list --project "$PROJECT" --json \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
apps = data.get('result') or data
for app in apps:
    if app.get('platform') == 'ANDROID' and app.get('namespace') == '${TEST_PKG}':
        print(app.get('appId', ''))
        break
"
)"

if [ -z "$TEST_APP_ID" ]; then
  echo "Could not find Firebase Android app for ${TEST_PKG}." >&2
  exit 1
fi

TMP="$(mktemp)"
$FB apps:sdkconfig ANDROID "$TEST_APP_ID" --project "$PROJECT" --out "$TMP"
python3 tool/ci/merge_firebase_android_clients.py android/app/google-services.json "$TMP"
rm -f "$TMP"
python3 tool/ci/ensure_google_services_test_apk.py
