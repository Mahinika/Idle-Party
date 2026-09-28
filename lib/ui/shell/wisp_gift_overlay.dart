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
import 'shell_common.dart';

/// Floating WISP on hub and dungeon (top center, clear of map chrome).
class WispGiftOverlay extends StatelessWidget {
  const WispGiftOverlay({super.key, required this.director});

  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) {
        if (!director.isWispVisible) return const SizedBox.shrink();
        final minimal =
            director.state.vfxQuality == VfxQuality.minimal;
        return Positioned(
          top: MediaQuery.paddingOf(context).top + 56,
          left: 0,
          right: 0,
          child: Center(
            child: _WispTapTarget(
              minimal: minimal,
              onTap: director.tapWispGift,
            ),
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
                  final scale = widget.minimal ? 1.0 : 0.92 + t * 0.12;
                  final glow = widget.minimal ? 0.35 : 0.25 + t * 0.45;
                  return Transform.scale(
                    scale: scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: GameTheme.torch.withValues(alpha: glow),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon.glyph(
                      UiGlyph.wisp,
                      size: 40,
                      color: GameTheme.torchHot,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'WISP',
                      style: GameTheme.pixel(
                        size: 9,
                        color: GameTheme.parchment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// KEEP (dismiss) vs WATCH (rewarded ad) after collecting the small pile.
Future<void> openWispChoiceSheet(
  BuildContext context,
  GameDirector director,
) async {
  if (!director.wispPendingChoice) return;
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
            final keep = md.wispPendingKeepGold;
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
                              'You kept +${formatCount(keep)} gold.',
                              style: GameTheme.body(size: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Watch a short ad on hub for the bigger pile '
                              'and 1 hour ×2 gold. Fights never pause for ads.',
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.parchmentDim,
                              ),
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
                              label: 'WATCH · $watchLabel',
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await director.watchWispGiftAd();
                              },
                            ),
                            const SizedBox(height: 8),
                            GameButton(
                              label: 'KEEP',
                              style: GameButtonStyle.grey,
                              onPressed: () {
                                director.dismissWispPending();
                                Navigator.of(ctx).pop();
                              },
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
}
