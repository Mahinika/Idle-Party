import 'package:flutter/material.dart';

import '../game_theme.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Dense POWER upgrade row — accent · title · bonus · trailing buy.
///
/// Shared by Gold forge tracks and Essence sanctuary tracks so both tabs
/// feel like the same idle list family.
class PowerUpgradeRow extends StatelessWidget {
  const PowerUpgradeRow({
    super.key,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.trailing,
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
  final String? tag;
  final String? detail;
  final Widget? below;
  final bool selected;

  /// Tighter pad for phone GOLD / ESSENCE lists.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final titleSize = dense ? 14.0 : 15.0;
    final subSize = dense ? 12.0 : 13.0;
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 2 : 6),
      padding: EdgeInsets.fromLTRB(
        dense ? 8 : 10,
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
                            style: GameTheme.body(
                              size: titleSize,
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
                              style: GameTheme.pixel(
                                size: 8,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GameTheme.body(
                        size: subSize,
                        color: GameTheme.parchmentDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: GameTheme.body(
                          size: dense ? 11 : 12,
                          color: GameTheme.mossLit,
                        ),
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

/// Short buy control for dense FORGE / CAMP lists (~32px, no glow).
class PowerUpgradePriceChip extends StatelessWidget {
  const PowerUpgradePriceChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = enabled
        ? (primary
              ? GameTheme.buttonBrownBottom
              : GameTheme.panelInset)
        : GameTheme.buttonDisabledBottom;
    final border = enabled
        ? (primary
              ? GameTheme.torch.withValues(alpha: 0.65)
              : GameTheme.border.withValues(alpha: 0.75))
        : GameTheme.buttonDisabledBorder;
    final textColor = enabled
        ? (primary ? GameTheme.torchHot : GameTheme.parchment)
        : GameTheme.buttonDisabledText;
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
            child: Ink(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                border: Border.all(color: border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 32,
                  maxHeight: 32,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.button(size: 12, color: textColor),
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
