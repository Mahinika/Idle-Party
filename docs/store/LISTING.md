# Idle Party — Play listing copy & rating answers

English store text and questionnaire answers for Google Play Console.
Package id: `com.idleparty.app`. Version: keep in sync with `pubspec.yaml` / tag `v*`.

## Short description (≤80 characters)

```
Cozy idle RPG — watch your party fight, steer with God Hand, grow forever.
```

(72 characters)

## Full description

```
Idle Party is a cozy idle RPG. Your heroes clear fantasy dungeons while you watch, tap to steer, and grow lasting power between runs.

WATCH THE PARTY
• Auto combat on multi-chamber floors with gates, bosses, and loot
• Farm a floor for gear or Push toward the boss
• God Hand: tap the map to blast foes and briefly guide the party

WORLD PATH
• Nine named zones — from Sandy Caverns to Crystal Spire, Sunken Tidehold, and Ashen Vault
• Unlock the next zone by clearing the previous boss or earning lifetime gold
• Infinity Gauntlet (Ascension 10+): endless Spire climb with a saved best floor

BUILD YOUR WAY
• WotLK-inspired specs and party roles
• Gear, loadouts, armor sets, Apex craft, pets, sanctuary, and relics
• Ascend to reset the run while keeping meta progress

DESIGNED TO BE FAIR AND CALM
• No ads, no account, no pay-to-win store
• Progress saves on your device
• Optional clipboard export/import if you want a backup

Idle Party is a single-player game. Sit back, peek in, and nudge the party when you feel like it.
```

## App category / tags (suggestion)

- Category: **Game → Role Playing** (or Idle / Casual if Console prompts)
- Tags: idle, RPG, party, cozy, offline

## Contact / privacy URL (prep)

- Privacy: `https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md`
- Prefer a stable raw or Pages URL later if Console rejects blob links.

## Data safety (match PRIVACY.md)

| Question | Answer |
|----------|--------|
| Collects user data? | **No** (no accounts, no analytics to Idle Party servers) |
| Shared with third parties? | **No** |
| Encrypted in transit? | N/A (no app-owned network collection) |
| Users can request deletion? | N/A — local-only; uninstall clears device save |
| Data types collected | **None** declared for Idle Party backends |
| Optional clipboard export/import | User-initiated backup only; not uploaded by the app |

If Console asks about “App activity” / “Device or other IDs”: answer **not collected** for Idle Party’s own purposes. Platform/store update traffic is outside the app’s servers.

## IARC / content rating — recommended answers

Complete the official questionnaire in Play Console. Use these intents (adjust if a question’s wording differs):

| Topic | Answer | Why |
|-------|--------|-----|
| Violence | **Fantasy violence** / mild cartoon combat | Party fights monsters; no realistic gore |
| Blood | **None** or **unrealistic/mild** if forced | Pixel fantasy hits, not graphic injury |
| Sexual content | **None** | |
| Nudity | **None** | |
| Language | **None** / no strong language | English UI is clean |
| Controlled substances | **None** | Fantasy “flask” potions only |
| Gambling | **None** | No real-money gambling; no casino sims |
| User-generated content / chat | **No** | Single-player, no chat |
| Location sharing | **No** | |
| Purchases | **No** in-app purchases in current builds | Sideload/GitHub; no Play IAP wired |
| Ads | **No** | |
| Age gate / online interactions | Offline single-player | |

**Expected rating:** broadly **Everyone** / **PEGI 7** / mild fantasy violence — Console’s IARC result is authoritative once submitted.

## Screenshots (this folder)

Phone screenshots live in `docs/store/screenshots/`. Aim for **4–6** portrait (or Console’s current phone size):

| File | Shot |
|------|------|
| `01_title.png` | Start menu / title |
| `02_hub.png` | Hub World Path |
| `03_dungeon.png` | Live dungeon combat |
| `04_more.png` | MORE menu / meta |
| `05_whats_new.png` | What’s New or Guides |
| `06_god_hand.png` | Dungeon with God Hand / party HUD |

Feature graphic: `docs/store/feature_graphic.png` (**1024×500**).
Icon source: `assets/custom/ui/app_icon.png`.

## Operator paste order

1. Create app `com.idleparty.app` in Play Console  
2. Paste short + full description  
3. Upload icon, feature graphic, screenshots  
4. Set privacy URL + Data safety from the table above  
5. Run IARC questionnaire with the answers above  
6. Upload AAB from GitHub Release `v*` (when signing secrets are set) → Internal testing  
