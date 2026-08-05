import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../models/gear_set.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import 'custom_assets.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'hero_paper_doll.dart';
import 'kenney_assets.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// WoW-style character sheet: equipment slots around a paper-doll, stats below.
class CharacterEquipPanel extends StatelessWidget {
  const CharacterEquipPanel({
    super.key,
    required this.state,
    required this.heroIndex,
    required this.onSelectHero,
    required this.selectedItemId,
    required this.onSelectItem,
    required this.onUnequip,
    this.compact = false,
  });

  final GameState state;
  final int heroIndex;
  final void Function(int index) onSelectHero;
  final String? selectedItemId;
  final void Function(String id) onSelectItem;
  final void Function(EquipmentSlot slot) onUnequip;
  final bool compact;

  static const leftColumn = <EquipmentSlot>[
    EquipmentSlot.head,
    EquipmentSlot.neck,
    EquipmentSlot.shoulder,
    EquipmentSlot.cloak,
    EquipmentSlot.chest,
    EquipmentSlot.wrist,
  ];

  static const rightColumn = <EquipmentSlot>[
    EquipmentSlot.hands,
    EquipmentSlot.waist,
    EquipmentSlot.legs,
    EquipmentSlot.boots,
    EquipmentSlot.ring,
    EquipmentSlot.ring2,
  ];

  static const weaponRow = <EquipmentSlot>[
    EquipmentSlot.trinket,
    EquipmentSlot.trinket2,
    EquipmentSlot.weapon,
    EquipmentSlot.offHand,
    EquipmentSlot.ranged,
    EquipmentSlot.consumable,
  ];

  static const slotLabels = <EquipmentSlot, String>{
    EquipmentSlot.weapon: 'MH',
    EquipmentSlot.offHand: 'OH',
    EquipmentSlot.ranged: 'RNG',
    EquipmentSlot.head: 'Head',
    EquipmentSlot.shoulder: 'Shoulder',
    EquipmentSlot.chest: 'Chest',
    EquipmentSlot.hands: 'Hands',
    EquipmentSlot.waist: 'Waist',
    EquipmentSlot.legs: 'Legs',
    EquipmentSlot.boots: 'Feet',
    EquipmentSlot.wrist: 'Wrist',
    EquipmentSlot.cloak: 'Back',
    EquipmentSlot.neck: 'Neck',
    EquipmentSlot.ring: 'Finger',
    EquipmentSlot.ring2: 'Finger',
    EquipmentSlot.trinket: 'Trinket',
    EquipmentSlot.trinket2: 'Trinket',
    EquipmentSlot.consumable: 'Flask',
  };

  static String? emptyIconFor(EquipmentSlot slot) => switch (slot) {
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
        EquipmentSlot.trinket2 =>
          CustomAssets.iconTrinket,
        EquipmentSlot.weapon => CustomAssets.iconSword,
        EquipmentSlot.offHand => CustomAssets.iconShield,
        EquipmentSlot.ranged => CustomAssets.iconBow,
        EquipmentSlot.consumable => CustomAssets.iconFlask,
      };

