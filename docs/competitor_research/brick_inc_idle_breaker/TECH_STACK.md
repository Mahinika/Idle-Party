# Tech stack (observed)

Source: logcat during cold start on Play Phone emu, v **2.7.1** (build **9305**). No decompile.

## Client

| Piece | Evidence |
|-------|----------|
| Engine | Unity **6000.3.21f1**, IL2CPP, **arm64-v8a** |
| Launcher activity | `co.ab180.airbridge.unity.AirbridgeActivity` (Airbridge deep link SDK) |
| Attribution | Airbridge Unity SDK **4.9.2** |
| Social | Facebook Unity SDK **18.0.0** |
| Auth | Unity Authentication, Google / Apple / Facebook OIDC, **Google Play Games** linked |
| Analytics | Firebase Analytics, Remote Config |
| Ads | **LevelPlayAdsService** + AdMob (GMA log lines) |
| IAP | **UnityIAPService** → Play Billing |
| Assets | Addressables (`Sound/sfx_*` keys), Play Asset Delivery packs |
| WebView | Embedded (consent / ads) |

## Server

REST-style **`Api*`** calls on boot:

- System status, time, master data, config, events, user status, user data find, text overrides

Responses JSON (`status: SUCCESS`, maintenance messages, save ids).

## Privacy / compliance

UMP consent logged: GDPR **True**, tracking **True**, `IABTCF_PurposeConsents`.

## Emulator caveat

x86_64 emu runs **arm64** split via translation; some Addressable audio keys missing — does not affect UI research.

## Raw log

[`logcat_unity_services.txt`](logcat_unity_services.txt) — filtered Unity `[Service]` and related lines (~3 MB).
