import 'package:flutter/material.dart';
import '../../models/vfx_quality.dart';
import '../cave_atmosphere.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';
import 'shell_layout.dart';
import 'wallet_strip.dart';

class OverlayScrim extends StatelessWidget {
  const OverlayScrim({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle = '',
    this.heightFactor = 0.85,
    this.gold,
    this.essence,
    this.showEssence = true,
    this.showClose = true,
  });

  final String title;
  /// One-line job hint under the title (TT2-style: one tab = one job).
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;
  final int? gold;
  final int? essence;
  final bool showEssence;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final calm = _calmScrim(context);
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
                  child: calm
                      ? const SizedBox.expand(key: Key('scrim-static'))
                      : CaveAtmosphere.torchBloom(
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
                gold: gold,
                essence: essence,
                showEssence: showEssence,
                showClose: showClose,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal VFX and the OS reduce-motion flag keep the sheet scrim still.
bool _calmScrim(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return true;
  var minimal = false;
  context.visitAncestorElements((element) {
    final name = element.widget.runtimeType.toString();
    if (name != 'MenuSurface' &&
        name != 'PlayShell' &&
        name != 'HomeShell' &&
        name != 'HubScreen') {
      return true;
    }
    final dynamic host = element.widget;
    final dynamic quality = host.director?.state?.vfxQuality;
    if (quality is VfxQuality) {
      minimal = quality == VfxQuality.minimal;
      return false;
    }
    return true;
  });
  return minimal;
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
    this.gold,
    this.essence,
    this.showEssence = true,
    this.showClose = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;
  final int? gold;
  final int? essence;
  final bool showEssence;
  final bool showClose;

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
        gold: gold,
        essence: essence,
        showEssence: showEssence,
        showClose: showClose,
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
      top: false,
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
    this.gold,
    this.essence,
    this.showEssence = true,
    this.showClose = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final EdgeInsets margin;
  final BorderRadius? borderRadius;
  final bool? showHandle;
  final int? gold;
  final int? essence;
  final bool showEssence;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final handle = showHandle ?? borderRadius != null;
    final showHeader =
        title.isNotEmpty || showClose || gold != null || essence != null;
    final panel = Container(
      margin: margin,
      padding: EdgeInsets.fromLTRB(
        12,
        handle ? 6 : (showHeader ? 6 : 0),
        12,
        8,
      ),
      decoration: MenuChrome.panel(borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (handle) MenuChrome.sheetHandle(),
          if (showHeader)
            _SheetHeader(
              title: title,
              subtitle: subtitle,
              onClose: onClose,
              gold: gold,
              essence: essence,
              showEssence: showEssence,
              showClose: showClose,
            ),
          if (showHeader) ...[
            ShellLayout.gap(4),
            ShellLayout.divider(),
            ShellLayout.gap(6),
          ],
          Expanded(child: child),
        ],
      ),
    );
    // Mobile sheet already wraps SafeArea; avoid double bottom inset.
    if (margin == EdgeInsets.zero) return panel;
    return SafeArea(top: false, child: panel);
  }
}

/// Sheet title stays one word. At M and up the wallet row is too wide to
/// share a line with Cinzel, so the title takes the full width.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.gold,
    required this.essence,
    required this.showEssence,
    required this.showClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final int? gold;
  final int? essence;
  final bool showEssence;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final showWallet = gold != null && essence != null;
    final titleBlock = title.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: GameTheme.title(),
              ),
              if (subtitle.isNotEmpty) ...[
                ShellLayout.gap(2),
                ShellLayout.hint(subtitle, maxLines: 2),
              ],
            ],
          );
    final close = GameButton(
      label: 'CLOSE',
      onPressed: onClose,
      style: GameButtonStyle.grey,
      expanded: false,
      dense: true,
    );
    final wallet = showWallet
        ? WalletStrip(
            gold: gold!,
            essence: essence!,
            showEssence: showEssence,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = _textWidth(title, GameTheme.title());
        final walletWidth = showWallet ? _textWidth('888.8k', GameTheme.button(size: GameTheme.typeButton)) * (showEssence ? 2.4 : 1.2) : 0.0;
        final closeWidth = showClose ? 96.0 : 0.0;
        final stack = showWallet &&
            titleWidth + walletWidth + closeWidth + 24 > constraints.maxWidth;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?titleBlock,
              const SizedBox(height: 6),
              Row(
                children: [
                  wallet!,
                  const Spacer(),
                  if (showClose) close,
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleBlock != null) Expanded(child: titleBlock) else const Spacer(),
            if (wallet != null) ...[
              const SizedBox(width: 6),
              wallet,
              const SizedBox(width: 6),
            ],
            if (showClose) close,
          ],
        );
      },
    );
  }

  static double _textWidth(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}
