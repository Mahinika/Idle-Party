#!/usr/bin/env bash
# Build per-ability GIFs and a top-12 montage from horizontal strip PNGs (6×128px).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANIM="$ROOT/docs/design/abilities-61/rendered/anim"
FPS=10
TMP="$ANIM/_gif_tmp"
mkdir -p "$TMP"

if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg required" >&2
  exit 1
fi

for strip in "$ANIM"/*_strip.png; do
  [[ -f "$strip" ]] || continue
  id="$(basename "$strip" "_strip.png")"
  work="$TMP/$id"
  rm -rf "$work"
  mkdir -p "$work"
  for i in 0 1 2 3 4 5; do
    x=$((i * 128))
    ffmpeg -y -loglevel error -i "$strip" -vf "crop=128:128:${x}:0" "$work/f${i}.png"
  done
  palette="$work/palette.png"
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$work/f%d.png" -vf "scale=128:128:flags=neighbor,palettegen=stats_mode=diff" "$palette"
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$work/f%d.png" -i "$palette" -lavfi "scale=128:128:flags=neighbor[x];[x][1:v]paletteuse=dither=bayer" "$ANIM/${id}.gif"
  rm -rf "$work"
done
rmdir "$TMP" 2>/dev/null || true

TOP12=(
  meteor holyFire arcaneBarrage frozenOrb summonInfernal stampede
  secretTechnique crashLightning powerWordBarrier darkTransformation starsurge wildfireBomb
)
MONTAGE="$ANIM/top12_montage.gif"
LIST="$ANIM/_montage_list.txt"
: >"$LIST"
for id in "${TOP12[@]}"; do
  gif="$ANIM/${id}.gif"
  if [[ -f "$gif" ]]; then
    echo "file '$gif'" >>"$LIST"
  fi
done
if [[ -s "$LIST" ]]; then
  ffmpeg -y -loglevel error -f concat -safe 0 -i "$LIST" -vf "fps=$FPS,scale=384:-1:flags=neighbor,tile=3x4" "$MONTAGE"
fi
rm -f "$LIST"
echo "GIF build done under $ANIM"