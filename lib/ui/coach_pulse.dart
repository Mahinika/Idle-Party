import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Soft glow pulse around a control while a first-session coach hint is active.
class CoachPulse extends StatefulWidget {
  const CoachPulse({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<CoachPulse> createState() => _CoachPulseState();
}

class _CoachPulseState extends State<CoachPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CoachPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
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
  const CoachLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.body(size: 12, color: GameTheme.torchHot),
      ),
    );
  }
}
