#!/usr/bin/env bash
# Pre-install Flutter's pinned NDK before Gradle runs sdkmanager (CI zip flakes).
set -euo pipefail

NDK_VERSION="${1:-28.2.13676358}"
NDK_PKG="ndk;${NDK_VERSION}"
NDK_ZIP_URL="https://dl.google.com/android/repository/android-ndk-r28c-linux.zip"

android_home="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
export ANDROID_HOME="$android_home"
export ANDROID_SDK_ROOT="$android_home"

ndk_dir="${android_home}/ndk/${NDK_VERSION}"

ndk_ready() {
  [[ -d "$ndk_dir" && -f "$ndk_dir/source.properties" ]]
}

if ndk_ready; then
  echo "NDK ${NDK_VERSION} already present at ${ndk_dir}"
  exit 0
fi

install_from_google_zip() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  local zip="${tmp}/android-ndk.zip"
  echo "Downloading NDK zip from ${NDK_ZIP_URL}..."
  if ! curl -fSL --retry 5 --retry-delay 15 --retry-all-errors \
    -o "$zip" "$NDK_ZIP_URL"; then
    echo "curl download failed." >&2
    return 1
  fi
  mkdir -p "$ndk_dir"
  unzip -q "$zip" -d "$tmp/extract"
  local extracted="${tmp}/extract/android-ndk-r28c"
  if [[ ! -d "$extracted" ]]; then
    echo "Unexpected NDK zip layout (no android-ndk-r28c/)." >&2
    return 1
  fi
  rm -rf "$ndk_dir"
  mkdir -p "$(dirname "$ndk_dir")"
  mv "$extracted" "$ndk_dir"
  ndk_ready
}

install_via_sdkmanager() {
  local sdkmanager=""
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
    return 1
  fi
  echo "Using sdkmanager: ${sdkmanager}"
  set +o pipefail
  yes | "$sdkmanager" --licenses >/dev/null 2>&1 || true
  for attempt in 1 2 3; do
    echo "sdkmanager ${NDK_PKG} (attempt ${attempt}/3)..."
    rm -rf "$ndk_dir" "${android_home}/.temp/PackageOperation" 2>/dev/null || true
    yes | "$sdkmanager" --install "${NDK_PKG}" || true
    if ndk_ready; then
      set -o pipefail
      return 0
    fi
    sleep $((attempt * 20))
  done
  set -o pipefail
  return 1
}

if install_from_google_zip; then
  echo "NDK ${NDK_VERSION} installed from Google zip."
  exit 0
fi

echo "Zip install failed; falling back to sdkmanager..." >&2
rm -rf "$ndk_dir" 2>/dev/null || true
if install_via_sdkmanager && ndk_ready; then
  echo "NDK ${NDK_VERSION} installed via sdkmanager."
  exit 0
fi

echo "Failed to install NDK ${NDK_VERSION}." >&2
exit 1
