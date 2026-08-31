import 'package:flutter/material.dart';

import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/gear_set.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';
import 'custom_assets.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'item_tooltip.dart';
import 'kenney_assets.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// Character sheet inspired by classic mobile RPG equip screens:
/// hero preview, labeled slots around it, big DAMAGE / ARMOR under the doll.
class CharacterEquipPanel extends StatelessWidget {
  const CharacterEquipPanel({
    super.key,
    required this.state,
    required this.heroIndex,
    required this.onSelectHero,
    required this.selectedItemId,
    required this.onSelectItem,
    required this.onUnequip,
    this.onEmptySlotTap,
    this.compact = false,
    this.showHeroStrip = true,
  });

  final GameState state;
  final int heroIndex;
  final void Function(int index) onSelectHero;
  final String? selectedItemId;
  final void Function(String id) onSelectItem;
  final void Function(EquipmentSlot slot) onUnequip;
  final void Function(EquipmentSlot slot)? onEmptySlotTap;
  final bool compact;
  final bool showHeroStrip;

  /// Left armor column (reference: helm → feet).
  static const leftColumn = <EquipmentSlot>[
    EquipmentSlot.head,
    EquipmentSlot.shoulder,
    EquipmentSlot.chest,
    EquipmentSlot.hands,
    EquipmentSlot.legs,
    EquipmentSlot.boots,
  ];

  /// Right accessory column (reference: neck → charm).
  static const rightColumn = <EquipmentSlot>[
    EquipmentSlot.neck,
    EquipmentSlot.cloak,
    EquipmentSlot.wrist,
    EquipmentSlot.waist,
    EquipmentSlot.ring,
    EquipmentSlot.ring2,
  ];

  /// Bottom weapon row under the doll (weapon / shield emphasized).
  static const weaponRow = <EquipmentSlot>[
    EquipmentSlot.weapon,
    EquipmentSlot.offHand,
    EquipmentSlot.ranged,
    EquipmentSlot.trinket,
    EquipmentSlot.trinket2,
    EquipmentSlot.consumable,
  ];

  static List<EquipmentSlot> get allSlots => [
    ...leftColumn,
    ...rightColumn,
    ...weaponRow,
  ];

  static const slotLabels = <EquipmentSlot, String>{
    EquipmentSlot.weapon: 'WEAPON',
    EquipmentSlot.offHand: 'OFFHAND',
    EquipmentSlot.ranged: 'RANGED',
    EquipmentSlot.head: 'HELM',
    EquipmentSlot.shoulder: 'SHOULDER',
    EquipmentSlot.chest: 'CHEST',
    EquipmentSlot.hands: 'GLOVES',
    EquipmentSlot.waist: 'BELT',
    EquipmentSlot.legs: 'LEGS',
    EquipmentSlot.boots: 'FEET',
    EquipmentSlot.wrist: 'WRIST',
    EquipmentSlot.cloak: 'CAPE',
    EquipmentSlot.neck: 'NECK',
    EquipmentSlot.ring: 'RING1',
    EquipmentSlot.ring2: 'RING2',
    EquipmentSlot.trinket: 'CHARM1',
    EquipmentSlot.trinket2: 'CHARM2',
    EquipmentSlot.consumable: 'FLASK',
  };

  /// Paper-doll label for an empty or filled off-hand (shield / tome / weapon).
  static String offHandLabel(OffHandKind? kind) => switch (kind) {
    OffHandKind.shield => 'SHIELD',
    OffHandKind.frill => 'TOME',
    OffHandKind.weapon => 'OFFHAND',
    null => 'OFFHAND',
  };

  static String? emptyIconFor(EquipmentSlot slot, {OffHandKind? offHandKind}) =>
      switch (slot) {
        EquipmentSlot.head => CustomAssets.iconHelm,
        EquipmentSlot.shoulder => CustomAssets.iconShoulders,
        EquipmentSlot.chest => CustomAssets.iconChest,
        EquipmentSlot.hands => CustomAssets.iconGloves,
        EquipmentSlot.waist => CustomAssets.iconBelt,
        EquipmentSlot.legs => CustomAssets.iconLegs,
        EquipmentSlot.boots => CustomAssets.iconBoots,
        EquipmentSlot.cloak => CustomAssets.iconCloak,
        EquipmentSlot.neck => CustomAssets.iconNeck,
        EquipmentSlot.wrist => CustomAssets.iconWrist,
        EquipmentSlot.ring || EquipmentSlot.ring2 => CustomAssets.iconRing,
        EquipmentSlot.trinket ||
        EquipmentSlot.trinket2 => CustomAssets.iconTrinket,
        EquipmentSlot.weapon => CustomAssets.iconSword,
        EquipmentSlot.offHand => switch (offHandKind) {
          OffHandKind.frill => CustomAssets.iconTome,
          OffHandKind.weapon => CustomAssets.iconSwordAlt,
          _ => CustomAssets.iconShield,
        },
        EquipmentSlot.ranged => CustomAssets.iconBow,
        EquipmentSlot.consumable => CustomAssets.iconFlask,
      };

