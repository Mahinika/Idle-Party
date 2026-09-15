# Idle Party — itch.io page (paste-ready)

Play stays the install path. This page is discovery + a Google Play button.
Do **not** upload an APK.

**Live (2026-09-12)**

| | |
|---|---|
| Public | https://cognifox-studio.itch.io/idle-party |
| Edit | https://itch.io/game/edit/5000361 |
| Game id | `5000361` |
| Studio | Cognifox Studio |
| Community | https://itch.io/t/6930311/idle-party-idle-rpg-for-android-google-play |
| Board | https://itch.io/board/10022/release-announcements |

**Cover:** `cover_630x500.png` (630×500, owned marketing art).
**Screenshots (3–5):** from `tool/store_listing/marketing/`

- `02_todays_chase_1080x1920.png`
- `03_party_fights_1080x1920.png`
- `05_build_party_1080x1920.png`
- `07_afk_progress_1080x1920.png`
- `08_keystone_1080x1920.png`

**Trailer:** `https://www.youtube.com/watch?v=OMWXbgGBFMA`

Pricing: **No payments**. Generative AI: **No**.

---

## Upload gotchas (do not re-learn)

Play Console localhost-CORS in `play-store-prep/reference.md` does **not** work
here. itch.io is HTTPS.

**Dead (do not retry)**

1. CDP `DOM.setFileInputFiles` — denied in Cursor browser.
2. Local `py -3` CORS on `127.0.0.1` (or `_cors_server.py`) — mixed content /
   CORS. itch will not fetch localhost.
3. `browser_fill` or transcribing huge `.b64` through the fill tool — corrupts
   the payload.

**Working hop (cover + screenshots)**

1. In the locked itch tab, patch `HTMLInputElement.prototype.click` so
   **Upload Cover Image** / **Add screenshots** do not open the native picker.
2. Host a **complete** `.b64` text file on an HTTPS origin with CORS (last time:
   a secret GitHub gist). `fetch` it from the itch page.
3. `atob` → `Uint8Array` → `File` → `DataTransfer` → `input.files` + `change`.
4. Delete the gist immediately (`gh gist delete <id> --yes`). Do not recreate
   unless uploading more images.

Never commit `tool/store_listing/itch/upload/` (JPEG / `.b64` / chunks). Keep
this `PAGE.md` and the owned cover PNGs.

**Community post**

- Studio email must be **verified** before posting.
- reCAPTCHA is **owner-only** — fill the form, then wait for them to tick
  **I'm not a robot** and **New topic**.
- Board rules: itch page URL + short summary + embedded image **or** YouTube
  (editor **Video** button). Put the embed under the Trailer line so the label
  is not left empty.

---

## Create game form

| Field | Value |
|---|---|
| Title | Idle Party |
| Project URL | `idle-party` (or `cognifox-studio/idle-party`) |
| Short description | Idle RPG: grow a fantasy party that fights AFK — always know today's chase. |
| Classification | Games |
| Kind of project | Downloadable |
| Release status | Released |
| Pricing | Free / No payments |
| Genre | Role Playing |
| Tags | idle, incremental, rpg, party, dungeon, android, afk, fantasy, pixel-art, singleplayer |
| Platforms | Android checkbox may stay off unless a file is uploaded — Play store URL is the CTA |
| App store — Google Play | `https://play.google.com/store/apps/details?id=com.idleparty.app` |
| Visibility | Public |

---

## Description (English)

```
Idle fantasy RPG for phones. Build a party that keeps fighting while you are away. Return to loot, progress, and one clear TODAY goal.

**Play on Android (Google Play)**
https://play.google.com/store/apps/details?id=com.idleparty.app

Idle Party is a portrait idle RPG. Your heroes move, fight, heal, and use their own abilities — the same combat when you AFK. Install from Play — this page is the itch.io home, not a PC/web build. Combat is on screen in about a minute.

## Build your party
- Choose classic fantasy roles: Shield, Healer, and Damage to start, then tanks, healers, melee fighters, ranged heroes, and spellcasters.
- Discover 10 classes and 31 distinct hero specs.
- Equip, merge, and craft gear to make the whole party stronger.
- Battle through 15 dungeon zones filled with room chests, enemies, and bosses.

## Idle progress, real combat
- Watch the party fight on its own. Tap the fight to help. Leave a dungeon whenever you want and continue when you are ready.
- TODAY puts your next useful goal on the main button: claim, equip, or enter.
- Day-one menus stay small until gold, the shop, and essence mean something.

## Keep growing
- Ascend to unlock more heroes and permanent upgrades. Your party stays; the run bag resets.
- Reach level 100 to open challenging endgame modes: KEYSTONE, Infinity Gauntlet, Rifts, and Greater Rifts.
- Take on daily, weekly, and long-term quests.
- Optional Google Play Games adds cloud save and seasonal leaderboards.

## Fair play
- Single-player — no Idle Party account required.
- Optional rewarded ads (hub SCROLLS) grant timed scrolls and never interrupt a fight.
- Optional SHOP sells cheap convenience only (boosts, ad-free, small QoL) — not pay-to-win gear.

Start your party and take one more floor.

Cognifox Studio · cognifoxstudio@gmail.com
Privacy: https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md
```

---

## Community post (Share your project)

Title: `Idle Party — idle RPG for Android (Google Play)`

Tag: **Free**. Agree to the rules.

Paste body, then use the editor **Video** button for the trailer (do not leave
a bare `Trailer:` line under an embed that already sat at the top):

```
Idle Party is a portrait idle RPG: grow a fantasy party that keeps fighting while you are away, then come back to loot and one clear TODAY goal.

10 classes / 31 specs, 15 dungeon zones, Ascend, and endgame KEYSTONE once the party hits 100.

itch.io page: https://cognifox-studio.itch.io/idle-party

Android on Google Play (free, single-player, no account):
https://play.google.com/store/apps/details?id=com.idleparty.app

Fair SHOP (convenience only) and optional hub SCROLLS ads — nothing interrupts combat.

Trailer:
```

YouTube: `https://www.youtube.com/watch?v=OMWXbgGBFMA`
