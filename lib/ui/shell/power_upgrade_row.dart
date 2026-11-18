import 'package:flutter/material.dart';

import '../chunky_face.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Dense POWER upgrade row: icon tile · title · "now › next" · buy.
///
/// Shared by Gold forge tracks and Essence sanctuary tracks so both tabs
/// feel like the same idle list family. [subtitle] is the current value;
/// when [gainNext] is set the line reads "subtitle › gainNext" with the next
/// value in green.
class PowerUpgradeRow extends StatelessWidget {
  const PowerUpgradeRow({
    super.key,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.leading,
    this.gainNext,
    this.gainNote,
    this.tag,
    this.detail,
    this.progress,
    this.below,
    this.selected = false,
    this.dense = false,
    this.titleLines = 1,
  });

  /// Max lines for [title]. MARKET item names may wrap to two.
  final int titleLines;

  final Color accent;
  final String title;
  final String subtitle;
  final Widget trailing;

  /// Icon tile left of the title. Null keeps the old accent dot.
  final Widget? leading;

  /// Value after the buy, painted green after an arrow.
  final String? gainNext;

  /// Dim suffix after [gainNext] (for example SOFT).
  final String? gainNote;
  final String? tag;
  final String? detail;

  /// Purple bar toward the next soft cap (0..1). Null: no bar.
  final double? progress;
  final Widget? below;
  final bool selected;

  /// Tighter pad for phone GOLD / ESSENCE lists.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final lead = leading;
    final next = gainNext;
    final note = gainNote;
    final effectStyle = GameTheme.hint(color: GameTheme.parchmentDim);
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 4 : 6),
      padding: EdgeInsets.fromLTRB(
        lead != null ? 6 : (dense ? 8 : 10),
        dense ? 3 : 8,
        dense ? 6 : 8,
        dense ? 3 : 8,
      ),
      decoration: MenuChrome.listCard(selected: selected, borderColor: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (lead != null) ...[
                lead,
                const SizedBox(width: 8),
              ] else
                Container(
                  width: dense ? 7 : 8,
                  height: dense ? 7 : 8,
                  margin: EdgeInsets.only(right: dense ? 8 : 10),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: (dense
                                ? GameTheme.readable
                                : GameTheme
                                      .section)(color: GameTheme.parchment),
                            maxLines: titleLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: GameTheme.panelInset,
                              borderRadius: BorderRadius.circular(
                                GameTheme.radiusSm,
                              ),
                              border: Border.all(
                                color: GameTheme.torch.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              tag!,
                              style: GameTheme.hint(color: GameTheme.torchHot),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (next == null)
                      Text(
                        subtitle,
                        style: effectStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text.rich(
                        TextSpan(
                          style: effectStyle,
                          children: [
                            TextSpan(text: subtitle),
                            const TextSpan(text: ' › '),
                            TextSpan(
                              text: next,
                              style: GameTheme.hint(color: GameTheme.gainGreen),
                            ),
                            if (note != null) TextSpan(text: ' · $note'),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (progress != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 1),
                        child: SoftCapBar(value: progress!),
                      ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: GameTheme.hint(color: GameTheme.torchHot),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              trailing,
            ],
          ),
          if (below != null) ...[const SizedBox(height: 4), below!],
        ],
      ),
    );
  }
}

/// 48 dp icon tile with a fixed color per stat (left of an upgrade card).
///
/// Pass an [icon] asset, or a [child] (for example an item sprite) to paint
/// inside the same tile. [dim] greys a locked tile.
class UpgradeIconTile extends StatelessWidget {
  const UpgradeIconTile({
    super.key,
    this.icon,
    this.child,
    required this.accent,
    this.size = GameTheme.primaryTouch,
    this.dim = false,
  }) : assert(icon != null || child != null);

  final String? icon;
  final Widget? child;
  final Color accent;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final tone = dim ? GameTheme.buyGreyTop : accent;
    final top = Color.lerp(tone, GameTheme.parchment, dim ? 0.05 : 0.18)!;
    final bottom = Color.lerp(tone, GameTheme.ink, 0.55)!;
    final mark = child ?? GameIcon.asset(icon!, size: size * 0.6);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          border: Border.all(color: GameTheme.buyGoldEdge, width: 2),
          boxShadow: const [
            BoxShadow(color: GameTheme.chunkyShadow, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: dim ? Opacity(opacity: 0.45, child: mark) : mark,
      ),
    );
  }
}

/// Buy control for dense FORGE / CAMP lists.
///
/// Gold when the wallet covers it, grey when it does not, so the row reads
/// without the words. The tap area is at least 76x48 dp around a lighter
/// 64x36 face. [quantity] paints a ×N badge in the face's corner: the
/// number of buys one tap makes.
class PowerUpgradePriceChip extends StatelessWidget {
  const PowerUpgradePriceChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.quantity,
    this.essence = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  /// The price is essence, not gold: the face uses the essence tone.
  final bool essence;

  /// Buys per tap. Null hides the badge.
  final int? quantity;

  /// Room above the face for the ×N badge.
  static const double badgeLift = 7;

  /// Narrowest gold face.
  static const double minFaceWidth = 64;

  /// Tap area floor around the face.
  static const double minTapWidth = 76;
  static const double minTapHeight = GameTheme.primaryTouch;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final q = quantity;
    final face = ChunkyFace(
      tone: !enabled
          ? ChunkyTone.grey
          : (essence ? ChunkyTone.essence : ChunkyTone.gold),
      raised: enabled,
      highlight: primary && enabled,
      minWidth: minFaceWidth,
      minHeight: GameTheme.chunkyFace,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.button(
          size: GameTheme.typeBody,
          color: !enabled
              ? GameTheme.buyGreyText
              : (essence ? GameTheme.essenceBuyText : GameTheme.buyGoldText),
        ),
      ),
    );
    return WebClickScope(
      label: label,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: TapPad(
              minWidth: minTapWidth,
              minHeight: minTapHeight,
              child: Padding(
                padding: const EdgeInsets.only(top: badgeLift),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    face,
                    // ×1 is what the selector already says; the badge only
                    // speaks when one tap buys more than once.
                    if (q != null && q > 1 && enabled)
                      Positioned(
                        top: -badgeLift - 1,
                        right: -3,
                        child: QtyBadge(quantity: q),
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

/// Small rose ×N pill in a buy button's corner.
class QtyBadge extends StatelessWidget {
  const QtyBadge({super.key, required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GameTheme.toggleOnTop, GameTheme.toggleOnBottom],
          ),
          borderRadius: BorderRadius.circular(GameTheme.radiusHud),
          border: Border.all(color: GameTheme.buyGoldEdge),
        ),
        child: Text(
          '×$quantity',
          maxLines: 1,
          style: GameTheme.hint(color: GameTheme.toggleOnText),
        ),
      ),
    );
  }
}

/// Thin purple bar: how far a track is toward its soft cap.
class SoftCapBar extends StatelessWidget {
  const SoftCapBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: 'Soft cap ${(v * 100).round()}%',
      excludeSemantics: true,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: GameTheme.levelAccentDeep,
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GameTheme.levelAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
