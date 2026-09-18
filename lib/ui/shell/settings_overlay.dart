import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ad_rewarded.dart';
import '../../core/community_links.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/local_reminders.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/play_games_section.dart';
import '../meta/save_transfer.dart';
import '../redeem_coupon_dialog.dart';
import 'bag_cleanup_filters.dart';
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

  /// ACCOUNT session-log hint. God Hand waits until first-hour chrome lifts.
  static String sessionLogHint({required bool plain}) => plain
      ? 'Optional session log on this device only — chase and wipes. '
          'Never uploaded. Copy to clipboard for your own notes.'
      : 'Optional session log on this device only — chase, wipes, God Hand. '
          'Never uploaded. Copy to clipboard for your own notes.';

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

enum _SettingsPage { sound, display, bag, account }

class _SettingsOverlayState extends State<SettingsOverlay>
    with SingleTickerProviderStateMixin {
  GameDirector get director => widget.director;
  GameState get state => director.state;
  late final TabController _tabs;
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
    _tabs = TabController(length: _SettingsPage.values.length, vsync: this)
      ..addListener(_onTabChanged);
    _maybeScrollToBagFilters();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
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
      if (!mounted) return;
      _tabs.animateTo(_SettingsPage.bag.index);
    });
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs,
          scrollable: false,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'SOUND'),
            Tab(text: 'DISPLAY'),
            Tab(text: 'BAG'),
            Tab(text: 'ACCOUNT'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _scrollPage(_SettingsPage.sound, _soundPage()),
              _scrollPage(_SettingsPage.display, _displayPage()),
              _scrollPage(_SettingsPage.bag, _bagPage()),
              _scrollPage(_SettingsPage.account, _accountPage(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scrollPage(_SettingsPage page, Widget child) {
    return SingleChildScrollView(
      key: PageStorageKey<String>('settings-${page.name}'),
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
      child: child,
    );
  }

  Widget _soundPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Music, ambience, combat sound, and vibration.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabel('SOUND'),
        const SizedBox(height: 4),
        Text(
          'Mute turns everything off. Music is the hub / dungeon track; '
          'ambience is the soft bed underneath; SFX is combat and UI.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _SettingsToggle(
          label: 'Mute all sound',
          value: state.soundMuted,
          onChanged: director.setSoundMuted,
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: state.soundMuted ? 0.45 : 1,
          child: IgnorePointer(
            ignoring: state.soundMuted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VolumeSlider(
                  label: 'Music',
                  value: state.musicVolume,
                  onChanged: director.setMusicVolume,
                ),
                const SizedBox(height: 8),
                _VolumeSlider(
                  label: 'Ambience',
                  value: state.ambienceVolume,
                  onChanged: director.setAmbienceVolume,
                ),
                const SizedBox(height: 8),
                _VolumeSlider(
                  label: 'SFX',
                  value: state.sfxVolume,
                  onChanged: director.setSfxVolume,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SettingsToggle(
          label: 'Haptics (vibration)',
          value: state.hapticsEnabled,
          onChanged: director.setHapticsEnabled,
        ),
      ],
    );
  }

  Widget _displayPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Text, dungeon framing, and combat readability. OS display size '
          'still applies on top.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
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
        Text(
          'Changes combat damage floaters and bark colors only — not map art. '
          'Chamber dots already use shape (square / diamond / circle).',
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'RESET DISPLAY DEFAULTS',
          tip: 'Text 100% · Zoom Normal · Full VFX · Music Low · sound on',
          style: GameButtonStyle.grey,
          onPressed: _resetDisplayDefaults,
        ),
      ],
    );
  }

  Widget _bagPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Automatic cleanup when the run bag gets crowded.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        BagCleanupFilters(director: director),
      ],
    );
  }

  Widget _accountPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save, Play Games, privacy, community, updates, and device data.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabelScoped(
          'PLAY NOTES (local)',
          scope: MenuScope.account,
        ),
        const SizedBox(height: 4),
        Text(
          SettingsOverlay.sessionLogHint(
            plain: GameLogic.plainPlayerChrome(state),
          ),
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _SettingsToggle(
          label: 'Session log',
          value: state.sessionTelemetryOptIn,
          onChanged: director.setSessionTelemetryOptIn,
        ),
        if (LocalReminders.showSettingsToggle(state)) ...[
          const SizedBox(height: 16),
          MenuChrome.sectionLabelScoped('REMINDERS', scope: MenuScope.account),
          const SizedBox(height: 4),
          Text(
            'Quiet pings when gold is waiting or a cave is ready. '
            'At most a couple a day. Never during a fight.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 8),
          _SettingsToggle(
            label: 'Away reminders',
            value: state.metaDepth.notifyOptIn,
            onChanged: (v) => director.setNotifyOptIn(v),
          ),
        ],
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
        const SizedBox(height: 12),
        GameButton(
          label: 'REDEEM CODE',
          tip: 'Unlock a coupon on this save',
          style: GameButtonStyle.grey,
          onPressed: () => showRedeemCouponDialog(context, director),
        ),
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
        const SizedBox(height: 8),
        GameButton(
          label: 'RATE ON PLAY',
          tip: 'Opens Google Play — no reward for rating',
          style: GameButtonStyle.grey,
          onPressed: () => director.requestPlayReview(source: 'settings'),
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
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    final valueLabel = pct <= 0 ? 'Off' : '$pct%';
    return Semantics(
      slider: true,
      label: '$label volume',
      value: valueLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: GameTheme.body(size: 14))),
              Text(
                valueLabel,
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MenuChrome.slider(
            value: value.clamp(0.0, 1.0),
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: onChanged,
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
