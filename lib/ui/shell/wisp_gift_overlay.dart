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

/// Floating lantern on the open map — right of center, clear of the header.
class WispGiftOverlay extends StatelessWidget {
  const WispGiftOverlay({super.key, required this.director});

  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) {
        if (!director.isWispVisible) return const SizedBox.shrink();
        if (director.wispMenuPaused) return const SizedBox.shrink();
        final minimal = director.state.vfxQuality == VfxQuality.minimal;
        return Align(
          alignment: const Alignment(0.84, -0.58),
          child: _WispTapTarget(
            minimal: minimal,
            onTap: () async {
              director.tapWispGift();
              if (!director.wispPendingChoice) return;
              director.setWispChoiceOpen(true);
              await openWispChoiceSheet(context, director);
              director.setWispChoiceOpen(false);
            },
          ),
        );
      },
    );
  }
}

class _WispTapTarget extends StatefulWidget {
  const _WispTapTarget({required this.minimal, required this.onTap});

  final bool minimal;
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
        label: 'WISP. Tap for gold',
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
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 42,
                      child: CustomPaint(painter: _LanternPainter()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pixel lantern: dark iron, warm glass, bright flame. No blur.
class _LanternPainter extends CustomPainter {
  const _LanternPainter();

  static const _rows = <String>[
    '...#...',
    '..#.#..',
    '...#...',
    '..###..',
    '.#####.',
    '#+*^*+#',
    '#+***+#',
    '.#####.',
    '..#.#..',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 7;
    const glyphRows = 9;
    final px = size.width / cols;
    final ox = (size.width - cols * px) / 2;
    final oy = (size.height - glyphRows * px) / 2;
    final iron = Paint()
      ..color = const Color(0xFF3A2414)
      ..isAntiAlias = false;
    final glass = Paint()
      ..color = const Color(0xFF8A4E16)
      ..isAntiAlias = false;
    final flame = Paint()
      ..color = const Color(0xFFFFC14A)
      ..isAntiAlias = false;
    final tip = Paint()
      ..color = const Color(0xFFFFF6D0)
      ..isAntiAlias = false;
    for (var y = 0; y < _rows.length; y++) {
      final row = _rows[y];
      for (var x = 0; x < row.length; x++) {
        final paint = switch (row[x]) {
          '#' => iron,
          '+' => glass,
          '*' => flame,
          '^' => tip,
          _ => null,
        };
        if (paint == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(ox + x * px, oy + y * px, px, px),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LanternPainter oldDelegate) => false;
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
            final atCap = WispGift.goldHourAtCap(director.state);
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
                                GameIcon.glyph(
                                  UiGlyph.wisp,
                                  size: 18,
                                  color: GameTheme.torch,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'WISP GIFT',
                                    style: GameTheme.menuTitle(size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Watch a short ad for the bigger pile '
                              'and 1 hour ×2 gold?',
                              style: GameTheme.body(size: 14),
                            ),
                            if (atCap) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Gold Rush is already stacked to 24h — '
                                'you still get the gold pile.',
                                style: GameTheme.body(
                                  size: 11,
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                            ],
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
                              label: 'NO THANKS',
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
