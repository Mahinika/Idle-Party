import 'package:flutter/material.dart';

import '../core/game_guides.dart';
import 'game_theme.dart';
import 'menu_chrome.dart';

/// Expandable how-to guide opened from MORE → GUIDES.
class GuidesOverlay extends StatefulWidget {
  const GuidesOverlay({super.key});

  @override
  State<GuidesOverlay> createState() => _GuidesOverlayState();
}

class _GuidesOverlayState extends State<GuidesOverlay> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final topics = GameGuides.topics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How systems work and how to use them. Tap a topic to expand.',
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: topics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final topic = topics[i];
              final open = _openId == topic.id;
              return Semantics(
                button: true,
                label: 'Guide · ${topic.title}',
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(
                      () => _openId = open ? null : topic.id,
                    ),
                    borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: MenuChrome.cardBox(selected: open),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  topic.title,
                                  style: GameTheme.body(
                                    size: 17,
                                    color: open
                                        ? GameTheme.torchHot
                                        : GameTheme.parchment,
                                  ),
                                ),
                              ),
                              Text(
                                open ? '▾' : '▸',
                                style: GameTheme.body(
                                  size: 16,
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                            ],
                          ),
                          if (open) ...[
                            const SizedBox(height: 8),
                            Text(
                              topic.body,
                              style: GameTheme.body(
                                size: 14,
                                color: GameTheme.parchment,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
