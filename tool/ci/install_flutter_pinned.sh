#!/usr/bin/env bash
# Install the Flutter version pinned in .flutter-version, then
# flutter pub get. Idempotent. Used by Cursor Cloud Agent Builds
# (.cursor/environment.json). Safe to re-run.
set -euo pipefail

# Do not inherit a caller git dir; this script clones Flutter and runs
# from the Idle Party repo root.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR || true

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

pin="$(tr -d '[:space:]' < .flutter-version)"
if [[ -z "$pin" ]]; then
  echo "Could not read Flutter pin from .flutter-version" >&2
  exit 1
fi

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

# Fresh checkouts print "Building flutter tool..." before the version
# line. Match the version line, not the first line of stdout.
flutter_version() {
  local bin="$1"
  "$bin" --version | awk '/^Flutter / { print $2; exit }'
}

on_path_ok() {
  command -v flutter >/dev/null 2>&1 || return 1
  [[ "$(flutter_version flutter)" == "$pin" ]]
}

sdk_ok() {
  [[ -x "$1/bin/flutter" ]] || return 1
  [[ "$(flutter_version "$1/bin/flutter")" == "$pin" ]]
}

persist_path() {
  local home="$1"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$home/bin/flutter" "$HOME/.local/bin/flutter"
  ln -sfn "$home/bin/dart" "$HOME/.local/bin/dart"
  local line="export PATH=\"$home/bin:\$PATH\""
  local rc
  for rc in "$HOME/.profile" "$HOME/.bashrc"; do
    if [[ -f "$rc" ]] && grep -Fqs "$home/bin" "$rc"; then
      continue
    fi
    printf '\n# Idle Party pinned Flutter (cloud agent install)\n%s\n' "$line" >> "$rc"
  done
}

install_sdk() {
  if sdk_ok "$FLUTTER_HOME"; then
    return 0
  fi
  local dest="$FLUTTER_HOME"
  if [[ -e "$dest" ]] && ! sdk_ok "$dest"; then
    dest="$HOME/flutter-$pin"
  fi
  if ! sdk_ok "$dest"; then
    if [[ -d "$dest/.git" ]]; then
      git -C "$dest" fetch --depth 1 origin "refs/tags/$pin:refs/tags/$pin"
      git -C "$dest" checkout --force "$pin"
    else
      mkdir -p "$(dirname "$dest")"
      rm -rf "$dest"
      git clone --depth 1 --branch "$pin" https://github.com/flutter/flutter.git "$dest"
    fi
  fi
  if ! sdk_ok "$dest"; then
    echo "Flutter $pin is not available at $dest" >&2
    exit 1
  fi
  FLUTTER_HOME="$dest"
}

if on_path_ok; then
  FLUTTER_HOME="$(cd "$(dirname "$(command -v flutter)")/.." && pwd)"
  echo "Flutter $pin already on PATH: $(command -v flutter)"
elif sdk_ok "$FLUTTER_HOME"; then
  export PATH="$FLUTTER_HOME/bin:$PATH"
  echo "Flutter $pin already at $FLUTTER_HOME"
else
  install_sdk
  export PATH="$FLUTTER_HOME/bin:$PATH"
  echo "Installed Flutter $pin at $FLUTTER_HOME"
fi

persist_path "$FLUTTER_HOME"
flutter --version
flutter config --no-analytics >/dev/null

pub_stamp="$root/.dart_tool/ci_pubget.stamp"
pub_lock="$root/pubspec.lock"
if [[ -f "$pub_stamp" && -f "$pub_lock" ]] &&
  cmp -s "$pub_lock" "$pub_stamp"; then
  echo "flutter pub get skipped (pubspec.lock unchanged)"
else
  flutter pub get
  cp -f "$pub_lock" "$pub_stamp"
fi

echo "Flutter $pin ready."
