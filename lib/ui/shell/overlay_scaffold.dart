import 'package:flutter/material.dart';
import '../cave_atmosphere.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

class OverlayScrim extends StatelessWidget {
  const OverlayScrim({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle = '',
    this.heightFactor = 0.85,
  });

  final String title;
  /// One-line job hint under the title (TT2-style: one tab = one job).
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: _PlaytestBridgeLayer(
        child: Material(
          color: MenuChrome.scrim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Tap outside the sheet to dismiss.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: CaveAtmosphere.torchBloom(
                    intensity: 0.7,
                    alignment: const Alignment(0, 0.1),
                    sizeFactor: 0.85,
                  ),
                ),
              ),
              // Phone product: full-width sheet (never the centered desktop card).
              _MobileSheet(
                title: title,
                subtitle: subtitle,
                onClose: onClose,
                heightFactor: heightFactor,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaytestBridgeLayer extends StatefulWidget {
  const _PlaytestBridgeLayer({required this.child});
  final Widget child;

  @override
  State<_PlaytestBridgeLayer> createState() => _PlaytestBridgeLayerState();
}

class _PlaytestBridgeLayerState extends State<_PlaytestBridgeLayer> {
  @override
  void initState() {
    super.initState();
    WebClickBridge.pushLayer();
  }

  @override
  void dispose() {
    WebClickBridge.popLayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MobileSheet extends StatelessWidget {
  const _MobileSheet({
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle = '',
    this.heightFactor = 0.85,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final fullHeight = heightFactor >= 0.99;
    // Absorb taps so scrim-dismiss behind the sheet does not fire.
    final sheet = GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: _OverlayPanel(
        title: title,
        subtitle: subtitle,
        onClose: onClose,
        margin: EdgeInsets.zero,
        // Full-height tabs: square top so hub never peeks in the corners.
        borderRadius: fullHeight ? BorderRadius.zero : MenuChrome.sheetRadius,
        // Full height: skip drag handle — reclaim vertical space.
        showHandle: !fullHeight,
        child: child,
      ),
    );

    if (fullHeight) {
      // Fill the Expanded stack above [AppBottomBar] — bar already owns the
      // home-indicator inset, so do not shrink the sheet with viewPadding.
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SizedBox.expand(child: sheet),
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          widthFactor: 1,
          child: sheet,
        ),
      ),
    );
  }
}

class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel({
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle = '',
    this.margin = const EdgeInsets.all(16),
    this.borderRadius,
    this.showHandle,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final EdgeInsets margin;
  final BorderRadius? borderRadius;
  final bool? showHandle;

  @override
  Widget build(BuildContext context) {
    final handle = showHandle ?? borderRadius != null;
    final panel = Container(
      margin: margin,
      padding: EdgeInsets.fromLTRB(12, handle ? 6 : 6, 12, 8),
      decoration: MenuChrome.panel(borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (handle) MenuChrome.sheetHandle(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GameTheme.menuTitle(size: 18)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                const Spacer(),
              GameButton(
                label: 'CLOSE',
                onPressed: onClose,
                style: GameButtonStyle.grey,
                expanded: false,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: GameTheme.borderLit.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
    // Mobile sheet already wraps SafeArea; avoid double bottom inset.
    if (margin == EdgeInsets.zero) return panel;
    return SafeArea(top: false, child: panel);
  }
}
