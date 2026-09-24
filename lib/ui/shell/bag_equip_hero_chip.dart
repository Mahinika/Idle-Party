part of 'inventory_dock.dart';

class _EquipHeroChip extends StatelessWidget {
  const _EquipHeroChip({
    required this.hero,
    required this.candidate,
    required this.onTap,
    this.pairingStash,
    this.isBest = false,
    this.plannedUpgrade = false,
    this.plainEnglish = false,
  });

  final PartyHero hero;
  final EquipmentItem candidate;
  final VoidCallback onTap;
  final List<EquipmentItem>? pairingStash;
  final bool isBest;
  final bool plannedUpgrade;
  final bool plainEnglish;

  @override
  Widget build(BuildContext context) {
    final cmp = GameLogic.compareForHero(
      hero,
      candidate,
      pairingStash: pairingStash,
    );
    final reject = ClassProficiency.rejectReason(
      role: hero.gearAffinity,
      level: hero.level,
      item: candidate,
      specId: hero.specId,
    );
    final cannotUse = reject != null || cmp.powerDelta <= -9000;
    final deltaColor = cannotUse
        ? GameTheme.parchmentDim
        : (cmp.powerDelta > 0
              ? GameTheme.clear
              : (cmp.powerDelta < 0
                    ? GameTheme.statDown
                    : GameTheme.parchmentDim));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cannotUse
                ? GameTheme.equipChipBlocked
                : (plannedUpgrade
                      ? GameTheme.equipChipUpgrade
                      : GameTheme.equipChipNeutral),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isBest
                  ? GameTheme.torchHot
                  : (plannedUpgrade ? GameTheme.clear : GameTheme.borderLit),
              width: isBest ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    hero.displayRoleLabel(plainEnglish: plainEnglish),
                    style: GameTheme.body(size: 11, color: GameTheme.parchment),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 3),
                    Text(
                      'BEST',
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              if (cannotUse)
                Text(
                  reject ?? 'Cannot use',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 10, color: GameTheme.accentWarn),
                )
              else ...[
                Text(
                  'ATK${GameLogic.formatDelta(cmp.atkDelta)} '
                  'DEF${GameLogic.formatDelta(cmp.defDelta)} '
                  'STA${GameLogic.formatDelta(cmp.vitDelta)}',
                  style: GameTheme.body(size: 11, color: deltaColor),
                ),
                Text(
                  'Score ${GameLogic.formatDelta(cmp.powerDelta)}',
                  style: GameTheme.body(
                    size: 10,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                if (plannedUpgrade)
                  Text(
                    'UPGRADE',
                    style: GameTheme.body(size: 10, color: GameTheme.clear),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
