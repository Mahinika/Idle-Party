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

firebase apps:sdkconfig ANDROID \
  --project "$PROJECT" \
  --out android/app/google-services.json

python3 tool/ci/ensure_google_services_test_apk.py
echo "Commit android/app/google-services.json when both package names are listed."
