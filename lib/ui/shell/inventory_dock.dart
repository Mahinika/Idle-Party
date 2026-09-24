import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gear_service.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../character_equip_panel.dart';
import '../equipment_icon.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/roster_panel.dart';
import '../item_tooltip.dart';
import '../web_click_bridge.dart';
import 'bag_cleanup_filters.dart';
import 'shell_common.dart';

part 'bag_equip_hero_chip.dart';
part 'bag_slot.dart';
part 'bag_combine_slot.dart';

class InventoryDock extends StatefulWidget {
  /// MERGE footer. BiS waits until first-hour plain chrome lifts.
  static String mergeFooterHint({required bool plainEnglish}) => plainEnglish
      ? 'Merges junk pairs of the same slot (skips upgrades). Uses gold.'
      : 'Merges junk pairs of the same slot (skips upgrades and BiS (kept safe)). Uses gold.';

  const InventoryDock({
    super.key,
    required this.state,
    required this.director,
    required this.selectedId,
    required this.combineA,
    required this.combineB,
    required this.panel,
    required this.onPanelChanged,
    required this.onSelect,
    required this.onPutCombine,
    required this.onEquip,
    required this.onUnequip,
    required this.bagSlotFilter,
    required this.onBrowseBagSlot,
    required this.onClearBagSlotFilter,
    required this.equipHeroIndex,
    required this.onEquipHeroChanged,
    required this.onEquipToHero,
    required this.onAutoEquip,
    required this.onClearCombineA,
    required this.onClearCombineB,
    required this.onCombine,
    required this.onCleanBag,
    required this.onAutoMerge,
    this.onOpenMarket,
    this.flatChrome = false,
  });

  final GameState state;
  final GameDirector director;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
  final GearPanel panel;
  final ValueChanged<GearPanel> onPanelChanged;
  final bool flatChrome;
  final void Function(String id) onSelect;
  final void Function(String id) onPutCombine;
  final VoidCallback onEquip;
  final void Function(EquipmentSlot slot) onUnequip;
  final EquipmentSlot? bagSlotFilter;
  final void Function(EquipmentSlot slot) onBrowseBagSlot;
  final VoidCallback onClearBagSlotFilter;
  final int equipHeroIndex;
  final void Function(int index) onEquipHeroChanged;
  final void Function(int heroIndex) onEquipToHero;
  final VoidCallback onAutoEquip;
  final VoidCallback onClearCombineA;
  final VoidCallback onClearCombineB;
  final VoidCallback onCombine;
  final VoidCallback onCleanBag;
  final VoidCallback onAutoMerge;
  final VoidCallback? onOpenMarket;

  @override
  State<InventoryDock> createState() => _InventoryDockState();
}

