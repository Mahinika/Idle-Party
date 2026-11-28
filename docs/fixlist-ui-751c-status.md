# Fixlist UI status — `cursor/fixlist-ui-751c` → `cursor/integrate-pre-sunday-polish-c1b7`

Base: `751c72ac`. UI-only batch (code/perf/audio on `cursor/fixlist-code-751c`).

Task header cited **286** ROI rows; this table lists **292** explicit `IP-###` ids from the export (002–382, gaps omitted).

Status values: **fixed** | **verified-not-real** | **skipped-needs-approval** | **deferred(reason)**

| Item ID | Status | Notes |
|---------|--------|-------|
| IP-002 | fixed | lib/ui/shell/dungeon_top_hud.dart place line 2-row |
| IP-003 | fixed | lib/ui/shell/shop_dock.dart one-line lead |
| IP-004 | fixed | lib/ui/shell/shop_dock.dart SCROLLS fight rail |
| IP-005 | fixed | lib/ui/shell/shop_dock.dart shelf-driven lead |
| IP-006 | fixed | lib/core/nav_copy.dart TRAIN under fight |
| IP-007 | fixed | lib/ui/shell/settings_overlay.dart BACK padding |
| IP-008 | fixed | lib/ui/shell/settings_overlay.dart slider layout |
| IP-010 | fixed | notify after first boss in town |
| IP-011 | fixed | lib/ui/shell/discord_thanks_overlay.dart defer after vault |
| IP-012 | fixed | lib/core/return_week.dart tomorrow TRAIN |
| IP-013 | fixed | lib/core/return_week.dart chase TRAIN/CAMP+TRAIN |
| IP-014 | fixed | lib/models/town_building.dart QUESTS sign |
| IP-015 | fixed | lib/ui/shell/market_overlay.dart need line wrap |
| IP-022 | fixed | lib/ui/shell/dungeon_party_hud.dart SLOW long-press |
| IP-024 | fixed | lib/models/town_building.dart CRAFT Semantics |
| IP-025 | fixed | lib/ui/menu_chrome.dart slider % semantics |
| IP-026 | fixed | lib/ui/hero_look_row.dart Semantics |
| IP-027 | fixed | lib/ui/meta/rift_tier_picker.dart Semantics |
| IP-028 | fixed | lib/ui/new_game_party_picker.dart Semantics+ellipsis |
| IP-029 | fixed | lib/ui/shell/offline_banner.dart Semantics |
| IP-030 | fixed | lib/ui/shell/overlay_scaffold.dart close Semantics |
| IP-033 | fixed | fixlist batch 2 copy/UI |
| IP-034 | fixed | fixlist batch 2 copy/UI |
| IP-035 | fixed | fixlist batch 2 copy/UI |
| IP-036 | fixed | fixlist batch 2 copy/UI |
| IP-037 | fixed | Rail HUD shows SCROLLS shelf; WATCH ad icon keeps WATCH label (no dup a11y) |
| IP-038 | fixed | fixlist batch 2 copy/UI |
| IP-039 | fixed | fixlist batch 2 copy/UI |
| IP-040 | fixed | fixlist batch 2 copy/UI |
| IP-041 | fixed | fixlist batch 2 copy/UI |
| IP-042 | fixed | fixlist batch 2 copy/UI |
| IP-043 | fixed | lib/ui/shell/inventory_dock.dart MERGE footer shortened; keeps raw-power honesty |
| IP-061 | fixed | lib/ui/start_menu_screen.dart CHOOSE PARTY |
| IP-062 | fixed | notify one LATER; test/local_reminders_test.dart |
| IP-063 | fixed | lib/core/return_week.dart spendSentence TRAIN |
| IP-064 | fixed | lib/core/return_week.dart readySpend TRAIN |
| IP-065 | fixed | lib/ui/hub_screen.dart ASCEND ghost |
| IP-066 | fixed | vault dialog after claim |
| IP-067 | fixed | QUESTS REROLL (ad) copy |
| IP-069 | verified-not-real | test/dungeon_party_strip_test.dart 360×640 @1.45 |
| IP-071 | verified-not-real | shop lead omits unlisted Play SKUs |
| IP-073 | verified-not-real | CRAFT goal picker at panel open |
| IP-074 | deferred(code PR apex) | lib/ui/apex_forge_panel.dart double-tap toast |
| IP-075 | deferred(code PR apex) | lib/ui/apex_forge_panel.dart vault equip bag |
| IP-076 | deferred(code PR apex) | lib/ui/apex_forge_panel.dart bag-only CRAFT |
| IP-077 | fixed | lib/ui/new_game_party_picker.dart (IP-028) |
| IP-078 | deferred(5m welcome threshold; owner approval to change) | lib/ui/meta/offline_welcome.dart threshold 5m not 2m |
| IP-079 | fixed | lib/core/return_week.dart shorter jackpot |
| IP-081 | fixed | lib/ui/shell/shop_dock.dart wrap+nav padding |
| IP-082 | fixed | lib/ui/shell/home/map_screen.dart zone labels |
| IP-083 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-084 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-085 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-086 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-087 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-088 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-089 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-090 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-091 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-092 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-093 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-094 | fixed | lib/ui/shell/dungeon_party_hud.dart ellipsis/lines |
| IP-095 | verified-not-real | lib/ui/shell/dungeon_target_hud.dart @1.45 |
| IP-096 | verified-not-real | lib/ui/shell/dungeon_target_hud.dart @1.45 |
| IP-097 | verified-not-real | lib/ui/shell/dungeon_target_hud.dart @1.45 |
| IP-098 | verified-not-real | lib/ui/shell/dungeon_target_hud.dart @1.45 |
| IP-099 | verified-not-real | lib/ui/shell/dungeon_target_hud.dart @1.45 |
| IP-100 | fixed | lib/ui/shell/dungeon_top_hud.dart coach ellipsis |
| IP-101 | fixed | lib/ui/shell/dungeon_top_hud.dart coach ellipsis |
| IP-102 | fixed | lib/ui/shell/dungeon_top_hud.dart coach ellipsis |
| IP-103 | fixed | lib/ui/shell/dungeon_top_hud.dart coach ellipsis |
| IP-104 | fixed | lib/ui/shell/dungeon_top_hud.dart coach ellipsis |
| IP-105 | fixed | lib/ui/shell/dungeon_top_hud.dart coach ellipsis |
| IP-106 | verified-not-real | lib/ui/shell/home/home_nav_bar.dart @1.45 |
| IP-107 | verified-not-real | lib/ui/shell/home/home_nav_bar.dart @1.45 |
| IP-108 | verified-not-real | lib/ui/shell/home/home_nav_bar.dart @1.45 |
| IP-109 | verified-not-real | lib/ui/shell/home/home_nav_bar.dart @1.45 |
| IP-110 | verified-not-real | lib/ui/shell/home/home_nav_bar.dart @1.45 |
| IP-111 | verified-not-real | lib/ui/shell/home/home_nav_bar.dart @1.45 |
| IP-112 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-113 | fixed | lib/ui/character_equip_panel.dart HP line ellipsis |
| IP-114 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-115 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-116 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-117 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-118 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-119 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-120 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-121 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-122 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-123 | verified-not-real | lib/ui/hub/hub_today_card.dart ellipsis OK |
| IP-124 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-125 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-126 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-127 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-128 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-129 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-130 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-131 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-132 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-133 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-134 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-135 | verified-not-real | map/town/inventory @1.45 smoke |
| IP-136 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-137 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-138 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-139 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-140 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-141 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-142 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-143 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-144 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-145 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-146 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-147 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-148 | verified-not-real | power_upgrade/shop hints ellipsis |
| IP-149 | fixed | lib/ui/shell/home/town_viewport.dart signs @1.45 |
| IP-152 | fixed | lib/ui/apex_forge_panel.dart Semantics |
| IP-153 | fixed | scroll tickets naming |
| IP-158 | fixed | lib/ui/shell/home/fight_seam.dart panel scale |
| IP-159 | fixed | lib/ui/shell/dungeon_party_hud.dart L badge scales |
| IP-160 | fixed | lib/ui/shell/dungeon_party_hud.dart CC label scales |
| IP-161 | fixed | lib/ui/character_equip_panel.dart tab level scales |
| IP-165 | fixed | lib/core/shop_catalog.dart shorter packs |
| IP-166 | fixed | lib/ui/confirm_dialogs.dart Return to town |
| IP-167 | fixed | lib/ui/shell/dungeon_top_hud.dart wipe→town |
| IP-168 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-169 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-170 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-171 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-172 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-173 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-174 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-175 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-176 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-177 | fixed | lib/core/game_guides.dart TRAIN copy |
| IP-178 | fixed | lib/core/game_guides.dart MENU copy |
| IP-179 | fixed | lib/core/game_guides.dart MENU copy |
| IP-180 | fixed | lib/core/game_guides.dart MENU copy |
| IP-181 | fixed | lib/core/game_guides.dart MENU copy |
| IP-182 | fixed | lib/core/game_guides.dart MENU copy |
| IP-183 | fixed | lib/core/game_guides.dart MENU copy |
| IP-184 | fixed | lib/core/menu_router.dart Train this run |
| IP-185 | fixed | lib/ui/apex_forge_panel.dart TRAIN+b blessings |
| IP-186 | verified-not-real | 11_market.png |
| IP-187 | fixed | lib/ui/shell/home/home_top_bar.dart Cinders row |
| IP-188 | fixed | lib/ui/shell/inventory_dock.dart bag empty copy |
| IP-189 | fixed | lib/ui/shell/settings_overlay.dart remove Spellcraft |
| IP-225 | fixed | lib/core/menu_router.dart STARTER not POUCH |
| IP-226 | fixed | lib/ui/shell/dungeon_top_hud.dart FARM/PUSH wording |
| IP-227 | fixed | hub/menu copy batch 2 |
| IP-228 | fixed | lib/ui/hub_screen.dart ENTER DUNGEON |
| IP-232 | deferred(manual 4x device test) | 4× speed unlock playtest |
| IP-233 | verified-not-real | coach path order checked |
| IP-234 | verified-not-real | lib/ui/shell/wallet_strip.dart @1.45 |
| IP-236 | deferred(code PR) | lib/ui/apex_forge_panel.dart legacy upgrade line |
| IP-237 | verified-not-real | locked-tab toasts unchanged |
| IP-242 | deferred(code PR floaters) | lib/ui/floater_banner_stack.dart overlap |
| IP-243 | verified-not-real | short fight tokens; ellipsis present |
| IP-244 | verified-not-real | short fight tokens; ellipsis present |
| IP-245 | verified-not-real | short fight tokens; ellipsis present |
| IP-246 | fixed | lib/ui/shell/home/hud_pills.dart:105 ellipsis |
| IP-247 | fixed | lib/ui/shell/home/hud_pills.dart:186 ellipsis |
| IP-248 | verified-not-real | short fight tokens; ellipsis present |
| IP-249 | verified-not-real | short fight tokens; ellipsis present |
| IP-250 | verified-not-real | short fight tokens; ellipsis present |
| IP-251 | verified-not-real | short fight tokens; ellipsis present |
| IP-252 | verified-not-real | short fight tokens; ellipsis present |
| IP-253 | fixed | minTouch/Semantics verified batch 3 |
| IP-254 | fixed | minTouch/Semantics verified batch 3 |
| IP-255 | fixed | minTouch/Semantics verified batch 3 |
| IP-256 | fixed | minTouch/Semantics verified batch 3 |
| IP-257 | fixed | minTouch/Semantics verified batch 3 |
| IP-258 | fixed | minTouch/Semantics verified batch 3 |
| IP-265 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-266 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-267 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-268 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-269 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-270 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-271 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-272 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-273 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-274 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-275 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-276 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-277 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-278 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-279 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-280 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-281 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-282 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-283 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-284 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-285 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-286 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-287 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-288 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-289 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-290 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-291 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-292 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-293 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-294 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-295 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-296 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-297 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-298 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-299 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-300 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-301 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-302 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-303 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-304 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-305 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-306 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-307 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-308 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-309 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-310 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-311 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-312 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-313 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-314 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-315 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-316 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-317 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-318 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-319 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-320 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-321 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-322 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-323 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-324 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-325 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-326 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-327 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-328 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-329 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-330 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-331 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-332 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-333 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-334 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-335 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-336 | verified-not-real | ShellLayout.hint or overflow @1.45 |
| IP-337 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-338 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-339 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-340 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-341 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-342 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-343 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-344 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-345 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-346 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-347 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-348 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-349 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-350 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-351 | fixed | batch 4 TextOverflow.ellipsis sweep |
| IP-352 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-353 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-354 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-355 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-356 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-357 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-358 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-359 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-360 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-361 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-362 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-363 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-364 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-365 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-366 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-367 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-368 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-369 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-370 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-371 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-372 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-373 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-374 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-375 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-376 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-377 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-378 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-379 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-380 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-381 | verified-not-real | sweep: overflow or short copy @1.45 |
| IP-382 | verified-not-real | sweep: overflow or short copy @1.45 |

