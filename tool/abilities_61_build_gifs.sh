#!/usr/bin/env bash
# Build per-ability GIFs and a top-12 montage from RENDER_ABILITIES_61 frame PNGs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANIM="$ROOT/docs/design/abilities-61/rendered/anim"
FPS=10

if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg required" >&2
  exit 1
fi

for dir in "$ANIM"/*/; do
  [[ -d "$dir" ]] || continue
  id="$(basename "$dir")"
  if ! compgen -G "$dir/f*.png" >/dev/null; then
    continue
  fi
  palette="$dir/palette.png"
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$dir/f%d.png" -vf "scale=128:128:flags=neighbor,palettegen=stats_mode=diff" "$palette"
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$dir/f%d.png" -i "$palette" -lavfi "scale=128:128:flags=neighbor[x];[x][1:v]paletteuse=dither=bayer" "$ANIM/${id}.gif"
done

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
echo "GIF build done under $ANIM"