import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/chase_contract.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/hub_chase.dart';
import '../core/keystone.dart';
import '../core/local_season.dart';
import '../core/logic_notices.dart';
import '../core/play_games_bridge.dart';
import '../core/play_games_scores.dart';
import '../core/play_leaderboard_ids.dart';
import '../core/rift.dart';
import '../core/greater_rift.dart';
import '../models/achievement_def.dart';
import '../models/dungeon_def.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/meta_depth.dart';
import 'confirm_dialogs.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'save_import_flow.dart';
import 'web_click_bridge.dart';

export 'shell/discord_thanks_overlay.dart';
export 'shell/whats_new_overlay.dart';

/// Local achievements list — unlocked ids come from `GameState.achievements`.
class AchievementsOverlay extends StatelessWidget {
  const AchievementsOverlay({super.key, required this.director});
  final GameDirector director;

  static String _categoryLabel(AchievementCategory c) => switch (c) {
    AchievementCategory.combat => 'COMBAT',
    AchievementCategory.meta => 'META',
    AchievementCategory.explorer => 'EXPLORER',
    AchievementCategory.collector => 'COLLECTOR',
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final unlocked = state.achievements.toSet();
    final byCategory = <AchievementCategory, List<AchievementDef>>{};
    for (final def in AchievementCatalog.all) {
      byCategory.putIfAbsent(def.category, () => <AchievementDef>[]).add(def);
    }
    final categories = AchievementCategory.values
        .where((c) => byCategory.containsKey(c))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.willRankTitle}  ·  score ${state.collectionScore}',
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 14, color: GameTheme.torchHot),
        ),
        if (state.metaDepth.titles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Titles',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final title in state.metaDepth.titles)
                KenneyButton(
                  label: state.metaDepth.activeTitle == title
                      ? '★ $title'
                      : title,
                  expanded: false,
                  style: state.metaDepth.activeTitle == title
                      ? KenneyButtonStyle.brown
                      : KenneyButtonStyle.grey,
                  onPressed: () => director.setActiveTitle(title),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${unlocked.length}/${AchievementCatalog.all.length} UNLOCKED',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              for (final cat in categories) ...[
                MenuChrome.sectionLabelScoped(
                  _categoryLabel(cat),
                  scope: MenuScope.account,
                ),
                const SizedBox(height: 6),
                for (final def in byCategory[cat]!) ...[
                  Builder(
                    builder: (context) {
                      final done = unlocked.contains(def.id);
                      final hide = def.hidden && !done;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: MenuChrome.listCard(
                          borderColor: done
                              ? GameTheme.clear
                              : GameTheme.border,
                        ),
                        child: Row(
                          children: [
                            KenneySprite(
                              asset: done
                                  ? KenneyAssets.iconTrophy
                                  : KenneyAssets.iconSkull,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hide ? 'Hidden' : def.title,
                                    style: GameTheme.body(
                                      size: 15,
                                      color: done
                                          ? GameTheme.torchHot
                                          : GameTheme.parchment,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    hide
                                        ? 'Hidden achievement'
                                        : def.description,
                                    style: GameTheme.body(
                                      size: 14,
                                      color: GameTheme.parchmentDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              hide
                                  ? '---'
                                  : done
                                  ? 'AWARDED'
                                  : '+${def.essenceReward}e',
                              style: GameTheme.body(
                                size: 11,
                                color: done
                                    ? GameTheme.clear
                                    : GameTheme.parchmentDim,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Discovered enemies / items grid — purely cosmetic Codex.
class CodexOverlay extends StatefulWidget {
  const CodexOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<CodexOverlay> createState() => _CodexOverlayState();
}

class _CodexOverlayState extends State<CodexOverlay> {
  bool _showEnemies = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final entries = _showEnemies ? state.codexEnemies : state.codexItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'MONSTERS (${state.codexEnemies.length})',
                style: _showEnemies
                    ? KenneyButtonStyle.brown
                    : KenneyButtonStyle.grey,
                onPressed: () => setState(() => _showEnemies = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: 'ITEMS (${state.codexItems.length})',
                style: !_showEnemies
                    ? KenneyButtonStyle.brown
                    : KenneyButtonStyle.grey,
                onPressed: () => setState(() => _showEnemies = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Codex ${GameLogic.codexCompletionPercent(state)}%  |  '
          '${state.codexEnemies.length + state.codexItems.length} discovered '
          '(goal ${GameLogic.expectedCodexEntries} entries)',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: GameLogic.codexRewardTiers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final entry = GameLogic.codexRewardTiers.entries.elementAt(i);
              final claimed = state.metaDepth.codexClaims.contains(entry.key);
              final pct = GameLogic.codexCompletionPercent(state);
              final ready = pct >= entry.value.pct && !claimed;
              final locked = pct < entry.value.pct;
              return KenneyButton(
                label: claimed
                    ? '${entry.value.pct}% done'
                    : locked
                    ? 'Need ${entry.value.pct}%'
                    : '${entry.value.pct}% +${entry.value.reward}e',
                expanded: false,
                style: ready
                    ? KenneyButtonStyle.brown
                    : KenneyButtonStyle.grey,
                onPressed: ready
                    ? () => widget.director.claimCodexReward(entry.key)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _showEnemies
                        ? 'No monsters discovered yet. Fight your way through a dungeon.'
                        : 'No items discovered yet. Clear floors for gear drops.',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 15,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final name = entries[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: MenuChrome.listCard(inset: true),
                        child: Row(
                          children: [
                            KenneySprite(
                              asset: _showEnemies
                                  ? KenneyAssets.enemySpriteForCodexName(name)
                                  : KenneyAssets.codexItemIconFor(name),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: GameTheme.body(size: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Save/apply up to 3 named gear presets.
class TeamCompositionOverlay extends StatefulWidget {
  const TeamCompositionOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<TeamCompositionOverlay> createState() => _TeamCompositionOverlayState();
}

class _TeamCompositionOverlayState extends State<TeamCompositionOverlay> {
  String? _pendingSlotReplace;

  GameDirector get director => widget.director;

  void _toast(String msg) => director.showToast(msg, life: 2.4);

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final maxSlots = state.maxActivePartySize;
    final active = state.heroes;
    final hasTank = active.any((h) => h.spec.isTank);
    final hasHeal = active.any((h) => h.spec.isHealer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.inDungeon
              ? 'Leave the dungeon to change your lineup.'
              : 'Pick up to $maxSlots active heroes from your roster.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (!hasTank || !hasHeal) ...[
          const SizedBox(height: 6),
          Text(
            [if (!hasTank) 'No Shield', if (!hasHeal) 'No Healer'].join(' · '),
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        ],
        const SizedBox(height: 10),
        MenuChrome.sectionLabelScoped('ACTIVE', scope: MenuScope.account),
        const SizedBox(height: 6),
        for (var i = 0; i < maxSlots; i++) ...[
          _ActiveSlotChip(
            index: i,
            hero: i < active.length ? active[i] : null,
            selected:
                _pendingSlotReplace ==
                (i < active.length ? active[i].id : 'empty_$i'),
            locked: state.inDungeon,
            onTap: state.inDungeon
                ? null
                : () {
                    if (i < active.length) {
                      setState(() {
                        _pendingSlotReplace = active[i].id;
                      });
                    } else {
                      setState(() => _pendingSlotReplace = 'empty_$i');
                    }
                  },
            onClear: state.inDungeon || i >= active.length
                ? null
                : () {
                    final ids = [
                      for (final h in active)
                        if (h.id != active[i].id) h.id,
                    ];
                    if (ids.isEmpty) {
                      _toast('Need at least one hero');
                      return;
                    }
                    director.setActiveParty(ids);
                    setState(() => _pendingSlotReplace = null);
                  },
          ),
          const SizedBox(height: 6),
        ],
        if (!state.metaDepth.partySlot5Unlocked) ...[
          const SizedBox(height: 8),
          KenneyButton(
            label:
                'UNLOCK 5TH SLOT  ${GameLogic.partySlot5EssenceCost}e  AL${GameLogic.partySlot5MinAscension}+',
            style: KenneyButtonStyle.brown,
            onPressed:
                state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
                    state.essence >= GameLogic.partySlot5EssenceCost
                ? () {
                    director.unlockPartySlot5();
                  }
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            'Same buy as POWER → FORGE → KEEP.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 12),
        MenuChrome.sectionLabelScoped('ROSTER', scope: MenuScope.account),
        const SizedBox(height: 6),
        for (final classId in HeroClassId.values) ...[
          Text(
            HeroSpecs.classLabel(classId),
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 4),
          for (final specId in HeroSpecs.forClass(classId))
            _RosterSpecRow(
              def: HeroSpecs.def(specId),
              unlocked: state.isSpecUnlocked(specId),
              onRoster: state.heroRoster.any((h) => h.specId == specId),
              inActive: active.any((h) => h.specId == specId),
              disabled: state.inDungeon,
              onUnlock: () {
                director.unlockSpec(specId);
              },
              onAdd: () {
                PartyHero? hero;
                for (final h in state.heroRoster) {
                  if (h.specId == specId) {
                    hero = h;
                    break;
                  }
                }
                if (hero == null) return;
                if (active.any((h) => h.id == hero!.id)) {
                  _toast('Already active');
                  return;
                }
                if (active.length >= maxSlots) {
                  if (_pendingSlotReplace != null &&
                      !_pendingSlotReplace!.startsWith('empty_')) {
                    final ids = [
                      for (final h in active)
                        if (h.id == _pendingSlotReplace) hero.id else h.id,
                    ];
                    director.setActiveParty(ids);
                    setState(() => _pendingSlotReplace = null);
                    return;
                  }
                  _toast('Party full — tap an active slot to replace');
                  return;
                }
                director.setActiveParty([...state.activeHeroIds, hero.id]);
                setState(() => _pendingSlotReplace = null);
              },
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ActiveSlotChip extends StatelessWidget {
  const _ActiveSlotChip({
    required this.index,
    required this.hero,
    required this.selected,
    required this.locked,
    this.onTap,
    this.onClear,
  });

  final int index;
  final PartyHero? hero;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = hero == null
        ? 'SLOT ${index + 1}'
        : '${hero!.name} · ${hero!.roleLabel}';
    return Row(
      children: [
        Expanded(
          child: KenneyButton(
            label: label,
            style: selected ? KenneyButtonStyle.brown : KenneyButtonStyle.grey,
            onPressed: onTap,
          ),
        ),
        if (onClear != null && !locked) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: KenneyButton(
              label: 'X',
              style: KenneyButtonStyle.grey,
              expanded: false,
              onPressed: onClear,
            ),
          ),
        ],
      ],
    );
  }
}

class _RosterSpecRow extends StatelessWidget {
  const _RosterSpecRow({
    required this.def,
    required this.unlocked,
    required this.onRoster,
    required this.inActive,
    required this.disabled,
    required this.onUnlock,
    required this.onAdd,
  });

  final HeroSpecDef def;
  final bool unlocked;
  final bool onRoster;
  final bool inActive;
  final bool disabled;
  final VoidCallback onUnlock;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final status = !unlocked
        ? (def.unlockHint.isEmpty ? 'LOCKED' : def.unlockHint)
        : inActive
        ? 'ACTIVE'
        : onRoster
        ? 'BENCH'
        : 'READY';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${def.name}\n$status',
              style: GameTheme.body(
                size: 12,
                color: unlocked ? GameTheme.parchment : GameTheme.parchmentDim,
              ),
            ),
          ),
          if (!unlocked)
            KenneyButton(
              label: 'UNLOCK',
              expanded: false,
              style: KenneyButtonStyle.grey,
              onPressed: disabled ? null : onUnlock,
            )
          else if (!inActive && onRoster)
            KenneyButton(
              label: 'ADD',
              expanded: false,
              style: KenneyButtonStyle.brown,
              onPressed: disabled ? null : onAdd,
            ),
        ],
      ),
    );
  }
}

/// Rich offline progress breakdown — replaces the plain toast with a
/// full-detail dialog the player must dismiss.
Future<void> showOfflineProgressDialog(
  BuildContext context,
  GameDirector director, {
  void Function(HubChaseKind kind)? onOpenParty,
  VoidCallback? onOpenMarket,
  void Function(String dungeonId)? onEnterDungeon,
}) async {
  final summary = director.offlineSummary;
  if (summary == null) return;
  final contract = ChaseContract.fromState(summary.state);
  final chase = contract.chase;
  final rows = summary.highlightRows;
  final notices = List<String>.from(
    LogicNotices.metaPayoffs,
  ).take(2).toList(growable: false);

  VoidCallback? readyAction;
  var readyLabel = contract.readyActionLabel ?? '';
  switch (chase.kind) {
    case HubChaseKind.claimDailyVault:
      readyAction = () {
        director.claimDailyVault();
        director.dismissOfflineSummary();
        Navigator.pop(context);
      };
    case HubChaseKind.claimMissions:
      readyAction = () {
        director.claimAllReadyMissions();
        director.dismissOfflineSummary();
        Navigator.pop(context);
      };
    case HubChaseKind.monthGoal:
      readyAction = () {
        director.claimMonthPass();
        director.dismissOfflineSummary();
        Navigator.pop(context);
      };
    case HubChaseKind.ascend:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        confirmAscend(context, director);
      };
    case HubChaseKind.dailyRun:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        confirmDailyRun(context, director);
      };
    case HubChaseKind.keystone:
      final key = chase.keyLevel ?? 1;
      readyLabel = 'ENTER KEY +$key';
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        director.setHardmodeLevel(key);
        final id =
            chase.zoneId ?? GameLogic.recommendedDungeonId(director.state);
        final unlocked = DungeonCatalog.isUnlocked(
          id,
          GameLogic.partyMeanLevel(director.state),
          director.state.highestDungeonCleared,
        );
        if (unlocked) {
          if (onEnterDungeon != null) {
            onEnterDungeon(id);
          } else {
            director.enterDungeon(dungeonId: id);
          }
        }
      };
    case HubChaseKind.gauntletMilestone:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        confirmGauntletRun(context, director);
      };
    case HubChaseKind.riftMilestone:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        confirmRiftRun(context, director);
      };
    case HubChaseKind.greaterRiftMilestone:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        confirmGreaterRiftRun(context, director);
      };
    case HubChaseKind.ashenCrown:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        director.enterAshenCrown();
      };
    case HubChaseKind.meetHero:
      readyLabel = 'PARTY';
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        // Hub passes onOpenParty. Fallback: open still works via toast only.
        if (onOpenParty != null) {
          onOpenParty(HubChaseKind.meetHero);
        }
      };
    case HubChaseKind.equipBag:
      readyLabel = 'PARTY';
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        onOpenParty?.call(HubChaseKind.equipBag);
      };
    case HubChaseKind.marketUpgrade:
      readyLabel = 'MARKET';
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        onOpenMarket?.call();
      };
    case HubChaseKind.unlockZone:
    case HubChaseKind.clearFloors:
    case HubChaseKind.dailyVaultProgress:
      final id = chase.zoneId ?? GameLogic.recommendedDungeonId(summary.state);
      readyLabel = 'ENTER';
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        final unlocked = DungeonCatalog.isUnlocked(
          id,
          GameLogic.partyMeanLevel(director.state),
          director.state.highestDungeonCleared,
        );
        if (unlocked) {
          if (onEnterDungeon != null) {
            onEnterDungeon(id);
          } else {
            director.enterDungeon(dungeonId: id);
          }
        }
      };
    default:
      break;
  }

  final showChaseCta = readyAction != null &&
      (chase.urgency == HubChaseUrgency.ready ||
          chase.urgency == HubChaseUrgency.almost ||
          chase.kind == HubChaseKind.keystone ||
          chase.kind == HubChaseKind.unlockZone ||
          chase.kind == HubChaseKind.clearFloors ||
          chase.kind == HubChaseKind.dailyVaultProgress ||
          chase.kind == HubChaseKind.marketUpgrade);

  WebClickBridge.pushLayer();
  await showDialog<void>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'Welcome back!',
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Away for ${OfflineProgressResult.formatOfflineDuration(summary.secondsApplied)}',
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
              const SizedBox(height: 6),
              Text(
                summary.welcomeLead,
                style: GameTheme.body(size: 14, color: GameTheme.torchHot),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final row in rows)
                  MenuChrome.statRow(label: row.$1, value: row.$2),
              ],
              if (notices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notices.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 13, color: GameTheme.mossLit),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                contract.upNextLine,
                style: GameTheme.body(
                  size: 14,
                  color: chase.urgency == HubChaseUrgency.normal
                      ? GameTheme.mossLit
                      : GameTheme.accentWarn,
                ),
              ),
              Text(
                chase.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
              if (contract.ascendTeaser != null &&
                  contract.ascendTeaser!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contract.ascendTeaser!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 13, color: GameTheme.torch),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (showChaseCta) ...[
          KenneyButton(
            label: readyLabel,
            expanded: false,
            style: KenneyButtonStyle.brown,
            onPressed: readyAction,
          ),
        ],
        KenneyButton(
          label: 'NICE',
          expanded: false,
          onPressed: () {
            director.dismissOfflineSummary();
            Navigator.pop(ctx);
          },
        ),
      ],
    ),
  ).whenComplete(WebClickBridge.popLayer);
}

/// Keystone run prefs — set before entering a dungeon (Mythic+-style).
class ChallengeToggles extends StatefulWidget {
  const ChallengeToggles({
    super.key,
    required this.director,
    this.collapsed = false,
  });
  final GameDirector director;
  final bool collapsed;

  @override
  State<ChallengeToggles> createState() => _ChallengeTogglesState();
}

class _ChallengeTogglesState extends State<ChallengeToggles> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final keyOn = widget.director.state.hardmodeLevel > 0 ||
        GameLogic.endgameUnlocked(widget.director.state) ||
        widget.director.state.challengeBossRush ||
        widget.director.state.challengeNoFlask ||
        widget.director.state.challengeTiny;
    _expanded = !widget.collapsed || keyOn;
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final state = director.state;
    final md = state.metaDepth;
    final maxKey = state.effectiveMaxHardmode;
    final vaultReady = GameLogic.canClaimDailyVault(state);
    final affixes = Keystone.previewAffixes(state);
    final vaultE = GameLogic.dailyVaultClaimPreviewEssence(state);
    final weekKey = md.weeklyKey.isNotEmpty
        ? md.weeklyKey
        : GameLogic.isoWeekKey(DateTime.now().toUtc());
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    final weekClaimed = LocalSeasonCatalog.weekGoalClaimed(state, week);
    final weekReady = LocalSeasonCatalog.weekGoalReady(state, week);
    final weekAlmost = LocalSeasonCatalog.weekGoalAlmost(state, week);
    final month = LocalSeasonCatalog.forMonthKey(
      md.seasonKey.contains('·')
          ? md.seasonKey.split('·').last.trim()
          : GameLogic.isoMonthKey(DateTime.now().toUtc()),
    );
    final activeBits = <String>[
      if (state.hardmodeLevel > 0) 'KEY+${state.hardmodeLevel}',
      if (state.challengeBossRush) 'Boss Rush',
      if (state.challengeNoFlask) 'No Flask',
      if (state.challengeTiny) 'Tiny',
      if (vaultReady) 'Vault ready',
    ];
    final chase = ChaseContract.fromState(state);

    final headerLabel = _expanded
        ? (activeBits.isEmpty
              ? '▾ KEYSTONE off'
              : '▾ KEYSTONE ${activeBits.join(' · ')}')
        : (activeBits.isEmpty
              ? '▸ KEYSTONE off'
              : '▸ KEYSTONE ${activeBits.join(' · ')}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebClickScope(
          label: headerLabel,
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Semantics(
            button: true,
            label: headerLabel,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _expanded ? '▾ KEYSTONE' : '▸ KEYSTONE',
                      style: GameTheme.body(size: 12, color: GameTheme.torchHot),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeBits.isEmpty ? 'off' : activeBits.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 4),
          _HardmodeStepper(
            level: state.hardmodeLevel,
            maxLevel: maxKey,
            onChanged: director.setHardmodeLevel,
          ),
          const SizedBox(height: 4),
          Text(
            state.hardmodeLevel <= 0
                ? 'KEY +0 (normal) · no key loot bonus · max KEY +$maxKey'
                : 'KEY +${state.hardmodeLevel} · loot +${Keystone.lootItemLevelBonus(state.hardmodeLevel)} iLvl · ${Keystone.goldMulLabel(state.hardmodeLevel)}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          if (affixes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in affixes)
                  _KeyAffixChip(
                    label: Keystone.label(a),
                    blurb: Keystone.blurb(a),
                    risk: Keystone.riskTier(a),
                  ),
              ],
            ),
          ],
          if (week.hasGoal) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: MenuChrome.cardBox(selected: weekReady || weekAlmost),
              child: Column(
                children: [
                  Text(
                    weekReady
                        ? 'WEEK GOAL READY'
                        : weekAlmost
                        ? 'WEEK GOAL ALMOST'
                        : 'WEEK GOAL',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 12,
                      color: weekReady || weekAlmost
                          ? GameTheme.torchHot
                          : GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    week.name,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 13, color: GameTheme.parchment),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekClaimed
                        ? 'Claimed · ${week.titleReward ?? week.name}'
                        : '${week.blurb}\n'
                              '${LocalSeasonCatalog.weekProgressLabel(state, week)}'
                              '${weekReady ? ' · auto-claims on hub sync' : ''}',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ChallengeChip(
                  label: 'BOSS RUSH',
                  active: state.challengeBossRush,
                  onTap: () =>
                      director.setChallengeBossRush(!state.challengeBossRush),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChallengeChip(
                  label: 'NO FLASK',
                  active: state.challengeNoFlask,
                  onTap: () =>
                      director.setChallengeNoFlask(!state.challengeNoFlask),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Boss Rush: bosses only · No Flask: healing flasks disabled',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
          const SizedBox(height: 6),
          _ChallengeChip(
            label: 'TINY (3 heroes)',
            active: state.challengeTiny,
            onTap: () => director.setChallengeTiny(!state.challengeTiny),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Tiny: run with 3 heroes max — harder, smaller party',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
          if (state.metaDepth.challengeBestBossRushKey > 0 ||
              state.metaDepth.challengeBestNoFlaskKey > 0 ||
              state.metaDepth.challengeBestTinyKey > 0) ...[
            const SizedBox(height: 4),
            Text(
              'PB · Rush +${state.metaDepth.challengeBestBossRushKey} · '
              'Flask +${state.metaDepth.challengeBestNoFlaskKey} · '
              'Tiny +${state.metaDepth.challengeBestTinyKey}',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ],
          Text(
            'Power ${GameLogic.partyPowerScore(state)} · sheet score (not a clear guarantee)',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: MenuChrome.cardBox(selected: vaultReady),
            child: Column(
              children: [
                Text(
                  'DAILY VAULT',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: vaultReady
                        ? GameTheme.torchHot
                        : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  md.dailyVaultClaimed
                      ? 'Today: claimed'
                      : 'Today: clears ${md.dailyVaultClears}/'
                            '${GameLogic.dailyVaultClearTarget}'
                            ' · best timed KEY +${md.dailyBestTimedKey}'
                            '${vaultReady ? ' · ready' : ''}',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  md.seasonKey.isEmpty
                      ? 'Season: rotating…'
                      : 'Season: ${month.name} · '
                            '+${GameLogic.seasonWeeklyBonusEssence}e '
                            'first vault claim',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                if (vaultReady) ...[
                  const SizedBox(height: 6),
                  KenneyButton(
                    label: 'CLAIM VAULT  +${vaultE}e',
                    onPressed: director.claimDailyVault,
                  ),
                ],
              ],
            ),
          ),
          if (GameLogic.endgameUnlocked(state)) ...[
            const SizedBox(height: 6),
            Text(
              'TODAY · ${chase.title}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            !GameLogic.endgameUnlocked(state)
                ? 'KEYSTONE unlocks at party level ${GameLogic.maxHeroLevel} with Gauntlet and Rift.'
                : 'Timed boss under par upgrades KEY. Vault: 1 clear or timed KEY+2.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }
}

/// META → KEY: Rift tier dial (party max-level endgame).
class RiftHubPanel extends StatelessWidget {
  const RiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'RIFT unlocks at party level ${GameLogic.maxHeroLevel} — timed kill challenges with escalating tiers.',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.riftBestTier;
    final maxSel = Rift.maxSelectableTier(best);
    final pref = Rift.clampTier(
      state.metaDepth.riftPreferredTier.clamp(Rift.minTier, maxSel),
    );
    final kills = Rift.killTarget(pref);
    final par = Rift.formatTimer(Rift.parTimeMs(pref));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'RIFT',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Farm Rift — gold and gear mid-run. Best R$best · kill $kills before $par · '
          '+${Rift.successEssence(pref)}e / +${Rift.successGold(pref)}g',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            MenuChrome.stepperButton(
              label: 'RIFT -',
              sign: '-',
              onPressed: pref > Rift.minTier
                  ? () => director.setRiftPreferredTier(pref - 1)
                  : null,
            ),
            Expanded(
              child: Text(
                'R$pref',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
            ),
            MenuChrome.stepperButton(
              label: 'RIFT +',
              sign: '+',
              onPressed: pref < maxSel
                  ? () => director.setRiftPreferredTier(pref + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'ENTER RIFT R$pref',
          style: KenneyButtonStyle.brown,
          onPressed: GameLogic.canEnterRift(state)
              ? () => confirmRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}

/// META → KEY: Greater Rift tier dial (party max-level prestige + boards).
class GreaterRiftHubPanel extends StatelessWidget {
  const GreaterRiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'GREATER RIFT unlocks at party level ${GameLogic.maxHeroLevel} — '
        'prestige ladder ranked on BOARDS.',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.grBestTier;
    final maxSel = GreaterRift.maxSelectableTier(best);
    final pref = GreaterRift.clampTier(
      state.metaDepth.grPreferredTier.clamp(GreaterRift.minTier, maxSel),
    );
    final kills = GreaterRift.killTarget(pref);
    final par = GreaterRift.formatTimer(GreaterRift.parTimeMs(pref));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GREATER RIFT',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Best GR$best · kill $kills before $par · '
          '+${GreaterRift.successEssence(pref)}e / +${GreaterRift.successGold(pref)}g · '
          'no mid-run gear',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            MenuChrome.stepperButton(
              label: 'GR -',
              sign: '-',
              onPressed: pref > GreaterRift.minTier
                  ? () => director.setGrPreferredTier(pref - 1)
                  : null,
            ),
            Expanded(
              child: Text(
                'GR$pref',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
            ),
            MenuChrome.stepperButton(
              label: 'GR +',
              sign: '+',
              onPressed: pref < maxSel
                  ? () => director.setGrPreferredTier(pref + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'ENTER GR$pref',
          style: KenneyButtonStyle.red,
          onPressed: GameLogic.canEnterGreaterRift(state)
              ? () => confirmGreaterRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}

class _HardmodeStepper extends StatelessWidget {
  const _HardmodeStepper({
    required this.level,
    required this.maxLevel,
    required this.onChanged,
  });
  final int level;
  final int maxLevel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: MenuChrome.cardBox(selected: level > 0),
      child: Row(
        children: [
          MenuChrome.stepperButton(
            label: 'KEYSTONE -',
            sign: '-',
            onPressed: level > 0 ? () => onChanged(level - 1) : null,
            size: 36,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  level <= 0 ? 'KEYSTONE  OFF' : 'KEYSTONE  +$level',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: level > 0
                        ? GameTheme.torchHot
                        : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '0 = normal  ·  max +$maxLevel (AL)',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
          MenuChrome.stepperButton(
            label: 'KEYSTONE +',
            sign: '+',
            onPressed: level < maxLevel ? () => onChanged(level + 1) : null,
            size: 36,
          ),
        ],
      ),
    );
  }
}

class _KeyAffixChip extends StatelessWidget {
  const _KeyAffixChip({
    required this.label,
    required this.blurb,
    required this.risk,
  });

  final String label;
  final String blurb;
  final String risk;

  Color get _riskColor => switch (risk) {
    'Soft' => GameTheme.mossLit,
    'Brutal' => GameTheme.bloodLit,
    _ => GameTheme.accentWarn,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GameTheme.panelInset,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        border: Border.all(color: _riskColor.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              risk,
              style: GameTheme.pixel(size: 8, color: _riskColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label · $blurb',
            style: GameTheme.body(size: 11, color: GameTheme.parchment),
          ),
        ],
      ),
    );
  }
}

class _ChallengeChip extends StatelessWidget {
  const _ChallengeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
              alignment: Alignment.center,
              decoration: MenuChrome.listCard(selected: active),
              child: Text(
                label,
                style: GameTheme.body(
                  size: 14,
                  color: active ? GameTheme.torchHot : GameTheme.parchmentDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Save export/import — clipboard JSON, no servers involved.
class SaveTransferSection extends StatelessWidget {
  const SaveTransferSection({super.key, required this.director});
  final GameDirector director;

  Future<void> _export(BuildContext context) async {
    final json = director.exportSaveJson();
    await Clipboard.setData(ClipboardData(text: json));
    director.showToast('Save copied to clipboard');
  }

  Future<void> _import(BuildContext context) async {
    await SaveImportFlow.fromClipboard(context: context, director: director);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save transfer (clipboard)',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'EXPORT',
                style: KenneyButtonStyle.grey,
                onPressed: () => _export(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: 'IMPORT',
                style: KenneyButtonStyle.grey,
                onPressed: () => _import(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Export copies JSON to clipboard — paste somewhere safe as a backup.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
      ],
    );
  }
}

/// Shared busy flag + Play Games sign-in / cloud restore dialogs.
mixin _PlayGamesActions<T extends StatefulWidget> on State<T> {
  bool playGamesBusy = false;

  GameDirector get playGamesDirector;

  Future<void> runPlayGames(Future<void> Function() action) async {
    if (playGamesBusy) return;
    setState(() => playGamesBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => playGamesBusy = false);
    }
  }

  Future<void> signInPlayGamesFlow() => runPlayGames(() async {
    final director = playGamesDirector;
    final ok = await director.signInPlayGames();
    if (!ok || !mounted) return;
    final cloud = await director.loadPlayGamesCloud();
    if (cloud == null || !mounted) return;
    final conflict = director.peekCloudConflict(cloud);
    if (conflict != CloudConflict.askUser) return;
    final useCloud = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Cloud save differs',
        content: Text(
          'This device:\n${director.playGamesConflictHint(director.state)}\n\n'
          'Play Games:\n${director.playGamesConflictHint(cloud)}\n\n'
          'Which save should we keep?',
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'KEEP DEVICE',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'USE CLOUD',
            style: KenneyButtonStyle.brown,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (useCloud == true) {
      await director.restoreFromPlayGames(force: true);
    }
  });

  Future<void> restorePlayGamesFlow() => runPlayGames(() async {
    final director = playGamesDirector;
    final cloud = await director.loadPlayGamesCloud();
    if (cloud == null) {
      director.showToast('No Play Games save found', life: 2.2);
      return;
    }
    final conflict = director.peekCloudConflict(cloud);
    if (conflict == CloudConflict.askUser && mounted) {
      final useCloud = await showDialog<bool>(
        context: context,
        barrierColor: MenuChrome.scrim,
        builder: (ctx) => MenuChrome.dialog(
          title: 'Restore from Play Games?',
          content: Text(
            'This device:\n${director.playGamesConflictHint(director.state)}\n\n'
            'Play Games:\n${director.playGamesConflictHint(cloud)}',
            style: GameTheme.body(size: 14, color: GameTheme.parchment),
          ),
          actions: [
            MenuChrome.dialogCancel(
              label: 'CANCEL',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            KenneyButton(
              label: 'RESTORE',
              style: KenneyButtonStyle.red,
              expanded: false,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (useCloud != true) return;
      await director.restoreFromPlayGames(force: true);
      return;
    }
    await director.restoreFromPlayGames(
      force: conflict == CloudConflict.preferCloud,
    );
  });
}

/// META → KEY: seasonal Timed KEY + Gauntlet boards (Google hosts).
class PlayGamesBoardsSection extends StatefulWidget {
  const PlayGamesBoardsSection({super.key, required this.director});
  final GameDirector director;

  @override
  State<PlayGamesBoardsSection> createState() => _PlayGamesBoardsSectionState();
}

class _PlayGamesBoardsSectionState extends State<PlayGamesBoardsSection>
    with _PlayGamesActions {
  @override
  GameDirector get playGamesDirector => widget.director;

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final md = director.state.metaDepth;
    final month = md.leaderboardSeasonKey.isNotEmpty
        ? md.leaderboardSeasonKey
        : GameLogic.isoMonthKey(DateTime.now().toUtc());
    final timedLabel = md.seasonBestTimedKey > 0
        ? PlayGamesScores.formatTimedLabel(
            md.seasonBestTimedKey,
            md.seasonBestTimedClearMs,
          )
        : 'No timed KEY yet';
    final gauntletLabel = md.seasonBestGauntletFloor > 0
        ? 'Gauntlet F${md.seasonBestGauntletFloor}'
        : 'No Gauntlet floor yet';
    final grLabel = md.seasonBestGrTier > 0
        ? PlayGamesScores.formatGreaterRiftLabel(
            md.seasonBestGrTier,
            md.seasonBestGrClearMs,
          )
        : 'No Greater Rift yet';
    final boardsReady = PlayLeaderboardIds.hasBoards(month);
    final grBoardReady = PlayLeaderboardIds.hasGreaterRiftBoard(month);
    final signedIn = PlayGamesBridge.isSignedInCached || md.playGamesOptIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BOARDS',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Season $month · Timed KEY + Gauntlet + Greater Rift (Play Games)',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Text(
          timedLabel,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          gauntletLabel,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          grLabel,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        if (!signedIn) ...[
          const SizedBox(height: 8),
          KenneyButton(
            label: 'SIGN IN TO RANK',
            style: KenneyButtonStyle.brown,
            onPressed: playGamesBusy ? null : signInPlayGamesFlow,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'VIEW KEY',
                style: KenneyButtonStyle.grey,
                onPressed: playGamesBusy || !boardsReady
                    ? null
                    : () => runPlayGames(director.showPlayTimedLeaderboard),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: 'VIEW GAUNTLET',
                style: KenneyButtonStyle.grey,
                onPressed: playGamesBusy || !boardsReady
                    ? null
                    : () => runPlayGames(director.showPlayGauntletLeaderboard),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: 'VIEW GR',
          style: KenneyButtonStyle.grey,
          onPressed: playGamesBusy || !grBoardReady
              ? null
              : () => runPlayGames(director.showPlayGreaterRiftLeaderboard),
        ),
        const SizedBox(height: 6),
        Text(
          boardsReady
              ? signedIn
                    ? 'New season PBs submit while signed in. Cloud save: SETTINGS.'
                    : 'Sign in to submit ranks. Cloud save stays under SETTINGS.'
              : 'Leaderboard IDs not set yet — add them in Play Console, then '
                    'paste into play_leaderboard_ids.dart.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (!grBoardReady) ...[
          const SizedBox(height: 4),
          Text(
            'Greater Rift board ID empty — create in Play Console, then paste.',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }
}

/// META → SETTINGS: Play Games sign-in + cloud backup (boards live under KEY).
class PlayGamesSection extends StatefulWidget {
  const PlayGamesSection({super.key, required this.director});
  final GameDirector director;

  @override
  State<PlayGamesSection> createState() => _PlayGamesSectionState();
}

class _PlayGamesSectionState extends State<PlayGamesSection>
    with _PlayGamesActions {
  @override
  GameDirector get playGamesDirector => widget.director;

  @override
  Widget build(BuildContext context) {
    final md = widget.director.state.metaDepth;
    final month = md.leaderboardSeasonKey.isNotEmpty
        ? md.leaderboardSeasonKey
        : GameLogic.isoMonthKey(DateTime.now().toUtc());
    final signedIn = PlayGamesBridge.isSignedInCached || md.playGamesOptIn;
    final lastBackup = PlayGamesBridge.lastCloudUploadAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PLAY GAMES',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Season $month · cloud backup. Boards: META → KEY.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (lastBackup != null) ...[
          const SizedBox(height: 4),
          Text(
            'Last cloud backup · ${lastBackup.toLocal()}',
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 8),
        KenneyButton(
          label: signedIn ? 'SIGNED IN' : 'SIGN IN WITH PLAY GAMES',
          style: KenneyButtonStyle.brown,
          onPressed: playGamesBusy || signedIn ? null : signInPlayGamesFlow,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'BACKUP NOW',
                style: KenneyButtonStyle.grey,
                onPressed: playGamesBusy
                    ? null
                    : () => runPlayGames(() async {
                        await widget.director.backupToPlayGames();
                      }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: 'RESTORE',
                style: KenneyButtonStyle.grey,
                onPressed: playGamesBusy ? null : restorePlayGamesFlow,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// AL-gated essence sinks that survive Ascend.
class PrestigeShopOverlay extends StatelessWidget {
  const PrestigeShopOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.ascensionLevel < 3) ...[
          Text(
            'Browse freely — buying unlocks at Ascension Level 3+.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Essence shop — permanent upgrades that survive Ascend.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Text(
          '${state.essence} essence · AL${state.ascensionLevel}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: PrestigeShopCatalog.offered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = PrestigeShopCatalog.offered[i];
              final locked = state.ascensionLevel < item.minAl;
              final ownedCount = switch (item.id) {
                'stash_slot' => state.metaDepth.stashBonusSlots ~/ 2,
                'combine_luck' => state.metaDepth.combinatorLuck,
                'torch_keep' => state.metaDepth.torchKeepLevel,
                'gh_cdr' => state.metaDepth.godHandCdLevel,
                'roster_cap' => state.metaDepth.petRosterCapBonus ~/ 2,
                'loadout_slot' => state.metaDepth.loadoutBonusSlots,
                'flask_discount' => state.metaDepth.marketDiscountLevel,
                'filter_span' => state.metaDepth.filterSpanLevel,
                'offline_ledger' => state.metaDepth.offlineHighlightBonus,
                'legacy_spark' => state.metaDepth.legacyPoints,
                'daily_essence' => state.metaDepth.dailyEssenceBonusLevel,
                'gauntlet_gold' => state.metaDepth.gauntletGoldBonusLevel,
                _ => 0,
              };
              final atCap = switch (item.id) {
                'stash_slot' => state.metaDepth.stashBonusSlots >= 20,
                'combine_luck' => state.metaDepth.combinatorLuck >= 5,
                'torch_keep' => state.metaDepth.torchKeepLevel >= 10,
                'gh_cdr' => state.metaDepth.godHandCdLevel >= 8,
                'roster_cap' => state.metaDepth.petRosterCapBonus >= 10,
                'loadout_slot' => state.metaDepth.loadoutBonusSlots >= 2,
                'flask_discount' => state.metaDepth.marketDiscountLevel >= 5,
                'filter_span' => state.metaDepth.filterSpanLevel >= 5,
                'offline_ledger' => state.metaDepth.offlineHighlightBonus >= 3,
                'legacy_spark' => state.metaDepth.legacyPoints >= 20,
                'daily_essence' => state.metaDepth.dailyEssenceBonusLevel >= 5,
                'gauntlet_gold' => state.metaDepth.gauntletGoldBonusLevel >= 5,
                _ => false,
              };
              final canBuy = !locked && !atCap && state.essence >= item.cost;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: MenuChrome.listCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.name,
                      style: GameTheme.body(
                        size: 15,
                        color: locked
                            ? GameTheme.parchmentDim
                            : GameTheme.torchHot,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: GameTheme.body(
                        size: 14,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final have = _prestigeHaveLine(state, item.id);
                        if (have.isEmpty) return const SizedBox.shrink();
                        return Text(
                          have,
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.mossLit,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locked
                                ? 'Needs AL${item.minAl}'
                                : atCap
                                ? 'MAX'
                                : '${item.cost}e'
                                      '${ownedCount > 0 ? ' · x$ownedCount' : ''}',
                            style: GameTheme.body(
                              size: 13,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ),
                        KenneyButton(
                          label: locked
                              ? 'AL${item.minAl}+'
                              : atCap
                              ? 'MAX'
                              : 'BUY ${item.cost}e',
                          expanded: false,
                          onPressed: canBuy
                              ? () => director.buyPrestigeShopItem(item.id)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _prestigeHaveLine(GameState state, String id) {
    final md = state.metaDepth;
    return switch (id) {
      'stash_slot' => 'Have ${md.stashBonusSlots} extra bag slots (max 20)',
      'combine_luck' =>
        'Luck ${md.combinatorLuck}/5 · MERGE −${md.combinatorLuck * 3}g',
      'torch_keep' =>
        'Now +${state.torchOfflineGoldPercent}% hub AFK gold (max 80%)',
      'gh_cdr' =>
        'CD ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · '
            'Lv${md.godHandCdLevel}/8 · same as Forge KEEP',
      'roster_cap' => 'Roster +${md.petRosterCapBonus} (max +10)',
      'loadout_slot' =>
        'Loadouts ${GameLogic.maxLoadoutsFor(state)} '
            '(base 3 · shop +${md.loadoutBonusSlots}/2)',
      'flask_discount' =>
        'Market −${md.marketDiscountLevel * 5}% gold (max 25%)',
      'filter_span' =>
        'Auto-sell/scrap max iLvl ${GameLogic.maxAutoSellIlvlCap(state)} '
            '(+${md.filterSpanLevel * 8} from shop)',
      'offline_ledger' =>
        'Welcome Back rows ${3 + md.offlineHighlightBonus} (max 6)',
      'legacy_spark' => 'Legacy ATK +${md.legacyPoints} (max 20)',
      'daily_essence' =>
        'Vault claim +${GameLogic.dailyVaultClaimEssence(state)}e '
            '· Daily Run ${25 + md.dailyEssenceBonusLevel * GameLogic.dawnTitheEssencePerLevel}e',
      'gauntlet_gold' =>
        '+${md.gauntletGoldBonusLevel * 4}% Gauntlet gold (max 20%)',
      _ => '',
    };
  }
}
