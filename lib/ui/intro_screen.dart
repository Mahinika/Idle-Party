import 'package:flutter/material.dart';

import '../core/story_lore.dart';
import 'cave_atmosphere.dart';
import 'custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';

/// Cold-start title: full-bleed custom cave scene + brand + ENTER.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
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
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
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

  Future<void> _finish() async {
    if (!_inputUnlocked || _finishing || !mounted) return;
    _finishing = true;
    await _exit.forward();
    if (mounted) widget.onFinished();
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
                        tight ? 10 : 18,
                        24,
                        tight ? 10 : 16,
                      ),
                      child: Column(
                        children: [
                          Opacity(
                            opacity: titleOpacity,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - enter)),
                              child: Text(
                                'IDLE PARTY',
                                textAlign: TextAlign.center,
                                style: GameTheme.pixel(
                                  size: titleSize,
                                  color: GameTheme.torchHot,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(flex: 5),
                          Opacity(
                            opacity: copyOpacity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  StoryLore.introTagline,
                                  textAlign: TextAlign.center,
                                  style: GameTheme.body(
                                    size: tight ? 18 : 22,
                                    color: GameTheme.parchment,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  StoryLore.introSubline,
                                  textAlign: TextAlign.center,
                                  style: GameTheme.body(
                                    size: tight ? 15 : 17,
                                    color: GameTheme.parchmentDim
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: tight ? 14 : 20),
                          Opacity(
                            opacity: ctaOpacity,
                            child: SizedBox(
                              width: 240,
                              child: KenneyButton(
                                label: 'ENTER',
                                style: KenneyButtonStyle.brown,
                                onPressed: _inputUnlocked ? _finish : null,
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),
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
