#!/usr/bin/env bash
# One-time owner setup: register com.idleparty.app.test and refresh google-services.json.
set -euo pipefail
cd "$(dirname "$0")/../.."
PROJECT=idle-party-4a2e9
TEST_PKG=com.idleparty.app.test

if ! command -v firebase >/dev/null 2>&1; then
  echo "Install Firebase CLI: npx --yes firebase-tools@14.2.0"
  exit 1
fi

firebase login
firebase apps:create ANDROID "$TEST_PKG" \
  --project "$PROJECT" \
  --display-name "Idle Party Test" \
  --non-interactive 2>/dev/null || true

TEST_APP_ID="$(
  firebase apps:list --project "$PROJECT" --json \
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
firebase apps:sdkconfig ANDROID "$TEST_APP_ID" --project "$PROJECT" --out "$TMP"
python3 tool/ci/merge_firebase_android_clients.py android/app/google-services.json "$TMP"
rm -f "$TMP"
python3 tool/ci/ensure_google_services_test_apk.py
echo "Commit android/app/google-services.json when both package names are listed."
