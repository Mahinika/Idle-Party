import 'package:flutter/material.dart';

import '../core/game_guides.dart';
import '../core/game_state.dart';
import 'game_theme.dart';
import 'menu_chrome.dart';
import 'web_click_bridge.dart';

/// Expandable how-to guide opened from MORE → INFO.
class GuidesOverlay extends StatefulWidget {
  const GuidesOverlay({super.key, this.state});

  /// When set, first-hour saves only see early topics.
  final GameState? state;

  @override
  State<GuidesOverlay> createState() => _GuidesOverlayState();
}

class _GuidesOverlayState extends State<GuidesOverlay> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final topics = widget.state == null
        ? GameGuides.topics
        : GameGuides.topicsFor(widget.state!);
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
              void toggle() => setState(() => _openId = open ? null : topic.id);
              return WebClickScope(
                label: 'Guide ${topic.title}',
                onPressed: toggle,
                child: Semantics(
                  button: true,
                  selected: open,
                  label: 'Guide · ${topic.title}',
                  onTap: toggle,
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: toggle,
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(
                          minHeight: GameTheme.minTouch,
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: MenuChrome.cardBox(selected: open),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
