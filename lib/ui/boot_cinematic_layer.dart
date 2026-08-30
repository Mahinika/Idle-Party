import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'cave_atmosphere.dart';
import 'custom_assets.dart';
import 'kenney_button.dart';

/// Full-bleed skippable boot video. Falls back via [onDecodeFailed].
class BootCinematicLayer extends StatefulWidget {
  const BootCinematicLayer({
    super.key,
    required this.muted,
    required this.onFinished,
    required this.onDecodeFailed,
  });

  final bool muted;
  final VoidCallback onFinished;
  final VoidCallback onDecodeFailed;

  @override
  State<BootCinematicLayer> createState() => _BootCinematicLayerState();
}

class _BootCinematicLayerState extends State<BootCinematicLayer> {
  VideoPlayerController? _controller;
  bool _inputUnlocked = false;
  bool _finishing = false;
  bool _ready = false;
  Timer? _unlock;

  @override
  void initState() {
    super.initState();
    _unlock = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _finishing) return;
      setState(() => _inputUnlocked = true);
    });
    unawaited(_start());
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.asset(CustomAssets.introVideo);
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (!mounted || _finishing) return;
      widget.onDecodeFailed();
      return;
    }
    if (!mounted || _finishing) {
      await controller.dispose();
      return;
    }
    controller.setVolume(widget.muted ? 0 : 1);
    controller.setLooping(false);
    controller.addListener(_onTick);
    _controller = controller;
    setState(() => _ready = true);
    await controller.play();
  }

  void _onTick() {
    final c = _controller;
    if (c == null || _finishing || !c.value.isInitialized) return;
    final duration = c.value.duration;
    if (duration == Duration.zero) return;
    if (c.value.position >= duration) {
      _finish();
    }
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    _unlock?.cancel();
    _controller?.removeListener(_onTick);
    widget.onFinished();
  }

  @override
  void dispose() {
    _unlock?.cancel();
    final c = _controller;
    _controller = null;
    c?.removeListener(_onTick);
    unawaited(c?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        CaveAtmosphere.fullBleedScene(
          CustomAssets.introScene,
          alignment: const Alignment(0, -0.05),
        ),
        if (_ready && c != null && c.value.isInitialized)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              children: [
                const Spacer(),
                KenneyButton(
                  label: 'SKIP',
                  style: KenneyButtonStyle.grey,
                  onPressed: _inputUnlocked ? _finish : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
