"""Download CC0 audio, master it for a phone speaker, and write Idle Party files.

Raw zips stay in tool/out/audio_src (gitignored). Only the OGG files under
assets/custom/audio/ are shipped. Every shipped file is listed in
assets/custom/audio/ATTRIBUTION.md from this script, so the note cannot drift.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tool" / "out" / "audio_src"
SFX = ROOT / "assets" / "custom" / "audio" / "sfx"
MUSIC = ROOT / "assets" / "custom" / "audio" / "music"
NOTE = ROOT / "assets" / "custom" / "audio" / "ATTRIBUTION.md"
MANIFEST = Path(__file__).resolve().parent / "manifest.json"

UA = {"User-Agent": "IdlePartyAudio/1.0"}

# Pages opened and checked for a CC0 license name before use.
PACKS = {
    "rubberduck.zip": "https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip",
    "tinysized.zip": "https://opengameart.org/sites/default/files/tinysized.zip",
    "weapons.zip": "https://opengameart.org/sites/default/files/weapons-apparel.zip",
    "artisticdude.zip": "https://opengameart.org/sites/default/files/rpg_sound_pack.zip",
    "town_theme.mp3": "https://opengameart.org/sites/default/files/TownTheme.mp3",
    "mystical_town.ogg": "https://opengameart.org/sites/default/files/symphony%20-%20mystical%20town%2001_1.ogg",
    "dungeon002.ogg": "https://opengameart.org/sites/default/files/dungeon002_0.ogg",
    "whispers.ogg": "https://opengameart.org/sites/default/files/whispers_in_the_fog.ogg",
    "fairy_boss.ogg": "https://opengameart.org/sites/default/files/fairy_boss_battles_bpm185_0.ogg",
    "icy_realm.mp3": "https://opengameart.org/sites/default/files/019_seven_and_eight_7-8_combined_0.mp3",
    "cystally.zip": "https://opengameart.org/sites/default/files/crystallymusic.zip",
}

PHONE_SFX = "highpass=f=140,equalizer=f=4500:t=q:w=1.5:g=-2"
PHONE_MUSIC = "highpass=f=80,equalizer=f=4500:t=q:w=1.5:g=-2"
LETTERS = "abcdefghijklmnopqrstuvwxyz"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def download() -> dict[str, str]:
    SRC.mkdir(parents=True, exist_ok=True)
    sums: dict[str, str] = {}
    for name, url in PACKS.items():
        dest = SRC / name
        if not dest.exists() or dest.stat().st_size < 1000:
            print("get", name)
            req = urllib.request.Request(url, headers=UA)
            dest.write_bytes(urllib.request.urlopen(req, timeout=180).read())
        sums[name] = sha256(dest)
        print(name, sums[name][:12], dest.stat().st_size)
        if dest.suffix == ".zip":
            out = SRC / dest.stem
            if not out.exists():
                out.mkdir()
                with zipfile.ZipFile(dest) as zf:
                    zf.extractall(out)
    return sums


def find(rel: str) -> Path:
    """Find a source file under a pack folder or the raw download dir."""
    direct = SRC / rel
    if direct.exists():
        return direct
    hits = [
        p
        for p in SRC.rglob(Path(rel).name)
        if "__MACOSX" not in p.parts and p.is_file()
    ]
    if not hits:
        raise FileNotFoundError(rel)
    hits.sort(key=lambda p: len(p.parts))
    return hits[0]


def render(
    src: Path,
    dest: Path,
    *,
    music: bool,
    max_s: float | None,
    extra_af: str = "",
) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    parts = [PHONE_MUSIC if music else PHONE_SFX]
    if extra_af:
        parts.append(extra_af)
    loud = "loudnorm=I=-16:TP=-1.5:LRA=11" if music else "loudnorm=I=-14:TP=-1.5:LRA=9"
    parts.append(loud)
    if max_s is not None:
        fade = min(0.06, max_s / 5)
        start = max(0.0, max_s - fade)
        parts.append(f"atrim=0:{max_s:.3f},afade=t=out:st={start:.3f}:d={fade:.3f}")
    af = ",".join(parts)
    quality = "2" if music else "5"
    channels = "2" if music else "1"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(src),
            "-af",
            af,
            "-ac",
            channels,
            "-ar",
            "44100",
            "-c:a",
            "libvorbis",
            "-q:a",
            quality,
            str(dest),
        ],
        check=True,
    )


def probe(path: Path) -> tuple[float, int]:
    dur = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "csv=p=0",
            str(path),
        ],
        text=True,
    ).strip()
    ch = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=channels",
            "-of",
            "csv=p=0",
            str(path),
        ],
        text=True,
    ).strip()
    return float(dur), int(ch)


def sfx_job(out_name: str, src_name: str, *, max_s: float, extra_af: str = "", metal: bool = False) -> dict:
    return {
        "out": SFX / out_name,
        "src": src_name,
        "max_s": 0.25 if metal else max_s,
        "extra_af": extra_af,
        "music": False,
        "metal": metal or max_s <= 0.25,
    }


def main() -> None:
    sums = download()
    cyst = find("cystally")  # folder or a file inside the zip
    cyst_ogg = next(
        (p for p in (SRC / "cystally").rglob("*.ogg") if "__MACOSX" not in p.parts),
        None,
    )
    if cyst_ogg is None:
        raise SystemExit(f"cystally ogg missing under {cyst}")

    rd = "rubberduck"
    tiny = "tinysized/sfx-cc0"
    weap = "weapons/sfx"
    ad = "artisticdude/RPG Sound Pack"

    jobs: list[dict] = []

    def add_many(stem: str, sources: list[str], *, max_s: float, extra_af: str = "", metal: bool = False) -> None:
        for i, src in enumerate(sources):
            jobs.append(
                sfx_job(
                    f"{stem}_{LETTERS[i]}.ogg",
                    src,
                    max_s=max_s,
                    extra_af=extra_af,
                    metal=metal,
                )
            )

    add_many(
        "hit_blade",
        [f"{weap}/sword-knife-clash-{i:02d}.wav" for i in range(1, 7)],
        max_s=0.25,
        metal=True,
    )
    add_many(
        "hit_axe",
        [
            f"{tiny}/metal-hammer-hit-01.wav",
            f"{tiny}/metal-hammer-hit-02.wav",
            f"{rd}/metal_01.ogg",
            f"{rd}/metal_02.ogg",
            f"{rd}/metal_03.ogg",
            f"{weap}/sword-thermos-hit-01.wav",
        ],
        max_s=0.25,
        metal=True,
    )
    add_many(
        "hit_blunt",
        [f"{tiny}/wood-bowl-spoon-0{i}.wav" for i in range(1, 5)]
        + [f"{rd}/stones_0{i}.ogg" for i in range(1, 3)],
        max_s=0.25,
    )
    add_many(
        "hit_dagger",
        [f"{tiny}/metal-knife-scrape-0{i}.wav" for i in range(1, 4)]
        + [f"{weap}/sword-knife-clash-{i:02d}.wav" for i in (8, 9, 10)],
        max_s=0.22,
        metal=True,
    )
    add_many(
        "hit_fist",
        [f"{tiny}/apple-cut-0{i}.wav" for i in range(1, 4)]
        + [
            f"{rd}/creature_hurt_01.ogg",
            f"{rd}/creature_hurt_02.ogg",
            f"{rd}/creature_slime_01.ogg",
        ],
        max_s=0.28,
    )
    add_many(
        "hit_bow",
        [
            f"{tiny}/wood-twigs-break-01.wav",
            f"{tiny}/wood-twigs-break-02.wav",
            f"{weap}/sword-thermos-hit-01.wav",
            f"{tiny}/apple-cut-02.wav",
        ],
        max_s=0.22,
    )
    add_many(
        "swish_melee",
        [
            f"{ad}/battle/swing.wav",
            f"{ad}/battle/swing2.wav",
            f"{ad}/battle/swing3.wav",
        ],
        max_s=0.45,
    )
    add_many(
        "swish_bow",
        [f"{weap}/arrow-feathers-0{i}.wav" for i in range(1, 4)],
        max_s=0.4,
    )
    add_many(
        "bow_release",
        [f"{weap}/arrow-grab-from-quiver-0{i}.wav" for i in range(1, 5)],
        max_s=0.45,
    )

    schools = {
        "fire": (
            [f"{rd}/spell_fire_0{i}.ogg" for i in range(1, 7)],
            "",
        ),
        "frost": (
            [
                f"{rd}/spell_01.ogg",
                f"{rd}/spell_02.ogg",
                f"{ad}/battle/spell.wav",
                f"{ad}/battle/magic1.wav",
                f"{tiny}/water-drop-01.wav",
                f"{tiny}/water-drop-02.wav",
            ],
            "asetrate=44100*1.30,aresample=44100,highpass=f=420",
        ),
        "holy": (
            [f"{rd}/spell_fire_0{i}.ogg" for i in range(1, 7)],
            "asetrate=44100*1.14,aresample=44100,equalizer=f=2800:t=q:w=1:g=3",
        ),
        "shadow": (
            [
                f"{rd}/spell_01.ogg",
                f"{rd}/spell_02.ogg",
                f"{ad}/battle/magic1.wav",
                f"{rd}/creature_misc_01.ogg",
                f"{rd}/creature_misc_02.ogg",
                f"{ad}/battle/spell.wav",
            ],
            "asetrate=44100*0.74,aresample=44100,lowpass=f=900",
        ),
        "arcane": (
            [
                f"{ad}/battle/spell.wav",
                f"{ad}/battle/magic1.wav",
                f"{rd}/spell_01.ogg",
                f"{rd}/spell_02.ogg",
                f"{rd}/spell_fire_07.ogg",
                f"{rd}/metal_01.ogg",
            ],
            "asetrate=44100*1.08,aresample=44100,highpass=f=280",
        ),
        "nature": (
            [
                f"{tiny}/wood-twigs-break-01.wav",
                f"{tiny}/wood-twigs-break-02.wav",
                f"{rd}/creature_slime_02.ogg",
                f"{rd}/spell_02.ogg",
                f"{tiny}/water-drop-03.wav",
                f"{rd}/creature_slime_03.ogg",
            ],
            "asetrate=44100*0.92,aresample=44100,lowpass=f=2200",
        ),
        "lightning": (
            [
                f"{tiny}/metal-knife-scrape-01.wav",
                f"{tiny}/metal-knife-scrape-02.wav",
                f"{rd}/metal_02.ogg",
                f"{tiny}/metal-hammer-hit-01.wav",
                f"{rd}/spell_fire_03.ogg",
                f"{rd}/metal_03.ogg",
            ],
            "highpass=f=700,asetrate=44100*1.2,aresample=44100",
        ),
        "demon": (
            [
                f"{rd}/creature_roar_01.ogg",
                f"{rd}/creature_roar_02.ogg",
                f"{rd}/creature_roar_03.ogg",
                f"{rd}/creature_monster_01.ogg",
                f"{rd}/creature_monster_02.ogg",
                f"{rd}/spell_01.ogg",
            ],
            "asetrate=44100*0.68,aresample=44100,lowpass=f=780",
        ),
        "poison": (
            [
                f"{rd}/creature_slime_01.ogg",
                f"{rd}/creature_slime_02.ogg",
                f"{rd}/creature_slime_03.ogg",
                f"{rd}/creature_slime_04.ogg",
                f"{tiny}/water-drop-01.wav",
                f"{tiny}/water-pour-01.wav",
            ],
            "asetrate=44100*0.86,aresample=44100,lowpass=f=1600",
        ),
    }
    for school, (sources, extra) in schools.items():
        add_many(f"spell_{school}", sources, max_s=0.7, extra_af=extra)
        add_many(f"cast_{school}", sources[:3], max_s=0.32, extra_af=extra)

    add_many(
        "enemy_hit",
        [
            f"{rd}/creature_hurt_01.ogg",
            f"{rd}/creature_hurt_02.ogg",
            f"{rd}/creature_monster_03.ogg",
        ],
        max_s=0.4,
    )
    add_many(
        "enemy_die_flesh",
        [
            f"{rd}/creature_die_01.ogg",
            f"{rd}/creature_slime_01.ogg",
            f"{rd}/creature_monster_04.ogg",
        ],
        max_s=0.7,
    )
    add_many(
        "enemy_die_bone",
        [f"{rd}/stones_0{i}.ogg" for i in range(1, 4)],
        max_s=0.35,
    )
    add_many(
        "enemy_die_stone",
        [f"{rd}/item_stone_0{i}.ogg" for i in range(1, 4)],
        max_s=0.35,
    )
    add_many(
        "crit",
        [f"{tiny}/sword-clash-0{i}.wav" for i in range(1, 5)],
        max_s=0.25,
        metal=True,
    )
    add_many(
        "kill",
        [
            f"{rd}/creature_die_01.ogg",
            f"{rd}/creature_roar_01.ogg",
            f"{rd}/creature_roar_02.ogg",
            f"{rd}/creature_monster_01.ogg",
        ],
        max_s=0.6,
    )
    jobs.append(sfx_job("mat_flesh.ogg", f"{tiny}/apple-cut-01.wav", max_s=0.2))
    jobs.append(sfx_job("mat_bone.ogg", f"{rd}/stones_04.ogg", max_s=0.22))
    jobs.append(sfx_job("mat_wet.ogg", f"{tiny}/water-drop-02.wav", max_s=0.28))
    jobs.append(sfx_job("mat_stone.ogg", f"{rd}/item_stone_04.ogg", max_s=0.22))
    jobs.append(sfx_job("gold.ogg", f"{rd}/item_coins_01.ogg", max_s=0.45))

    music_jobs = [
        ("hub_town.ogg", "town_theme.mp3", "Town Theme RPG", "https://opengameart.org/content/town-theme-rpg", "cynicmusic"),
        ("hub_mystical.ogg", "mystical_town.ogg", "Mystical RPG Maker Town Theme", "https://opengameart.org/content/mystical-rpg-maker-town-theme", "symphony"),
        ("dark_dungeon.ogg", "dungeon002.ogg", "Dungeon Ambience", "https://opengameart.org/content/dungeon-ambience", "yd"),
        ("dark_whispers.ogg", "whispers.ogg", "Whispers in the Fog", "https://opengameart.org/content/whispers-in-the-fog", "Ruhinre"),
        ("ice_realm.ogg", "icy_realm.mp3", "Icy Realm", "https://opengameart.org/content/icy-realm-seven-and-eight", "cynicmusic"),
        ("boss_fairy.ogg", "fairy_boss.ogg", "Fairy Boss Battles", "https://opengameart.org/content/fairy-boss-battles", "MintoDog"),
    ]

    print(f"rendering {len(jobs)} sfx")
    made: list[str] = []
    for job in jobs:
        dest: Path = job["out"]
        render(
            find(job["src"]),
            dest,
            music=False,
            max_s=job["max_s"],
            extra_af=job["extra_af"],
        )
        dur, ch = probe(dest)
        if ch != 1:
            raise SystemExit(f"{dest.name} is not mono ({ch})")
        if job["metal"] and dur > 0.27:
            raise SystemExit(f"{dest.name} metal tail {dur:.3f}s")
        made.append(dest.name)
        print(" ", dest.name, f"{dur:.2f}s")

    print("rendering music")
    music_rows = []
    for out_name, src_name, title, url, author in music_jobs:
        dest = MUSIC / out_name
        src = cyst_ogg if out_name == "ice_crystal.ogg" else find(src_name)
        render(src, dest, music=True, max_s=None)
        dur, ch = probe(dest)
        if ch != 2:
            raise SystemExit(f"{dest.name} music should stay stereo ({ch})")
        music_rows.append((out_name, title, url, author, dur))
        print(" ", out_name, f"{dur:.1f}s", dest.stat().st_size)

    # Second ice bed from the cystally zip (CC0, no credit required).
    ice_crystal = MUSIC / "ice_crystal.ogg"
    render(cyst_ogg, ice_crystal, music=True, max_s=None)
    dur, ch = probe(ice_crystal)
    music_rows.append(
        (
            "ice_crystal.ogg",
            "cystally music",
            "https://opengameart.org/content/cystally-music",
            "primbal",
            dur,
        )
    )
    print(" ice_crystal.ogg", f"{dur:.1f}s")

    write_note(music_rows)
    MANIFEST.write_text(
        json.dumps({"packs": sums, "sfx": made}, indent=2) + "\n",
        encoding="utf-8",
    )
    total = sum(p.stat().st_size for p in (ROOT / "assets" / "custom" / "audio").rglob("*") if p.is_file())
    print(f"audio folder {total / (1024 * 1024):.1f} MB")
    if total > 25 * 1024 * 1024:
        raise SystemExit("audio folder over 25 MB")


def write_note(music_rows: list[tuple]) -> None:
    lines = [
        "# Custom audio (Idle Party)",
        "",
        "Shipped files are CC0 or owned. This note is written by `tool/audio_import/import_audio.py`.",
        "",
        "## Music",
        "",
        "| File | Source | License |",
        "|------|--------|---------|",
        "| `music/hub.ogg` | [Heavenly Loop](https://opengameart.org/content/heavenly-loop) by isaiah658 | CC0 |",
        "| `music/bed_warm.ogg` | Owned synth, warm caves (Sandy, Goblin, King). `tool/audio_synth` | Owned |",
        "| `music/bed_dark.ogg` | Owned synth, dark caves (Underworld, City of Dead, Hell) | Owned |",
        "| `music/bed_ice.ogg` | Owned synth, ice caves (Crystal Spire, Rimeglass) | Owned |",
        "| `music/bed_wet.ogg` | Owned synth, wet caves (Tidehold, Blightfen, Hollow Grove) | Owned |",
        "| `music/bed_storm.ogg` | Owned synth, storm and machine caves (Ashen, Brassvault, Stormwake, Mothveil) | Owned |",
        "| `music/boss.ogg` | Owned synth (“Unresolved Crown”) | Owned |",
        "| `music/resolve.ogg` | Owned synth (“Floor Breath”) | Owned |",
        "| `music/down.ogg` | Owned synth (“The Drop”) | Owned |",
        "| `music/dungeon.mp3` | Owned ElevenLabs spare. Not played. | Owned |",
    ]
    for name, title, url, author, _dur in music_rows:
        lines.append(f"| `music/{name}` | [{title}]({url}) by {author} | CC0 |")
    lines += [
        "",
        "## SFX",
        "",
        "Combat, cast, death, crit, kill, material, and gold clips are trimmed CC0 recordings,",
        "mastered for a phone speaker (high-pass, a small 4.5 kHz dip, loudness match, mono).",
        "Metal hits are cut to 250 ms. Menu, loot, and the remaining one-shots stay owned synth.",
        "",
        "| Pack | Source | License |",
        "|------|--------|---------|",
        "| 80 CC0 RPG SFX | [rubberduck](https://opengameart.org/content/80-cc0-rpg-sfx) | CC0 |",
        "| Fantasy Sound Effects | [Vehicle](https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx) | CC0 |",
        "| Fantasy Weapons | [Vehicle](https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library) | CC0 |",
        "| RPG Sound Pack | [artisticdude](https://opengameart.org/content/rpg-sound-pack) | CC0 |",
        "",
        "Imported combat ids: hit_blade, hit_axe, hit_blunt, hit_dagger, hit_fist, hit_bow,",
        "swish_melee, swish_bow, bow_release, spell_*, cast_*, enemy_hit, enemy_die_*,",
        "crit, kill, mat_*, gold.",
        "",
        "## Files",
        "",
        "Ambience pads are owned synth (`tool/audio_synth`). Every shipped file is listed here.",
        "",
    ]
    audio = ROOT / "assets" / "custom" / "audio"
    for path in sorted(audio.rglob("*")):
        if path.suffix.lower() in {".ogg", ".mp3"}:
            rel = path.relative_to(audio).as_posix()
            lines.append(f"- `{rel}`")
    lines.append("")
    NOTE.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
