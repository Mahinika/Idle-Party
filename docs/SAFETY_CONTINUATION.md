# Safety batch continuation

This file is the handoff after the save-safety batch. It is not a second
roadmap. Later batches build on the current game. Do not replace
SpatialCombat, the home shell, CAMP/SHOP, or the five save slots.

Main at the start of the safety batch: `85801192` (CAMP Ad-free after the
third free level, every SHOP pack, compact FORGE/CAMP/MARKET). UI PR
https://github.com/Mahinika/Idle-Party/pull/50 (`cursor/icon-hires-polish-3edc`,
head `456d7a4a`) is a separate phone-test. Do not edit that branch.

## QA follow-up on the same save PR

Independent review found six holes in the first patch. They are fixed in
this PR, still without a Play release or a Firestore deploy.

- Device copy and cloud install write a journal. The previous file is copied
  aside before the active slot changes, and the incoming file is not treated
  as saved until the active slot reads back. A failed write returns false.
- Ad-free, the season pass, Long Away, bag slots, scroll bits, and purchase
  ids are kept from both files. Gold, Cinders, and tickets are not added
  together. A level-1 paid file is not an empty party.
- Cloud writes start blocked. Signed-out, unavailable, and failed reads
  block. Every upload re-reads at commit and aborts if the Play account
  changed. Automatic upload does not overwrite a different snapshot.
- A shop grant and a cloud install take the same save turn. The grant's
  bytes are the ones written, and a restore cannot drop a grant that already
  returned success.
- Two real saves ask the player. A higher floor does not outrank a CAMP
  upgrade that the other file lacks. Only an untouched starter party is
  replaced on its own.
- games_services 5.3.0 reports a missing snapshot and a network error as the
  same `failed_to_load_game`. A first backup is allowed only when the snapshot
  list succeeds and does not contain this save. An exception from open is
  never treated as empty.

## Done in the safety batch

- `shopOfferStartedMs` reloads without the year-2001 cap. Ad-free, Long Away,
  and granted purchase ids are unchanged.
- A Play Games read failure is not an empty snapshot. Automatic upload stays
  off until a read is confirmed empty or a real save.
- Cloud replace uses durable progress. A wall-clock rollback cannot silently
  install an older cloud save. The previous device file is kept
  (`idle_party_displaced_save`) and SETTINGS shows DEVICE COPY after that.
- A backward clock does not rewind `lastUpdated` or pay the gap as time away.
  An in-flight offline credit does not write over a restore that won the race.
- `setDungeonTilesReady` and `clearToast` no longer notify listeners during
  build. Crashlytics still records real fatals.

## Do not do yet

Firestore rules and the friend-claim data model stay put until the parent
confirms which Firebase project and edition are live. The file
`firestore.rules` in git is not proof of what is deployed.

Risk in the repo copy, not a claim about production:

- Clients sign in anonymously, and the rules only require `request.auth != null`.
- `friendCodes` update lets any signed-in caller increment `claims` while
  leaving `ownerDevice` unchanged. Knowing an 8-character code is enough.
- `friendClaims` create lets any signed-in caller pick a 64-character device
  id. That can burn the 30-claim cap.
- `FirestoreFriendReferralGateway._claimApart` writes the claim doc and the
  counter as two requests. Two callers can lose an increment. The rules
  comment in that file already says the transaction often fails the rules
  check because of server timestamps.

Next validated patch, after the project is identified: read the live ruleset,
diff it against `firestore.rules`, then make the claim counter a single
transaction the rules accept (or a trusted function). Do not grant tickets
from a client-writable counter without that. Do not read production saves
and do not send claim traffic to try the hole.

## Later batches, in dependency order

1. First ten minutes. Sandy start, three heroes, and the home fight are the
   base. Teach the first fight and the first claim with the screens that
   already exist. Land or rebase PR 50 before changing home chrome, fight
   seams, or `shell_layout.dart`.
2. Hero roles. The 10 classes and 31 specs stay. Show tank, damage, and
   healer with the current kits and the cutout skeleton. Do not add a second
   combat sim to explain roles.
3. First-week milestones. TODAY, the daily vault, and `ChaseContract` are the
   milestone track. Add goals there. Do not add a parallel quest board.
4. Differentiated bosses. Extend `boss_tells.dart` and `enemy_specials.dart`
   per zone. The first boss stays on floor 2.
5. Offline return. Welcome Back and `OfflineProgress` stay the authority.
   This batch already stops a backward clock from inventing or erasing the
   gap. The next pass makes that return readable. It depends on this batch.
6. Impactful upgrades. Forge, CAMP, and gear budget stay the math. Keep the
   CAMP ad-free offer and the SHOP pack list from `9d44edef` and `85801192`.
   Do not retune billing in the same change as a balance pass.
7. Honest monetization. Say what an ad and a pack actually grant. Ad-free
   after the third free CAMP level stays. The referral counter patch above
   is a blocker before any ticket payout change.
8. Analytics baseline. Name the events already in `docs/ANALYTICS.md` and
   count them. Do not mute Crashlytics and do not downgrade Flutter framework
   errors to make the fatal chart green. The 1.13.17 overflow samples were
   `RenderFlex` reports after `party_wipe` / `rewarded_offer` / `wipe_retry`
   on the emulator. `DungeonWipePanel` is a non-scrolling column. Home shell
   layout is PR 50's files. Reproduce on a device before restyling either.

RenderFlex was not given a widget name in this batch, and it was not
restyled here.
