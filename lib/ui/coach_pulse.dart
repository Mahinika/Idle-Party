import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Soft glow pulse around a control while a first-session coach hint is active.
class CoachPulse extends StatefulWidget {
  const CoachPulse({
    super.key,
    required this.active,
    required this.child,
    this.enabled = true,
  });

  final bool active;
  final Widget child;

  /// False when minimal VFX or reduce-motion should skip the pulse ticker.
  final bool enabled;

  @override
  State<CoachPulse> createState() => _CoachPulseState();
}

class _CoachPulseState extends State<CoachPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  bool get _shouldAnimate =>
      widget.enabled &&
      widget.active &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active && widget.enabled) _pulse.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant CoachPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (!_shouldAnimate) {
      _pulse.stop();
      _pulse.value = 0;
      return;
    }
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) return widget.child;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            boxShadow: [
              BoxShadow(
                color: GameTheme.torchHot.withValues(alpha: 0.22 + t * 0.35),
                blurRadius: 6 + t * 10,
                spreadRadius: t * 1.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One short line above a coach target (hub ENTER / bottom tabs).
class CoachLine extends StatelessWidget {
  const CoachLine(this.text, {super.key, this.maxLines = 1});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.hint(color: GameTheme.torchHot),
      ),
    );
  }
}
