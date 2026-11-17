import 'package:flutter/material.dart';

import '../chunky_face.dart';
import '../game_theme.dart';
import '../web_click_bridge.dart';

/// How many buys one tap makes. Shared by FORGE and CAMP. Not saved.
enum BuyQty { one, ten, max }

/// ×1 · ×10 · MAX. The picked one has a rose rim and rose text on a
/// pressed stone face: a secondary pick, so the FORGE/CAMP tab above stays
/// the one filled rose face on screen. Long-press MAX for the
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

  /// Per-button tap floor: 48 wide, 44 tall, around a 40x32 face.
  static const double buttonWidth = GameTheme.primaryTouch;
  static const double faceWidth = 40;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(BuyQty.one, '×1'),
        _button(BuyQty.ten, '×10'),
        _button(BuyQty.max, maxLabel, longPress: onMaxLongPress),
      ],
    );
  }

  Widget _button(BuyQty qty, String label, {VoidCallback? longPress}) {
    final selected = value == qty;
    const tone = ChunkyTone.stone;
    final textColor = selected
        ? GameTheme.toggleOnAccent
        : GameTheme.parchmentDim;
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
            child: TapPad(
              minWidth: buttonWidth,
              child: ChunkyFace(
                tone: tone,
                raised: !selected,
                edgeColor: selected ? GameTheme.toggleOnAccent : null,
                minWidth: faceWidth,
                minHeight: GameTheme.chunkyFaceDense,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.button(
                    size: GameTheme.typeBody,
                    color: textColor,
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
