import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/wisp_gift.dart';
import '../../models/vfx_quality.dart';
import '../game_button.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Floating lantern in a dungeon — right of center, clear of the header.
/// Not shown on the hub.
class WispGiftOverlay extends StatelessWidget {
  const WispGiftOverlay({super.key, required this.director});

  final GameDirector director;

  /// How far a top-of-fight toast must sit below the lantern, including
  /// "Tap for gold" when [hint] is on. The toast used to cover that hint
  /// at text scale 1.45.
  static double toastTopClearance(BuildContext context, {required bool hint}) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final hintBlock = hint ? 8.0 + GameTheme.typeHint * scale * 2 : 0.0;
    return 8 + 48 + hintBlock + 8;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) {
        if (!director.isWispVisible) return const SizedBox.shrink();
        if (director.wispMenuPaused) return const SizedBox.shrink();
        final minimal = director.state.vfxQuality == VfxQuality.minimal;
        final parked = director.state.metaDepth.roi2.goldLanternReady;
        final showTapHint =
            director.state.metaDepth.wispBossHold || parked;
        final hintLabel =
            parked ? 'Gold lantern ready' : 'WISP · Tap for gold';
        return LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final hintWidth = showTapHint
                ? (96.0 * (scale < 1 ? 1 : scale)).clamp(96.0, 128.0)
                : 48.0;
            final cluster = 48.0 + (showTapHint ? 8.0 + 18.0 * scale : 0.0);
            final adTop = constraints.maxHeight - 96 - 56;
            final overlapsAd =
                !constraints.hasBoundedHeight ||
                constraints.maxHeight < 280 ||
                8 + cluster > adTop;
            final clearAd = overlapsAd || scale > 1.15;
            // WATCH AD sits at right: 6. This inset keeps the lantern and
            // the "Tap for gold" hint left of that button and on a 360 dp
            // screen at text scale 1.45.
            final right = clearAd ? 160.0 : 8.0;
            return Padding(
              padding: EdgeInsets.only(top: 8, right: right),
              child: Align(
                alignment: Alignment.topRight,
                child: _WispTapTarget(
                  minimal: minimal,
                  showTapHint: showTapHint,
                  hintLabel: hintLabel,
                  hintWidth: hintWidth,
                  onTap: () async {
                    director.tapWispGift();
                    if (!director.wispPendingChoice) return;
                    director.setWispChoiceOpen(true);
                    await openWispChoiceSheet(context, director);
                    director.setWispChoiceOpen(false);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WispTapTarget extends StatefulWidget {
  const _WispTapTarget({
    required this.minimal,
    required this.showTapHint,
    required this.hintLabel,
    required this.hintWidth,
    required this.onTap,
  });

  final bool minimal;
  final bool showTapHint;
  final String hintLabel;
  final double hintWidth;
  final VoidCallback onTap;

  @override
  State<_WispTapTarget> createState() => _WispTapTargetState();
}

class _WispTapTargetState extends State<_WispTapTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (!widget.minimal) {
      unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant _WispTapTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minimal != widget.minimal) {
      if (widget.minimal) {
        _pulse.stop();
        _pulse.value = 0.5;
      } else if (!_pulse.isAnimating) {
        unawaited(_pulse.repeat(reverse: true));
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: 'WISP',
      onPressed: widget.onTap,
      child: Semantics(
        button: true,
        label: widget.hintLabel,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(GameTheme.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_pulse.value);
                  final dy = widget.minimal ? 0.0 : -3 + t * 6;
                  final glow = widget.minimal ? 0.5 : 0.42 + t * 0.38;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CustomPaint(
                            painter: _WispGlowPainter(
                              glowStrength: glow,
                              softGlow: !widget.minimal,
                            ),
                            child: Center(
                              child: GameIcon.asset(
                                UiIcon.wispLantern,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        if (widget.showTapHint)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SizedBox(
                              width: widget.hintWidth,
                              child: Text(
                                widget.hintLabel,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: GameTheme.hint(
                                  color: GameTheme.torchHot,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Warm torch glow behind the WISP lantern PNG.
class _WispGlowPainter extends CustomPainter {
  const _WispGlowPainter({required this.glowStrength, required this.softGlow});

  final double glowStrength;
  final bool softGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.56;
    final g = glowStrength.clamp(0.0, 1.0);

    if (softGlow) {
      canvas.drawCircle(
        Offset(cx, cy),
        size.shortestSide * 0.48,
        Paint()
          ..color = GameTheme.torch.withValues(alpha: 0.22 * g)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        size.shortestSide * 0.32,
        Paint()
          ..color = GameTheme.torchHot.withValues(alpha: 0.38 * g)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        size.shortestSide * 0.18,
        Paint()
          ..color = GameTheme.wispGlow.withValues(alpha: 0.55 * g)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    } else {
      canvas.drawCircle(
        Offset(cx, cy),
        size.shortestSide * 0.34,
        Paint()
          ..color = GameTheme.torch.withValues(alpha: 0.35 * g)
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WispGlowPainter oldDelegate) =>
      oldDelegate.glowStrength != glowStrength ||
      oldDelegate.softGlow != softGlow;
}

/// KEEP (dismiss) vs WATCH (rewarded ad) after collecting the small pile.
Future<void> openWispChoiceSheet(
  BuildContext context,
  GameDirector director,
) async {
  if (!director.wispPendingChoice) return;
  var watch = false;
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      isDismissible: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: director,
          builder: (ctx, _) {
            final md = director.state.metaDepth;
            if (!WispGift.hasPendingChoice(md)) {
              return const SizedBox.shrink();
            }
            final watchLabel = WispGift.watchButtonLabel(director.state);
            final keepLabel = WispGift.keepButtonLabel(director.state);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: MenuChrome.sheet,
                  borderRadius: MenuChrome.sheetRadius,
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: MenuChrome.sheetRadius,
                      border: Border.all(
                        color: GameTheme.borderLit.withValues(alpha: 0.45),
                      ),
                    ),
                    child: MenuChrome.playSafeArea(
                      bottom: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MenuChrome.sheetHandle(),
                            Row(
                              children: [
                                GameIcon.asset(
                                  UiIcon.wispLantern,
                                  size: 18,
                                  color: GameTheme.torch,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'WISP GIFT',
                                    style: GameTheme.title(),
                                  ),
                                ),
                                MenuChrome.sheetCloseX(ctx),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Watch a short ad for a bigger gold pile? '
                              'NO THANKS keeps the smaller gift.',
                              style: GameTheme.readable(),
                            ),
                            const SizedBox(height: 12),
                            GameButton(
                              label: 'WATCH AD · $watchLabel',
                              onPressed: () {
                                watch = true;
                                Navigator.of(ctx).pop();
                              },
                            ),
                            const SizedBox(height: 8),
                            GameButton(
                              label: 'NO THANKS · $keepLabel',
                              style: GameButtonStyle.grey,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
  if (watch) {
    await director.watchWispGiftAd();
  } else {
    director.dismissWispPending();
  }
}
