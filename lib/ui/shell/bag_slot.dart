part of 'inventory_dock.dart';

class _BagSlot extends StatelessWidget {
  const _BagSlot({
    required this.item,
    required this.state,
    required this.highlight,
    this.hero,
    this.dimmed = false,
    this.onTap,
    this.onLongPress,
  });

  final EquipmentItem? item;
  final GameState state;
  final PartyHero? hero;
  final bool highlight;
  final bool dimmed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static String _slotHint(EquipmentSlot slot) {
    return switch (slot) {
      EquipmentSlot.weapon => 'Main',
      EquipmentSlot.offHand => 'Off',
      EquipmentSlot.ranged => 'Ranged',
      EquipmentSlot.head => 'Head',
      EquipmentSlot.shoulder => 'Shldr',
      EquipmentSlot.chest => 'Chest',
      EquipmentSlot.hands => 'Hand',
      EquipmentSlot.waist => 'Belt',
      EquipmentSlot.legs => 'Legs',
      EquipmentSlot.boots => 'Feet',
      EquipmentSlot.wrist => 'Wrist',
      EquipmentSlot.cloak => 'Back',
      EquipmentSlot.neck => 'Neck',
      EquipmentSlot.ring || EquipmentSlot.ring2 => 'Ring',
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'Trink',
      EquipmentSlot.consumable => 'Flask',
    };
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = item == null
        ? GameTheme.rarityCommon
        : rarityBorderColor(item!.rarity);
    final isBest = item != null && isBestStashItem(state, item!);
    final isUpgrade = item != null && isUpgradeForAny(state, item!);
    final ilLabel = item == null ? null : gearDisplayIlvlLabel(item!);
    final a11yLabel = item == null
        ? 'Empty bag slot'
        : ilLabel == null
        ? item!.name
        : '${item!.name}, item level ${ilLabel.substring(1)}';
    final slot = Opacity(
      opacity: dimmed ? 0.25 : 1,
      child: Semantics(
        button: item != null,
        label: a11yLabel,
        onTap: onTap,
        onLongPress: onLongPress,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item == null
                    ? [
                        GameTheme.panelInset.withValues(alpha: 0.7),
                        GameTheme.stoneDeep.withValues(alpha: 0.75),
                      ]
                    : [
                        Color.lerp(GameTheme.stoneRaised, rarityColor, 0.18)!,
                        Color.lerp(GameTheme.stoneDeep, rarityColor, 0.1)!,
                      ],
              ),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              border: Border.all(
                color: highlight ? GameTheme.torchHot : rarityColor,
                width: highlight ? 1.6 : 1.1,
              ),
              boxShadow: highlight
                  ? [
                      BoxShadow(
                        color: GameTheme.torch.withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.hardEdge,
            child: item == null
                ? const SizedBox.shrink()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 3, color: rarityColor),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: EquipmentIcon(
                            item: item!,
                            size: 26,
                            hero: hero,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        left: 6,
                        child: ExcludeSemantics(
                          child: Text(
                            _slotHint(item!.slot),
                            style: GameTheme.body(
                              size: 10,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ),
                      ),
                      if (ilLabel != null)
                        Positioned(
                          bottom: 2,
                          left: 6,
                          child: ExcludeSemantics(
                            child: Text(
                              ilLabel,
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.parchment,
                              ),
                            ),
                          ),
                        ),
                      if (isUpgrade && !isBest)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: GameTheme.mossChip,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'UP',
                              style: GameTheme.body(
                                size: 10,
                                color: GameTheme.clear,
                              ),
                            ),
                          ),
                        ),
                      if (isBest)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: GameTheme.mossChip,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'BEST',
                              style: GameTheme.body(
                                size: 10,
                                color: GameTheme.clear,
                              ),
                            ),
                          ),
                        ),
                      if (isSoulboundItem(item!))
                        Positioned(
                          bottom: 2,
                          right: 3,
                          child: Text(
                            'SB',
                            style: GameTheme.body(
                              size: 10,
                              color: GameTheme.torchHot,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (item == null) return slot;
    return WebClickScope(
      label: item!.name,
      onPressed: onTap,
      child: ItemTooltipAnchor(
        item: item!,
        hero: hero,
        pairingStash: state.gearStash,
        gameState: state,
        child: slot,
      ),
    );
  }
}
