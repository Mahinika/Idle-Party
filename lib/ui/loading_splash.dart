import 'package:flutter/material.dart';

import '../assets/kenney_assets.dart';
import 'cognifox_mark.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// Cold-start splash while [GameDirector.boot] runs. No minimum dwell.
///
/// Production uses [branded] false so Android 12+ system splash hands off
/// onto the same ink, with no second studio card. The branded lockup is
/// kept for tests and any caller that still wants the studio mark.
class LoadingSplash extends StatelessWidget {
  const LoadingSplash({super.key, this.branded = true});

  /// When false, only the system-splash ink and a loading label remain.
  final bool branded;

  @override
  Widget build(BuildContext context) {
    if (!branded) {
      return Scaffold(
        backgroundColor: GameTheme.systemSplashInk,
        body: Semantics(
          label: 'Loading Idle Party',
          liveRegion: true,
          child: SizedBox.expand(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: GameTheme.ink,
      body: Semantics(
        label: 'Loading Idle Party',
        liveRegion: true,
        child: MenuChrome.playSafeArea(
          top: true,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: CognifoxSplashStage(
              footer: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LoadingTorch(),
                  const SizedBox(height: 12),
                  Text(
                    'Loading…',
                    style: GameTheme.section(color: GameTheme.parchmentDim),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow torch blink while boot finishes. No spinner, no [FittedBox].
class _LoadingTorch extends StatefulWidget {
  const _LoadingTorch();

  @override
  State<_LoadingTorch> createState() => _LoadingTorchState();
}

class _LoadingTorchState extends State<_LoadingTorch>
    with SingleTickerProviderStateMixin {
  AnimationController? _blink;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.disableAnimationsOf(context);
    if (calm) {
      _blink?.dispose();
      _blink = null;
      return;
    }
    _blink ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blink = _blink;
    final torch = KenneySprite(asset: KenneyAssets.torch, size: 48);
    if (blink == null) return torch;
    return AnimatedBuilder(
      animation: blink,
      builder: (context, child) =>
          Opacity(opacity: 0.45 + (blink.value * 0.55), child: child),
      child: torch,
    );
  }
}
