# Idle Party — what to do next

**2026-10-31.** Live on Google Play as **1.13.5 (231)**, submitted 2026-10-28.
This is a short money-first list. The 52-week plan stays in
`docs/YEAR_ROADMAP.md`. Week jobs stay in `docs/weeks/`. Do not start a
second program from this file.

## Where the money is

Window 30 Sep–27 Oct (Play, devices): **28,900** impressions, **162**
acquisitions, **74** first opens, **153** monthly active, **D7 retained
devices 9**. About **88** installs never opened. AdMob 21–27 Oct:
**59** active users, **1.49** sessions per user, average session **5m 21s**,
**84** ad requests, **1** impression, earnings **0.01 kr**. Match rate was
high. The requests are the boot preload. Almost nobody taps WATCH.

Crashes on the builds that are out are quiet. Do not move combat onto an
isolate from the old ANR notes.

## Do this, in order

1. **Get them to come back.** The cave already keeps fighting while the app
   is closed, and the hub already names one cave for tomorrow. D7 is still
   9 devices. The first-boss coach line now says the party keeps fighting
   if you close the app. Do not add a second daily calendar.
2. **Offer the ad when the gold is on screen.** Welcome Back now has an
   optional watch that turns that return’s gold into ×3 — the same number
   as Scroll of Rest. Skip keeps the gold. Ad-free and Forever Rest are
   not asked. Nothing new is written into the save. Next: keep SCROLLS
   one tap from the hub after the first boss, and do not remove the boot
   preload (that only hides requests; it does not create watches).
3. **Sell what Play can already charge.** SHOP now lists Ad-free,
   Supporter, and Long Away. Forever scrolls and the Cinder pouch stay in
   the catalog for a code or a restore, and a row appears only after Play
   returns that product. Hour packs stay restore-only. A restore does not
   grant a consumable again, and it does not stack Ad-free tickets, bag
   slots, or Long Away. Do not add a SKU the Console does not have
   (`perm_scroll_*` and `cinder_pouch` still are not). A new pack needs a
   Play product before the button can take money. Not in the 1.13.5 Play
   binary until that build is uploaded.
4. **Keep the live build stable.** Current main crashes when a room or boss
   clears: `_clearKeystoneRun` called itself. The 1.13.5 binary on Play
   does not have that split. This change calls the real helpers. No
   save-field renames. New fields, if a later change needs one, default
   when missing and survive Ascend the way tickets and shop flags already
   do. Wallet gold still resets on Ascend.
5. **Then the phone.** Week 46 is “the fight fits the phone.” That is a
   look change and needs a before and after on the A56. Zone identity
   (so the next cave does not look like the last) is the fun after that.
   Store shots are 1.13.5. The preview video is still 1.13.3. 1.13.6 is
   the last version within three patches of that film. The next bump
   needs a new Sandy preview or the listing test fails. Do not buy installs.

## Not this

- A second fight sim, a new class, or a new cave, unless a named goal
  needs it.
- Raising the 8-hour offline cap. It was left on purpose.
- iOS, a web product, or GitHub as the install path.
- Paid APIs. AdMob, Play Billing, and Firebase are already in the app.

## Run it

```bash
flutter pub get
flutter analyze lib test --no-fatal-infos
flutter test --exclude-tags sim
flutter test test/ad_boost_test.dart test/offline_progress_test.dart
```

Phone: Samsung A56 (`flutter emulators --launch Samsung_A56`, then
`flutter run`). Players install from Google Play
(`com.idleparty.app`). Do not upload an AAB unless asked that turn.
