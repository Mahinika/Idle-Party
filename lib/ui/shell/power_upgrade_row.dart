import 'package:flutter/material.dart';

import '../game_theme.dart';
import '../menu_chrome.dart';

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
      margin: EdgeInsets.only(bottom: dense ? 3 : 6),
      padding: EdgeInsets.fromLTRB(
        dense ? 8 : 10,
        dense ? 5 : 8,
        dense ? 6 : 8,
        dense ? 5 : 8,
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
                            dense ? '$title $subtitle' : title,
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
                    if (!dense) ...[
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
                    ],
                    if (detail != null)
                      Text(
                        detail!,
                        style: GameTheme.body(
                          size: dense ? 11 : 12,
                          color: GameTheme.mossLit,
                        ),
                        maxLines: 1,
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
