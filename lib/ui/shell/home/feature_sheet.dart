import 'package:flutter/material.dart';

import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';

/// Full-screen sheet template: title, scroll, primary action at the thumb.
///
/// Built for later features. QUESTS is the first caller.
Future<void> showFeatureSheet({
  required BuildContext context,
  required String title,
  String? countdown,
  required Widget body,
  String? primaryLabel,
  VoidCallback? onPrimary,
}) {
  WebClickBridge.pushLayer();
  return showDialog<void>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.72;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: SizedBox(
          height: height,
          child: DecoratedBox(
          decoration: MenuChrome.panel(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: GameTheme.menuTitle(size: 18)),
                if (countdown != null && countdown.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    countdown,
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.torchHot,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(child: body),
                const SizedBox(height: 8),
                Row(
                  children: [
                    WebClickScope(
                      label: 'Back',
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Back'),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (primaryLabel != null)
                      GameButton(
                        label: primaryLabel,
                        expanded: false,
                        onPressed: () {
                          onPrimary?.call();
                          Navigator.of(ctx).pop();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      );
    },
  ).whenComplete(WebClickBridge.popLayer);
}
