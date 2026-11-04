#!/usr/bin/env bash
# Pre-install Flutter's pinned NDK before Gradle runs sdkmanager (CI zip flakes).
set -euo pipefail

NDK_VERSION="${1:-28.2.13676358}"
NDK_PKG="ndk;${NDK_VERSION}"

android_home="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
export ANDROID_HOME="$android_home"
export ANDROID_SDK_ROOT="$android_home"

ndk_dir="${android_home}/ndk/${NDK_VERSION}"
if [[ -d "$ndk_dir" && -f "$ndk_dir/source.properties" ]]; then
  echo "NDK ${NDK_VERSION} already present at ${ndk_dir}"
  exit 0
fi

sdkmanager=""
for candidate in \
  "${android_home}/cmdline-tools/latest/bin/sdkmanager" \
  "${android_home}/cmdline-tools/bin/sdkmanager" \
  "${android_home}/tools/bin/sdkmanager"; do
  if [[ -x "$candidate" ]]; then
    sdkmanager="$candidate"
    break
  fi
done

if [[ -z "$sdkmanager" ]]; then
  echo "sdkmanager not found under ${android_home}" >&2
  exit 1
fi

echo "Using sdkmanager: ${sdkmanager}"
yes | "$sdkmanager" --licenses >/dev/null 2>&1 || true

for attempt in 1 2 3 4; do
  echo "Installing ${NDK_PKG} (attempt ${attempt}/4)..."
  rm -rf "${android_home}/.temp/PackageOperation" 2>/dev/null || true
  if yes | "$sdkmanager" --install "${NDK_PKG}"; then
    if [[ -d "$ndk_dir" ]]; then
      echo "NDK ${NDK_VERSION} installed."
      exit 0
    fi
  fi
  rm -rf "$ndk_dir" 2>/dev/null || true
  sleep $((attempt * 20))
done

echo "Failed to install ${NDK_PKG} after 4 attempts." >&2
exit 1
