import 'package:flutter/material.dart';

import '../chunky_face.dart';
import '../game_theme.dart';
import '../web_click_bridge.dart';

/// How many buys one tap makes. Shared by FORGE and CAMP. Not saved.
enum BuyQty { one, ten, max }

/// ×1 · ×10 · MAX. The picked one is rose. Long-press MAX for the
/// wallet-slice sheet (FORGE 5/25/50/100%) when [onMaxLongPress] is set.
class BuyQtyToggle extends StatelessWidget {
  const BuyQtyToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.onMaxLongPress,
    this.maxLabel = 'MAX',
  });

  final BuyQty value;
  final ValueChanged<BuyQty> onChanged;

  /// Opens finer bulk choices. Null: MAX has no long-press.
  final VoidCallback? onMaxLongPress;

  /// Face text on MAX (a wallet slice such as "25%" when one is picked).
  final String maxLabel;

  /// Per-button floor: 48 wide, 44 tall.
  static const double buttonWidth = GameTheme.primaryTouch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(BuyQty.one, '×1'),
        const SizedBox(width: 6),
        _button(BuyQty.ten, '×10'),
        const SizedBox(width: 6),
        _button(BuyQty.max, maxLabel, longPress: onMaxLongPress),
      ],
    );
  }

  Widget _button(BuyQty qty, String label, {VoidCallback? longPress}) {
    final selected = value == qty;
    final tone = selected ? ChunkyTone.rose : ChunkyTone.stone;
    final semantics = qty == BuyQty.max && longPress != null
        ? '$label · hold for wallet slices'
        : label;
    return WebClickScope(
      label: label,
      onPressed: () => onChanged(qty),
      child: Semantics(
        button: true,
        selected: selected,
        label: semantics,
        onTap: () => onChanged(qty),
        onLongPress: longPress,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(qty),
            onLongPress: longPress,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: ChunkyFace(
              tone: tone,
              raised: !selected,
              minWidth: buttonWidth,
              minHeight: GameTheme.minTouch,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.button(
                  size: GameTheme.typeButtonDense,
                  color: ChunkyFace.textOn(tone),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
