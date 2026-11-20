import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gear/gear_scorer.dart';
import '../../core/gear/gear_upgrade_copy.dart';
import '../../core/gear_service.dart';
import '../../core/run_stash_shop.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../../core/nav_copy.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../character_equip_panel.dart';
import '../chunky_face.dart';
import '../equipment_icon.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/roster_panel.dart';
import '../item_tooltip.dart';
import '../web_click_bridge.dart';
import 'bag_cleanup_filters.dart';
import 'home/nav_clearance.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

part 'bag_equip_hero_chip.dart';
part 'bag_slot.dart';
part 'bag_actions.dart';
part 'bag_combine_slot.dart';

class InventoryDock extends StatefulWidget {
  /// Below this body height (+60 per 1.0 of text scale) the picked-item
  /// details ride in the bag scroll instead of under the action row.
  static const double bagPinnedMinHeight = 480;

  /// One empty-bag line; the MARKET nudge is a chip there, a link otherwise.
  static const String emptyBagLine = 'Bag empty — farm for loot.';

  static const Key bagGoldBuyKey = ValueKey('bag-gold-buy');

  /// "Need 5,000g more for BAG +5" under a gold bag buy the wallet cannot
  /// cover.
  /// BAG help line (audit F053).
  static const String bagHint = 'Tap an item to pick it. Hold for details.';

  /// Empty MERGE slot prompts (audit F056).
  static const String mergePickFirst = 'Pick a bag item';
  static const String mergePickSecond = 'Pick one, same slot';
  static const Key mergeOpenBagKey = ValueKey('merge_open_bag');
  static const Key mergeButtonKey = ValueKey('merge_button');

  static String bagNeedLine(GameState state) {
    final short = RunStashShop.goldBuyCost(state) - state.gold;
    return 'Need ${formatGold(short < 0 ? 0 : short)} more for '
        'BAG +${RunStashShop.slotsPerGoldBuy}';
  }

  static const String marketNudgeLabel = 'Need gear? › MARKET';

  /// BAG grid: 4 square tiles a row, 6 dp apart.
  static const int bagColumns = 4;
  static const double bagGridGap = 6;
  static const Key bagScrollKey = ValueKey('bag-scroll');
  static const Key equipScrollKey = ValueKey('equip-tab-scroll');
  static const Key bagFiltersKey = ValueKey('bag-filters');
  static const Key bagAutoEquipKey = ValueKey('bag-auto-equip');

  /// At or above this text scale the action row uses short labels
  /// ("EQUIP 14" instead of "EQUIP BEST 14").
  static const double bagCompactLabelScale = 1.2;

  /// The MARKET link sits under the count only while the bag holds at most
  /// this many pieces; otherwise it waits at the bottom of the scroll.
  static const int marketLinkMaxItems = 4;

  /// Short bodies move the picked-item details into the scroll so the grid
  /// keeps its rows (true below 480 dp, +60 per 1.0 of text scale).
  static bool bagScrolls(double bodyHeight, double textScale) =>
      bodyHeight < bagPinnedMinHeight + 60 * (textScale - 1);

  /// MERGE footer. BiS waits until first-hour plain chrome lifts.
  static String mergeFooterHint({
    required bool plainEnglish,
    int keptCount = 0,
    List<String> keptNames = const [],
  }) {
    if (plainEnglish) {
      return 'Same-slot junk pairs › one stronger piece. Uses gold.';
    }
    final base =
        'Same-slot junk pairs › one stronger piece (skips upgrades). Uses gold. '
        'AUTO MERGE picks by raw power.';
    if (keptCount <= 0) return base;
    final sample = keptNames.isEmpty ? '' : ' · e.g. ${keptNames.join(', ')}';
    return '$base Skips $keptCount keep${keptCount == 1 ? '' : 's'}$sample.';
  }

