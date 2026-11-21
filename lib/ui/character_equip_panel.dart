import 'package:flutter/material.dart';

import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/keystone.dart';
import '../core/market_service.dart';
import '../models/combat_ratings.dart';
import '../models/gear_set.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';
import '../models/spec_mastery.dart';
import '../assets/custom_assets.dart';
import 'equipment_icon.dart';
import 'game_icon.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'item_tooltip.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'shell/shell_common.dart';

/// Character sheet inspired by classic mobile RPG equip screens:
/// hero preview, labeled slots around it, big DAMAGE / ARMOR under the doll.
class CharacterEquipPanel extends StatelessWidget {
  static const String slotLegend = 'Main · Off · Ranged · Charms · Flask';
  static const slotLegendKey = ValueKey('equip-slot-legend');

  /// Key stats under the hero name (audit F012). HP is on the line below.
  static String heroStatsLine({required num atk, required num def}) =>
      'AP ${atk.round()} · Armor ${def.round()}';
  static const Key heroStatsLineKey = ValueKey('hero_stats_line');
  static const Key heroGearLineKey = ValueKey('hero_gear_line');

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
    EquipmentSlot.weapon: 'MAIN',
    EquipmentSlot.offHand: 'OFF',
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

  /// Slot chip when a bandage fills the consumable slot.
  static String consumableSlotLabel(EquipmentItem? item) {
    if (item != null && MarketService.isBandageConsumable(item)) {
      return 'BANDAGE';
    }
    return 'FLASK';
  }

  /// Paper-doll label for an empty or filled off-hand (shield / tome / weapon).
  static String offHandLabel(
    OffHandKind? kind, {
    bool lockedByTwoHand = false,
  }) {
    if (lockedByTwoHand) return '2H';
    return switch (kind) {
      OffHandKind.shield => 'SHIELD',
      OffHandKind.frill => 'TOME',
      OffHandKind.weapon => 'OFFHAND',
      null => 'OFFHAND',
    };
  }

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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final roomyText = textScale <= GameTheme.typeScaleMax - 0.01;
    // Slots at the 44/48 dp touch size, not 40 (polish7 P050).
    final slotSize = compact ? 44.0 : 48.0;
    final slotGap = compact ? (roomyText ? 4.0 : 3.0) : 5.0;
    final dollSize = compact ? (roomyText ? 96.0 : 88.0) : 128.0;
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
    final autoWear =
        stashPiece != null &&
        GameLogic.autoEquipWouldWear(
          state,
          stashPiece.id,
          heroIndex: heroIndex,
        );