class _InventoryDockState extends State<InventoryDock>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<GearPanel> _visible = const [GearPanel.gear, GearPanel.bag];
  bool _showFilters = false;

  GameState get state => widget.state;
  String? get selectedId => widget.selectedId;
  String? get combineA => widget.combineA;
  String? get combineB => widget.combineB;
  void Function(String id) get onSelect => widget.onSelect;
  void Function(String id) get onPutCombine => widget.onPutCombine;
  VoidCallback get onEquip => widget.onEquip;
  void Function(EquipmentSlot slot) get onUnequip => widget.onUnequip;
  EquipmentSlot? get bagSlotFilter => widget.bagSlotFilter;
  void Function(EquipmentSlot slot) get onBrowseBagSlot =>
      widget.onBrowseBagSlot;
  VoidCallback get onClearBagSlotFilter => widget.onClearBagSlotFilter;
  int get equipHeroIndex => widget.equipHeroIndex;
  void Function(int index) get onEquipHeroChanged => widget.onEquipHeroChanged;
  void Function(int heroIndex) get onEquipToHero => widget.onEquipToHero;
  VoidCallback get onAutoEquip => widget.onAutoEquip;
  VoidCallback get onClearCombineA => widget.onClearCombineA;
  VoidCallback get onClearCombineB => widget.onClearCombineB;
  VoidCallback get onCombine => widget.onCombine;
  VoidCallback get onCleanBag => widget.onCleanBag;
  VoidCallback get onAutoMerge => widget.onAutoMerge;
  VoidCallback? get onOpenMarket => widget.onOpenMarket;

  bool _itemMatchesBagFilter(EquipmentItem item, EquipmentSlot filter) {
    return GameLogic.equipTargetsFor(item).contains(filter);
  }

  String _gearPanelReason(GearPanel tab) {
    final meet = MenuAlerts.meetRosterHint(state);
    if (meet.isNotEmpty && tab != GearPanel.roster) return meet;

    switch (tab) {
      case GearPanel.gear:
        return MenuAlerts.gearEquipHint(state, equipHeroIndex);
      case GearPanel.bag:
        final upgrades = MenuAlerts.bagUpgradeCount(state);
        if (upgrades > 0) {
          return upgrades == 1
              ? '1 better item in bag — tap EQUIP 1'
              : '$upgrades better items in bag — tap EQUIP $upgrades';
        }
        return MenuAlerts.bagStatusLine(state);
      case GearPanel.merge:
      case GearPanel.roster:
        final alert = MenuAlerts.partyAlert(state);
        return alert.isQuiet ? '' : alert.reason;
    }
  }

  @override
  void initState() {
    super.initState();
    // GEAR / BAG always exist; advanced tabs append as they unlock.
    _tabs = FlexTabs(
      vsync: this,
      length: 2,
      initialIndex: widget.panel == GearPanel.gear ? 0 : 1,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) widget.onPanelChanged(_visible[i]);
      },
    );
  }

  @override
  void didUpdateWidget(covariant InventoryDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panel != GearPanel.bag && _showFilters) {
      _showFilters = false;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// One-tap "wear the better stuff" — says how many so the bag is not a chore.
  Widget _autoEquipButton({bool dense = false, bool expanded = true}) {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    return GameButton(
      label: upgrades > 0 ? 'EQUIP $upgrades' : 'EQUIP',
      tip: upgrades > 0
          ? 'One tap: equip all $upgrades upgrades now'
          : MenuAlerts.bagEquipIdleTip(state),
      onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
      primary: upgrades > 0 && !dense,
      dense: dense,
      expanded: expanded,
      style: upgrades > 0 ? GameButtonStyle.brown : GameButtonStyle.grey,
    );
  }

  /// Combinator slots only resolve bag items (never equipped).
  EquipmentItem? _findStash(String? id) {
    if (id == null) return null;
    return GameLogic.findStashGear(state, id);
  }

  Widget _equipTab() {
    final worn = selectedId == null
        ? null
        : GameLogic.findEquippedLocation(state, selectedId!);
    final inStash =
        selectedId != null && state.gearStash.any((g) => g.id == selectedId);

    Widget actions() {
      final upgrades = MenuAlerts.bagUpgradeCount(state);
      final singleLabel = worn != null ? 'UNEQUIP' : 'EQUIP';
      final singleAction = worn != null
          ? () => onUnequip(worn.slot)
          : (inStash ? onEquip : null);
      // Selected item keeps its own EQUIP/UNEQUIP; bulk upgrades stay secondary.
      if (selectedId != null && (worn != null || inStash)) {
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: GameButton(
                label: singleLabel,
                onPressed: singleAction,
                style: worn != null
                    ? GameButtonStyle.grey
                    : GameButtonStyle.brown,
                primary: worn == null,
                dense: true,
                expanded: true,
              ),
            ),
            if (upgrades > 0) ...[
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _autoEquipButton(dense: true, expanded: true),
              ),
            ] else ...[
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: GameButton(
                  label: 'OPEN BAG',
                  onPressed: () => widget.onPanelChanged(GearPanel.bag),
                  style: GameButtonStyle.grey,
                  dense: true,
                  expanded: true,
                ),
              ),
            ],
          ],
        );
      }
      // Upgrades: EQUIP N + OPEN BAG. Empty upgrade list: one OPEN BAG only
      // (avoid twin OPEN BAG / BAG that both do the same thing).
      if (upgrades > 0) {
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: _autoEquipButton(dense: true, expanded: true),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: GameButton(
                label: 'OPEN BAG',
                onPressed: () => widget.onPanelChanged(GearPanel.bag),
                style: GameButtonStyle.grey,
                dense: true,
                expanded: true,
              ),
            ),
          ],
        );
      }
      return GameButton(
        label: 'OPEN BAG',
        onPressed: () => widget.onPanelChanged(GearPanel.bag),
        style: GameButtonStyle.grey,
        primary: false,
        dense: true,
        expanded: true,
      );
    }

    Widget sheet() {
      return CharacterEquipPanel(
        state: state,
        heroIndex: equipHeroIndex,
        onSelectHero: onEquipHeroChanged,
        selectedItemId: selectedId,
        onSelectItem: onSelect,
        onUnequip: onUnequip,
        onEmptySlotTap: onBrowseBagSlot,
        compact: true,
      );
    }

    // Phone product only: doll + actions; bag lives on its own GEAR → BAG tab.
    // (A side-by-side / stacked bag pane used to appear in wide browsers and
    // looked nothing like the APK the player installs.)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SingleChildScrollView(child: sheet())),
        const SizedBox(height: 4),
        actions(),
      ],
    );
  }

  Widget _equipHeroChipsFor(EquipmentItem selected) {
    final plannedHero = [
      for (var i = 0; i < state.heroes.length; i++)
        if (GameLogic.autoEquipWouldWear(state, selected.id, heroIndex: i)) i,
    ];
    final bestIndex = plannedHero.isEmpty ? -1 : plannedHero.first;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < state.heroes.length; i++)
          _EquipHeroChip(
            hero: state.heroes[i],
            candidate: selected,
            pairingStash: state.gearStash,
            isBest: i == bestIndex,
            plannedUpgrade: i == bestIndex,
            plainEnglish: GameLogic.plainPlayerChrome(state),
            onTap: () => onEquipToHero(i),
          ),
      ],
    );
  }

  Widget _bagTab(List<EquipmentItem?> slots, EquipmentItem? primary) {
    final cap = GameLogic.maxGearStashFor(state);
    final filled = state.gearStash.length;
    final nearFull = GearService.isBagJammed(state);
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    final showShopChip =
        onOpenMarket != null &&
        upgrades == 0 &&
        !nearFull &&
        MenuTabs.showShop(state);
    final mergeOpen = MenuTabs.showMerge(state);
    final bagHint = MenuAlerts.bagPanelHint(state);
    final filter = bagSlotFilter;
    final filterLabel = filter == null
        ? null
        : (CharacterEquipPanel.slotLabels[filter] ?? filter.name);
    final filteredSlots = filter == null
        ? slots
        : [
            for (final item in state.gearStash)
              if (_itemMatchesBagFilter(item, filter)) item,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nearFull && filled >= cap
                    ? 'BAG FULL'
                    : nearFull
                    ? 'NEARLY FULL'
                    : 'CAPACITY',
                style: GameTheme.body(
                  size: 14,
                  color: nearFull
                      ? GameTheme.accentWarn
                      : GameTheme.parchmentDim,
                ),
              ),
            ),
            Text(
              '$filled / $cap',
              style: GameTheme.body(
                size: 15,
                color: nearFull ? GameTheme.accentWarn : GameTheme.parchment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: cap <= 0 ? 0 : (filled / cap).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: GameTheme.panelInset,
            color: filled >= cap
                ? GameTheme.bloodLit
                : nearFull
                ? GameTheme.accentWarn
                : GameTheme.mossLit,
          ),
        ),
        const SizedBox(height: 4),
        if (filter != null) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MenuChrome.chip(
                label: filterLabel ?? filter.name,
                selected: true,
                tone: GameTheme.torchHot,
              ),
              Text(
                filteredSlots.isEmpty
                    ? 'none in bag'
                    : '${filteredSlots.length} in bag',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
              MenuChrome.chip(label: 'CLEAR', onTap: onClearBagSlotFilter),
            ],
          ),
          const SizedBox(height: 4),
        ] else if (bagHint.isNotEmpty)
          Text(
            bagHint,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        const SizedBox(height: 6),
        if (showShopChip)
          Center(
            child: MenuChrome.chip(
              label: 'Need gear? → Shop',
              onTap: onOpenMarket,
            ),
          ),
        if (showShopChip) const SizedBox(height: 6),
        Expanded(
          child: _showFilters
              ? SingleChildScrollView(
                  child: BagCleanupFilters(
                    director: widget.director,
                    compact: true,
                  ),
                )
              : filteredSlots.isEmpty && filter != null
              ? Center(
                  child: Text(
                    'No $filterLabel gear in BAG.\nLoot more, or CLEAR filter.',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, gridConstraints) {
                    return GridView.builder(
                      itemCount: filteredSlots.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            mainAxisExtent: 72,
                          ),
                      itemBuilder: (context, index) {
                        final item = filteredSlots[index];
                        final selected = item != null && item.id == selectedId;
                        final inCombine =
                            item != null &&
                            (item.id == combineA || item.id == combineB);
                        final combineFiltered =
                            primary != null &&
                            item != null &&
                            item.slot != primary.slot;
                        return _BagSlot(
                          item: item,
                          state: state,
                          hero: state.heroes.isEmpty
                              ? null
                              : state.heroes[equipHeroIndex.clamp(
                                  0,
                                  state.heroes.length - 1,
                                )],
                          highlight: selected || inCombine,
                          dimmed: combineFiltered,
                          onTap: item == null || combineFiltered
                              ? null
                              : () => onSelect(item.id),
                          onLongPress: null,
                        );
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 4),
        _autoEquipButton(),
        const SizedBox(height: 4),
        GameButton(
          label: 'CLEAN BAG',
          tip: MenuAlerts.bagCleanButtonTip(state),
          onPressed: state.gearStash.isEmpty ? null : onCleanBag,
          style: GameButtonStyle.grey,
        ),
        const SizedBox(height: 4),
        GameButton(
          label: 'FILTERS',
          tip: MenuAlerts.bagFiltersButtonTip(state, showing: _showFilters),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          style: _showFilters ? GameButtonStyle.brown : GameButtonStyle.grey,
        ),
        if (mergeOpen && selectedId != null) ...[
          const SizedBox(height: 4),
          GameButton(
            label: 'ADD TO MERGE',
            onPressed: GameLogic.findStashGear(state, selectedId!) == null
                ? null
                : () => onPutCombine(selectedId!),
            style: GameButtonStyle.grey,
          ),
        ],
        if (selectedId != null) ...[
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final selected = GameLogic.findGear(state, selectedId!);
              if (selected == null) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selected.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 14,
                      color: itemRarityColor(selected.rarity),
                    ),
                  ),
                  Text(
                    selected.statsLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(size: 12, color: GameTheme.torchHot),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equip on:',
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _equipHeroChipsFor(selected),
                ],
              );
            },
          ),
        ] else
          Text(
            mergeOpen
                ? 'Tap item to select · long-press for tip · ADD TO MERGE for MERGE tab.'
                : 'Tap item to select · long-press for tip.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        if (state.gearStash.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Bag empty — clear floors for loot, or open BAG after a run.',
              style: GameTheme.body(size: 12, color: GameTheme.mossLit),
            ),
          ),
      ],
    );
  }

  Widget _toolsTab({
    required EquipmentItem? primary,
    required EquipmentItem? secondary,
    required bool canCombine,
    required int cost,
    required EquipmentItem? preview,
  }) {
    final slotLabel = primary?.slot.name ?? secondary?.slot.name;
    final goldOk = canCombine && state.gold >= cost;
    final status = () {
      if (primary == null && secondary == null) {
        return 'Load two same-slot items from BAG (ADD TO MERGE).';
      }
      if (primary == null || secondary == null) {
        return 'Add one more item of the same slot from BAG.';
      }
      if (!canCombine) {
        return 'Slots must match — clear one and pick the same gear type.';
      }
      if (!goldOk) {
        return 'Need $cost gold to merge (have ${state.gold}).';
      }
      return 'Ready — merge destroys both and creates one stronger piece.';
    }();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabelScoped('MERGE', scope: MenuScope.run),
          const SizedBox(height: 4),
          Text(
            'Sacrifice two bag items of the same slot for one upgraded result. Equipped gear is never used.'
            '${state.metaDepth.combinatorLuck > 0 ? ' Charm luck ${state.metaDepth.combinatorLuck}/5 · −${state.metaDepth.combinatorLuck * 3}g on MERGE.' : ''}',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          if (slotLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Slot filter: $slotLabel',
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ],
          const SizedBox(height: 8),
          _CombineSlot(
            label: 'BASE',
            emptyHint: 'First item',
            item: primary,
            onClear: combineA == null ? null : onClearCombineA,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '+',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
            ),
          ),
          _CombineSlot(
            label: 'FUEL',
            emptyHint: 'Same slot as BASE',
            item: secondary,
            onClear: combineB == null ? null : onClearCombineB,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: MenuChrome.cardBox(inset: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  preview == null
                      ? 'RESULT  —'
                      : () {
                          final delta = primary == null
                              ? 0
                              : preview.powerScore - primary.powerScore;
                          final jump = delta > 0 ? '  +$delta' : '';
                          return 'RESULT  ${GameLogic.rarityNames[preview.rarity]}'
                              '  i${preview.effectiveItemLevel}'
                              '  SCORE ${preview.powerScore}$jump';
                        }(),
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: preview == null
                        ? GameTheme.parchmentDim
                        : GameTheme.torchHot,
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview.statsLine,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(size: 12, color: GameTheme.parchment),
                  ),
                  if (primary != null && secondary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Cost $cost g · '
                      '${GameLogic.rarityNames[primary.rarity]} i${primary.effectiveItemLevel} + '
                      '${GameLogic.rarityNames[secondary.rarity]} i${secondary.effectiveItemLevel}'
                      ' → ${GameLogic.rarityNames[preview.rarity]} i${preview.effectiveItemLevel}',
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ],
                  if (preview.effectLabel.isNotEmpty)
                    Text(
                      preview.effectLabel,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(size: 12, color: GameTheme.mossLit),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: goldOk
                ? 'MERGE  $cost g'
                : (canCombine ? 'MERGE  $cost g' : 'MERGE'),
            onPressed: goldOk ? onCombine : null,
            style: GameButtonStyle.red,
            primary: true,
          ),
          const SizedBox(height: 6),
          GameButton(
            label: 'AUTO MERGE',
            onPressed: state.gearStash.length < 2 ? null : onAutoMerge,
            style: GameButtonStyle.grey,
          ),
          const SizedBox(height: 4),
          Text(
            InventoryDock.mergeFooterHint(
              plainEnglish: GameLogic.plainPlayerChrome(state),
            ),
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          if (primary == null || secondary == null) ...[
            const SizedBox(height: 6),
            GameButton(
              label: 'OPEN BAG',
              onPressed: () => widget.onPanelChanged(GearPanel.bag),
              style: GameButtonStyle.grey,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Flask heals the party in the dungeon.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = _findStash(combineA);
    final secondary = _findStash(combineB);
    final canCombine =
        primary != null &&
        secondary != null &&
        GameLogic.canCombine(primary, secondary);
    final cost = canCombine ? GameLogic.combineCost(primary, secondary) : 0;
    final preview = canCombine
        ? GameLogic.previewCombine(primary, secondary)
        : null;
    final slots = List<EquipmentItem?>.generate(
      GameLogic.maxGearStashFor(state),
      (i) => i < state.gearStash.length ? state.gearStash[i] : null,
    );
    // Progressive menu: MERGE / ROSTER appear once they do something.
    _visible = MenuRouter.visibleGearPanels(state);
    final safeTab = _visible.contains(widget.panel)
        ? widget.panel
        : _visible.first;
    if (safeTab != widget.panel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPanelChanged(safeTab);
      });
    }
    final pages = <({String label, Widget body})>[
      for (final tab in _visible)
        switch (tab) {
          GearPanel.gear => (label: 'GEAR', body: _equipTab()),
          GearPanel.bag => (label: 'BAG', body: _bagTab(slots, primary)),
          GearPanel.merge => (
            label: 'MERGE',
            body: _toolsTab(
              primary: primary,
              secondary: secondary,
              canCombine: canCombine,
              cost: cost,
              preview: preview,
            ),
          ),
          GearPanel.roster => (
            label: 'ROSTER',
            body: SingleChildScrollView(
              child: TeamCompositionOverlay(director: widget.director),
            ),
          ),
        },
    ];
    _tabs.syncToId(_visible, safeTab);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          tabs: [
            for (var i = 0; i < pages.length; i++)
              MenuChrome.bridgedTab(
                pages[i].label,
                onSelect: () {
                  _tabs.controller.animateTo(i);
                  widget.onPanelChanged(_visible[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        Builder(
          builder: (context) {
            final reason = _gearPanelReason(safeTab);
            if (reason.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GameTheme.body(size: 12, color: GameTheme.torchHot),
              ),
            );
          },
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs.controller,
            // Phone: no horizontal swipe between tabs (avoids mid-swipe overlap
            // and fights vertical bag scroll). Tap the tab rail instead.
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final page in pages) page.body],
          ),
        ),
      ],
    );

    // Overlay GEAR already has panel chrome — skip nested “second sheet”
    // so the menu sits flush to the top with no dead strip.
    if (widget.flatChrome) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
        child: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.panel.withValues(alpha: 0.94),
            GameTheme.stoneDeep.withValues(alpha: 0.97),
          ],
        ),
        border: Border(
          top: BorderSide(color: GameTheme.borderLit.withValues(alpha: 0.4)),
        ),
        boxShadow: [
          BoxShadow(
            color: GameTheme.torch.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
          const BoxShadow(
            color: GameTheme.shadowMid,
            blurRadius: 16,
            offset: Offset(0, -6),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(GameTheme.radiusLg),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: body,
    );
  }
}

