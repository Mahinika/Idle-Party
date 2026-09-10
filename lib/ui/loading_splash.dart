import 'dart:async';

import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../core/story_lore.dart';
import 'cave_atmosphere.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';

/// Cold-start splash while [GameDirector.boot] runs. No minimum dwell.
///
/// Cycles full-bleed stills from [CustomAssets.splashStills] with a short
/// crossfade. Native Android launch uses ink + logo only; this picks up once
/// Flutter paints.
class LoadingSplash extends StatefulWidget {
  const LoadingSplash({super.key});

  static const Duration crossfadeDuration = Duration(milliseconds: 700);

  static Duration get slideDuration {
    final name = WidgetsBinding.instance.runtimeType.toString();
    if (name.contains('TestWidgetsFlutterBinding')) {
      return const Duration(milliseconds: 120);
    }
    return const Duration(milliseconds: 2200);
  }

  @override
  State<LoadingSplash> createState() => _LoadingSplashState();
}

class _LoadingSplashState extends State<LoadingSplash> {
  int _index = 0;
  Timer? _advance;

  static const _alignments = <Alignment>[
    Alignment(0, -0.15),
    Alignment(0, -0.05),
    Alignment.center,
    Alignment(0, -0.08),
    Alignment(0, -0.1),
    Alignment(0, -0.06),
  ];

  @override
  void initState() {
    super.initState();
    _armAdvance();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNearby(0));
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _armAdvance() {
    _advance?.cancel();
    _advance = Timer.periodic(LoadingSplash.slideDuration, (_) {
      if (!mounted) return;
      final next = (_index + 1) % CustomAssets.splashStills.length;
      setState(() => _index = next);
      _precacheNearby(next);
    });
  }

  void _precacheNearby(int from) {
    if (!mounted) return;
    final stills = CustomAssets.splashStills;
    // One ahead only — decoding three full-bleed stills fights cold-start frames.
    if (stills.isEmpty) return;
    final asset = stills[(from + 1) % stills.length];
    precacheImage(AssetImage(asset), context);
  }

  Alignment _alignmentFor(int index) {
    if (index < _alignments.length) return _alignments[index];
    return Alignment.center;
  }

  @override
  Widget build(BuildContext context) {
    final still = CustomAssets.splashStills[_index];
    return Scaffold(
      backgroundColor: GameTheme.ink,
      body: Semantics(
        label: 'Loading Idle Party',
        liveRegion: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: LoadingSplash.crossfadeDuration,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              layoutBuilder: (current, previous) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previous,
                    ?current,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<String>(still),
                child: CaveAtmosphere.fullBleedScene(
                  still,
                  alignment: _alignmentFor(_index),
                ),
              ),
            ),
            CaveAtmosphere.readabilityScrim(top: 0.62, bottom: 0.72),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneySprite(asset: CustomAssets.introLogo, size: 112),
                  const SizedBox(height: 16),
                  Text(
                    'IDLE PARTY',
                    textAlign: TextAlign.center,
                    style: GameTheme.pixel(
                      size: 26,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    StoryLore.introTagline,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: GameTheme.torch.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading…',
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