    Widget heroTab(int i) {
      final h = heroes[i];
      final active = i == index;
      final role = h.displayName(
        plainEnglish: GameLogic.plainPlayerChrome(state),
      );
      final level = 'Lv${h.level}';
      final label = '$role · $level';
      return Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          onTap: () => onSelectHero(i),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 4 : 6,
              ),
              alignment: Alignment.center,
              decoration: MenuChrome.cardBox(selected: active),
              child: Row(
                children: [
                  if (!compact) ...[
                    HeroDollSprite(hero: h, partyIndex: i, size: 26),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      role,
                      key: ValueKey('hero-tab-name-$i'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.readable(color: GameTheme.torchHot),
                    ),
                  ),
                  // Level is a badge: it stays full size and does not scale,
                  // so a long name ellipsizes instead of eating the last digit.
                  Text(
                    ' · $level',
                    key: ValueKey('hero-tab-level-$i'),
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: GameTheme.readable(color: GameTheme.torchHot),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            child: Row(
              children: [
                for (var i = 0; i < heroes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(child: heroTab(i)),
                ],
              ],
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
        ],
        Row(
          children: [
            // ‹ › only when there is no hero chip strip above (F052).
            if (!showHeroStrip)
              GameIconButton(
                glyph: UiGlyph.prev,
                label: 'Previous hero',
                size: 16,
                color: GameTheme.torchHot,
                width: GameTheme.minTouch,
                height: GameTheme.minTouch,
                onPressed: heroes.length > 1
                    ? () => onSelectHero(
                        (index - 1 + heroes.length) % heroes.length,
                      )
                    : null,
              ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    hero.displayName(
                      plainEnglish: GameLogic.plainPlayerChrome(state),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GameTheme.title(),
                  ),
                  // No second, tiny doll here: the big one is right below
                  // (polish7 P050).
                  // Class as the sub-line; the key stats up top, above the
                  // fold on a 640 phone (F010 / F012).
                  Text(
                    'L${hero.level} · ${hero.spec.displayClassName} · ${hero.spec.displaySpecName}',
                    textAlign: TextAlign.center,
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                  Text(
                    CharacterEquipPanel.heroStatsLine(atk: atk, def: def),
                    key: CharacterEquipPanel.heroStatsLineKey,
                    textAlign: TextAlign.center,
                    style: GameTheme.hint(color: GameTheme.parchment),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    () {
                      final avg = _avgDisplayItemLevel(hero);
                      final minIl = _minDisplayItemLevel(hero);
                      return [
                        if (avg != null) 'iLvl $avg',
                        if (avg != null && minIl != null && minIl != avg)
                          'min $minIl',
                      ].join('  ·  ');
                    }(),
                    key: CharacterEquipPanel.heroGearLineKey,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.section(color: GameTheme.parchmentDim),
                  ),
                  Text(
                    state.isPartyDefeated
                        ? 'WIPED'
                        : 'HP ${hero.currentHp.clamp(0, maxHp)}/$maxHp',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: GameTheme.section(color: GameTheme.parchmentDim),
                  ),
                ],
              ),
            ),
            if (!showHeroStrip)
              GameIconButton(
                glyph: UiGlyph.next,
                label: 'Next hero',
                size: 16,
                color: GameTheme.torchHot,
                width: GameTheme.minTouch,
                height: GameTheme.minTouch,
                onPressed: heroes.length > 1
                    ? () => onSelectHero((index + 1) % heroes.length)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 6),
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
                    decoration: MenuChrome.dollWellDecoration(),
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
                      'Heirloom (legacy) ${state.soulboundItem!.name}'
                      '${state.metaDepth.soulboundRefine > 0 ? ' · refine ${state.metaDepth.soulboundRefine} (+${state.soulboundRefineAttackBonus} AP · +${state.soulboundRefineDefenseBonus} Armor)' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GameTheme.hint(color: GameTheme.mossLit),
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
                  Builder(
                    builder: (_) {
                      final blocked = ClassProficiency.weaponBlocksOffHand(
                        hero.itemIn(EquipmentSlot.weapon),
                      );
                      if (blocked) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Two-hand — swap 1H + off-hand from BAG',
                            textAlign: TextAlign.center,
                            style: GameTheme.hint(
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        );
                      }
                      final preferred = ClassProficiency.preferredOffHandKind(
                        hero.spec,
                      );
                      final oh = hero.itemIn(EquipmentSlot.offHand);
                      if (preferred == OffHandKind.shield) {
                        if (oh?.offHandKind == OffHandKind.shield) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Off-hand needs a shield',
                            textAlign: TextAlign.center,
                            style: GameTheme.hint(color: GameTheme.torchHot),
                          ),
                        );
                      }
                      if (preferred == OffHandKind.weapon) {
                        if (oh?.offHandKind == OffHandKind.weapon) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Off-hand needs a dual-wield weapon',
                            textAlign: TextAlign.center,
                            style: GameTheme.hint(color: GameTheme.torchHot),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
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
                  Builder(
                    builder: (context) {
                      final big =
                          MediaQuery.textScalerOf(context).scale(1) > 1.2;
                      final legend = compact && big
                          ? 'Main · Off · Rng · Charms · Flask'
                          : CharacterEquipPanel.slotLegend;
                      return Text(
                        legend,
                        key: CharacterEquipPanel.slotLegendKey,
                        textAlign: TextAlign.center,
                        maxLines: compact && big ? 3 : 2,
                        style: GameTheme.hint(color: GameTheme.parchmentDim),
                      );
                    },
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
                  style: GameTheme.readable(
                    color: itemRarityColor(selected.rarity),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slotLabels[selected.slot] ?? selected.slot.name}'
                  '${gearDisplayIlvlLabel(selected) == null ? '' : ' · ${gearDisplayIlvlLabel(selected)}'}'
                  ' · ${selected.statsLine}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.hint(color: GameTheme.parchment),
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
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                if (compare != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'vs worn  AP${GameLogic.formatDelta(compare.atkDelta)}'
                    '  Armor${GameLogic.formatDelta(compare.defDelta)}'
                    '  STA${GameLogic.formatDelta(compare.vitDelta)}'
                    '${autoWear ? '  UPGRADE' : ''}',
                    style: GameTheme.hint(
                      color: autoWear
                          ? GameTheme.clear
                          : (compare.powerDelta < 0
                                ? GameTheme.bloodLit
                                : GameTheme.parchmentDim),
                    ),
                  ),
                  Text(
                    'Score ${GameLogic.formatDelta(compare.powerDelta)}',
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                ] else if (selectedWornHere)
                  Text(
                    'Equipped · UNEQUIP below · long-press for tip',
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
              ],
            ),
          ),
        ],
        if (onEmptySlotTap != null && !compact) ...[
          const SizedBox(height: 8),
          Text(
            'Tip: tap an empty gear slot to filter BAG to that slot.',
            textAlign: TextAlign.center,
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
        ],
        if (stashPiece != null && compact) ...[
          const SizedBox(height: 8),
          ItemTooltipCard(
            item: stashPiece,
            hero: hero,
            pairingStash: state.gearStash,
            gameState: state,
            compact: true,
          ),
        ],
        SizedBox(height: compact ? 4 : 8),
        if (compact)
          MenuChrome.fold(
            title: 'HERO STATS',
            subtitle: 'AP $atk · Armor $def · HP $maxHp',
            expandLabel: 'All stats',
            collapseLabel: 'Combat only',
            initiallyExpanded: false,
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final entry in _heroStatChips(
                    state,
                    hero,
                    ratings,
                    atk,
                    def,
                    maxHp,
                    includeExtended: true,
                  ))
                    MenuChrome.chip(
                      label: entry.$1,
                      value: entry.$2,
                      stacked: true,
                      minWidth: 72,
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          )
        else ...[
          Text(
            'HERO STATS',
            textAlign: TextAlign.center,
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in _heroStatChips(
                state,
                hero,
                ratings,
                atk,
                def,
                maxHp,
                includeExtended: true,
              ))
                MenuChrome.chip(
                  label: entry.$1,
                  value: entry.$2,
                  stacked: true,
                  minWidth: 72,
                ),
            ],
          ),
          if (((_avgDisplayItemLevel(hero) ?? 0) >= 100) ||
              ((_minDisplayItemLevel(hero) ?? 0) >= 100)) ...[
            const SizedBox(height: 4),
            Text(
              'iLvl past 100 soft-caps — shown value is the budget size.',
              textAlign: TextAlign.center,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
          ],
        ],
      ],
    );
  }

  List<(String, String)> _heroStatChips(
    GameState state,
    PartyHero hero,
    CombatRatings ratings,
    int atk,
    int def,
    int maxHp, {
    bool includeExtended = true,
  }) {
    final kind = SpecMastery.kindFor(hero.specId);
    final masteryLabel = kind == null
        ? 'MASTERY'
        : SpecMastery.playerLabel(kind);
    final combat = <(String, String)>[
      ('DMG', '$atk'),
      ('Armor', '$def'),
      ('HP', '$maxHp'),
      ('CRIT', '${state.effectiveHeroCrit(hero)}%'),
    ];
    if (!includeExtended) return combat;
    final avg = _avgDisplayItemLevel(hero);
    final minIl = _minDisplayItemLevel(hero);
    final keyBonus = state.hardmodeLevel > 0
        ? Keystone.lootItemLevelBonus(state.hardmodeLevel)
        : 0;
    return [
      ('STR', '${ratings.strength}'),
      ('AGI', '${ratings.agility}'),
      ('STA', '${ratings.stamina}'),
      ('INT', '${ratings.intellect}'),
      ('SPI', '${ratings.spirit}'),
      ...combat,
      ('HASTE', state.effectiveHeroAttackSpeed(hero).toStringAsFixed(2)),
      (masteryLabel, '${ratings.masteryPoints.round()}'),
      ('LS', '${hero.gearLifestealPercent}%'),
      if (avg != null) ('iLvl avg', '$avg'),
      if (minIl != null && minIl != avg) ('iLvl min', '$minIl'),
      if (keyBonus > 0) ('KEY loot', '+$keyBonus iLvl'),
    ];
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

  int? _avgDisplayItemLevel(PartyHero hero) {
    final values = <int>[];
    for (final slot in allSlots) {
      final item = hero.itemIn(slot);
      if (item == null) continue;
      final il = gearDisplayIlvl(item);
      if (il != null) values.add(il);
    }
    if (values.isEmpty) return null;
    return (values.fold<int>(0, (a, b) => a + b) / values.length).round();
  }

  int? _minDisplayItemLevel(PartyHero hero) {
    int? minIl;
    for (final slot in allSlots) {
      final item = hero.itemIn(slot);
      if (item == null) continue;
      final il = gearDisplayIlvl(item);
      if (il == null) continue;
      minIl = minIl == null ? il : (il < minIl ? il : minIl);
    }
    return minIl;
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

  /// Dashed frame on an open (empty, not blocked) slot.
  static const Key emptyFrameKey = ValueKey('paper_doll_empty_frame');

  @override
  Widget build(BuildContext context) {
    final blockedOh =
        slot == EquipmentSlot.offHand &&
        hero != null &&
        ClassProficiency.weaponBlocksOffHand(
          hero!.itemIn(EquipmentSlot.weapon),
        );
    // Empty: a dashed plum frame + "+" says "open slot"; filled: the rarity
    // edge for every rarity (audit F011).
    final emptyOpen = item == null && !blockedOh;
    final border = blockedOh
        ? GameTheme.border.withValues(alpha: 0.45)
        : item == null
        ? Colors.transparent
        : itemRarityBorder(item!.rarity);
    final ohKind =
        item?.offHandKind ??
        (hero != null
            ? ClassProficiency.preferredOffHandKind(hero!.spec)
            : null);
    final emptyIcon = CharacterEquipPanel.emptyIconFor(
      slot,
      offHandKind: slot == EquipmentSlot.offHand ? ohKind : null,
    );
    final short = slot == EquipmentSlot.offHand
        ? CharacterEquipPanel.offHandLabel(ohKind, lockedByTwoHand: blockedOh)
        : slot == EquipmentSlot.consumable
        ? CharacterEquipPanel.consumableSlotLabel(item)
        : (CharacterEquipPanel.slotLabels[slot] ?? slot.name);
    final a11y = blockedOh
        ? 'Off-hand empty — two-hand weapon equipped. Tap bag to swap 1H and off-hand.'
        : item == null
        ? 'Empty $short — browse bag'
        : '${item!.name} ${item!.effectiveItemLevel}';

    final hit = size < GameTheme.minTouch ? GameTheme.minTouch : size;
    Widget slotFace;
    if (item != null) {
      slotFace = Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(2),
            child: EquipmentIcon(item: item!, size: size - 4, hero: hero),
          ),
          if (selected && item != null && gearDisplayIlvl(item!) != null)
            Positioned(
              right: 2,
              bottom: 1,
              child: Text(
                '${gearDisplayIlvl(item!)}',
                style: GameTheme.hint(color: GameTheme.parchment),
              ),
            ),
        ],
      );
    } else if (labeled || blockedOh) {
      // At big text the label alone fills a small slot; drop the faint
      // icon rather than overflow (no shrink-to-fit).
      final labelH =
          MediaQuery.textScalerOf(context).scale(GameTheme.typeHint) * 1.25;
      final iconFits = size * 0.38 + labelH <= size - 4;
      slotFace = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (emptyIcon != null && iconFits)
            Opacity(
              opacity: blockedOh ? 0.2 : 0.22,
              child: KenneySprite(asset: emptyIcon, size: size * 0.38),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              short,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
          ),
        ],
      );
    } else if (emptyIcon != null) {
      slotFace = Opacity(
        opacity: 0.28,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: KenneySprite(asset: emptyIcon, size: size - 12),
        ),
      );
    } else {
      slotFace = Center(
        child: Text(
          short.length <= 4 ? short : short.substring(0, 3),
          textAlign: TextAlign.center,
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
      );
    }

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
            child: Opacity(
              opacity: blockedOh ? 0.45 : 1,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: GameTheme.panelInset,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected && !blockedOh ? GameTheme.torchHot : border,
                    width: selected && !blockedOh ? 2 : 1.4,
                  ),
                  boxShadow: selected && !blockedOh
                      ? [
                          BoxShadow(
                            color: GameTheme.torch.withValues(alpha: 0.28),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.hardEdge,
                child: emptyOpen
                    ? CustomPaint(
                        key: PaperDollSlot.emptyFrameKey,
                        foregroundPainter: _DashedFramePainter(
                          color: GameTheme.toggleOnShine.withValues(alpha: 0.8),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            slotFace,
                            Positioned(
                              right: 3,
                              top: 3,
                              child: GameIcon.glyph(
                                UiGlyph.add,
                                size: 9,
                                color: GameTheme.toggleOnShine,
                              ),
                            ),
                          ],
                        ),
                      )
                    : slotFace,
              ),
            ),
          ),
        ),
      ),
    );

    if (blockedOh) {
      return Tooltip(
        message: 'Two-hand equipped — tap BAG to wear 1H + off-hand',
        child: body,
      );
    }
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

/// Dashed rounded frame for an open gear slot.
class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        ).deflate(0.7),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) => old.color != color;
}
