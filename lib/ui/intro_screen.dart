import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_theme.dart';
import 'custom_assets.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';

/// Cold-start title sequence: brand first, then fade into the hub.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _torch;
  late final AnimationController _exit;
  Timer? _autoAdvance;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _torch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _autoAdvance = Timer(const Duration(milliseconds: 3200), _finish);
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _enter.dispose();
    _torch.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing || !mounted) return;
    _finishing = true;
    _autoAdvance?.cancel();
    await _exit.forward();
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _torch, _exit]),
      builder: (context, _) {
        final enter = Curves.easeOutCubic.transform(_enter.value);
        final torch = 0.55 + _torch.value * 0.45;
        final fadeOut = 1.0 - Curves.easeIn.transform(_exit.value);

        return Opacity(
          opacity: fadeOut,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _finish,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1A120A),
                        GameTheme.ink,
                        Color(0xFF0A0806),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Soft torch glow behind the brand.
                Align(
                  alignment: const Alignment(0, -0.18),
                  child: Container(
                    width: 280 * torch,
                    height: 220 * torch,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          GameTheme.torch.withValues(alpha: 0.28 * torch),
                          GameTheme.torch.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Subtle vignette / stone grain feel via stacked fades.
                IgnorePointer(
                  child: CustomPaint(painter: _IntroVignettePainter()),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        Opacity(
                          opacity: enter.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - enter)),
                            child: Column(
                              children: [
                                KenneySprite(
                                  asset: CustomAssets.introLogo,
                                  size: 96,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'IDLE PARTY',
                                  textAlign: TextAlign.center,
                                  style: GameTheme.pixel(
                                    size: 22,
                                    color: GameTheme.torchHot,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'A party that fights while you watch.',
                                  textAlign: TextAlign.center,
                                  style: GameTheme.body(
                                    size: 20,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: ((enter - 0.35) / 0.65).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - enter)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final asset in [
                                  KenneyAssets.heroKnight,
                                  KenneyAssets.heroHealer,
                                  KenneyAssets.heroWizard,
                                  KenneyAssets.heroRogue,
                                ])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        math.sin(
                                              (_torch.value * math.pi * 2) +
                                                  asset.hashCode,
                                            ) *
                                            3,
                                      ),
                                      child: KenneySprite(
                                        asset: asset,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        Opacity(
                          opacity: ((enter - 0.55) / 0.45).clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 220,
                                child: KenneyButton(
                                  label: 'ENTER',
                                  onPressed: _finish,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Tap anywhere',
                                style: GameTheme.body(
                                  size: 15,
                                  color: GameTheme.parchmentDim
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
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

class _IntroVignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.15,
          colors: [
            Colors.transparent,
            GameTheme.ink.withValues(alpha: 0.75),
          ],
          stops: const [0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
