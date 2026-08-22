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
import '../models/achievement_def.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/meta_depth.dart';
import 'confirm_dialogs.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'web_click_bridge.dart';

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

class LoadoutsOverlay extends StatelessWidget {
  const LoadoutsOverlay({super.key, required this.director});
  final GameDirector director;

  Future<void> _promptSave(BuildContext context, String slotId) async {
    final controller = TextEditingController(text: 'Loadout $slotId');
    final name = await showDialog<String>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Save loadout $slotId',
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GameTheme.body(size: 16),
          decoration: const InputDecoration(hintText: 'Loadout name'),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx),
          ),
          KenneyButton(
            label: 'SAVE',
            expanded: false,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      director.saveLoadout(id: slotId, name: name);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String slotId) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Delete loadout?',
        content: Text(
          'Remove saved gear preset $slotId. This cannot be undone.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'DELETE',
            expanded: false,
            style: KenneyButtonStyle.red,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) director.deleteLoadout(slotId);
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final slotCount = GameLogic.maxLoadoutsFor(state);
    final slotIds = [
      for (var i = 1; i <= slotCount; i++) '$i',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save equipped gear into a preset, then swap instantly. '
          'Empty slots: SAVE first — APPLY stays off until something is saved.'
          '${slotCount > 3 ? ' Extra slots from POWER → SHOP.' : ''}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        for (final slotId in slotIds) ...[
          _LoadoutSlotRow(
            slotId: slotId,
            loadout: _findLoadout(state, slotId),
            onSave: () => _promptSave(context, slotId),
            onApply: () => director.applyLoadout(slotId),
            onDelete: () => _confirmDelete(context, slotId),
          ),
          const SizedBox(height: 8),
        ],
        if (state.loadouts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tip: gear up in BAG, then SAVE Slot 1 before a tough zone.',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 13, color: GameTheme.torchHot),
            ),
          ),
      ],
    );
  }

  static GearLoadout? _findLoadout(GameState state, String id) {
    for (final l in state.loadouts) {
      if (l.id == id) return l;
    }
    return null;
  }
}

class _LoadoutSlotRow extends StatelessWidget {
  const _LoadoutSlotRow({
    required this.slotId,
    required this.loadout,
    required this.onSave,
    required this.onApply,
    required this.onDelete,
  });

  final String slotId;
  final GearLoadout? loadout;
  final VoidCallback onSave;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final saved = loadout != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            saved ? loadout!.name : 'Slot $slotId — empty',
            style: GameTheme.body(
              size: 15,
              color: saved ? GameTheme.torchHot : GameTheme.parchmentDim,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: KenneyButton(
                  label: 'SAVE',
                  style: KenneyButtonStyle.grey,
                  onPressed: onSave,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KenneyButton(
                  label: 'APPLY',
                  style: saved
                      ? KenneyButtonStyle.brown
                      : KenneyButtonStyle.grey,
                  onPressed: saved ? onApply : null,
                ),
              ),
              if (saved) ...[
                const SizedBox(width: 8),
                KenneyButton(
                  label: 'DEL',
                  style: KenneyButtonStyle.red,
                  expanded: false,
                  onPressed: onDelete,
                ),
              ],
            ],
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
  VoidCallback? onOpenParty,
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
        for (final m in director.state.missions) {
          if (m.isComplete) director.claimMission(m.id);
        }
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
      break;
    case HubChaseKind.gauntletMilestone:
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        confirmGauntletRun(context, director);
      };
    case HubChaseKind.meetHero:
      readyLabel = 'PARTY';
      readyAction = () {
        director.dismissOfflineSummary();
        Navigator.pop(context);
        // Hub passes onOpenParty (acks + opens PARTY). Fallback: ack only.
        if (onOpenParty != null) {
          onOpenParty();
        } else {
          director.ackPendingHeroReveals();
        }
      };
    default:
      break;
  }

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
        if (chase.urgency == HubChaseUrgency.ready && readyAction != null) ...[
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
    _expanded = !widget.collapsed;
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
      if (vaultReady) 'Vault ready',
      if (weekReady) 'Week ready',
    ];

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
                ? 'Normal · max KEY +$maxKey'
                : 'KEY +${state.hardmodeLevel} · loot +${Keystone.lootItemLevelBonus(state.hardmodeLevel)} iLvl · ${Keystone.goldMulLabel(state.hardmodeLevel)}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          if (affixes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              affixes.map(Keystone.label).join(' · '),
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
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
                  md.seasonKey.isEmpty
                      ? 'Season rotating…'
                      : '${month.name} · +${GameLogic.seasonWeeklyBonusEssence}e first vault claim',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  md.dailyVaultClaimed
                      ? 'Claimed today'
                      : 'Clears ${md.dailyVaultClears}/${GameLogic.dailyVaultClearTarget}'
                            ' · best timed KEY +${md.dailyBestTimedKey}'
                            '${vaultReady ? ' · ready' : ''}',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
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
          const SizedBox(height: 2),
          Text(
            'Timed boss under par upgrades KEY. Vault: 1 clear or timed KEY+2.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
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
    final data = await Clipboard.getData('text/plain');
    final raw = data?.text;
    if (raw == null || raw.isEmpty) {
      director.showToast('Clipboard is empty');
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Import save?',
        content: Text(
          'This replaces your current save with the clipboard contents. '
          'This cannot be undone.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'IMPORT',
            style: KenneyButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = director.importSaveJson(raw);
    director.showToast(success ? 'Save imported' : 'Could not read that save');
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

/// Opt-in Play Games: seasonal boards + cloud save (Google hosts; no Idle Party server).
class PlayGamesSection extends StatefulWidget {
  const PlayGamesSection({super.key, required this.director});
  final GameDirector director;

  @override
  State<PlayGamesSection> createState() => _PlayGamesSectionState();
}

class _PlayGamesSectionState extends State<PlayGamesSection> {
  bool _busy = false;

  GameDirector get director => widget.director;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() async {
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

  Future<void> _restore() => _run(() async {
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

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final md = state.metaDepth;
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
    final boardsReady = PlayLeaderboardIds.hasBoards(month);
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
          'Season $month · opt-in boards + cloud backup',
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
          onPressed: _busy || signedIn ? null : _signIn,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'VIEW KEY',
                style: KenneyButtonStyle.grey,
                onPressed: _busy || !boardsReady
                    ? null
                    : () => _run(director.showPlayTimedLeaderboard),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: 'VIEW GAUNTLET',
                style: KenneyButtonStyle.grey,
                onPressed: _busy || !boardsReady
                    ? null
                    : () => _run(director.showPlayGauntletLeaderboard),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'BACKUP NOW',
                style: KenneyButtonStyle.grey,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await director.backupToPlayGames();
                      }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: 'RESTORE',
                style: KenneyButtonStyle.grey,
                onPressed: _busy ? null : _restore,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          boardsReady
              ? 'Boards submit on new season PBs while signed in.'
              : 'Leaderboard IDs not set yet — add them in Play Console, then '
                    'paste into play_leaderboard_ids.dart.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
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
