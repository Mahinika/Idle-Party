part of 'inventory_dock.dart';

/// Small AUTO EQUIP switch for the BAG action row: "AUTO" plus a pixel
/// track that is lit when on. 44 dp tall tap area, reads as a toggle.
class _AutoEquipSwitch extends StatelessWidget {
  const _AutoEquipSwitch({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  static const double _trackW = 22;
  static const double _trackH = 12;

  @override
  Widget build(BuildContext context) {
    final tip = on
        ? 'AUTO EQUIP is on: wears upgrades during the fight and while the '
              'app is closed. Tap to stop.'
        : 'AUTO EQUIP is off. Tap to wear upgrades during the fight and '
              'while the app is closed.';
    final track = Container(
      width: _trackW,
      height: _trackH,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? GameTheme.mossChip : GameTheme.panelInset,
        border: Border.all(
          color: on ? GameTheme.mossLit : GameTheme.border,
          width: 1,
        ),
      ),
      child: Container(
        width: _trackH - 4,
        height: _trackH - 4,
        color: on ? GameTheme.torchHot : GameTheme.parchmentDim,
      ),
    );
    return WebClickScope(
      label: 'AUTO EQUIP',
      onPressed: () => onChanged(!on),
      child: Semantics(
        key: InventoryDock.bagAutoEquipKey,
        button: true,
        toggled: on,
        label: 'AUTO EQUIP',
        onTap: () => onChanged(!on),
        excludeSemantics: true,
        child: Tooltip(
          message: tip,
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: false,
          child: InkWell(
            onTap: () => onChanged(!on),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
              child: Center(
                widthFactor: 1,
                child: ChunkyFace(
                  tone: on ? ChunkyTone.stone : ChunkyTone.grey,
                  highlight: on,
                  minHeight: GameTheme.minTouch - 6,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AUTO',
                        style: GameTheme.hint(
                          color: on
                              ? GameTheme.torchHot
                              : GameTheme.parchmentDim,
                        ),
                      ),
                      const SizedBox(width: 5),
                      track,
                    ],
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

/// FILTERS as a square icon chip (sell / scrap rules), 44 dp.
class _BagFiltersButton extends StatelessWidget {
  const _BagFiltersButton({
    required this.showing,
    required this.tip,
    required this.onTap,
  });

  final bool showing;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: 'FILTERS',
      onPressed: onTap,
      child: Semantics(
        key: InventoryDock.bagFiltersKey,
        button: true,
        toggled: showing,
        label: 'FILTERS',
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: 'FILTERS — $tip',
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: false,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: GameTheme.minTouch,
              child: Center(
                child: ChunkyFace(
                  tone: showing ? ChunkyTone.gold : ChunkyTone.grey,
                  highlight: showing,
                  minWidth: GameTheme.minTouch - 6,
                  minHeight: GameTheme.minTouch - 6,
                  padding: EdgeInsets.zero,
                  child: GameIcon.asset(UiIcon.settings, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
