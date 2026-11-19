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
            // Label column grows with text scale: a fixed 44 made
            // "SECOND" run into its value at 1.45.
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(44) + 4,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: GameTheme.hint(color: item != null
                      ? GameTheme.torchHot
                      : GameTheme.parchmentDim),
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
                      style: GameTheme.readable(),
                    ),
                    Text(
                      '${GameLogic.rarityNames[item!.rarity]}'
                      '  i${item!.effectiveItemLevel}',
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Clear merge slot',
                child: GameIcon.glyph(
                  UiGlyph.close,
                  size: 16,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ] else
              Expanded(
                // Muted italic prompt, so it does not read as a picked
                // value (audit F056).
                child: Text(
                  emptyHint,
                  style: GameTheme.hint(
                    color: GameTheme.parchmentDim,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
