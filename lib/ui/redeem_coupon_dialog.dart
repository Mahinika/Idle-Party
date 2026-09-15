import 'package:flutter/material.dart';

import '../core/game_director.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';
import 'web_click_bridge.dart';

Future<void> showRedeemCouponDialog(
  BuildContext context,
  GameDirector director,
) async {
  final ctrl = TextEditingController();
  WebClickBridge.pushLayer();
  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: GameTheme.sheet,
          title: Text(
            'REDEEM CODE',
            style: GameTheme.body(size: 16, color: GameTheme.parchment),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            style: GameTheme.body(size: 15, color: GameTheme.parchment),
            cursorColor: GameTheme.torchHot,
            onSubmitted: (_) {
              final code = ctrl.text;
              Navigator.of(ctx).pop();
              director.redeemCoupon(code);
            },
            decoration: InputDecoration(
              hintText: 'Enter code',
              hintStyle: GameTheme.body(
                size: 14,
                color: GameTheme.parchmentDim,
              ),
              filled: true,
              fillColor: GameTheme.panelInset,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                borderSide: BorderSide(color: GameTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                borderSide: BorderSide(color: GameTheme.torch),
              ),
            ),
          ),
          actions: [
            MenuChrome.dialogCancel(
              label: 'CLOSE',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            GameButton(
              label: 'REDEEM',
              style: GameButtonStyle.brown,
              expanded: false,
              onPressed: () {
                final code = ctrl.text;
                Navigator.of(ctx).pop();
                director.redeemCoupon(code);
              },
            ),
          ],
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
    ctrl.dispose();
  }
}