## Summary counts with exact totals summing to 292

| Status | Count |
|--------|------:|
| deferred(5m welcome threshold; owner approval to change) | 1 |
| deferred(code PR apex) | 3 |
| deferred(code PR floaters) | 1 |
| deferred(code PR) | 1 |
| deferred(manual 4x device test) | 1 |
| fixed | 120 |
| verified-not-real | 165 |
| **Total** | **292** |

## Goldens changed (list every path in repo diff vs 751c72ac)

- `test/goldens/after/fight_a56.png`
- `test/goldens/after/fight_hit_a56.png`
- `test/goldens/after/fight_hit_min_a56.png`
- `test/goldens/after/gear_a56.png`
- `test/goldens/after/gold_a56.png`
- `test/goldens/after/home_shell_fight_a56.png`
- `test/goldens/after/home_shell_full_a56.png`
- `test/goldens/after/home_shell_split_a56.png`
- `test/goldens/after/home_shop_compact_a56.png`
- `test/goldens/after/scrolls_a56.png`
- `test/goldens/after/shop_a56.png`
- `test/goldens/widgets/playtest_gear_equip_360_scale145.png`
- `test/goldens/widgets/playtest_home_topbar_elite_411.png`

## CI placeholder

- `flutter analyze lib test --no-fatal-infos`
- Targeted widget tests for touched files
- GitHub: `changelog-main`, `analyze-test`, `compile-kotlin` on PR #138

## Integration spot-check (cursor/integrate-fixlist-751c)

The table above has **165** `verified-not-real` rows (the summary line is not an item). A 32-id spot-check against this branch's source found **29 truly not real**. Three neighboring clips in files those rows already named were real and got `TextOverflow.ellipsis` (no `FittedBox`, no copy change):

- Enemy name on the target HUD used `TextOverflow.clip` (`dungeon_target_hud.dart`, same HUD as IP-095–099).
- God Hand cooldown (`9.9s`) sits in a 28 dp ring (`spatial_dungeon_view.dart`, same view as IP-251/252).
- MERGE slot label `FIRST` / `SECOND` had `maxLines` and no overflow (`bag_combine_slot.dart`, IP-311's file; the item name already ellipsized).

Shop and SCROLLS goldens were rebaked on Linux Flutter 3.47.9 because #138 and #140 both changed the same screens. Paths:

- `test/goldens/after/home_shop_compact_a56.png`
- `test/goldens/after/scrolls_a56.png`
- `test/goldens/after/shop_a56.png`

`test/goldens/after/welcome_back_a56.png` is the #140 image (only that PR changed it). The other #138 goldens are unchanged from that PR.
