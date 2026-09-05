import 'dart:async';

import 'package:flutter/material.dart';

import '../core/story_lore.dart';
import 'boot_cinematic_layer.dart';
import 'cave_atmosphere.dart';
import '../assets/custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';

/// Skippable story beats after the loading splash, before CONTINUE / NEW GAME.
///
/// When [playCinematic] is true the optional RepoClip MP4 plays first (SKIP
/// still works). Decode failure falls back to these beats.
class BootIntroScreen extends StatefulWidget {
  const BootIntroScreen({
    super.key,
    required this.onFinished,
    this.playCinematic = false,
    this.muted = false,
    this.onCinematicConsumed,
  });

  final VoidCallback onFinished;

  /// First-launch boot video when [CustomAssets.introVideoBundled].
  final bool playCinematic;
  final bool muted;

  /// Called only after the cinematic actually played or was skipped.
  final VoidCallback? onCinematicConsumed;

  static const String cinematicTipId = 'boot_cinematic';

  static const Duration beatDuration = Duration(milliseconds: 2800);
  static const Duration inputUnlock = Duration(milliseconds: 400);

  static bool get inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  State<BootIntroScreen> createState() => _BootIntroScreenState();
}

class _BootIntroScreenState extends State<BootIntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _glow;
  int _beat = 0;
  bool _inputUnlocked = false;
  bool _finishing = false;
  bool _cinematicFailed = false;
  Timer? _advance;
  Timer? _unlock;

  bool get _useCinematic =>
      widget.playCinematic &&
      CustomAssets.introVideoBundled &&
      !BootIntroScreen.inWidgetTest &&
      !_cinematicFailed;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    if (!_useCinematic) {
      _armBeats();
    }
  }

  void _armBeats() {
    _unlock?.cancel();
    _inputUnlocked = false;
    _unlock = Timer(BootIntroScreen.inputUnlock, () {
      if (!mounted || _finishing) return;
      setState(() => _inputUnlocked = true);
    });
    _scheduleAdvance();
  }

  @override
  void dispose() {
    _advance?.cancel();
    _unlock?.cancel();
    _fade.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _scheduleAdvance() {
    _advance?.cancel();
    _advance = Timer(BootIntroScreen.beatDuration, () {
      if (!mounted || _finishing) return;
      _next();
    });
  }

  void _next() {
    if (_finishing) return;
    if (_beat >= StoryLore.introBeats.length - 1) {
      _finish();
      return;
    }
    setState(() => _beat += 1);
    _fade
      ..value = 0
      ..forward();
    _scheduleAdvance();
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    _advance?.cancel();
    _unlock?.cancel();
    widget.onFinished();
  }

  void _onTap() {
    if (!_inputUnlocked || _finishing) return;
    _next();
  }

  void _onCinematicFinished() {
    if (_finishing) return;
    widget.onCinematicConsumed?.call();
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    if (_useCinematic) {
      return BootCinematicLayer(
        muted: widget.muted,
        onFinished: _onCinematicFinished,
        onDecodeFailed: () {
          if (!mounted || _finishing) return;
          setState(() => _cinematicFailed = true);
          _armBeats();
        },
      );
    }
    final beat = StoryLore.introBeats[_beat];
    final first = _beat == 0;
    return AnimatedBuilder(
      animation: Listenable.merge([_fade, _glow]),
      builder: (context, _) {
        final glow = 0.55 + _glow.value * 0.45;
        final opacity = Curves.easeOut.transform(_fade.value);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CaveAtmosphere.fullBleedScene(
                CustomAssets.introScene,
                alignment: const Alignment(0, -0.05),
              ),
              CaveAtmosphere.readabilityScrim(top: 0.72, bottom: 0.58),
              CaveAtmosphere.torchBloom(
                intensity: glow,
                alignment: const Alignment(0, 0.82),
                sizeFactor: 0.35,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Opacity(
                        opacity: opacity,
                        child: Semantics(
                          header: true,
                          label: '${beat.title}. ${beat.body}',
                          child: Column(
                            children: [
                              if (first) ...[
                                KenneySprite(
                                  asset: CustomAssets.introLogo,
                                  size: 88,
                                ),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                beat.title,
                                textAlign: TextAlign.center,
                                style: GameTheme.menuTitle(
                                  size: first ? 22 : 20,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                beat.body,
                                textAlign: TextAlign.center,
                                style: GameTheme.body(
                                  size: 16,
                                  color: GameTheme.parchment,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                      if (_inputUnlocked)
                        Semantics(
                          button: true,
                          label: 'Tap to continue',
                          child: Text(
                            'Tap to continue',
                            textAlign: TextAlign.center,
                            style: GameTheme.body(
                              size: 13,
                              color: GameTheme.parchmentDim.withValues(
                                alpha: 0.45 + _glow.value * 0.35,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      GameButton(
                        label: 'SKIP',
                        style: GameButtonStyle.grey,
                        onPressed: _inputUnlocked ? _finish : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
