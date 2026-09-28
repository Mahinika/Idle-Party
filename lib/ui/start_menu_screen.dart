import 'package:flutter/material.dart';

import '../core/ad_rewarded.dart';
import '../core/community_links.dart';
import '../core/game_storage.dart';
import '../core/meta_systems.dart';
import '../core/story_lore.dart';
import 'cave_atmosphere.dart';
import '../assets/custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';
import 'web_click_bridge.dart';

/// Cold-start menu: brand scene + five save files.
class StartMenuScreen extends StatefulWidget {
  const StartMenuScreen({
    super.key,
    required this.slots,
    required this.activeSlot,
    required this.onOpenSlot,
    required this.onEraseSlot,
    required this.onRestore,
    this.onSettings,
  });

  final List<SaveSlotSummary> slots;
  final int activeSlot;
  final ValueChanged<int> onOpenSlot;
  final ValueChanged<int> onEraseSlot;
  final VoidCallback onRestore;
  final VoidCallback? onSettings;

  @override
  State<StartMenuScreen> createState() => _StartMenuScreenState();
}

class _StartMenuScreenState extends State<StartMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _glow;
  late final AnimationController _exit;
  bool _finishing = false;
  bool _inputUnlocked = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || _finishing) return;
      setState(() => _inputUnlocked = true);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _glow.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _choose(VoidCallback action) async {
    if (!_inputUnlocked || _finishing || !mounted) return;
    _finishing = true;
    await _exit.forward();
    if (mounted) action();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exit,
      builder: (context, child) {
        final fadeOut = 1.0 - Curves.easeIn.transform(_exit.value);
        return Opacity(opacity: fadeOut, child: child);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _glow]),
        builder: (context, _) {
          final enter = Curves.easeOutCubic.transform(_enter.value);
          final glow = 0.55 + _glow.value * 0.45;
          final titleOpacity = enter.clamp(0.0, 1.0);
          final copyOpacity = ((enter - 0.2) / 0.55).clamp(0.0, 1.0);
          final ctaOpacity = ((enter - 0.4) / 0.5).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              CaveAtmosphere.fullBleedScene(
                CustomAssets.introScene,
                alignment: const Alignment(0, -0.05),
              ),
              CaveAtmosphere.readabilityScrim(top: 0.7, bottom: 0.55),
              CaveAtmosphere.torchBloom(
                intensity: glow,
                alignment: const Alignment(0, 0.82),
                sizeFactor: 0.35,
              ),
              MenuChrome.playSafeArea(
                bottom: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tight = constraints.maxHeight < 580;
                    final titleSize = tight ? 22.0 : 28.0;

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        tight ? 18 : 28,
                        24,
                        tight ? 18 : 28,
                      ),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),
                          Opacity(
                            opacity: titleOpacity,
                            child: Semantics(
                              header: true,
                              label: 'Idle Party',
                              child: Text(
                                'IDLE PARTY',
                                textAlign: TextAlign.center,
                                style: GameTheme.pixel(
                                  size: titleSize,
                                  color: GameTheme.torchHot,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: tight ? 6 : 8),
                          Opacity(
                            opacity: copyOpacity,
                            child: Text(
                              StoryLore.introTagline,
                              textAlign: TextAlign.center,
                              style: GameTheme.body(
                                size: tight ? 14 : 16,
                                color: GameTheme.parchment,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: copyOpacity,
                            child: Text(
                              StoryLore.introSubline,
                              textAlign: TextAlign.center,
                              style: GameTheme.body(
                                size: 13,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Opacity(
                              opacity: ctaOpacity,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < widget.slots.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 6),
                                      _SaveSlotRow(
                                        slot: widget.slots[i],
                                        selected:
                                            widget.slots[i].index ==
                                                widget.activeSlot &&
                                            widget.slots[i].occupied,
                                        enabled: _inputUnlocked,
                                        onOpen: () => _choose(
                                          () => widget.onOpenSlot(
                                            widget.slots[i].index,
                                          ),
                                        ),
                                        onErase: widget.slots[i].occupied
                                            ? () => widget.onEraseSlot(
                                                widget.slots[i].index,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: ctaOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                GameButton(
                                  label: 'RESTORE SAVE',
                                  style: GameButtonStyle.grey,
                                  onPressed: _inputUnlocked
                                      ? widget.onRestore
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  children: [
                                    if (widget.onSettings != null)
                                      MenuChrome.textLink(
                                        label: 'SETTINGS',
                                        onPressed: _inputUnlocked
                                            ? widget.onSettings
                                            : null,
                                      ),
                                    MenuChrome.textLink(
                                      label: 'PRIVACY',
                                      onPressed: _inputUnlocked
                                          ? AdRewarded.showPrivacyOptions
                                          : null,
                                    ),
                                    MenuChrome.textLink(
                                      label: 'DISCORD',
                                      onPressed: _inputUnlocked
                                          ? () => CommunityLinks.openDiscord()
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  MetaSystems.currentVersion,
                                  textAlign: TextAlign.center,
                                  style: GameTheme.body(
                                    size: 11,
                                    color: GameTheme.parchmentDim.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
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
        },
      ),
    );
  }
}

class _SaveSlotRow extends StatelessWidget {
  const _SaveSlotRow({
    required this.slot,
    required this.selected,
    required this.enabled,
    required this.onOpen,
    required this.onErase,
  });

  final SaveSlotSummary slot;
  final bool selected;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback? onErase;

  @override
  Widget build(BuildContext context) {
    final open = enabled && !slot.corrupt ? onOpen : null;
    final headline = slot.corrupt
        ? 'Could not read this save'
        : (slot.partyName ?? 'Empty');
    final border = selected
        ? GameTheme.torchHot.withValues(alpha: 0.85)
        : GameTheme.border.withValues(alpha: slot.occupied ? 0.95 : 0.55);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: GameTheme.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: WebClickScope(
              label: slot.label,
              onPressed: open,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: open,
                  borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: GameTheme.minTouch,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slot.label,
                            style: GameTheme.pixel(
                              size: 11,
                              color: GameTheme.torchHot,
                            ),
                          ),
                          Text(
                            headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.body(
                              size: 14,
                              color: slot.occupied
                                  ? GameTheme.parchment
                                  : GameTheme.parchmentDim,
                            ),
                          ),
                          if (slot.detail != null)
                            Text(
                              slot.detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onErase != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GameButton(
                label: 'ERASE ${slot.index + 1}',
                style: GameButtonStyle.red,
                dense: true,
                expanded: false,
                onPressed: enabled ? onErase : null,
              ),
            ),
        ],
      ),
    );
  }
}
