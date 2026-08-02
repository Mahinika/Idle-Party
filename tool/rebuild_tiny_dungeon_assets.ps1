# Rebuild Tiny Dungeon game assets from Kenney originals (tile_XXXX).
# Semantic names live in lib/ui/kenney_assets.dart — files stay as tile IDs.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root "2D assets\Tiny Dungeon\Tiles"
$dst = Join-Path $root "assets\kenney\tiny_dungeon"
$extras = Join-Path $root "assets\kenney\extras"

if (-not (Test-Path $src)) { throw "Missing Tiny Dungeon source: $src" }

New-Item -ItemType Directory -Force -Path $dst | Out-Null
New-Item -ItemType Directory -Force -Path $extras | Out-Null

# Preserve non-Tiny extras currently in tiny_dungeon (wrong pack / UI loot).
foreach ($name in @('book.png', 'coin_gold.png', 'ring.png')) {
  $p = Join-Path $dst $name
  if (Test-Path $p) {
    Copy-Item $p (Join-Path $extras $name) -Force
  }
}

# Remove old semantic copies (keep only tile_*.png going forward).
Get-ChildItem $dst -File | Where-Object { $_.Name -notmatch '^tile_\d{4}\.png$' } | Remove-Item -Force

# Copy all 132 originals.
for ($i = 0; $i -lt 132; $i++) {
  $name = "tile_{0:D4}.png" -f $i
  Copy-Item (Join-Path $src $name) (Join-Path $dst $name) -Force
}

Write-Host "Rebuilt $dst with 132 tile_XXXX.png files"
Write-Host "Extras in $extras : $((Get-ChildItem $extras -File).Name -join ', ')"
