import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ad_rewarded.dart';
import '../../core/community_links.dart';
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
    this.bagFiltersScrollNonce = 0,
  });
  final GameDirector director;
  final VoidCallback onClose;
  final int bagFiltersScrollNonce;

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  GameDirector get director => widget.director;
  GameState get state => director.state;
  final GlobalKey _bagCleanupKey = GlobalKey();
  int _seenBagFiltersScrollNonce = 0;

  static const List<(String, double)> _textPresets = <(String, double)>[
    ('S', 0.85),
    ('M', 1.0),
    ('L', 1.15),
    ('XL', 1.30),
  ];

  @override
  void initState() {
    super.initState();
    _maybeScrollToBagFilters();
  }

  @override
  void didUpdateWidget(covariant SettingsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bagFiltersScrollNonce != oldWidget.bagFiltersScrollNonce) {
      _maybeScrollToBagFilters();
    }
  }

  void _maybeScrollToBagFilters() {
    if (widget.bagFiltersScrollNonce <= _seenBagFiltersScrollNonce) return;
    _seenBagFiltersScrollNonce = widget.bagFiltersScrollNonce;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _bagCleanupKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

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
          MenuChrome.dialogCancel(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KenneyButton(
            label: 'RESET',
            style: KenneyButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await director.reset();
    }
  }

  void _resetDisplayDefaults() {
    director.resetDisplayDefaults();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phone preferences — text size, dungeon zoom, sound, and comfort. '
            'OS display size still applies on top.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 12),
          MenuChrome.sectionLabel('DISPLAY'),
          const SizedBox(height: 6),
          Text(
            'UI text scale',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in _textPresets)
                ChoiceChip(
                  label: Text(preset.$1, style: GameTheme.body(size: 12)),
                  selected: (state.uiTextScale - preset.$2).abs() < 0.02,
                  onSelected: (_) => director.setUiTextScale(preset.$2),
                ),
            ],
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
                    value: state.uiTextScale.clamp(
                      kUiTextScaleMin,
                      kUiTextScaleMax,
                    ),
                    min: kUiTextScaleMin,
                    max: kUiTextScaleMax,
                    divisions: 13,
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
          const SizedBox(height: 10),
          _SettingsCycle(
            label: state.dungeonZoom.settingsLabel,
            hint: state.dungeonZoom.settingsHint,
            onCycle: director.cycleDungeonZoom,
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: 'Keep screen on in dungeon',
            value: state.keepScreenAwake,
            onChanged: director.setKeepScreenAwake,
          ),
          const SizedBox(height: 12),
          MenuChrome.sectionLabel('SOUND & FEEL'),
          const SizedBox(height: 6),
          _SettingsToggle(
            label: 'Mute sound',
            value: state.soundMuted,
            onChanged: director.setSoundMuted,
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: 'Haptics (vibration)',
            value: state.hapticsEnabled,
            onChanged: director.setHapticsEnabled,
          ),
          const SizedBox(height: 12),
          MenuChrome.sectionLabel('COMBAT LOOK'),
          const SizedBox(height: 6),
          _SettingsCycle(
            label: state.vfxQuality.settingsLabel,
            hint: state.vfxQuality.settingsHint,
            onCycle: director.cycleVfxQuality,
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: 'Colorblind-friendly combat numbers',
            value: state.colorblindMode,
            onChanged: director.setColorblindMode,
          ),
          const SizedBox(height: 8),
          KenneyButton(
            label: 'RESET DISPLAY DEFAULTS',
            tip: 'Text 100% · Zoom Normal · Full VFX · sound & haptics on',
            style: KenneyButtonStyle.grey,
            onPressed: _resetDisplayDefaults,
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _bagCleanupKey,
            child: MenuChrome.sectionLabelScoped(
              'BAG CLEANUP',
              scope: MenuScope.account,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Near-full bag auto-rules (also BAG → AUTO-SELL FILTERS). '
            'Sell = gold. Scrap/disassemble = essence. BiS / upgrades are never cleaned.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
          Text(
            'Auto-sell → gold (junk sold for coins)',
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
            'Auto-scrap → essence (junk broken for essence)',
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
            'leftovers that match disassemble filters. Market tap = gold.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped(
            'PLAY NOTES (local)',
            scope: MenuScope.account,
          ),
          const SizedBox(height: 4),
          Text(
            'Optional session log on this device only — chase, wipes, God Hand. '
            'Never uploaded. Copy to clipboard for your own notes.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: 'Session log',
            value: state.sessionTelemetryOptIn,
            onChanged: director.setSessionTelemetryOptIn,
          ),
          if (state.sessionTelemetryOptIn) ...[
            const SizedBox(height: 8),
            KenneyButton(
              label: 'COPY LOG',
              style: KenneyButtonStyle.grey,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: director.sessionTelemetryExport()),
                );
                director.showToast('Session log copied', life: 1.8);
              },
            ),
            const SizedBox(height: 6),
            KenneyButton(
              label: 'CLEAR LOG',
              style: KenneyButtonStyle.grey,
              onPressed: director.clearSessionTelemetry,
            ),
          ],
          const SizedBox(height: 16),
          PlayGamesSection(director: director),
          if (AdRewarded.realAdsAvailable) ...[
            const SizedBox(height: 16),
            MenuChrome.sectionLabelScoped('ADS', scope: MenuScope.account),
            const SizedBox(height: 6),
            KenneyButton(
              label: 'AD PRIVACY',
              tip: 'Change or withdraw ad consent (EU / EEA)',
              style: KenneyButtonStyle.grey,
              onPressed: () => AdRewarded.showPrivacyOptions(),
            ),
          ],
          SaveTransferSection(director: director),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped('COMMUNITY', scope: MenuScope.account),
          const SizedBox(height: 6),
          KenneyButton(
            label: 'JOIN DISCORD',
            tip: 'Opens Discord so you can join the Idle Party server',
            style: KenneyButtonStyle.brown,
            onPressed: () async {
              final ok = await CommunityLinks.openDiscord();
              if (!ok && mounted) {
                director.showToast('Could not open Discord link', life: 2.2);
              }
            },
          ),
          if (director.showPlayUpdateNotice) ...[
            const SizedBox(height: 8),
            KenneyButton(
              label: 'GET UPDATE',
              tip: 'A newer Idle Party is ready on Google Play',
              style: KenneyButtonStyle.grey,
              onPressed: director.openPlayUpdate,
            ),
          ],
          const SizedBox(height: 8),
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
              label: 'DEV: FAKE PLAY UPDATE',
              style: KenneyButtonStyle.grey,
              onPressed: director.debugForcePlayUpdateNotice,
            ),
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
              label: 'DEV: ENTER GAUNTLET (Lv${GameLogic.maxHeroLevel})',
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
        MenuChrome.stepperButton(
          label: '$offLabel decrease',
          sign: '-',
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
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
        MenuChrome.stepperButton(
          label: '$offLabel increase',
          sign: '+',
          onPressed: value < max ? () => onChanged(value + 1) : null,
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
          MenuChrome.stepperButton(
            label: 'Max rarity decrease',
            sign: '-',
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ),
          MenuChrome.stepperButton(
            label: 'Max rarity increase',
            sign: '+',
            onPressed: enabled && value < 4 ? () => onChanged(value + 1) : null,
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
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
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
