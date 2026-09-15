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
  WebClickBridge.pushLayer();
  String? code;
  try {
    code = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => const _RedeemCouponDialog(),
    );
  } finally {
    WebClickBridge.popLayer();
  }
  if (code == null) return;
  director.redeemCoupon(code);
}

class _RedeemCouponDialog extends StatefulWidget {
  const _RedeemCouponDialog();

  @override
  State<_RedeemCouponDialog> createState() => _RedeemCouponDialogState();
}

class _RedeemCouponDialogState extends State<_RedeemCouponDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GameTheme.sheet,
      title: Text(
        'REDEEM CODE',
        style: GameTheme.body(size: 16, color: GameTheme.parchment),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        style: GameTheme.body(size: 15, color: GameTheme.parchment),
        cursorColor: GameTheme.torchHot,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Enter code',
          hintStyle: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        GameButton(
          label: 'REDEEM',
          style: GameButtonStyle.brown,
          expanded: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
