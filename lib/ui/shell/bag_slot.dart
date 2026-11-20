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

  /// Icon share of the tile's short side (about 60–70%), snapped to whole
  /// 16 px steps so the nearest-neighbour pixels stay even.
  static double iconSizeFor(double side) {
    final raw = side * 0.66;
    final snapped = (raw / 16).round() * 16.0;
    return snapped.clamp(side * 0.55, side * 0.72).floorToDouble();
  }

  static Widget _badge(String text, Color fill) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text, style: GameTheme.hint(color: GameTheme.clear)),
  );

  @override
  Widget build(BuildContext context) {
    final rarityColor = item == null
        ? GameTheme.rarityCommon
        : rarityBorderColor(item!.rarity);
    final isBest = item != null && isBestStashItem(state, item!);
    final isUpgrade = item != null && isUpgradeForAny(state, item!);
    final upgradeBrief = item != null && isUpgrade
        ? GearUpgradeCopy.bagTileDeltaLine(state, item!)
        : '';
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: item == null
                    ? [
                        GameTheme.panelInset.withValues(alpha: 0.7),
                        GameTheme.stoneDeep.withValues(alpha: 0.75),
                      ]
                    : [
                        Color.lerp(GameTheme.stoneRaised, rarityColor, 0.30)!,
                        Color.lerp(GameTheme.stoneDeep, rarityColor, 0.14)!,
                      ],
              ),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              border: Border.all(
                color: highlight ? GameTheme.torchHot : rarityColor,
                width: highlight ? 2.5 : 2,
              ),
              boxShadow: highlight
                  ? [
                      BoxShadow(
                        color: GameTheme.torch.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.hardEdge,
            child: item == null
                ? Center(
                    child: GameIcon.asset(
                      UiIcon.chest,
                      size: 18,
                      color: GameTheme.parchmentDim.withValues(alpha: 0.35),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      final side = box.biggest.shortestSide;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: EquipmentIcon(
                              key: const ValueKey('bag-slot-icon'),
                              item: item!,
                              size: iconSizeFor(side),
                              hero: hero,
                            ),
                          ),
                          if (ilLabel != null)
                            Positioned(
                              bottom: 1,
                              left: 3,
                              child: ExcludeSemantics(
                                child: Text(
                                  ilLabel,
                                  maxLines: 1,
                                  style:
                                      GameTheme.hint(
                                        color: GameTheme.parchment,
                                      ).copyWith(
                                        shadows: const [
                                          Shadow(
                                            color: GameTheme.chunkyShadow,
                                            offset: Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          if (isBest || isUpgrade)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: ExcludeSemantics(
                                child: _badge(
                                  isBest ? 'BEST' : 'UP',
                                  GameTheme.mossChip,
                                ),
                              ),
                            ),
                          if (upgradeBrief.isNotEmpty)
                            Positioned(
                              top: 2,
                              left: 2,
                              right: 2,
                              child: ExcludeSemantics(
                                child: Text(
                                  upgradeBrief,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GameTheme.hint(color: GameTheme.clear)
                                      .copyWith(
                                        fontSize: 9,
                                        shadows: const [
                                          Shadow(
                                            color: GameTheme.chunkyShadow,
                                            offset: Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          if (isSoulboundItem(item!))
                            Positioned(
                              bottom: 1,
                              right: 3,
                              child: ExcludeSemantics(
                                child: Text(
                                  'SB',
                                  style: GameTheme.hint(
                                    color: GameTheme.torchHot,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
