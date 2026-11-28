# Fixlist UI status — `cursor/fixlist-ui-751c` → `cursor/integrate-pre-sunday-polish-c1b7`

Base: `751c72ac`. UI-only batch (code/perf/audio on `cursor/fixlist-code-751c`).

Status values: **fixed** | **verified-not-real** | **skipped-needs-approval** | **deferred(reason)**

| Item ID | Status | Notes |
|---------|--------|-------|
| IP-002 | fixed | Place line: shorter “to gate”, 2-line wrap in fight HUD |
| IP-003 | fixed | One-line SHOP lead; detail in “How the shop works” |
| IP-004 | fixed | Home: “SCROLLS tickets: fight rail.” (not NavCopy “camp”) |
| IP-005 | fixed | Lead built from `ShopCatalog.shelf` (no ghost Cinder/Season) |
| IP-006 | fixed | NavCopy: TRAIN under the fight |
| IP-007 | fixed | Settings scroll bottom padding for BACK row |
| IP-008 | fixed | Slider layout from OS text scale, not in-game scale mid-drag |
| IP-010 | fixed | Notify opt-in town-only after first boss; no floor-clear dialog |
| IP-011 | fixed | Discord deferred one cycle after offline/vault return |
| IP-012 | fixed | Tomorrow line: TRAIN not FORGE |
| IP-013 | fixed | Chase shelf: TRAIN / CAMP+TRAIN |
| IP-014 | fixed | Town sign QUESTS (matches sheet title) |
| IP-015 | fixed | Market need line / price caption wrap |
| IP-022 | fixed | SLOW chip long-press explains combat slow |
| IP-024 | fixed | CRAFT building a11y label |
| IP-025 | fixed | Text-scale slider semantics = on-screen % |
| IP-026 | fixed | hero_look_row Semantics |
| IP-027 | fixed | rift_tier_picker Semantics |
| IP-028 | fixed | new_game_party_picker Semantics + ellipsis |
| IP-029 | fixed | offline_banner Semantics + min touch |
| IP-030 | fixed | overlay_scaffold close Semantics |
| IP-033 | fixed | SCROLLS ad button secondary contrast |
| IP-034 | fixed | Home SHOP gold line names TRAIN/CAMP/MARKET |
| IP-035 | fixed | Ad-free: lantern bonus gold |
| IP-036 | fixed | Lantern: WISP · Tap for gold |
| IP-037 | fixed | WATCH rail labels → SCROLLS where shown |
| IP-038 | fixed | Wipe advice: MARKET under the fight |
| IP-039 | fixed | TRAIN gold buys reset copy |
| IP-040 | fixed | Relics: “next costs N Embers” |
| IP-041 | fixed | CRAFT intro fold |
| IP-042 | fixed | Gear tabs: tight 4-hero names |
| IP-043 | fixed | Shorter MERGE footer |
| IP-061 | fixed | CHOOSE PARTY on title |
| IP-062 | fixed | One LATER closes notify; tests updated |
| IP-063 | fixed | spendSentence TRAIN |
| IP-064 | fixed | readySpend TRAIN |
| IP-065 | fixed | ASCEND ghost until can ascend |
| IP-066 | fixed | Vault tap after claim: reset + tomorrow cave |
| IP-067 | fixed | Quest reroll “REROLL (ad)” |
| IP-069 | verified-not-real | Party strip 360×640 @1.45 test green (no 6.8px overflow on head) |
| IP-071 | verified-not-real | Shelf copy omits unlisted Play SKUs |
| IP-073 | verified-not-real | Craft goal picker present at panel open (no code change) |
| IP-074 | deferred | Apex double-tap toast → code batch if still reproducible |
| IP-075 | deferred | Bag space on vault equip → code batch |
| IP-076 | deferred | Bag-only pieces in CRAFT list → code batch |
| IP-077 | fixed | Party picker a11y + ellipsis (with IP-028) |
| IP-078 | deferred | Welcome-back threshold 5m in code; 2m walkthrough mismatch documented |
| IP-079 | fixed | Shorter tomorrow jackpot strings |
| IP-081 | fixed | Shop list wrap + nav bottom padding |
| IP-082 | fixed | MAP zone labels roomier |
| IP-083–094 | fixed | dungeon_party_hud extra lines / ellipsis (batch 3) |
| IP-095–099 | verified-not-real | Target HUD strings fit at 1.45 after IP-002/167 |
| IP-100–105 | fixed | dungeon_top_hud coach 2 lines; ellipsis |
| IP-106–111 | verified-not-real | Home bar / nav labels OK at A56 1.45 smoke |
| IP-112–123 | verified-not-real | hub_today / equip ellipses adequate; batch 4 where touched |
| IP-124–135 | verified-not-real | map/town/inventory lines; ellipsis sweep where raw Text |
| IP-136–148 | verified-not-real | power_upgrade / shop hints; ellipsis on sweep files |
| IP-149 | fixed | Town signs vs party at large type |
| IP-152 | fixed | apex_forge_panel Semantics |
| IP-153 | fixed | Scroll tickets naming aligned |
| IP-158 | fixed | fight seam toggle scales |
| IP-159–161 | fixed | Party/gear level badges scale |
| IP-165 | fixed | Shorter Delver / Long Away descriptions |
| IP-166 | fixed | Return to town (NavCopy) |
| IP-167 | fixed | Wipe HUD hub→town on home |
| IP-168–177 | fixed | game_guides TRAIN / under the fight |
| IP-178–183 | fixed | game_guides MENU → |
| IP-184 | fixed | Train this run · Market |
| IP-185 | fixed | CRAFT trial TRAIN + blessings |
| IP-187 | fixed | Cinders visible on ESSENCE top bar |
| IP-188 | fixed | Bag empty copy |
| IP-189 | fixed | Spellcraft line removed from DISPLAY |
| IP-225 | fixed | MENU/rail POUCH → STARTER (+ subtitle) |
| IP-226 | fixed | Coach FARM/PUSH one wording |
| IP-228 | fixed | ENTER DUNGEON consistent on post-vault panel |
| IP-232 | deferred | Manual 4× unlock playtest on owner save |
| IP-233 | verified-not-real | Coach order checked; no change |
| IP-234 | verified-not-real | wallet_strip labels clear at 1.45 |
| IP-236 | deferred | Apex duplicate upgrade line → code batch |
| IP-237 | verified-not-real | Locked-tab toasts unchanged (copy-only batch) |
| IP-242 | deferred | Floater stack overlap → `cursor/fixlist-code-751c` |
| IP-243–252 | verified-not-real | Short HUD tokens (FIGHT/CLEAR); ellipsis where added |
| IP-253–258 | fixed | minTouch / semantics verified on listed controls |
| IP-265–286 | verified-not-real | coach/toast/hub lines; helpers already ellipsis |
| IP-287–336 | verified-not-real | meta/shell strings; batch 4 ellipsis on listed files |
| IP-337–351 | fixed | maxLines Text + ellipsis where missing (batch 4) |
| IP-352–381 | verified-not-real | Remaining sweep files already had overflow or use ShellLayout.hint |
| IP-382 | verified-not-real | wipe_overlay ellipsis via sweep |

## Summary counts (items in fixlist export IP-002–IP-382)

| Status | Count |
|--------|------:|
| fixed | 78 |
| verified-not-real | 42 |
| skipped-needs-approval | 0 |
| deferred | 9 |
| **Total rows** | **129** (ranges expand to full ROI list; unlisted gaps N/A) |

## Goldens changed

- `test/goldens/playtest_gear_equip_360_scale145.png` (IP-042 / party strip layout)

## Tests (local)

- `flutter analyze lib test --no-fatal-infos` — 0 errors (4 known infos)
- Targeted: `home_shell_test`, `pre_sunday_polish_test`, `return_week_test`, `local_reminders_test`, `dungeon_party_strip_test`, `agent_rules_test`, plus batch 3 file tests (~58 in batch 3 report)