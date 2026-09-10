# Documentation audit — Privacy / Play / ads (2026-09-10)

**Scope:** Player-facing and store-ops docs vs code after Firebase Analytics +
AdMob↔Firebase link. Not a full `/repo auditandcleaning`.

**Verdict:** `docs/PRIVACY.md` was already mostly honest about Firebase.
Biggest gaps were **Play Console Data safety still unchecked**, stale
**AdMob store-link** wording in `PLAY_STORE.md`, and an open polish-board
item that still claimed “no analytics servers.”

## Sources of truth

| Topic | Code / console | Doc |
|-------|----------------|-----|
| Firebase Analytics | `lib/core/app_analytics*.dart`, `google-services.json` | PRIVACY + AGENTS + PLAY_STORE |
| UMP / AD PRIVACY | `ad_rewarded_io.dart` + `AppAnalytics.syncConsent` | PRIVACY |
| AdMob POWERUPS | `ad_config.dart`, live IDs | PRIVACY + PLAY_STORE + STORE_LISTING |
| AdMob ↔ Firebase | Console linked 2026-09-10 | PLAY_STORE (was missing → fixed) |
| Local session notes | `session_telemetry.dart` (opt-in, no network) | was undocumented in PRIVACY |
| Play Games / SHOP / update check | existing bridges | PRIVACY OK |

## Findings

| ID | Severity | Finding | Action |
|----|----------|---------|--------|
| D1 | **P0** | Play **Data safety** Firebase Analytics / App activity — **submitted for review 2026-09-10** (was lagging PRIVACY). | Google review in Publishing overview |
| D2 | P1 | PRIVACY said analytics was “optional” but did not say Android **may init on cold start** (UMP then), or that **outside EEA** Google may allow collection without a form. | PRIVACY clarified |
| D3 | P1 | AdMob↔Firebase link + impression-level revenue not mentioned in PRIVACY (ad metrics may flow into Analytics). | PRIVACY clarified |
| D4 | P2 | Local SETTINGS session notes undocumented (local-only; easy to confuse with Firebase). | PRIVACY clarified |
| D5 | P2 | PLAY_STORE still said AdMob “not store-linked” / “Requires review” while Apps shows Play linked + Klart. | PLAY_STORE cleaned |
| D6 | P2 | `PLAY_PROD_POLISH_1000` #008 / #025 open against outdated “no analytics / store-link” claims. | Rows marked Done |
| D7 | OK | STORE_LISTING does not mention analytics — fine; privacy URL + Data safety own that. Ads/SHOP honesty OK. | none |
| D8 | OK | AGENTS.md Firebase blurb matches code. | none |
| D9 | Note | AdMob red **betalningsproblem** banner is ops, not a doc lie — keep owner aware. | no code |

## Honesty checklist (player / Console)

- [x] Privacy URL points at `docs/PRIVACY.md` on `main`
- [x] PRIVACY lists: no Idle Party account · Play Games · POWERUPS/AdMob · Firebase Analytics · SHOP Billing · Play update check · clipboard
- [x] **Play Data safety** declares Firebase Analytics / App activity (submitted 2026-09-10)
- [x] Ads declaration Yes (POWERUPS)
- [x] Advertising ID declared
- [x] No “no ads forever” / no Idle Party analytics *server* claim that contradicts Firebase

## Follow-ups (not done this pass)

1. ~~Owner: update Play Data safety for Analytics (D1).~~ Done 2026-09-10 — under Google review.
2. Optional: fix AdMob payment-profile banner.
3. Optional: mention SHOP in STORE_LISTING full description when IAP products are active.
