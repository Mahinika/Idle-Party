import 'package:flutter/material.dart';

import '../../core/greater_rift.dart';
import '../../core/rift.dart';
import '../../core/rift_progress.dart';
import '../game_icon.dart';
import '../game_theme.dart';

/// Diablo 3–style rift progress: purple fill toward a skull.
///
/// Farm: fill + elapsed only. Ranked GR: fill vs a clock needle (ahead/behind).
class RiftProgressHud extends StatelessWidget {
  const RiftProgressHud({
    super.key,
    required this.progress01,
    required this.guardianActive,
    required this.farm,
    required this.tier,
    required this.timerMs,
    this.parMs = 0,
  });

  final double progress01;
  final bool guardianActive;
  final bool farm;
  final int tier;
  final int timerMs;
  final int parMs;

  @override
  Widget build(BuildContext context) {
    final p = RiftProgress.clamp01(progress01);
    final fill = guardianActive ? 1.0 : p;
    final pace = farm
        ? ''
        : RiftProgress.paceLabel(
            progress01: fill,
            timerMs: timerMs,
            parMs: parMs,
          );
    final needle = farm
        ? 0.0
        : RiftProgress.timeSpent01(timerMs: timerMs, parMs: parMs);
    final clock = farm
        ? Rift.formatTimer(timerMs)
        : GreaterRift.formatTimer((parMs - timerMs).clamp(0, parMs));
    final title = farm ? 'FARM R$tier' : 'GR$tier';
    final pct = guardianActive ? 'GUARDIAN' : RiftProgress.percentLabel(fill);
    final overPar = !farm && parMs > 0 && timerMs >= parMs;
    final semantics = farm
        ? '$title $pct · $clock elapsed · no fail timer · not ranked'
        : overPar
        ? '$title $pct · par failed · depleted if Guardian is still up'
        : '$title $pct · $clock left${pace.isEmpty ? '' : ' · $pace'}';

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 1),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: GameTheme.torchHot,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 18,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: RiftProgressBarPainter(
                          progress01: fill,
                          timeSpent01: needle,
                          showNeedle: !farm && !guardianActive && parMs > 0,
                          guardianActive: guardianActive,
                        ),
                      ),
                    ),
                    Text(
                      pct,
                      maxLines: 1,
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: guardianActive
                            ? GameTheme.torchHot
                            : GameTheme.parchment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            GameIcon.asset(
              UiIcon.skull,
              size: 14,
              color: guardianActive
                  ? GameTheme.riftBarFillHot
                  : GameTheme.parchmentDim,
            ),
            const SizedBox(width: 4),
            Text(
              clock,
              maxLines: 1,
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: !farm && pace == 'BEHIND'
                    ? GameTheme.bloodLit
                    : GameTheme.parchmentDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiftProgressBarPainter extends CustomPainter {
  RiftProgressBarPainter({
    required this.progress01,
    required this.timeSpent01,
    required this.showNeedle,
    required this.guardianActive,
  });

  final double progress01;
  final double timeSpent01;
  final bool showNeedle;
  final bool guardianActive;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromLTRBR(
      0,
      4,
      size.width,
      size.height - 4,
      const Radius.circular(2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = GameTheme.riftBarTrack,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = GameTheme.hudWellBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final fillW = (size.width * progress01).clamp(0.0, size.width);
    if (fillW > 0.5) {
      final fillRect = RRect.fromLTRBR(
        0,
        4,
        fillW,
        size.height - 4,
        const Radius.circular(2),
      );
      canvas.drawRRect(
        fillRect,
        Paint()
          ..color = guardianActive
              ? GameTheme.riftBarFillHot
              : GameTheme.riftBarFill,
      );
      // Electric top edge — D3 rift glow, cheap.
      canvas.drawLine(
        Offset(1, 5),
        Offset(fillW - 1, 5),
        Paint()
          ..color = GameTheme.riftBarFillHot.withValues(alpha: 0.85)
          ..strokeWidth = 1.2,
      );
    }

    if (!showNeedle) return;
    final x = (size.width * timeSpent01).clamp(1.0, size.width - 1);
    final needle = Paint()
      ..color = GameTheme.riftBarPace
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, 1), Offset(x, size.height - 1), needle);
    final tip = Path()
      ..moveTo(x, 0)
      ..lineTo(x - 3.5, 5)
      ..lineTo(x + 3.5, 5)
      ..close();
    canvas.drawPath(tip, Paint()..color = GameTheme.riftBarPace);
  }

  @override
  bool shouldRepaint(covariant RiftProgressBarPainter old) {
    return old.progress01 != progress01 ||
        old.timeSpent01 != timeSpent01 ||
        old.showNeedle != showNeedle ||
        old.guardianActive != guardianActive;
  }
}
