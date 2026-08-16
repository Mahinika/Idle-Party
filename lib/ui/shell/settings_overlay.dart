import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/meta_systems.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta_overlays.dart';

class SettingsOverlay extends StatefulWidget {
  const SettingsOverlay({
    super.key,
    required this.director,
    required this.onClose,
  });
  final GameDirector director;
  final VoidCallback onClose;

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  GameDirector get director => widget.director;
  GameState get state => director.state;

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Reset game?',
        content: Text(
          'All progress will be wiped. This cannot be undone.',
          style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'RESET',
              style: GameTheme.body(size: 16, color: GameTheme.bloodLit),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await director.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsToggle(
            label: 'Mute sound',
            value: state.soundMuted,
            onChanged: director.setSoundMuted,
          ),
          const SizedBox(height: 8),
          _SettingsCycle(
            label: state.vfxQuality.settingsLabel,
            hint: state.vfxQuality.settingsHint,
            onCycle: director.cycleVfxQuality,
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: 'Colorblind-friendly floaters',
            value: state.colorblindMode,
            onChanged: director.setColorblindMode,
          ),
          const SizedBox(height: 12),
          Text(
            'UI text scale',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Semantics(
            slider: true,
            label: 'UI text scale',
            value: '${(state.uiTextScale * 100).round()} percent',
            child: Row(
              children: [
                Expanded(
                  child: _CaveSlider(
                    value: state.uiTextScale.clamp(0.85, 1.3),
                    min: 0.85,
                    max: 1.3,
                    divisions: 9,
                    onChanged: director.setUiTextScale,
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    '${(state.uiTextScale * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: GameTheme.body(
                      size: 15,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MenuChrome.sectionLabel('BAG CLEANUP'),
          const SizedBox(height: 4),
          Text(
            'Near-full bag: merge → sell gold → scrap essence. '
            'BiS / upgrades are never cleaned. Bag → FILTERS opens these controls.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
          Text(
            'Auto-sell (gold)',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          _IlvlFilterRow(
            value: state.autoSellMaxPower,
            max: GameLogic.maxAutoSellIlvlCap(state),
            onChanged: director.setAutoSellMaxPower,
            offLabel: 'Off',
          ),
          const SizedBox(height: 6),
          _RarityFilterRow(
            value: state.autoSellMaxRarity,
            onChanged: director.setAutoSellMaxRarity,
            enabled: state.autoSellMaxPower > 0,
          ),
          const SizedBox(height: 12),
          Text(
            'Auto-disassemble (essence)',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          _IlvlFilterRow(
            value: state.autoDisassembleMaxIlvl,
            max: GameLogic.maxAutoSellIlvlCap(state),
            onChanged: director.setAutoDisassembleMaxIlvl,
            offLabel: 'Off',
          ),
          const SizedBox(height: 6),
          _RarityFilterRow(
            value: state.autoDisassembleMaxRarity,
            onChanged: director.setAutoDisassembleMaxRarity,
            enabled: state.autoDisassembleMaxIlvl > 0,
          ),
          const SizedBox(height: 8),
          Text(
            'Pickup & CLEAN BAG: sell gold first (≤iLvl + rarity), then scrap '
            'leftovers that match disassemble filters. Single-item SELL = essence. '
            'Market tap = gold.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 16),
          PlayGamesSection(director: director),
          const SizedBox(height: 16),
          SaveTransferSection(director: director),
          const SizedBox(height: 16),
          KenneyButton(
            label: MetaSystems.hasUnseenChangelog(state)
                ? "WHAT'S NEW ★"
                : "WHAT'S NEW",
            style: KenneyButtonStyle.grey,
            onPressed: () => WhatsNewOverlay.show(context, director),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            KenneyButton(
              label: director.debugTimeScale >= 9.5
                  ? 'DEV: SPEED 10x (tap → 1x)'
                  : 'DEV: SPEED 1x (tap → 10x)',
              style: KenneyButtonStyle.grey,
              onPressed: director.cycleDebugTimeScale,
            ),
            const SizedBox(height: 8),
            KenneyButton(
              label: 'DEV: ENTER GAUNTLET (AL10)',
              style: KenneyButtonStyle.grey,
              onPressed: state.inDungeon
                  ? null
                  : () {
                      widget.onClose();
                      director.devEnterGauntlet();
                    },
            ),
          ],
          const SizedBox(height: 8),
          KenneyButton(
            label: 'RESET GAME',
            style: KenneyButtonStyle.red,
            onPressed: _confirmReset,
          ),
        ],
      ),
    );
  }
}

class _IlvlFilterRow extends StatelessWidget {
  const _IlvlFilterRow({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.offLabel,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
            padding: EdgeInsets.zero,
            foregroundColor: GameTheme.parchment,
          ),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          child: Text('-', style: GameTheme.pixel(size: 10)),
        ),
        Expanded(
          child: _CaveSlider(
            value: value.toDouble().clamp(0, max.toDouble()),
            min: 0,
            max: max.toDouble(),
            divisions: max.clamp(1, 200),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
            padding: EdgeInsets.zero,
            foregroundColor: GameTheme.parchment,
          ),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          child: Text('+', style: GameTheme.pixel(size: 10)),
        ),
        SizedBox(
          width: 52,
          child: Text(
            value <= 0 ? offLabel : 'i$value',
            textAlign: TextAlign.right,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
        ),
      ],
    );
  }
}

class _RarityFilterRow extends StatelessWidget {
  const _RarityFilterRow({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = GameLogic.rarityFilterLabel(value);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          Text(
            'Max rarity',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
              padding: EdgeInsets.zero,
              foregroundColor: GameTheme.parchment,
            ),
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
            child: Text('-', style: GameTheme.pixel(size: 10)),
          ),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GameTheme.pixel(size: 7, color: GameTheme.torchHot),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
              padding: EdgeInsets.zero,
              foregroundColor: GameTheme.parchment,
            ),
            onPressed: enabled && value < 4 ? () => onChanged(value + 1) : null,
            child: Text('+', style: GameTheme.pixel(size: 10)),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: label,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: MenuChrome.cardBox(),
          child: Row(
            children: [
              Expanded(child: Text(label, style: GameTheme.body(size: 16))),
              ExcludeSemantics(child: _CaveSwitch(value: value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCycle extends StatelessWidget {
  const _SettingsCycle({
    required this.label,
    required this.hint,
    required this.onCycle,
  });

  final String label;
  final String hint;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $hint. Tap to cycle',
      onTap: onCycle,
      child: InkWell(
        onTap: onCycle,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: MenuChrome.cardBox(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GameTheme.body(size: 16)),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'TAP',
                style: GameTheme.pixel(size: 7, color: GameTheme.parchmentDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveSwitch extends StatelessWidget {
  const _CaveSwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? GameTheme.mossLit.withValues(alpha: 0.55)
              : GameTheme.stone.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? GameTheme.torchHot : GameTheme.border,
            width: value ? 1.5 : 1,
          ),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: value ? GameTheme.torchHot : GameTheme.parchmentDim,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _CaveSlider extends StatelessWidget {
  const _CaveSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  void _setFromLocal(double localX, double width) {
    if (width <= 0) return;
    final t = (localX / width).clamp(0.0, 1.0);
    final raw = min + t * (max - min);
    final step = (max - min) / divisions;
    final snapped = (raw / step).round() * step;
    onChanged(snapped.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFromLocal(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _setFromLocal(d.localPosition.dx, w),
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: GameTheme.stone.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: GameTheme.border),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: t,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: GameTheme.torch.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: (w - 16) * t,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: GameTheme.torchHot,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: GameTheme.borderLit),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
