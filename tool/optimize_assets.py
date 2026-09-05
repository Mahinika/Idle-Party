"""Shrink shipped PNGs to the size the game actually paints them.

The app decodes art far smaller than it stores it: painted scenes come through
`CaveAtmosphere` at `cacheWidth: 960`, enemy sprites through
`DecodedImageCache` at `targetWidth: 128`, and hub portraits show as ~32 px
discs. Everything above those caps is download weight the player never sees.

Usage (dry run is the default — nothing is written without --apply):

    py -3 tool/optimize_assets.py
    py -3 tool/optimize_assets.py --apply
    py -3 tool/optimize_assets.py --apply --only backdrops

Rules per group live in RULES below. The World Path map keeps its resolution
(it is drawn ~336 logical px wide on a DPR-3 phone, so 1024 px is right); only
its palette is reduced.
"""

from __future__ import annotations

import argparse
import io
import os
from dataclasses import dataclass

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))


@dataclass(frozen=True)
class Rule:
    name: str
    folder: str
    max_side: int | None
    colors: int | None
    files: tuple[str, ...] = ()

    def targets(self) -> list[str]:
        base = os.path.join(ROOT, self.folder)
        if self.files:
            return [os.path.join(base, f) for f in self.files]
        if not os.path.isdir(base):
            return []
        return [
            os.path.join(base, f)
            for f in sorted(os.listdir(base))
            if f.lower().endswith('.png')
        ]


RULES: tuple[Rule, ...] = (
    # Painted scenes: CaveAtmosphere decodes at 960 — anything above is thrown
    # away at runtime.
    Rule('backdrops', 'assets/custom/ui/backdrops', max_side=960, colors=256),
    Rule(
        'scenes',
        'assets/custom/ui',
        max_side=960,
        colors=256,
        files=('dungeon_backdrop.png',),
    ),
    # Portrait scenes are 720x1080 and already decode below the 960 cap on the
    # long side — resizing would only cost sharpness, so palette only.
    Rule(
        'portrait_scenes',
        'assets/custom/ui',
        max_side=None,
        colors=256,
        files=('hub_scene.png', 'intro_scene.png'),
    ),
    # Hub map: keep the pixels, drop the palette.
    Rule(
        'map',
        'assets/custom/ui',
        max_side=None,
        colors=256,
        files=('world_path_map.png',),
    ),
    # Hub zone portraits render as ~32 px discs.
    Rule('portraits', 'assets/custom/portraits', max_side=256, colors=None),
    # Stage sprites decode at targetWidth 128.
    Rule('enemies', 'assets/custom/enemies', max_side=256, colors=None),
    Rule('pets', 'assets/custom/pets', max_side=256, colors=None),
    Rule('heroes', 'assets/custom/heroes', max_side=256, colors=None),
)


def optimize(path: str, rule: Rule) -> bytes:
    im = Image.open(path)
    im.load()
    has_alpha = im.mode in ('RGBA', 'LA') or (
        im.mode == 'P' and 'transparency' in im.info
    )
    im = im.convert('RGBA' if has_alpha else 'RGB')

    if rule.max_side:
        w, h = im.size
        if max(w, h) > rule.max_side:
            scale = rule.max_side / max(w, h)
            im = im.resize(
                (max(1, round(w * scale)), max(1, round(h * scale))),
                Image.LANCZOS,
            )

    out = im
    if rule.colors:
        if has_alpha:
            # FASTOCTREE is the only Pillow quantizer that keeps alpha.
            out = im.quantize(colors=rule.colors, method=Image.Quantize.FASTOCTREE)
        else:
            # Dithered adaptive palette — hides banding in painted gradients.
            out = im.convert('P', palette=Image.Palette.ADAPTIVE, colors=rule.colors)

    buf = io.BytesIO()
    out.save(buf, format='PNG', optimize=True)
    data = buf.getvalue()

    if rule.colors:
        plain = io.BytesIO()
        im.save(plain, format='PNG', optimize=True)
        # Only accept the palette version when it actually pays for itself.
        if len(plain.getvalue()) < len(data) * 1.15:
            data = plain.getvalue()
    return data


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='write the files')
    ap.add_argument('--only', default=None, help='run a single rule by name')
    args = ap.parse_args()

    total_before = 0
    total_after = 0
    for rule in RULES:
        if args.only and rule.name != args.only:
            continue
        print(f'\n== {rule.name} ({rule.folder}) ==')
        for path in rule.targets():
            if not os.path.isfile(path):
                print(f'  MISSING {os.path.basename(path)}')
                continue
            before = os.path.getsize(path)
            with Image.open(path) as probe:
                before_size = probe.size
            data = optimize(path, rule)
            after = len(data)
            total_before += before
            total_after += min(after, before)
            if after >= before:
                print(
                    f'  keep    {os.path.basename(path):<28} '
                    f'{before / 1024:8.0f} KB (already lean)'
                )
                continue
            with Image.open(io.BytesIO(data)) as probe:
                after_size = probe.size
            print(
                f'  shrink  {os.path.basename(path):<28} '
                f'{before / 1024:8.0f} KB -> {after / 1024:7.0f} KB   '
                f'{before_size[0]}x{before_size[1]} -> '
                f'{after_size[0]}x{after_size[1]}'
            )
            if args.apply:
                with open(path, 'wb') as fh:
                    fh.write(data)

    print(
        f'\nTotal {total_before / 1024 / 1024:.2f} MB -> '
        f'{total_after / 1024 / 1024:.2f} MB'
        + ('' if args.apply else '   (dry run — pass --apply to write)')
    )


if __name__ == '__main__':
    main()
