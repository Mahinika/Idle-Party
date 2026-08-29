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
  });

  final Color accent;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String? tag;
  final String? detail;
  final Widget? below;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: MenuChrome.listCard(selected: selected, borderColor: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
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
                            style: GameTheme.pixel(
                              size: GameTheme.hudPixel,
                              color: GameTheme.parchment,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
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
                                size: 9,
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
                        size: 13,
                        color: GameTheme.parchmentDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: GameTheme.body(
                          size: 12,
                          color: GameTheme.mossLit,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
