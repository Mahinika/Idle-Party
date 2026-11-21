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

abstract final class RedeemCouponKeys {
  static const redeem = ValueKey<String>('redeem-submit');
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
    _ctrl = TextEditingController()..addListener(_onText);
  }

  bool _hasCode = false;

  void _onText() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasCode) setState(() => _hasCode = has);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    // Empty field: nothing to redeem (polish7 P046).
    if (_ctrl.text.trim().isEmpty) return;
    Navigator.of(context).pop(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return MenuChrome.dialog(
      title: 'REDEEM CODE',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // Never print a live code here (polish7 P046).
              'Got a code from us? Type it here. '
              'Already owned forever scrolls will not burn the code.',
              style: GameTheme.section(color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              style: GameTheme.readable(color: GameTheme.parchment),
              cursorColor: GameTheme.torchHot,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter code',
                hintStyle: GameTheme.readable(color: GameTheme.parchmentDim),
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
          ],
        ),
      ),
      actions: [
        MenuChrome.dialogCancel(
          label: 'CLOSE',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GameButton(
          key: RedeemCouponKeys.redeem,
          label: 'REDEEM',
          style: GameButtonStyle.go,
          expanded: false,
          onPressed: _hasCode ? _submit : null,
        ),
      ],
    );
  }
}
