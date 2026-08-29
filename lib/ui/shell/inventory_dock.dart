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
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../meta_overlays.dart';
import '../item_tooltip.dart';
import '../web_click_bridge.dart';
import 'shell_common.dart';

class InventoryDock extends StatefulWidget {
  const InventoryDock({
    super.key,
    required this.state,
    required this.director,
    required this.selectedId,
    required this.combineA,
    required this.combineB,
    required this.tab,
    required this.onTabChanged,
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
    required this.onOpenFilters,
    required this.onAutoMerge,
    this.onOpenMarket,
    this.flatChrome = false,
  });

  final GameState state;
  final GameDirector director;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
  final PartyTab tab;
  final ValueChanged<PartyTab> onTabChanged;
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
  final VoidCallback onOpenFilters;
  final VoidCallback onAutoMerge;
  final VoidCallback? onOpenMarket;

  @override
  State<InventoryDock> createState() => _InventoryDockState();
}

class _InventoryDockState extends State<InventoryDock>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<PartyTab> _visible = const [PartyTab.gear, PartyTab.bag];

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
  VoidCallback get onOpenFilters => widget.onOpenFilters;
  VoidCallback get onAutoMerge => widget.onAutoMerge;
  VoidCallback? get onOpenMarket => widget.onOpenMarket;

  bool _itemMatchesBagFilter(EquipmentItem item, EquipmentSlot filter) {
    return GameLogic.equipTargetsFor(item).contains(filter);
  }

  String _partyTabReason(PartyTab tab) {
    final meet = MenuAlerts.meetRosterHint(state);
    if (meet.isNotEmpty && tab != PartyTab.roster) return meet;

    switch (tab) {
      case PartyTab.gear:
        return MenuAlerts.gearEquipHint(state, equipHeroIndex);
      case PartyTab.bag:
        final upgrades = MenuAlerts.bagUpgradeCount(state);
        if (upgrades > 0) {
          return upgrades == 1
              ? '1 better item in bag — use EQUIP below'
              : '$upgrades better items in bag — use EQUIP below';
        }
        return MenuAlerts.bagStatusLine(state);
      case PartyTab.merge:
      case PartyTab.roster:
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
      initialIndex: widget.tab == PartyTab.gear ? 0 : 1,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) widget.onTabChanged(_visible[i]);
      },
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// One-tap "wear the better stuff" — says how many so the bag is not a chore.
  Widget _autoEquipButton() {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    return KenneyButton(
      label: upgrades > 0 ? 'EQUIP $upgrades' : 'AUTO EQUIP',
      tip: upgrades > 0
          ? 'One tap: equip all $upgrades upgrades now'
          : 'No upgrades waiting — scans bag when new gear drops',
      onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
      primary: upgrades > 0,
      style: upgrades > 0 ? KenneyButtonStyle.brown : KenneyButtonStyle.grey,
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
      if (upgrades > 0) {
        return _autoEquipButton();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KenneyButton(
            label: worn != null ? 'UNEQUIP' : 'EQUIP',
            onPressed: worn != null
                ? () => onUnequip(worn.slot)
                : (inStash ? onEquip : null),
            style: worn != null
                ? KenneyButtonStyle.grey
                : KenneyButtonStyle.brown,
            primary: inStash,
          ),
        ],
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

    // Phone product only: doll + actions; bag lives on its own PARTY tab.
    // (A side-by-side / stacked bag pane used to appear in wide browsers and
    // looked nothing like the APK the player installs.)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SingleChildScrollView(child: sheet())),
        const SizedBox(height: 6),
        actions(),
        const SizedBox(height: 6),
        KenneyButton(
          label: 'OPEN BAG',
          onPressed: () => widget.onTabChanged(PartyTab.bag),
          style: KenneyButtonStyle.grey,
        ),
      ],
    );
  }


  Widget _equipHeroChipsFor(EquipmentItem selected) {
    var bestIndex = -1;
    var bestDelta = 0;
    for (var i = 0; i < state.heroes.length; i++) {
      final cmp = GameLogic.compareForHero(
        state.heroes[i],
        selected,
        pairingStash: state.gearStash,
      );
      if (cmp.isUpgrade && cmp.powerDelta > bestDelta) {
        bestDelta = cmp.powerDelta;
        bestIndex = i;
      }
    }
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
              MenuChrome.chip(
                label: 'CLEAR',
                onTap: onClearBagSlotFilter,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ] else
          Text(
            () {
              final line = MenuAlerts.bagStatusLine(state);
              if (line.isNotEmpty) return line;
              if (nearFull && filled >= cap) {
                return 'CLEAN: sell junk for gold, then scrap leftovers for essence';
              }
              return 'CLEAN BAG: sell for gold first, then scrap for essence';
            }(),
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        const SizedBox(height: 6),
        if (onOpenMarket != null)
          Center(
            child: MenuChrome.chip(
              label: 'Need gear? → MARKET',
              onTap: onOpenMarket,
            ),
          ),
        if (onOpenMarket != null) const SizedBox(height: 6),
        Expanded(
          child: filteredSlots.isEmpty && filter != null
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
                    final phone =
                        GameTheme.isPhoneWidth(context) ||
                        gridConstraints.maxWidth <= 430;
                    return GridView.builder(
                      itemCount: filteredSlots.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: phone ? 3 : 4,
                        mainAxisSpacing: phone ? 8 : 6,
                        crossAxisSpacing: phone ? 8 : 6,
                        mainAxisExtent: phone ? 72 : 60,
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
        KenneyButton(
          label: 'CLEAN BAG',
          tip: 'Merge junk pairs → sell gold → scrap essence (BiS kept)',
          onPressed: state.gearStash.isEmpty ? null : onCleanBag,
          style: KenneyButtonStyle.grey,
        ),
        const SizedBox(height: 4),
        KenneyButton(
          label: 'AUTO-SELL FILTERS',
          tip: 'When bag is near full: sell gold vs scrap essence rules',
          onPressed: onOpenFilters,
          style: KenneyButtonStyle.grey,
        ),
        const SizedBox(height: 4),
        _autoEquipButton(),
        const SizedBox(height: 4),
        KenneyButton(
          label: selectedId == null ? 'AUTO MERGE' : 'ADD TO MERGE',
          tip: selectedId == null
              ? 'Merge junk pairs — skips BiS and bag upgrades'
              : null,
          onPressed: selectedId != null
              ? (GameLogic.findStashGear(state, selectedId!) == null
                    ? null
                    : () => onPutCombine(selectedId!))
              : (state.gearStash.length < 2 ? null : onAutoMerge),
          style: KenneyButtonStyle.grey,
        ),
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
            'Tap item to select · long-press for tip · ADD TO MERGE for TOOLS.',
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
          MenuChrome.sectionLabelScoped('COMBINATOR', scope: MenuScope.run),
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
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.mossLit,
                      ),
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
          KenneyButton(
            label: goldOk
                ? 'MERGE  $cost g'
                : (canCombine ? 'MERGE  $cost g' : 'MERGE'),
            onPressed: goldOk ? onCombine : null,
            style: KenneyButtonStyle.red,
            primary: true,
          ),
          const SizedBox(height: 6),
          KenneyButton(
            label: 'AUTO MERGE',
            onPressed: state.gearStash.length < 2 ? null : onAutoMerge,
            style: KenneyButtonStyle.grey,
          ),
          const SizedBox(height: 4),
          Text(
            'Merges junk pairs of the same slot (skips upgrades and BiS (kept safe)). Uses gold.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          if (primary == null || secondary == null) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: 'OPEN BAG',
              onPressed: () => widget.onTabChanged(PartyTab.bag),
              style: KenneyButtonStyle.grey,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Flask: party HUD · Pets: META → Beast · God Hand: POWER → Forge → KEEP',
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
    _visible = MenuRouter.visiblePartyTabs(state);
    final safeTab = _visible.contains(widget.tab) ? widget.tab : _visible.first;
    if (safeTab != widget.tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTabChanged(safeTab);
      });
    }
    final pages = <({String label, Widget body})>[
      for (final tab in _visible)
        switch (tab) {
          PartyTab.gear => (label: 'GEAR', body: _equipTab()),
          PartyTab.bag => (label: 'BAG', body: _bagTab(slots, primary)),
          PartyTab.merge => (
            label: 'MERGE',
            body: _toolsTab(
              primary: primary,
              secondary: secondary,
              canCombine: canCombine,
              cost: cost,
              preview: preview,
            ),
          ),
          PartyTab.roster => (
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
                  widget.onTabChanged(_visible[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        Builder(
          builder: (context) {
            final reason = _partyTabReason(safeTab);
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
            color: Color(0x88000000),
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

class _EquipHeroChip extends StatelessWidget {
  const _EquipHeroChip({
    required this.hero,
    required this.candidate,
    required this.onTap,
    this.pairingStash,
    this.isBest = false,
    this.plainEnglish = false,
  });

  final PartyHero hero;
  final EquipmentItem candidate;
  final VoidCallback onTap;
  final List<EquipmentItem>? pairingStash;
  final bool isBest;
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
                : (cmp.isUpgrade
                      ? GameTheme.equipChipUpgrade
                      : GameTheme.equipChipNeutral),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isBest
                  ? GameTheme.torchHot
                  : (cmp.isUpgrade ? GameTheme.clear : GameTheme.borderLit),
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
                  style: GameTheme.body(
                    size: 10,
                    color: GameTheme.accentWarn,
                  ),
                )
              else ...[
                Text(
                  'Score ${GameLogic.formatDelta(cmp.powerDelta)}',
                  style: GameTheme.body(size: 11, color: deltaColor),
                ),
                if (cmp.isUpgrade)
                  Text(
                    'UPGRADE',
                    style: GameTheme.body(size: 10, color: GameTheme.clear),
                  )
                else
                  Text(
                    'power ${GameLogic.formatDelta(cmp.atkDelta)} '
                    'D${GameLogic.formatDelta(cmp.defDelta)} '
                    'STA${GameLogic.formatDelta(cmp.vitDelta)}',
                    style: GameTheme.body(
                      size: 10,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
      EquipmentSlot.weapon => 'MH',
      EquipmentSlot.offHand => 'OH',
      EquipmentSlot.ranged => 'Rng',
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
    final a11yLabel = item == null
        ? 'Empty bag slot'
        : '${item!.name}, item level ${item!.effectiveItemLevel}';
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
                ? Center(
                    child: Icon(
                      Icons.add,
                      size: 14,
                      color: GameTheme.border.withValues(alpha: 0.55),
                    ),
                  )
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
                          child: KenneySprite(
                            asset: KenneyAssets.equipmentIconFor(item!),
                            size: 26,
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
                      Positioned(
                        bottom: 2,
                        left: 6,
                        child: ExcludeSemantics(
                          child: Text(
                            'i${item!.effectiveItemLevel}',
                            style: GameTheme.body(
                              size: 12,
                              color: GameTheme.parchment,
                            ),
                          ),
                        ),
                      ),
                      if (isBest)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xEE1E4030),
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
                      if (item!.slot == EquipmentSlot.weapon &&
                          !isSoulboundItem(item!))
                        Positioned(
                          bottom: 2,
                          right: 3,
                          child: Text(
                            patternGlyph(item!.pattern),
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
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
        child: slot,
      ),
    );
  }
}

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
              KenneySprite(
                asset: KenneyAssets.equipmentIconFor(item!),
                size: 24,
              ),
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
              Text(
                '✕',
                style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
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
