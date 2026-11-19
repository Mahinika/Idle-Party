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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;

  /// No pulse while the app is in the background.
  bool _foreground = true;

  bool get _shouldAnimate =>
      _foreground &&
      widget.enabled &&
      widget.active &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    setState(() => _foreground = fg);
    _syncPulse();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final life = WidgetsBinding.instance.lifecycleState;
    _foreground = life == null || life == AppLifecycleState.resumed;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
    WidgetsBinding.instance.removeObserver(this);
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
