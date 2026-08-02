import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/meta_systems.dart';
import '../models/achievement_def.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/meta_depth.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

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
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        if (state.metaDepth.titles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Titles',
            textAlign: TextAlign.center,
            style: GameTheme.pixel(size: 7, color: GameTheme.parchmentDim),
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
                Text(
                  _categoryLabel(cat),
                  style: GameTheme.pixel(
                    size: 7,
                    color: GameTheme.parchmentDim,
                  ),
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
                        decoration: BoxDecoration(
                          color: GameTheme.menuCard,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: done ? GameTheme.clear : GameTheme.border,
                          ),
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
                                    style: GameTheme.pixel(
                                      size: 7,
                                      color: done
                                          ? GameTheme.torchHot
                                          : GameTheme.parchmentDim,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    hide ? 'Hidden achievement' : def.description,
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
                              style: GameTheme.pixel(
                                size: 6,
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
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final entry in GameLogic.codexRewardTiers.entries)
              Builder(
                builder: (context) {
                  final claimed =
                      state.metaDepth.codexClaims.contains(entry.key);
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
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _showEnemies
                        ? 'No monsters discovered yet. Fight your way through a dungeon.'
                        : 'No items discovered yet. Clear floors for gear drops.',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 15, color: GameTheme.parchmentDim),
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
                        decoration: BoxDecoration(
                          color: GameTheme.menuCard,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: GameTheme.border),
                        ),
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
            [
              if (!hasTank) 'No tank',
              if (!hasHeal) 'No healer',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        ],
        const SizedBox(height: 10),
        Text('ACTIVE', style: GameTheme.pixel(size: 8)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < maxSlots; i++)
              _ActiveSlotChip(
                index: i,
                hero: i < active.length ? active[i] : null,
                selected: _pendingSlotReplace ==
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
          ],
        ),
        if (!state.metaDepth.partySlot5Unlocked) ...[
          const SizedBox(height: 8),
          KenneyButton(
            label:
                'UNLOCK 5TH SLOT  ${GameLogic.partySlot5EssenceCost}e  AL${GameLogic.partySlot5MinAscension}+',
            style: KenneyButtonStyle.brown,
            onPressed: state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
                    state.essence >= GameLogic.partySlot5EssenceCost
                ? () {
                    director.unlockPartySlot5();
                  }
                : null,
          ),
        ],
        const SizedBox(height: 12),
        Text('ROSTER', style: GameTheme.pixel(size: 8)),
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
        : '${hero!.name}\n${hero!.roleLabel}';
    return Column(
      children: [
        KenneyButton(
          label: label,
          expanded: false,
          style: selected ? KenneyButtonStyle.brown : KenneyButtonStyle.grey,
          onPressed: onTap,
        ),
        if (onClear != null && !locked)
          TextButton(
            onPressed: onClear,
            child: Text(
              'CLEAR',
              style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
            ),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Capture each hero\'s equipped gear into a preset, then swap '
          'instantly later. Sold items are silently skipped on apply.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        for (final slotId in const ['1', '2', '3']) ...[
          _LoadoutSlotRow(
            slotId: slotId,
            loadout: _findLoadout(state, slotId),
            onSave: () => _promptSave(context, slotId),
            onApply: () => director.applyLoadout(slotId),
            onDelete: () => _confirmDelete(context, slotId),
          ),
          const SizedBox(height: 8),
        ],
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
      decoration: BoxDecoration(
        color: GameTheme.menuCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GameTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            saved ? loadout!.name : 'Slot $slotId — empty',
            style: GameTheme.pixel(
              size: 7,
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
                  onPressed: saved ? onApply : null,
                ),
              ),
              if (saved) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'DEL',
                    style: GameTheme.pixel(
                      size: 8,
                      color: GameTheme.bloodLit,
                    ),
                  ),
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
  GameDirector director,
) async {
  final summary = director.offlineSummary;
  if (summary == null) return;
  await showDialog<void>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'Welcome back!',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Away for ${OfflineProgressResult.formatOfflineDuration(summary.secondsApplied)}',
            style: GameTheme.body(size: 16, color: GameTheme.parchment),
          ),
          const SizedBox(height: 6),
          Text(
            summary.state.inDungeon
                ? 'AFK runs spatial combat with assist (faster, softer packs).'
                : 'Hub AFK earns sanctuary idle gold only.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
          _OfflineStatRow(label: 'Gold earned', value: '+${summary.goldGained}g'),
          _OfflineStatRow(
            label: 'Essence earned',
            value: '+${summary.essenceGained}',
          ),
          _OfflineStatRow(
            label: 'Rooms cleared',
            value: '${summary.roomsCleared}',
          ),
          _OfflineStatRow(
            label: 'Floor progress',
            value: '+${summary.highestFloorDelta}',
          ),
          _OfflineStatRow(
            label: 'Bosses defeated',
            value: '${summary.bossDelta}',
          ),
        ],
      ),
      actions: [
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
  );
}

