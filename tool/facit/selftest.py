"""Prove each new facit check can fail, using in-memory pictures."""
from __future__ import annotations

from PIL import Image

from facit.armor import signature_problems, surface_stats
from facit.checks_v1 import face_cutout_ok
from facit.hands import proportion_key
from facit.style import authored_problems
from facit.unique import pair_problem
from gear_style import paint_material, style_lock


def _blob(color: tuple[int, int, int], box: tuple[int, int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    px = im.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = (*color, 255)
    return im


def _expect(label: str, ok: bool, errors: list[str]) -> None:
    if ok:
        return
    errors.append(label)


def run() -> int:
    errors: list[str] = []

    base = _blob((180, 180, 190), (40, 40, 90, 100))
    hue = _blob((80, 80, 180), (40, 40, 90, 100))
    _expect("unique hue-copy", pair_problem(base, hue) == "same-squint", errors)
    _expect("unique identical", pair_problem(base, base.copy()) == "same-bytes", errors)
    different = base.copy()
    px = different.load()
    for y in range(20, 50):
        for x in range(20, 55):
            px[x, y] = (180, 180, 190, 255)
    _expect("unique distinct passes", pair_problem(base, different) is None, errors)

    _expect("proportion huge shield", proportion_key("shield", 90, 40) == "too-long", errors)
    _expect("proportion ok sword", proportion_key("sword", 70, 40) is None, errors)

    flat = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    fp = flat.load()
    for y in range(30, 80):
        for x in range(30, 80):
            fp[x, y] = (0, 0, 0, 255) if x in (30, 79) or y in (30, 79) else (40, 40, 40, 255)
    keys = set(authored_problems(flat, "plate"))
    _expect("style black outline", "black-outline" in keys, errors)

    locked = style_lock(_blob((140, 140, 150), (36, 36, 96, 100)), "plate")
    _expect(
        "style_lock passes",
        not authored_problems(locked, "plate"),
        errors,
    )

    plate = paint_material(_blob((1, 1, 1), (20, 30, 110, 90)), "plate")
    mail = paint_material(_blob((1, 1, 1), (20, 30, 110, 90)), "mail")
    leather = paint_material(_blob((1, 1, 1), (20, 30, 110, 90)), "leather")
    cloth = paint_material(_blob((1, 1, 1), (20, 30, 110, 90)), "cloth")
    _expect("plate signature", not signature_problems("plate", surface_stats(plate)), errors)
    _expect("mail signature", not signature_problems("mail", surface_stats(mail)), errors)
    _expect("leather signature", not signature_problems("leather", surface_stats(leather)), errors)
    _expect("cloth signature", not signature_problems("cloth", surface_stats(cloth)), errors)
    _expect(
        "mail recolor of plate fails",
        "mail-dither" in signature_problems("mail", surface_stats(plate)),
        errors,
    )

    solid = _blob((90, 90, 100), (40, 10, 90, 55))
    _expect("helm without window", face_cutout_ok(solid, "warrior") is False, errors)
    window = solid.copy()
    wp = window.load()
    for y in range(28, 48):
        for x in range(52, 78):
            wp[x, y] = (0, 0, 0, 0)
    _expect("helm window passes", face_cutout_ok(window, "warrior") is True, errors)

    same = _blob((10, 10, 10), (0, 0, 8, 8))
    _expect("boots icon equals legs", same.tobytes() == same.copy().tobytes(), errors)

    if errors:
        for label in errors:
            print("SELFTEST FAIL", label)
        return 1
    print("selftest ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
