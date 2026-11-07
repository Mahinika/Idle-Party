# Safety batch continuation

This file is the handoff after the save-safety batch. It is not a second
roadmap. Later batches build on the current game. Do not replace
SpatialCombat, the home shell, CAMP/SHOP, or the five save slots.

Main at the start of the safety batch: `85801192` (CAMP Ad-free after the
third free level, every SHOP pack, compact FORGE/CAMP/MARKET). UI PR
https://github.com/Mahinika/Idle-Party/pull/50 (`cursor/icon-hires-polish-3edc`,
head `456d7a4a`) is a separate phone-test. Do not edit that branch.

## Second QA on the same save PR

A recovered swap used to return failure after the bytes had already moved,
and boot would then save over the unresolved copy. Those outcomes are now
explicit.

- `committed` means both parties are durable. Memory adopts that active file.
- `aborted` means the active slot never changed.
- `unresolved` means the journal still holds a party. Boot, autosave, grants,
  and cloud upload do not write over it. Play stays on the recovery gate
  until RETRY can finish the journal. A second device copy is refused.
- KEEP DEVICE and BACKUP NOW keep paid ownership from both files. Gold,
  Cinders, and tickets are not added together. Chosen purchase ids are kept
  ahead of the other file when the 64-id cap fills.
- An opted-in restart reads Play again. Automatic backup continues when the
  snapshot is missing, identical, or still this device's last upload.
  A different snapshot stays put until BACKUP NOW, which does that read
  itself. The button is not dead on a cold start.
- A shop grant bumps the save epoch, so a warm resume cannot write the
  pre-grant party after the purchase has been saved.
- Snapshot absence requires a fresh list. games_services 5.3.0 drops
  `isStale()`, so the app reads that bit on its own Android channel. A stale
  list is a failed read.
- SharedPreferences updates its cache before the platform returns. A failed
  setter is not treated as durable. `reload()` is the check. The unit test
  uses the real plugin cache. Process-kill coverage is a simulated throw
  after the durable map changes, not a killed OS process.

Play's `RESOLUTION_POLICY_MOST_RECENTLY_MODIFIED` can still replace another
device's snapshot after our re-read. `commitAndClose` does not prove the
server stored the file. Those limits stay inside the SDK. That unobserved
race is separate from the final read this app already has: BACKUP unions
paid ownership from that read into the uploaded file and into the local save.

## Third QA on the same save PR

The previous patch still lost a party when an exception landed after the
files were already in place, when a second device copy ran during recovery,
when cleanup deleted the proof before the journal, and when the final cloud
read was ignored. Those are closed here.

- An in-process throw after cleanup is reconciled. If both parties read back,
  the swap is committed. If they cannot be read, saving stays off so the next
  autosave cannot replace them. RETRY adopts the durable file.
- A journal that already exists is not overwritten. Device copy, erase, new
  game, and import wait on the save queue and refuse while recovery is open.
- Cleanup can finish after staging and the hold are already gone. A live
  party that differs from the last autosave is published into the device
  copy. The swap is marked commit before that active write, so a later
  retry publishes the hold instead of deleting it.
- Cold boot with the title card shows SAVE RECOVERY before play. Combat,
  hub idle, and BUY stay off. A grant that already started is still not
  consumed.
- An r1/r2 global journal is copied payload-first onto the one slot whose
  bytes match it, and the source marker is deleted last. Two matching
  slots are not guessed. The bytes stay. Export and the other slots stay
  available. A second cloud restore does not replace a parked party that
  is neither the current file nor the incoming file.
- A snapshot list with a missing or non-bool `stale` field is not fresh.
- The 64-id cap still drops an unconsumed receipt that does not fit. A
  receipt that fits is kept so Play does not grant it again. Consumed
  receipts are not redelivered by Play. Non-consumable flags still block a
  second grant of the same pack.

An Android compile of this head is the evidence for the snapshot channel.
No APK was uploaded and no device was installed.

The unsuffixed journal is slot 0's file and also where an early build
stored a copy for whichever slot was selected. A journal this build writes
names its slot. That name is enough to finish a slot 0 swap while another
save exists. An older journal has no name. One present slot file in the
payloads is the owner. No present file, including a slot that was erased
or quarantined, keeps every byte. Saving stays off. Export and an
unaffected slot are the way out. An existing file loads with saving on.
An empty file opens party setup and does not enter a fight until that
new game is saved. The same is true for a title PLAY or START: a false or
thrown initial save stays on setup, and a second START does not enter the
queue. Back leaves setup. A save that returns false before any byte lands
leaves the slot empty so START can be tried again. A commit that
returns false is not accepted from a later read. The platform map can
already show the new value after that false result. Retry does not
adopt that cached copy, and a duplicate purchase is not acknowledged
while the commit is still unproven. A failed title import puts the
previous slot back. A quarantine copy that returns false or throws
does not delete the original. A parse that only checks a file borrows
another random, so the combat generator stays where it was. A boot read that
throws is not an empty phone. A file that is JSON but does not parse
as a save is not an empty phone either. Boot probes that parse and does
not call the loader that moves the file aside when the probe fails. A
probe that succeeds still loads through storage. That load does not
quarantine a file it can parse. Restore, backup, a new game, erase, and
opening a slot stay off until a later read can see the file, or can
see that the phone really is empty and no party was already loaded.
An unreadable file, its mirror, and a quarantined copy are left in
place. Deleting the active file does not clear the pause. Retry adopts
the slot the preference names, not the constructor default. Retry does
not guess an owner.

A slot with no journal of its own is a finished migration only when every
global payload already matches that slot's active file or its parked file.
A temporary hold is not that copy. The global journal stays until the
scoped journal has landed, so a later device copy cannot overwrite the only
remaining party. Boot and RETRY do not recover while the migration is still
unmatched or collided. A parked file that differs from the party being
copied is left as it is. The cut coverage fails or throws on one chosen
side-file write. That fault is in-process. It is not an operating-system kill.

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