  @override
  Widget build(BuildContext context) {
    final heroes = state.heroes;
    if (heroes.isEmpty) return const SizedBox.shrink();
    final index = heroIndex.clamp(0, heroes.length - 1);
    final hero = heroes[index];
    final slotSize = compact ? 40.0 : 46.0;
    final slotGap = compact ? 4.0 : 5.0;
    final dollSize = compact ? 96.0 : 120.0;
    final weaponSize = compact ? 44.0 : 50.0;

    final atk = state.effectiveHeroAttack(hero);
    final def = state.effectiveHeroDefense(hero);
    final maxHp = state.effectiveHeroMaxHp(hero);
    final ratings = state.ratingsFor(hero);
    EquipmentItem? selected;
    if (selectedItemId != null) {
      final wornSlot = _slotOfSelected(hero, selectedItemId!);
      if (wornSlot != null) {
        selected = hero.itemIn(wornSlot);
      }
      selected ??= _findAnywhere(selectedItemId!);
    }
    final selectedItem = selected;
    final selectedWornHere =
        selectedItem != null && _slotOfSelected(hero, selectedItem.id) != null;
    final stashPiece =
        selectedItem != null &&
            state.gearStash.any((g) => g.id == selectedItem.id)
        ? selectedItem
        : null;
    final compare = stashPiece == null
        ? null
        : GameLogic.compareForHero(
            hero,
            stashPiece,
            pairingStash: state.gearStash,
          );
    final autoWear = stashPiece != null &&
        GameLogic.autoEquipWouldWear(state, stashPiece.id, heroIndex: heroIndex);

    Widget slotFor(EquipmentSlot slot, {double? size}) {
      final item = hero.itemIn(slot);
      return PaperDollSlot(
        slot: slot,
        item: item,
        hero: hero,
        pairingStash: state.gearStash,
        gameState: state,
        selected: item?.id == selectedItemId,
        size: size ?? slotSize,
        labeled: true,
        onTap: item != null
            ? () => onSelectItem(item.id)
            : (onEmptySlotTap != null ? () => onEmptySlotTap!(slot) : null),
        onUnequip: item == null ? null : () => onUnequip(slot),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeroStrip) ...[
          SizedBox(
            height: GameTheme.minTouch,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: heroes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final h = heroes[i];
                final active = i == index;
                return InkWell(
                  onTap: () => onSelectHero(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: GameTheme.minTouch,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      alignment: Alignment.center,
                      decoration: MenuChrome.cardBox(selected: active),
                      child: Row(
                        children: [
                          HeroDollSprite(hero: h, partyIndex: i, size: 26),
                          const SizedBox(width: 6),
                          Text(
                            '${h.displayRoleLabel(plainEnglish: GameLogic.plainPlayerChrome(state))} · L${h.level}',
                            style: GameTheme.body(size: 11, color: GameTheme.torchHot),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            _HeroArrow(
              icon: Icons.chevron_left_rounded,
              label: 'Previous hero',
              enabled: heroes.length > 1,
              onTap: () =>
                  onSelectHero((index - 1 + heroes.length) % heroes.length),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${hero.spec.name} — L${hero.level}',
                    textAlign: TextAlign.center,
                    style: GameTheme.menuTitle(size: compact ? 18 : 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.isPartyDefeated
                        ? 'iLvl ${_avgItemLevel(hero)} · min ${_minItemLevel(hero)}  ·  WIPED'
                        : 'iLvl ${_avgItemLevel(hero)} · min ${_minItemLevel(hero)}  ·  HP '
                              '${hero.currentHp.clamp(0, maxHp)}/$maxHp',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
            _HeroArrow(
              icon: Icons.chevron_right_rounded,
              label: 'Next hero',
              enabled: heroes.length > 1,
              onTap: () => onSelectHero((index + 1) % heroes.length),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SlotColumn(
              slots: leftColumn,
              slotGap: slotGap,
              slotBuilder: slotFor,
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: dollSize + 28,
                    height: dollSize + 28,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        center: Alignment(0, 0.55),
                        radius: 0.85,
                        colors: [
                          Color(0x5540A090),
                          GameTheme.dollBackdropTop,
                          GameTheme.dollBackdropBottom,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(GameTheme.radiusMd),
                      border: Border.all(
                        color: GameTheme.borderLit.withValues(alpha: 0.55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GameTheme.torch.withValues(alpha: 0.12),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: HeroDollSprite(
                      hero: hero,
                      partyIndex: index,
                      size: dollSize,
                    ),
                  ),
                  if (state.soulboundItem != null) ...[
                    SizedBox(height: slotGap),
                    Text(
                      'Heirloom ${state.soulboundItem!.name}'
                      '${state.metaDepth.soulboundRefine > 0 ? ' · r${state.metaDepth.soulboundRefine}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(size: 11, color: GameTheme.mossLit),
                    ),
                  ],
                  SizedBox(height: slotGap + 2),
                  // Weapon + shield as corner anchors (reference feel).
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      slotFor(EquipmentSlot.weapon, size: weaponSize),
                      SizedBox(width: slotGap + 6),
                      slotFor(EquipmentSlot.offHand, size: weaponSize),
                    ],
                  ),
                  if (ClassProficiency.canUseShield(hero.spec)) ...[
                    const SizedBox(height: 2),
                    Builder(
                      builder: (_) {
                        final hasShield =
                            hero.itemIn(EquipmentSlot.offHand)?.offHandKind ==
                            OffHandKind.shield;
                        return Text(
                          hasShield
                              ? 'Off-hand: shield equipped'
                              : 'Off-hand: Warrior / Paladin / Shaman need a shield',
                          textAlign: TextAlign.center,
                          style: GameTheme.body(
                            size: 11,
                            color: hasShield
                                ? GameTheme.parchmentDim
                                : GameTheme.torchHot,
                          ),
                        );
                      },
                    ),
                  ],
                  SizedBox(height: slotGap),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: slotGap,
                    runSpacing: slotGap,
                    children: [
                      for (final s in const [
                        EquipmentSlot.ranged,
                        EquipmentSlot.trinket,
                        EquipmentSlot.trinket2,
                        EquipmentSlot.consumable,
                      ])
                        slotFor(s),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'FLASK · Dungeon heal',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
            _SlotColumn(
              slots: rightColumn,
              slotGap: slotGap,
              slotBuilder: slotFor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MenuChrome.chip(
                label: 'ATK',
                value: '$atk',
                stacked: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MenuChrome.chip(
                label: 'DEF',
                value: '$def',
                stacked: true,
              ),
            ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: GameTheme.panelInset,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              border: Border.all(color: itemRarityColor(selected.rarity)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 14,
                    color: itemRarityColor(selected.rarity),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slotLabels[selected.slot] ?? selected.slot.name}'
                  ' · i${selected.effectiveItemLevel} · ${selected.statsLine}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 12, color: GameTheme.parchment),
                ),
                if (selected.setId != null && selected.setId!.isNotEmpty)
                  Text(
                    () {
                      final piece = selected!;
                      final setId = piece.setId!;
                      final n = GearSets.wornCount(hero.equipped, setId);
                      final bonus = n >= 4 ? '4pc' : (n >= 2 ? '2pc' : 'set');
                      return '${piece.setLabel} · $n/4 · $bonus';
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                if (compare != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'vs worn  Score ${GameLogic.formatDelta(compare.powerDelta)}'
                        '  A${GameLogic.formatDelta(compare.atkDelta)}'
                        '  D${GameLogic.formatDelta(compare.defDelta)}'
                        '  V${GameLogic.formatDelta(compare.vitDelta)}'
                        '${autoWear ? '  UPGRADE' : ''}',
                    style: GameTheme.body(
                      size: 12,
                      color: autoWear
                          ? GameTheme.clear
                          : (compare.powerDelta < 0
                                ? GameTheme.bloodLit
                                : GameTheme.parchmentDim),
                    ),
                  ),
                ] else if (selectedWornHere)
                  Text(
                    'Equipped · UNEQUIP below · long-press for tip',
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (onEmptySlotTap != null) ...[
          const SizedBox(height: 8),
          Text(
            'Tip: tap an empty gear slot to filter BAG to that slot.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'HERO STATS',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final entry in [
              ('STR', '${ratings.strength}'),
              ('AGI', '${ratings.agility}'),
              ('STA', '${ratings.stamina}'),
              ('INT', '${ratings.intellect}'),
              ('SPI', '${ratings.spirit}'),
              ('DMG', '$atk'),
              ('DEF', '$def'),
              ('HP', '$maxHp'),
              ('CRIT', '${state.effectiveHeroCrit(hero)}%'),
              (
                'HASTE',
                state.effectiveHeroAttackSpeed(hero).toStringAsFixed(2),
              ),
              ('LS', '${hero.gearLifestealPercent}%'),
              ('iLvl', '${_avgItemLevel(hero)}'),
              ('min', '${_minItemLevel(hero)}'),
            ])
              MenuChrome.chip(
                label: entry.$1,
                value: entry.$2,
                stacked: true,
                minWidth: 72,
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  EquipmentItem? _findAnywhere(String id) {
    for (final h in state.heroes) {
      for (final item in h.equipped.values) {
        if (item.id == id) return item;
      }
    }
    for (final item in state.gearStash) {
      if (item.id == id) return item;
    }
    return null;
  }

  EquipmentSlot? _slotOfSelected(PartyHero hero, String id) {
    for (final e in hero.equipped.entries) {
      if (e.value.id == id) return e.key;
    }
    return null;
  }

  int _avgItemLevel(PartyHero hero) {
    final slots = allSlots;
    if (slots.isEmpty) return 0;
    var sum = 0;
    for (final slot in slots) {
      sum += hero.itemIn(slot)?.effectiveItemLevel ?? 0;
    }
    return (sum / slots.length).round();
  }

  int _minItemLevel(PartyHero hero) {
    var minIlvl = 0;
    var any = false;
    for (final slot in allSlots) {
      final il = hero.itemIn(slot)?.effectiveItemLevel ?? 0;
      if (il <= 0) continue;
      if (!any || il < minIlvl) {
        minIlvl = il;
        any = true;
      }
    }
    return minIlvl;
  }
}

class _SlotColumn extends StatelessWidget {
  const _SlotColumn({
    required this.slots,
    required this.slotGap,
    required this.slotBuilder,
  });

  final List<EquipmentSlot> slots;
  final double slotGap;
  final Widget Function(EquipmentSlot slot, {double? size}) slotBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          slotBuilder(slots[i]),
          if (i != slots.length - 1) SizedBox(height: slotGap),
        ],
      ],
    );
  }
}

class _HeroArrow extends StatelessWidget {
  const _HeroArrow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: SizedBox(
          width: 40,
          height: 48,
          child: Icon(
            icon,
            size: 28,
            color: enabled
                ? GameTheme.torchHot
                : GameTheme.parchmentDim.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class PaperDollSlot extends StatelessWidget {
  const PaperDollSlot({
    super.key,
    required this.slot,
    required this.item,
    required this.selected,
    required this.size,
    this.hero,
    this.pairingStash,
    this.gameState,
    this.labeled = false,
    this.onTap,
    this.onUnequip,
  });

  final EquipmentSlot slot;
  final EquipmentItem? item;
  final PartyHero? hero;
  final List<EquipmentItem>? pairingStash;
  final GameState? gameState;
  final bool selected;
  final double size;
  final bool labeled;
  final VoidCallback? onTap;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    final border = item == null
        ? GameTheme.border
        : itemRarityBorder(item!.rarity);
    final ohKind = item?.offHandKind ??
        (hero != null
            ? ClassProficiency.preferredOffHandKind(hero!.spec)
            : null);
    final emptyIcon = CharacterEquipPanel.emptyIconFor(
      slot,
      offHandKind: slot == EquipmentSlot.offHand ? ohKind : null,
    );
    final short = slot == EquipmentSlot.offHand
        ? CharacterEquipPanel.offHandLabel(ohKind)
        : (CharacterEquipPanel.slotLabels[slot] ?? slot.name);
    final a11y = item == null
        ? 'Empty $short — browse bag'
        : '${item!.name} ${item!.effectiveItemLevel}';

    final hit = size < GameTheme.minTouch ? GameTheme.minTouch : size;
    final body = Semantics(
      button: onTap != null || onUnequip != null,
      label: a11y,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: hit,
        height: hit,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: GameTheme.panelInset,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? GameTheme.torchHot : border,
                  width: selected ? 2 : 1.4,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: GameTheme.torch.withValues(alpha: 0.28),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.hardEdge,
              child: item != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: KenneySprite(
                            asset: KenneyAssets.equipmentIconFor(item!),
                            size: size - 8,
                          ),
                        ),
                        if (item!.effectiveItemLevel > 0)
                          Positioned(
                            right: 2,
                            bottom: 1,
                            child: Text(
                              '${item!.effectiveItemLevel}',
                              style: GameTheme.body(
                                size: 9,
                                color: GameTheme.parchment,
                              ),
                            ),
                          ),
                      ],
                    )
                  : labeled
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (emptyIcon != null)
                          Opacity(
                            opacity: 0.22,
                            child: KenneySprite(
                              asset: emptyIcon,
                              size: size * 0.38,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            short,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.body(
                              size: 10,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ),
                      ],
                    )
                  : emptyIcon != null
                  ? Opacity(
                      opacity: 0.28,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: KenneySprite(asset: emptyIcon, size: size - 12),
                      ),
                    )
                  : Center(
                      child: Text(
                        short.length <= 4 ? short : short.substring(0, 3),
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 10,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );

    if (item == null) {
      return Tooltip(message: 'Empty $short — tap to browse bag', child: body);
    }
    return ItemTooltipAnchor(
      item: item!,
      hero: hero,
      pairingStash: pairingStash,
      gameState: gameState,
      child: body,
    );
  }
}
