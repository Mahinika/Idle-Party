import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/meta_systems.dart';
import '../models/achievement_def.dart';
import '../models/gear_loadout.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// Local achievements list — unlocked ids come from `GameState.achievements`.
class AchievementsOverlay extends StatelessWidget {
  const AchievementsOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final unlocked = state.achievements.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${unlocked.length}/${AchievementCatalog.all.length} UNLOCKED',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: AchievementCatalog.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final def = AchievementCatalog.all[i];
              final done = unlocked.contains(def.id);
              return Container(
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
                            def.title,
                            style: GameTheme.pixel(
                              size: 7,
                              color: done
                                  ? GameTheme.torchHot
                                  : GameTheme.parchmentDim,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            def.description,
                            style: GameTheme.body(
                              size: 14,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${def.essenceReward}e',
                      style: GameTheme.pixel(
                        size: 6,
                        color: done ? GameTheme.clear : GameTheme.parchmentDim,
                      ),
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
            onDelete: () => director.deleteLoadout(slotId),
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
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
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
                ? 'AFK uses a fast abstract combat sim (not live spatial).'
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
class ChallengeToggles extends StatelessWidget {
  const ChallengeToggles({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          onChanged: director.setHardmodeLevel,
        ),
        const SizedBox(height: 4),
        Text(
          state.hardmodeLevel <= 0
              ? 'Hardmode off. Raise +1..+10 — at +10: 1000% HP, damage, and enemy count.'
              : 'HM +${state.hardmodeLevel}: HP/ATK/pack +${state.hardmodeLevel * 90}% '
                  '(${(1.0 + state.hardmodeLevel * 0.9).toStringAsFixed(1)}×) · '
                  'gold +${state.hardmodeLevel * 15}% · '
                  'leg ~${(0.4 + state.hardmodeLevel * 1.1).toStringAsFixed(1)}%',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 2),
        Text(
          'Boss Rush / No Flask: +2e each clear. Hardmode: +1e per HM level.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
      ],
    );
  }
}

class _HardmodeStepper extends StatelessWidget {
  const _HardmodeStepper({required this.level, required this.onChanged});
  final int level;
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
                  '0 = easy  ·  10 = 1000% HP / ATK / count',
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
            onPressed: level < 10 ? () => onChanged(level + 1) : null,
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
