#!/usr/bin/env bash
# Delete GitHub test-* prereleases and tags older than MAX_AGE_DAYS. Never v* or Play releases.
set -euo pipefail

MAX_AGE_DAYS="${MAX_AGE_DAYS:-14}"
CUTOFF_EPOCH=$(date -u -d "-${MAX_AGE_DAYS} days" +%s 2>/dev/null || date -u -v-"${MAX_AGE_DAYS}d" +%s)

echo "Cutoff: releases created before epoch $CUTOFF_EPOCH (${MAX_AGE_DAYS} days ago)"

mapfile -t rows < <(gh release list --limit 200 --json tagName,isPrerelease,createdAt \
  | jq -r '.[] | select(.isPrerelease == true) | [.tagName, .createdAt] | @tsv')

deleted=0
for row in "${rows[@]:-}"; do
  [ -z "$row" ] && continue
  tag="${row%%$'\t'*}"
  created="${row#*$'\t'}"
  case "$tag" in
    test-*) ;;
    *) continue ;;
  esac
  case "$tag" in
    v*) echo "Skip (looks like version tag): $tag"; continue ;;
  esac
  created_epoch=$(date -u -d "$created" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +%s)
  if [ "$created_epoch" -ge "$CUTOFF_EPOCH" ]; then
    continue
  fi
  echo "Deleting prerelease and tag: $tag (created $created)"
  gh release delete "$tag" --yes --cleanup-tag
  deleted=$((deleted + 1))
done

echo "Deleted $deleted old test-* prerelease(s)."