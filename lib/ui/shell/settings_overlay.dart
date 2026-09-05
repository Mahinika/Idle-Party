import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ad_rewarded.dart';
import '../../core/community_links.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_cleanup.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/play_games_section.dart';
import '../meta/save_transfer.dart';
import 'whats_new_overlay.dart';

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
          GameButton(
            label: 'RESET',
            style: GameButtonStyle.red,
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

  static String _volumeLabel(double v) {
    if (v <= 0.01) return 'Off';
    if (v < 0.4) return 'Low';
    if (v < 0.85) return 'Med';
    return 'High';
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
          () {
            final scaleIdx = _textPresets.indexWhere(
              (p) => (state.uiTextScale - p.$2).abs() < 0.02,
            );
            return MenuChrome.segmented(
              labels: [for (final preset in _textPresets) preset.$1],
              selectedIndex: scaleIdx < 0 ? 1 : scaleIdx,
              onSelect: (i) => director.setUiTextScale(_textPresets[i].$2),
            );
          }(),
          const SizedBox(height: 6),
          Semantics(
            slider: true,
            label: 'UI text scale',
            value: '${(state.uiTextScale * 100).round()} percent',
            child: Row(
              children: [
                Expanded(
                  child: MenuChrome.slider(
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
          _SettingsCycle(
            label: 'SFX ${_volumeLabel(state.sfxVolume)}',
            hint: 'Combat and UI volume',
            onCycle: director.cycleSfxVolume,
          ),
          const SizedBox(height: 8),
          _SettingsCycle(
            label: 'Ambience ${_volumeLabel(state.ambienceVolume)}',
            hint: 'Soft hub / dungeon loop',
            onCycle: director.cycleAmbienceVolume,
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
          GameButton(
            label: 'RESET DISPLAY DEFAULTS',
            tip: 'Text 100% · Zoom Normal · Full VFX · SFX Med · sound on',
            style: GameButtonStyle.grey,
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
          MenuChrome.sectionLabelScoped(
            'AUTO-SELL · gold',
            scope: MenuScope.account,
          ),
          const SizedBox(height: 4),
          Text(
            'Junk sold for coins when bag is near full or you CLEAN BAG. '
            '${state.autoSellMaxPower <= 0 ? 'Off = never auto-sells.' : 'Sells iLvl 1–${state.autoSellMaxPower} at or below the rarity cap.'}',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Text(
            'Max iLvl to sell',
            style: GameTheme.body(size: 13, color: GameTheme.torchHot),
          ),
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
          if (state.autoSellMaxPower > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Sells ~${GearCleanup.autoSellPreviewCount(state)} stash items',
              style: GameTheme.body(size: 12, color: GameTheme.mossLit),
            ),
          ],
          const SizedBox(height: 12),
          MenuChrome.sectionLabelScoped(
            'AUTO-SCRAP · essence',
            scope: MenuScope.account,
          ),
          const SizedBox(height: 4),
          Text(
            'Leftovers broken for essence after sell pass — not the same as sell. '
            '${state.autoDisassembleMaxIlvl <= 0 ? 'Off = never auto-scraps.' : 'Scraps iLvl 1–${state.autoDisassembleMaxIlvl} at or below the rarity cap.'}',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Text(
            'Max iLvl to scrap',
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
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
            'leftovers that match scrap filters. GOLD → MARKET buys flasks '
            'and listings — it does not tap-sell stash.',
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
            GameButton(
              label: 'COPY LOG',
              style: GameButtonStyle.grey,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: director.sessionTelemetryExport()),
                );
                director.showToast('Session log copied', life: 1.8);
              },
            ),
            const SizedBox(height: 6),
            GameButton(
              label: 'CLEAR LOG',
              style: GameButtonStyle.grey,
              onPressed: director.clearSessionTelemetry,
            ),
          ],
          const SizedBox(height: 16),
          PlayGamesSection(director: director),
          if (AdRewarded.realAdsAvailable) ...[
            const SizedBox(height: 16),
            MenuChrome.sectionLabelScoped('ADS', scope: MenuScope.account),
            const SizedBox(height: 6),
            GameButton(
              label: 'AD PRIVACY',
              tip: 'Change or withdraw ad consent (EU / EEA)',
              style: GameButtonStyle.grey,
              onPressed: () => AdRewarded.showPrivacyOptions(),
            ),
          ],
          SaveTransferSection(director: director),
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped('COMMUNITY', scope: MenuScope.account),
          const SizedBox(height: 6),
          GameButton(
            label: 'JOIN DISCORD',
            tip: 'Opens Discord so you can join the Idle Party server',
            style: GameButtonStyle.brown,
            onPressed: () async {
              final ok = await CommunityLinks.openDiscord();
              if (!ok && mounted) {
                director.showToast('Could not open Discord link', life: 2.2);
              }
            },
          ),
          if (director.showPlayUpdateNotice) ...[
            const SizedBox(height: 8),
            GameButton(
              label: 'GET UPDATE',
              tip: 'A newer Idle Party is ready on Google Play',
              style: GameButtonStyle.grey,
              onPressed: director.openPlayUpdate,
            ),
          ],
          const SizedBox(height: 8),
          GameButton(
            label: "WHAT'S NEW",
            style: GameButtonStyle.grey,
            onPressed: () => WhatsNewOverlay.show(context, director),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            GameButton(
              label: 'DEV: FAKE PLAY UPDATE',
              style: GameButtonStyle.grey,
              onPressed: director.debugForcePlayUpdateNotice,
            ),
            const SizedBox(height: 8),
            GameButton(
              label: director.debugTimeScale >= 9.5
                  ? 'DEV: SPEED 10x (tap → 1x)'
                  : 'DEV: SPEED 1x (tap → 10x)',
              style: GameButtonStyle.grey,
              onPressed: director.cycleDebugTimeScale,
            ),
            const SizedBox(height: 8),
            GameButton(
              label: 'DEV: ENTER GAUNTLET (Lv${GameLogic.maxHeroLevel})',
              style: GameButtonStyle.grey,
              onPressed: state.inDungeon
                  ? null
                  : () {
                      widget.onClose();
                      director.devEnterGauntlet();
                    },
            ),
          ],
          const SizedBox(height: 24),
          MenuChrome.sectionLabelScoped('DANGER', scope: MenuScope.account),
          const SizedBox(height: 6),
          Text(
            'Deletes this save on device — separate from Play Games cloud.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: 'RESET GAME',
            style: GameButtonStyle.red,
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
          child: MenuChrome.slider(
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
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: MenuChrome.cardBox(),
          child: Row(
            children: [
              Expanded(child: Text(label, style: GameTheme.body(size: 16))),
              ExcludeSemantics(child: MenuChrome.toggleMark(value: value)),
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
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
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