  /// A waiting kit opens ROSTER. An explicit BAG open stays on the bag
  /// (wipe OPEN BAG). A kit that arrives while the bag is open still meets.
  static bool meetShouldSteal(
    GearPanel panel, {
    required bool revealJustArrived,
  }) {
    if (panel == GearPanel.roster) return false;
    if (panel == GearPanel.bag && !revealJustArrived) return false;
    return true;
  }

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
    this.showTabRail = true,
  });

  final GameState state;
  final GameDirector director;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
  final GearPanel panel;
  final ValueChanged<GearPanel> onPanelChanged;
  final bool flatChrome;
  final bool showTabRail;
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
  bool _upgradesOnlyFilter = false;
  bool _longPressTipShown = false;

  GameState get state => widget.state;
  GameDirector get director => widget.director;
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
    final meet = MenuAlerts.meetRosterHint(state, panel: tab);
    if (meet.isNotEmpty) return meet;

    switch (tab) {
      case GearPanel.gear:
        return MenuAlerts.gearEquipHint(state, equipHeroIndex, panel: tab);
      case GearPanel.bag:
        final upgrades = MenuAlerts.bagUpgradeCount(state);
        if (upgrades > 0) {
          return upgrades == 1
              ? '1 better item in bag — tap EQUIP BEST 1'
              : '$upgrades better items in bag — tap EQUIP BEST $upgrades';
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
    _maybeOpenRosterForMeet();
  }

  void _maybeOpenRosterForMeet({bool revealJustArrived = false}) {
    if (!MenuTabs.showRoster(state)) return;
    if (state.metaDepth.pendingHeroReveals.isEmpty) return;
    if (!InventoryDock.meetShouldSteal(
      widget.panel,
      revealJustArrived: revealJustArrived,
    )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPanelChanged(GearPanel.roster);
    });
  }

  @override
  void didUpdateWidget(covariant InventoryDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panel != GearPanel.bag && _showFilters) {
      _showFilters = false;
    }
    if (widget.panel != GearPanel.bag && _upgradesOnlyFilter) {
      _upgradesOnlyFilter = false;
    }
    final grew =
        oldWidget.state.metaDepth.pendingHeroReveals.length <
        state.metaDepth.pendingHeroReveals.length;
    if (grew) {
      _maybeOpenRosterForMeet(revealJustArrived: true);
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
      label: upgrades > 0 ? 'EQUIP BEST $upgrades' : 'EQUIP',
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
      if (selectedId != null && (worn != null || inStash)) {
        return Row(
          children: [
            Expanded(
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
              Expanded(child: _autoEquipButton(dense: true, expanded: true)),
            ],
          ],
        );
      }
      if (upgrades > 0) {
        return _autoEquipButton(dense: true, expanded: true);
      }
      return const SizedBox.shrink();
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

    // Phone: scroll the doll; EQUIP stays pinned under the scroll (audit gear).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: InventoryDock.equipScrollKey,
            padding: const EdgeInsets.fromLTRB(
              ShellLayout.sheetHorizontal,
              0,
              ShellLayout.sheetHorizontal,
              4,
            ),
            child: sheet(),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: GameTheme.panel.withValues(alpha: 0.98),
            border: Border(
              top: BorderSide(
                color: GameTheme.borderLit.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ShellLayout.sheetHorizontal,
              4,
              ShellLayout.sheetHorizontal,
              6,
            ),
            child: actions(),
          ),
        ),
      ],
    );
  }

  Widget _equipHeroChipsFor(EquipmentItem selected) {
    final plain = GameLogic.plainPlayerChrome(state);
    final plannedHero = [
      for (var i = 0; i < state.heroes.length; i++)
        if (GameLogic.autoEquipWouldWear(state, selected.id, heroIndex: i)) i,
    ];
    final bestIndex = plannedHero.isEmpty ? -1 : plannedHero.first;
    final wearable = <int>[];
    final blocked = <String, List<String>>{};
    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      final reject = ClassProficiency.rejectReason(
        role: hero.gearAffinity,
        level: hero.level,
        item: selected,
        specId: hero.specId,
      );
      if (reject == null) {
        wearable.add(i);
        continue;
      }
      final name = hero.displayRoleLabel(plainEnglish: plain);
      final why = reject.startsWith('$name ')
          ? reject.substring(name.length + 1)
          : reject;
      blocked.putIfAbsent(why, () => <String>[]).add(name);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wearable.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final i in wearable)
                _EquipHeroChip(
                  hero: state.heroes[i],
                  candidate: selected,
                  pairingStash: state.gearStash,
                  isBest: i == bestIndex,
                  plannedUpgrade: i == bestIndex,
                  plainEnglish: plain,
                  onTap: () => onEquipToHero(i),
                ),
            ],
          ),
        for (final entry in blocked.entries)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${entry.value.join(', ')} ${entry.key}.',
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
          ),
      ],
    );
  }

  Widget _bagTab(List<EquipmentItem?> slots, EquipmentItem? primary) {
    final cap = GameLogic.maxGearStashFor(state);
    final filled = state.gearStash.length;
    final nearFull = GearService.isBagJammed(state);
    final showMarketChip = onOpenMarket != null && showMarketGearHint(state);
    final mergeOpen = MenuTabs.showMerge(state);
    final bagHint = MenuAlerts.bagPanelHint(state);
    final filter = bagSlotFilter;
    final filterLabel = filter == null
        ? null
        : (CharacterEquipPanel.slotLabels[filter] ?? filter.name);
    var filteredSlots = filter == null
        ? slots
        : [
            for (final item in state.gearStash)
              if (_itemMatchesBagFilter(item, filter)) item,
          ];
    if (_upgradesOnlyFilter) {
      filteredSlots = [
        for (final item in filteredSlots)
          if (item != null && isUpgradeForAny(state, item)) item,
      ];
    }
    final selected = selectedId == null
        ? null
        : GameLogic.findGear(state, selectedId!);
    // The grid is the page: it fills the middle and scrolls. One compact
    // action row stays pinned under it. Bag space (EXPAND BAG), help and
    // the MARKET link sit at the bottom of the scroll.
    return LayoutBuilder(
      builder: (context, box) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final short = InventoryDock.bagScrolls(box.maxHeight, textScale);
        final hero = state.heroes.isEmpty
            ? null
            : state.heroes[equipHeroIndex.clamp(0, state.heroes.length - 1)];

        Widget gridSliver() {
          if (_showFilters) {
            return SliverToBoxAdapter(
              child: BagCleanupFilters(
                director: widget.director,
                compact: true,
              ),
            );
          }
          if (filled == 0 || filteredSlots.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      filled > 0 && (filter != null || _upgradesOnlyFilter)
                          ? 'No pieces in this filter.'
                          : InventoryDock.emptyBagLine,
                      textAlign: TextAlign.center,
                      style: GameTheme.section(color: GameTheme.parchmentDim),
                    ),
                    if (filled == 0 && showMarketChip) ...[
                      const SizedBox(height: 6),
                      MenuChrome.chip(
                        label: InventoryDock.marketNudgeLabel,
                        onTap: onOpenMarket,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: InventoryDock.bagColumns,
              mainAxisSpacing: InventoryDock.bagGridGap,
              crossAxisSpacing: InventoryDock.bagGridGap,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              childCount: filteredSlots.length,
              (context, index) {
                final item = filteredSlots[index];
                final picked = item != null && item.id == selectedId;
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
                  hero: hero,
                  highlight: picked || inCombine,
                  dimmed: combineFiltered,
                  onTap: item == null || combineFiltered
                      ? null
                      : () => onSelect(item.id),
                  onLongPress: item == null || combineFiltered
                      ? null
                      : () {
                          if (!_longPressTipShown) {
                            _longPressTipShown = true;
                            widget.director.showToast(
                              'Long-press shows grade and stat tip',
                              life: 2.2,
                            );
                          }
                        },
                );
              },
            ),
          );
        }

        final details = selected == null
            ? null
            : _bagSelectionDetails(selected, mergeOpen: mergeOpen);

        final scroll = CustomScrollView(
          key: InventoryDock.bagScrollKey,
          slivers: [
            if (short && details != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: details,
                ),
              ),
            gridSliver(),
            SliverToBoxAdapter(
              child: _bagScrollFooter(
                filled: filled,
                showMarketLink: showMarketChip && filled > 0,
                panelHint: filter == null && !nearFull ? bagHint : '',
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bagCapacityRow(filled: filled, cap: cap, nearFull: nearFull),
            if (filter != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
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
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                    MenuChrome.chip(
                      label: 'ALL SLOTS',
                      onTap: onClearBagSlotFilter,
                    ),
                  ],
                ),
              ),
            // A full bag is a warning: keep its line in view.
            if (filter == null && nearFull && bagHint.isNotEmpty) ...[
              ShellLayout.gap(4),
              ShellLayout.hint(bagHint, maxLines: 2),
            ],
            // Nearly empty bag: the MARKET link sits right under the count.
            if (showMarketChip &&
                filled > 0 &&
                filled <= InventoryDock.marketLinkMaxItems)
              Align(alignment: Alignment.centerLeft, child: _marketLink()),
            const SizedBox(height: 6),
            Expanded(child: scroll),
            const SizedBox(height: 4),
            _bagActionRow(textScale: textScale),
            if (!short && details != null) ...[
              const SizedBox(height: 4),
              details,
            ],
          ],
        );
      },
    );
  }

  /// "CAPACITY 14 / 50 ▬▬▬ [UPGRADES]" on one line.
  Widget _bagCapacityRow({
    required int filled,
    required int cap,
    required bool nearFull,
  }) {
    final tone = nearFull ? GameTheme.accentWarn : GameTheme.parchmentDim;
    return Row(
      children: [
        Text(
          nearFull && filled >= cap
              ? 'BAG FULL'
              : nearFull
              ? 'NEARLY FULL'
              : 'CAPACITY',
          style: GameTheme.hint(color: tone),
        ),
        const SizedBox(width: 6),
        Text(
          '$filled / $cap',
          style: GameTheme.readable(
            color: nearFull ? GameTheme.accentWarn : GameTheme.parchment,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
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
        ),
        // Nothing to filter in an empty bag.
        if (filled > 0) ...[
          const SizedBox(width: 8),
          MenuChrome.chip(
            label: 'UPGRADES',
            selected: _upgradesOnlyFilter,
            onTap: () =>
                setState(() => _upgradesOnlyFilter = !_upgradesOnlyFilter),
          ),
        ],
      ],
    );
  }

  /// AUTO EQUIP switch · EQUIP · SELL JUNK · FILTERS, one row.
  Widget _bagActionRow({required double textScale}) {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    final roomy = textScale < InventoryDock.bagCompactLabelScale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AutoEquipSwitch(
          on: state.autoEquipUpgrades,
          onChanged: (v) => widget.director.setAutoEquipUpgrades(v),
        ),
        // Empty bag: no dead EQUIP / SELL JUNK faces, only the AUTO switch
        // and FILTERS that still do something (polish7 P052).
        if (state.gearStash.isEmpty) const Spacer(),
        if (state.gearStash.isNotEmpty) ...[
        const SizedBox(width: 4),
        Expanded(
          flex: 5,
          child: GameButton(
            label: upgrades > 0
                ? (roomy ? 'EQUIP BEST $upgrades' : 'EQUIP $upgrades')
                : 'EQUIP',
            tip: upgrades > 0
                ? 'One tap: equip all $upgrades upgrades now'
                : MenuAlerts.bagEquipIdleTip(state),
            onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
            style: upgrades > 0 ? GameButtonStyle.brown : GameButtonStyle.grey,
            dense: true,
            expanded: true,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 4,
          child: GameButton(
            label: 'SELL JUNK',
            tip: MenuAlerts.bagCleanButtonTip(state),
            onPressed: state.gearStash.isEmpty ? null : onCleanBag,
            style: GameButtonStyle.grey,
            dense: true,
            expanded: true,
          ),
        ),
        ],
        const SizedBox(width: 4),
        _BagFiltersButton(
          showing: _showFilters,
          tip: MenuAlerts.bagFiltersButtonTip(state, showing: _showFilters),
          onTap: () => setState(() => _showFilters = !_showFilters),
        ),
      ],
    );
  }

  /// Small "Need gear? › MARKET" text link (44 dp tall tap area).
  Widget _marketLink() {
    return WebClickScope(
      label: InventoryDock.marketNudgeLabel,
      onPressed: onOpenMarket,
      child: Semantics(
        button: true,
        label: InventoryDock.marketNudgeLabel,
        excludeSemantics: true,
        child: InkWell(
          onTap: onOpenMarket,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(
                  InventoryDock.marketNudgeLabel,
                  style: GameTheme.hint(color: GameTheme.torchHot).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: GameTheme.torchHot,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom of the bag scroll: help, MARKET link, then EXPAND BAG.
  Widget _bagScrollFooter({
    required int filled,
    required bool showMarketLink,
    required String panelHint,
  }) {
    final canExpand =
        !RunStashShop.goldBuysAtCap(state.metaDepth) ||
        !RunStashShop.cinderBuysAtCap(state.metaDepth);
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: NavClearance.of(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filled > 0 && selectedId == null)
            Text(
              InventoryDock.bagHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
          if (panelHint.isNotEmpty) ...[
            ShellLayout.gap(4),
            ShellLayout.hint(panelHint, maxLines: 2),
          ],
          if (showMarketLink && filled > InventoryDock.marketLinkMaxItems)
            Align(alignment: Alignment.centerLeft, child: _marketLink()),
          // Bag space is a purchase, not the bag: it sits at the bottom of
          // the scroll with its price state spelled out.
          if (canExpand) ...[
            const SizedBox(height: 8),
            MenuChrome.sectionLabel('EXPAND BAG'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (!RunStashShop.goldBuysAtCap(state.metaDepth))
                  GameButton(
                    key: InventoryDock.bagGoldBuyKey,
                    label: RunStashShop.goldBuyLabel(state),
                    dense: true,
                    style: RunStashShop.canBuyGold(state)
                        ? GameButtonStyle.gold
                        : GameButtonStyle.grey,
                    onPressed: director.buyGoldBagExpansion,
                  ),
                if (!RunStashShop.cinderBuysAtCap(state.metaDepth))
                  GameButton(
                    label: RunStashShop.cinderBuyLabel(state),
                    dense: true,
                    style: RunStashShop.canBuyCinders(state)
                        ? GameButtonStyle.gold
                        : GameButtonStyle.grey,
                    onPressed: director.buyCinderBagExpansion,
                  ),
              ],
            ),
            if (!RunStashShop.goldBuysAtCap(state.metaDepth) &&
                !RunStashShop.canBuyGold(state)) ...[
              const SizedBox(height: 2),
              Text(
                InventoryDock.bagNeedLine(state),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Picked item: name, stats, ADD TO MERGE and the hero chips.
  Widget _bagSelectionDetails(
    EquipmentItem selected, {
    required bool mergeOpen,
  }) {
    final inStash = GameLogic.findStashGear(state, selected.id) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.readable(
                      color: itemRarityColor(selected.rarity),
                    ),
                  ),
                  Text(
                    selected.statsLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.torchHot),
                  ),
                  if (isUpgradeForAny(state, selected))
                    Text(
                      GearUpgradeCopy.bagTileDeltaLine(state, selected).isEmpty
                          ? 'Upgrade in bag'
                          : '${GearUpgradeCopy.bagTileDeltaLine(state, selected)} · wear it',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.hint(color: GameTheme.clear),
                    ),
                ],
              ),
            ),
            if (mergeOpen) ...[
              const SizedBox(width: 6),
              GameButton(
                label: 'ADD TO MERGE',
                onPressed: inStash ? () => onPutCombine(selected.id) : null,
                style: GameButtonStyle.grey,
                dense: true,
                expanded: false,
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text('Equip on:', style: GameTheme.hint(color: GameTheme.parchmentDim)),
        const SizedBox(height: 3),
        _equipHeroChipsFor(selected),
      ],
    );
  }

  int _mergeScore(EquipmentItem item) {
    if (state.heroes.isEmpty) return item.powerScore;
    var best = item.powerScore;
    for (final wearer in state.heroes) {
      if (!ClassProficiency.canEquip(
        role: wearer.gearAffinity,
        level: wearer.level,
        item: item,
        specId: wearer.specId,
      )) {
        continue;
      }
      final score = GearScorer.roleEquipScore(
        wearer.gearAffinity,
        item,
        specId: wearer.specId,
        level: wearer.level,
      );
      if (score > best) best = score;
    }
    return best;
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
      if (primary.isApex || secondary.isApex) {
        return NavCopy.playerText(
          'Apex gear cannot MERGE — upgrade it under MENU › CRAFT.',
          state.homeLayout,
        );
      }
      if (!canCombine) {
        return 'Slots must match — clear one and pick the same gear type.';
      }
      if (!goldOk) {
        return 'Need ${formatGold(cost)} to merge (have ${formatGold(state.gold)}).';
      }
      return 'Ready — MERGE spends both and makes one stronger piece.';
    }();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The sheet title already says MERGE (audit F054). With nothing
          // loaded, the one way forward leads (F014).
          if (primary == null && secondary == null) ...[
            GameButton(
              key: InventoryDock.mergeOpenBagKey,
              label: 'OPEN BAG',
              onPressed: () => widget.onPanelChanged(GearPanel.bag),
              // Still first (F014), but a normal-size face, not a giant
              // primary slab (polish7 P053).
              style: GameButtonStyle.brown,
              dense: true,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Two bag items, same slot. MERGE spends them for one stronger piece. Worn gear stays.'
            '${state.metaDepth.combinatorLuck > 0 ? ' Charm luck ${state.metaDepth.combinatorLuck}/5 · −${state.metaDepth.combinatorLuck * 3}g on MERGE.' : ''}',
            style: GameTheme.section(color: GameTheme.parchmentDim),
          ),
          if (slotLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Slot filter: $slotLabel',
              style: GameTheme.hint(color: GameTheme.torchHot),
            ),
          ],
          const SizedBox(height: 8),
          _CombineSlot(
            label: 'FIRST',
            emptyHint: InventoryDock.mergePickFirst,
            item: primary,
            onClear: combineA == null ? null : onClearCombineA,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '+',
              textAlign: TextAlign.center,
              style: GameTheme.readable(color: GameTheme.parchmentDim),
            ),
          ),
          _CombineSlot(
            label: 'SECOND',
            emptyHint: InventoryDock.mergePickSecond,
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
                          final score = _mergeScore(preview);
                          final delta = primary == null
                              ? 0
                              : score - _mergeScore(primary);
                          final jump = delta > 0 ? '  +$delta' : '';
                          return 'RESULT  ${GameLogic.rarityNames[preview.rarity]}'
                              '  i${preview.effectiveItemLevel}'
                              '  SCORE $score$jump';
                        }(),
                  textAlign: TextAlign.center,
                  style: GameTheme.hint(
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
                    style: GameTheme.hint(color: GameTheme.parchment),
                  ),
                  if (primary != null && secondary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Cost ${formatGold(cost)} · '
                      '${GameLogic.rarityNames[primary.rarity]} i${primary.effectiveItemLevel} + '
                      '${GameLogic.rarityNames[secondary.rarity]} i${secondary.effectiveItemLevel}'
                      ' › ${GameLogic.rarityNames[preview.rarity]} i${preview.effectiveItemLevel}',
                      textAlign: TextAlign.center,
                      style: GameTheme.hint(color: GameTheme.torchHot),
                    ),
                  ],
                  if (preview.effectLabel.isNotEmpty)
                    Text(
                      preview.effectLabel,
                      textAlign: TextAlign.center,
                      style: GameTheme.hint(color: GameTheme.mossLit),
                    ),
                ],
              ],
            ),
          ),
          // Nothing loaded: the intro above already says this; one
          // instruction, not two (polish7 P053).
          if (primary != null || secondary != null) ...[
            const SizedBox(height: 6),
            Text(
              status,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.visible,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
          ],
          const SizedBox(height: 8),
          GameButton(
            key: InventoryDock.mergeButtonKey,
            label: canCombine ? 'MERGE  ${formatGold(cost)}' : 'MERGE',
            onPressed: goldOk ? onCombine : null,
            style: GameButtonStyle.red,
            primary: canCombine,
            // Small until two items are loaded (F014).
            dense: !canCombine,
          ),
          const SizedBox(height: 6),
          GameButton(
            label: 'AUTO MERGE',
            onPressed: state.gearStash.length < 2 ? null : onAutoMerge,
            style: GameButtonStyle.grey,
            dense: !canCombine,
          ),
          ShellLayout.gap(4),
          ShellLayout.hint(
            InventoryDock.mergeFooterHint(
              plainEnglish: GameLogic.plainPlayerChrome(state),
              keptCount: GearService.autoMergeKeptCount(state),
              keptNames: GearService.autoMergeKeptNames(state),
            ),
            maxLines: 4,
          ),
          if ((primary == null) != (secondary == null)) ...[
            const SizedBox(height: 6),
            GameButton(
              label: 'OPEN BAG',
              onPressed: () => widget.onPanelChanged(GearPanel.bag),
              style: GameButtonStyle.grey,
              dense: true,
            ),
          ],
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
    final cost = canCombine
        ? GameLogic.combineCost(
            primary,
            secondary,
            combinatorLuck: state.metaDepth.combinatorLuck,
          )
        : 0;
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
              padding: ShellLayout.scrollBodyPadding,
              child: TeamCompositionOverlay(director: widget.director),
            ),
          ),
        },
    ];
    _tabs.syncToId(_visible, safeTab);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTabRail)
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
              padding: ShellLayout.listPadding.copyWith(top: 0, bottom: 4),
              child: ShellLayout.hint(reason, maxLines: 2),
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