  @override
  Widget build(BuildContext context) {
    final heroes = state.heroes;
    if (heroes.isEmpty) return const SizedBox.shrink();
    final index = heroIndex.clamp(0, heroes.length - 1);
    final hero = heroes[index];
    // Dense enough that balanced 6+6 columns fit with weapons under the doll.
    final slotSize = compact ? 36.0 : 42.0;
    final slotGap = compact ? 3.0 : 4.0;
    final dollSize = compact ? 76.0 : 100.0;

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

    Widget slotFor(EquipmentSlot slot) => PaperDollSlot(
          slot: slot,
          item: hero.itemIn(slot),
          selected: hero.itemIn(slot)?.id == selectedItemId,
          size: slotSize,
          onTap: hero.itemIn(slot) == null
              ? null
              : () => onSelectItem(hero.itemIn(slot)!.id),
          onUnequip:
              hero.itemIn(slot) == null ? null : () => onUnequip(slot),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: heroes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final h = heroes[i];
              final active = i == index;
              return InkWell(
                onTap: () => onSelectHero(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: MenuChrome.cardBox(selected: active),
                  child: Row(
                    children: [
                      HeroDollSprite(hero: h, partyIndex: i, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        '${h.roleLabel} · L${h.level}',
                        style: GameTheme.pixel(size: 8),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.isPartyDefeated
              ? '${hero.roleLabel}  |  Lv${hero.level}  |  iLvl ${_avgItemLevel(hero)}'
                  '  |  WIPED  (max $maxHp)'
              : '${hero.roleLabel}  |  Lv${hero.level}  |  iLvl ${_avgItemLevel(hero)}'
                  '  |  HP ${hero.currentHp.clamp(0, maxHp)}/$maxHp',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 6),
        // WoW paper doll: armor columns + model with weapons under feet.
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
                    width: dollSize + 16,
                    height: dollSize + 16,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF3A2A18),
                          Color(0xFF14100C),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: GameTheme.borderLit.withValues(alpha: 0.7),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: HeroPaperDollView(
                      hero: hero,
                      partyIndex: index,
                      size: dollSize,
                    ),
                  ),
                  if (state.soulboundItem != null) ...[
                    SizedBox(height: slotGap),
                    Text(
                      'SB ${state.soulboundItem!.name}'
                      ' · r${state.metaDepth.soulboundRefine}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.mossLit,
                      ),
                    ),
                  ],
                  SizedBox(height: slotGap),
                  // Weapon / off-hand / ranged / flask under the model (WoW).
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: slotGap,
                    runSpacing: slotGap,
                    children: [for (final s in weaponRow) slotFor(s)],
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
        if (selected != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1610),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _rarityColor(selected.rarity)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.pixel(
                    size: 6,
                    color: _rarityColor(selected.rarity),
                  ),
                ),
                Text(
                  '${slotLabels[selected.slot] ?? selected.slot.name}'
                  ' | i${selected.effectiveItemLevel} | ${selected.statsLine}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchment,
                  ),
                ),
                if (selected.setId != null && selected.setId!.isNotEmpty)
                  Text(
                    () {
                      final piece = selected!;
                      final setId = piece.setId!;
                      final n = GearSets.wornCount(hero.equipped, setId);
                      final bonus = n >= 4
                          ? '4pc'
                          : (n >= 2 ? '2pc' : 'set');
                      return '${piece.setLabel} · $n/4 · $bonus';
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                ('STR', '${ratings.strength}'),
                ('AGI', '${ratings.agility}'),
                ('STA', '${ratings.stamina}'),
                ('INT', '${ratings.intellect}'),
                ('SPI', '${ratings.spirit}'),
                ('DMG', '$atk'),
                ('DEF', '$def'),
                ('CRIT', '${state.effectiveHeroCrit(hero)}%'),
                (
                  'HASTE',
                  state.effectiveHeroAttackSpeed(hero).toStringAsFixed(2),
                ),
                ('LS', '${hero.gearLifestealPercent}%'),
              ]) ...[
                _MiniStat(label: entry.$1, value: entry.$2),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
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
    if (hero.equipped.isEmpty) return 0;
    var sum = 0;
    for (final item in hero.equipped.values) {
      sum += item.effectiveItemLevel;
    }
    return (sum / hero.equipped.length).round();
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
  final Widget Function(EquipmentSlot slot) slotBuilder;

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

class PaperDollSlot extends StatelessWidget {
  const PaperDollSlot({
    super.key,
    required this.slot,
    required this.item,
    required this.selected,
    required this.size,
    this.onTap,
    this.onUnequip,
  });

  final EquipmentSlot slot;
  final EquipmentItem? item;
  final bool selected;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    final border = item == null
        ? GameTheme.border
        : _rarityColor(item!.rarity);
    final emptyIcon = CharacterEquipPanel.emptyIconFor(slot);
    final short = CharacterEquipPanel.slotLabels[slot] ?? slot.name;

    final hit = size < GameTheme.minTouch ? GameTheme.minTouch : size;
    return Tooltip(
      message: item?.name ?? short,
      child: SizedBox(
        width: hit,
        height: hit,
        child: InkWell(
          onTap: onTap,
          onLongPress: onUnequip,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: MenuChrome.cardBox(selected: selected).copyWith(
                border: Border.all(
                  color: selected ? GameTheme.torch : border,
                  width: selected ? 2 : 1.5,
                ),
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
                              style: GameTheme.pixel(
                                size: 5,
                                color: GameTheme.parchment,
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
                            child: KenneySprite(
                              asset: emptyIcon,
                              size: size - 12,
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            short.length <= 4 ? short : short.substring(0, 3),
                            textAlign: TextAlign.center,
                            style: GameTheme.pixel(
                              size: 5,
                              color: GameTheme.parchmentDim,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: MenuChrome.cardBox(inset: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GameTheme.pixel(size: 5, color: GameTheme.parchmentDim),
          ),
          const SizedBox(width: 6),
          Text(value, style: GameTheme.pixel(size: 6, color: GameTheme.torchHot)),
        ],
      ),
    );
  }
}

Color _rarityColor(LootRarity rarity) => switch (rarity) {
      LootRarity.common => const Color(0xFF9A9080),
      LootRarity.uncommon => const Color(0xFF3DD68C),
      LootRarity.rare => const Color(0xFF4A9EFF),
      LootRarity.epic => const Color(0xFFC060FF),
      LootRarity.legendary => const Color(0xFFFF8C40),
    };
