import 'package:flutter/material.dart';

import '../core/meta_systems.dart';
import '../core/story_lore.dart';
import 'cave_atmosphere.dart';
import 'custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';

/// Cold-start menu: brand scene + Continue / New Game.
class StartMenuScreen extends StatefulWidget {
  const StartMenuScreen({
    super.key,
    required this.canContinue,
    required this.onContinue,
    required this.onNewGame,
    required this.onRestore,
    this.saveSummary,
  });

  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback onNewGame;
  final VoidCallback onRestore;

  /// Party name + zone when a save exists, e.g. "The Ember Guard · Sandy Caverns".
  final String? saveSummary;

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
    Future<void>.delayed(const Duration(milliseconds: 900), () {
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
              SafeArea(
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
                          const Spacer(flex: 2),
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
                          SizedBox(height: tight ? 10 : 14),
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
                          if (widget.canContinue &&
                              widget.saveSummary != null &&
                              widget.saveSummary!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Opacity(
                              opacity: copyOpacity,
                              child: Text(
                                widget.saveSummary!,
                                textAlign: TextAlign.center,
                                style: GameTheme.body(
                                  size: 13,
                                  color: GameTheme.torchHot,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(flex: 3),
                          Opacity(
                            opacity: ctaOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.canContinue) ...[
                                  KenneyButton(
                                    label: 'CONTINUE',
                                    style: KenneyButtonStyle.brown,
                                    onPressed: _inputUnlocked
                                        ? () => _choose(widget.onContinue)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  KenneyButton(
                                    label: 'NEW GAME',
                                    style: KenneyButtonStyle.grey,
                                    onPressed: _inputUnlocked
                                        ? () => _choose(widget.onNewGame)
                                        : null,
                                  ),
                                ] else
                                  KenneyButton(
                                    label: 'NEW GAME',
                                    style: KenneyButtonStyle.brown,
                                    onPressed: _inputUnlocked
                                        ? () => _choose(widget.onNewGame)
                                        : null,
                                  ),
                                const SizedBox(height: 8),
                                MenuChrome.textLink(
                                  label: 'RESTORE SAVE',
                                  onPressed: _inputUnlocked
                                      ? widget.onRestore
                                      : null,
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
