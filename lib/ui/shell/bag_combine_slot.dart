part of 'inventory_dock.dart';

class _CombineSlot extends StatelessWidget {
  const _CombineSlot({
    required this.label,
    required this.item,
    required this.emptyHint,
    this.onClear,
  });

  final String label;
  final EquipmentItem? item;
  final String emptyHint;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onClear,
      child: Container(
        constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: MenuChrome.cardBox(inset: true, selected: item != null),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                label,
                style: GameTheme.body(
                  size: 12,
                  color: item != null
                      ? GameTheme.torchHot
                      : GameTheme.parchmentDim,
                ),
              ),
            ),
            if (item != null) ...[
              EquipmentIcon(item: item!, size: 24),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(size: 14),
                    ),
                    Text(
                      '${GameLogic.rarityNames[item!.rarity]}'
                      '  i${item!.effectiveItemLevel}',
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                ),
              ),
              GameIcon.glyph(
                UiGlyph.close,
                size: 12,
                color: GameTheme.parchmentDim,
              ),
            ] else
              Expanded(
                child: Text(
                  emptyHint,
                  style: GameTheme.body(
                    size: 14,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
