import 'package:flutter/material.dart';
import '../cave_atmosphere.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

class OverlayScrim extends StatelessWidget {
  const OverlayScrim({super.key, 
    required this.title,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.85,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
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
              onClose: onClose,
              heightFactor: heightFactor,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSheet extends StatelessWidget {
  const _MobileSheet({
    required this.title,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.85,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    // Absorb taps so scrim-dismiss behind the sheet does not fire.
    final sheet = GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: _OverlayPanel(
        title: title,
        onClose: onClose,
        margin: EdgeInsets.zero,
        borderRadius: MenuChrome.sheetRadius,
        // Full-height GEAR: skip drag handle — reclaim vertical space.
        showHandle: heightFactor < 0.99,
        child: child,
      ),
    );

    if (heightFactor >= 0.99) {
      // Phone GEAR: flush to the top of the view — no dead strip from
      // SafeArea / browser safe-area-inset. Keep a bottom home-bar pad only.
      final bottom = MediaQuery.viewPaddingOf(context).bottom;
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox.expand(child: sheet),
        ),
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
    this.margin = const EdgeInsets.all(16),
    this.borderRadius,
    this.showHandle,
  });

  final String title;
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
            children: [
              if (title.isNotEmpty)
                Expanded(
                  child: Text(
                    title,
                    style: GameTheme.menuTitle(size: 18),
                  ),
                )
              else
                const Spacer(),
              KenneyButton(
                label: 'CLOSE',
                onPressed: onClose,
                style: KenneyButtonStyle.grey,
                expanded: false,
                primary: true,
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

/// POWER pillar — forge · sanctuary · market · essence shop.
