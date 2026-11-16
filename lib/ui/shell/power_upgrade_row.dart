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
    this.below,
    this.selected = false,
    this.dense = false,
  });

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
                            style: (dense ? GameTheme.readable : GameTheme.section)(
                              color: GameTheme.parchment,
                            ),
                            maxLines: 1,
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
          if (below != null) ...[
            const SizedBox(height: 4),
            below!,
          ],
        ],
      ),
    );
  }
}

/// 48 dp icon tile with a fixed color per stat (left of an upgrade card).
class UpgradeIconTile extends StatelessWidget {
  const UpgradeIconTile({
    super.key,
    required this.icon,
    required this.accent,
    this.size = GameTheme.primaryTouch,
  });

  final String icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(accent, GameTheme.parchment, 0.18)!;
    final bottom = Color.lerp(accent, GameTheme.ink, 0.55)!;
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
            BoxShadow(
              color: GameTheme.chunkyShadow,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: GameIcon.asset(icon, size: size * 0.6),
      ),
    );
  }
}

/// Buy control for dense FORGE / CAMP lists.
///
/// Gold when the wallet covers it, grey when it does not, so the row reads
/// without the words. At least 76x48 dp. [quantity] paints a ×N badge in
/// the corner: the number of buys one tap makes.
class PowerUpgradePriceChip extends StatelessWidget {
  const PowerUpgradePriceChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.quantity,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  /// Buys per tap. Null hides the badge.
  final int? quantity;

  /// Room above the face for the ×N badge.
  static const double badgeLift = 7;

  /// Narrowest gold face. Wide enough for "12.3k essence" at scale 1.
  static const double minFaceWidth = 76;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final q = quantity;
    final face = ChunkyFace(
      tone: enabled ? ChunkyTone.gold : ChunkyTone.grey,
      raised: enabled,
      highlight: primary && enabled,
      minWidth: minFaceWidth,
      minHeight: GameTheme.primaryTouch,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.button(
          size: GameTheme.typeButtonDense,
          color: enabled ? GameTheme.buyGoldText : GameTheme.buyGreyText,
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
        child: Padding(
          padding: const EdgeInsets.only(top: badgeLift),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  child: face,
                ),
              ),
              if (q != null && enabled)
                Positioned(
                  top: -badgeLift - 2,
                  right: -2,
                  child: QtyBadge(quantity: q),
                ),
            ],
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