class _OfflineStatRow extends StatelessWidget {
  const _OfflineStatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GameTheme.body(size: 15, color: GameTheme.parchmentDim),
            ),
          ),
          Text(
            value,
            style: GameTheme.body(size: 16, color: GameTheme.torchHot),
          ),
        ],
      ),
    );
  }
}

/// In-app "What's new" changelog — marks itself seen once shown.
class WhatsNewOverlay extends StatelessWidget {
  const WhatsNewOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VERSION ${MetaSystems.currentVersion}',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              for (final entry in MetaSystems.changelog)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: GameTheme.body(size: 16, color: GameTheme.torch)),
                      Expanded(
                        child: Text(entry, style: GameTheme.body(size: 15)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'GOT IT',
          onPressed: director.markChangelogSeen,
        ),
      ],
    );
  }
}

/// Boss Rush + No-Flask challenge toggles — set before entering a dungeon.
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

  static String _weeklyLabel(String mod) => switch (mod) {
        'glass' => 'Glass (fragile foes)',
        'swarm' => 'Swarm (more enemies)',
        'elite' => 'Elite (tougher packs)',
        _ => mod.isEmpty ? 'Rotating…' : mod,
      };

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final state = director.state;
    final md = state.metaDepth;
    final maxHm = state.effectiveMaxHardmode;
    final weeklyReady = md.weeklyProgress >= 3 && !md.weeklyClaimed;
    final activeBits = <String>[
      if (state.challengeBossRush) 'Boss Rush',
      if (state.challengeNoFlask) 'No Flask',
      if (state.hardmodeLevel > 0) 'HM+${state.hardmodeLevel}',
      if (weeklyReady) 'Weekly ready',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  _expanded ? '▾ CHALLENGES' : '▸ CHALLENGES',
                  style: GameTheme.pixel(
                    size: 8,
                    color: GameTheme.torchHot,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeBits.isEmpty
                        ? 'off'
                        : activeBits.join(' · '),
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
        if (_expanded) ...[
          const SizedBox(height: 4),
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
          const SizedBox(height: 8),
          _HardmodeStepper(
            level: state.hardmodeLevel,
            maxLevel: maxHm,
            onChanged: director.setHardmodeLevel,
          ),
          const SizedBox(height: 4),
          Text(
            state.hardmodeLevel <= 0
                ? 'Hardmode off. Cap +$maxHm (AL gates higher).'
                : 'HM +${state.hardmodeLevel}: tougher packs, more gold & legendaries.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: MenuChrome.cardBox(selected: weeklyReady),
            child: Column(
              children: [
                Text(
                  'WEEKLY · ${_weeklyLabel(md.weeklyModifier)}',
                  textAlign: TextAlign.center,
                  style: GameTheme.pixel(
                    size: 8,
                    color:
                        weeklyReady ? GameTheme.torchHot : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  md.weeklyClaimed
                      ? 'Claimed this week'
                      : 'Clears ${md.weeklyProgress}/3'
                          '${weeklyReady ? ' · ready' : ''}',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
                ),
                if (weeklyReady) ...[
                  const SizedBox(height: 6),
                  KenneyButton(
                    label: 'CLAIM WEEKLY  +${GameLogic.weeklyClaimEssence}e',
                    onPressed: director.claimWeekly,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Boss Rush / No Flask: +2e each clear. Hardmode: +1e per level.',
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
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              foregroundColor: GameTheme.parchment,
            ),
            onPressed: level > 0 ? () => onChanged(level - 1) : null,
            child: Text('-', style: GameTheme.pixel(size: 10)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  level <= 0 ? 'HARDMODE  OFF' : 'HARDMODE  +$level',
                  textAlign: TextAlign.center,
                  style: GameTheme.pixel(
                    size: 7,
                    color: level > 0 ? GameTheme.torchHot : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '0 = easy  ·  max +$maxLevel (AL)',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              foregroundColor: GameTheme.parchment,
            ),
            onPressed: level < maxLevel ? () => onChanged(level + 1) : null,
            child: Text('+', style: GameTheme.pixel(size: 10)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? GameTheme.stoneRaised.withValues(alpha: 0.9)
                : GameTheme.menuCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? GameTheme.torchHot : GameTheme.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: GameTheme.pixel(
              size: 6,
              color: active ? GameTheme.torchHot : GameTheme.parchmentDim,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
            ),
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
    director.showToast(
      success ? 'Save imported' : 'Could not read that save',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Save transfer (clipboard)', style: GameTheme.pixel(size: 7)),
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
      ],
    );
  }
}

/// Ascend milestone strip — small horizontal AL progress markers for the hub.
class AscendMilestonesStrip extends StatelessWidget {
  const AscendMilestonesStrip({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final milestones = MetaSystems.ascendMilestones;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: milestones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final target = milestones[i];
          final reached = state.ascensionLevel >= target;
          final reward = MetaSystems.ascendMilestoneEssence(target);
          return Tooltip(
            message: 'AL$target · +${reward}e on first reach',
            child: Container(
              width: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: reached
                    ? GameTheme.stoneRaised.withValues(alpha: 0.9)
                    : GameTheme.menuCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: reached ? GameTheme.torchHot : GameTheme.border,
                ),
              ),
              child: Text(
                'AL$target',
                style: GameTheme.pixel(
                  size: 6,
                  color: reached ? GameTheme.torchHot : GameTheme.parchmentDim,
                ),
              ),
            ),
          );
        },
      ),
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
            'Browse freely — purchases unlock at AL3+.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Essence ${state.essence}  |  AL${state.ascensionLevel}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: PrestigeShopCatalog.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = PrestigeShopCatalog.all[i];
              final locked = state.ascensionLevel < item.minAl;
              final ownedCount = switch (item.id) {
                'stash_slot' => state.metaDepth.stashBonusSlots ~/ 2,
                'combine_luck' => state.metaDepth.combinatorLuck,
                'torch_keep' => state.metaDepth.torchKeepLevel,
                'gh_cdr' => state.metaDepth.godHandCdLevel,
                'roster_cap' => state.metaDepth.petRosterCapBonus ~/ 2,
                'legacy_spark' => state.metaDepth.legacyPoints,
                _ => 0,
              };
              final atCap = switch (item.id) {
                'stash_slot' => state.metaDepth.stashBonusSlots >= 20,
                'combine_luck' => state.metaDepth.combinatorLuck >= 5,
                'torch_keep' => state.metaDepth.torchKeepLevel >= 10,
                'gh_cdr' => state.metaDepth.godHandCdLevel >= 8,
                'roster_cap' => state.metaDepth.petRosterCapBonus >= 10,
                'legacy_spark' => state.metaDepth.legacyPoints >= 20,
                _ => false,
              };
              final canBuy =
                  !locked && !atCap && state.essence >= item.cost;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GameTheme.menuCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GameTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.name,
                      style: GameTheme.pixel(
                        size: 7,
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
                          label: 'BUY',
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
}
