import 'package:flutter/material.dart';

import '../../core/chase_contract.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../../core/nav_intent.dart';
import '../menu_chrome.dart';
import 'essence_dock.dart';
import 'gold_dock.dart';
import 'inventory_dock.dart';
import 'jobs_overlay.dart';
import 'overlay_scaffold.dart';
import 'power_meta_pillars.dart';
import 'shop_dock.dart';
import '../meta/keystone_sheet.dart';
import 'whats_new_overlay.dart';
import 'home/essence_tiles_screen.dart';
import 'home/home_menu_grid.dart';
import 'home/map_screen.dart';

/// The one menu sheet, shared by hub and dungeon.
/// All routes fill the stack above the shared [AppBottomBar] (full height).
class MenuSurface extends StatefulWidget {
  /// Subtitle of the home ESSENCE tile hub.
  static const essenceHubHint = 'Lasting upgrades for the party';

  /// Home GEAR sub-tabs, under the sheet title (audit F046).
  static const Key gearTabsKey = ValueKey('home_gear_tabs');

  static String gearTabLabel(GearPanel panel) => switch (panel) {
    GearPanel.gear => 'GEAR',
    GearPanel.bag => 'BAG',
    GearPanel.merge => 'MERGE',
    GearPanel.roster => 'ROSTER',
  };

  const MenuSurface({
    super.key,
    required this.director,
    required this.router,
    this.home = false,
  });

  final GameDirector director;
  final MenuRouter router;
  final bool home;

  @override
  State<MenuSurface> createState() => _MenuSurfaceState();
}

/// Home bottom nav already shows CLOSE for these tabs — skip the sheet button.
bool _homeNavOwnsClose(MenuRoute route) => switch (route) {
  MenuRoute.gear ||
  MenuRoute.essence ||
  MenuRoute.shop ||
  MenuRoute.map => true,
  _ => false,
};

class _MenuSurfaceState extends State<MenuSurface> {
  MenuRoute _lastRoute = MenuRoute.none;

  GameState get state => widget.director.state;
  MenuRouter get router => widget.router;

  @override
  void initState() {
    super.initState();
    router.addListener(_onRouteChanged);
    _applyRoute();
  }

  @override
  void dispose() {
    router.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (router.route != _lastRoute) _applyRoute();
    if (mounted) setState(() {});
  }

  void _applyRoute() {
    final route = router.route;
    final prev = _lastRoute;
    _lastRoute = route;
    if (route != MenuRoute.none && route != MenuRoute.gear) {
      widget.director.clearToast();
    }
    if (prev == MenuRoute.gear && route != MenuRoute.gear) {
      widget.director.ackPendingHeroReveals();
    }
  }

  void _equipSelectedTo(int heroIndex) {
    final id = router.session.selectedItemId;
    if (id == null) return;
    if (widget.director.equipSelectedFromStash(id, heroIndex: heroIndex) ==
        EquipFromStashResult.equipped) {
      router.session
        ..equipHeroIndex = heroIndex
        ..clearSelection()
        ..clearBagSlotFilter();
    }
  }

  void _putInCombinator(String id) {
    if (GameLogic.findStashGear(state, id) == null) {
      widget.director.showToast('Unequip to bag before merging', life: 2.2);
      return;
    }
    final ready = router.session.putInCombinator(id);
    if (ready) {
      router.open(MenuRoute.gear, gear: GearPanel.merge);
      widget.director.showToast('Merge ready — check MERGE', life: 2.2);
    } else if (router.session.combineA != null &&
        router.session.combineB == null) {
      widget.director.showToast(
        'Added to merge · pick another same-slot item',
        life: 2.4,
      );
    }
  }

  Widget _inventoryDock() {
    final d = widget.director;
    final session = router.session;
    return InventoryDock(
      state: state,
      director: d,
      selectedId: session.selectedItemId,
      combineA: session.combineA,
      combineB: session.combineB,
      panel: router.gearPanel,
      onPanelChanged: (panel) => router.gearPanel = panel,
      flatChrome: true,
      showTabRail: !widget.home,
      onSelect: session.selectItem,
      onPutCombine: _putInCombinator,
      onEquip: () {
        if (session.selectedItemId == null) return;
        _equipSelectedTo(session.equipHeroIndex);
      },
      onUnequip: (slot) {
        d.unequipSlot(slot, heroIndex: session.equipHeroIndex);
        session.clearSelection();
      },
      bagSlotFilter: session.bagSlotFilter,
      onBrowseBagSlot: router.browseBagSlot,
      onClearBagSlotFilter: session.clearBagSlotFilter,
      equipHeroIndex: session.equipHeroIndex,
      onEquipHeroChanged: (i) => session.equipHeroIndex = i,
      onEquipToHero: _equipSelectedTo,
      onAutoEquip: () {
        d.autoEquipBetterGear();
        session.clearSelection();
      },
      onClearCombineA: session.clearCombineA,
      onClearCombineB: session.clearCombineB,
      onCombine: () {
        if (session.combineA == null || session.combineB == null) return;
        final onBag = router.gearPanel == GearPanel.bag;
        d.combineGear(
          primaryId: session.combineA!,
          secondaryId: session.combineB!,
        );
        session.clearCombine();
        if (onBag && MenuTabs.showMerge(d.state)) {
          router.open(MenuRoute.gear, gear: GearPanel.merge);
        }
      },
      onCleanBag: d.cleanBagJunk,
      onAutoMerge: () {
        d.autoMergeJunk();
        session.dropMissingIds(d.state.gearStash.map((g) => g.id).toSet());
      },
      onOpenMarket: () => router.apply(NavIntent.market),
    );
  }

  Widget _gearTabs() {
    final panels = MenuRouter.visibleGearPanels(state);
    if (panels.isEmpty) return const SizedBox.shrink();
    final selected = panels
        .indexOf(router.gearPanel)
        .clamp(0, panels.length - 1);
    return Padding(
      key: MenuSurface.gearTabsKey,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: MenuChrome.segmented(
        dense: true,
        labels: [for (final p in panels) MenuSurface.gearTabLabel(p)],
        selectedIndex: selected,
        onSelect: (i) => router.gearPanel = panels[i],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    if (router.route == MenuRoute.none) return const SizedBox.shrink();
    final questBoard =
        widget.home &&
        router.route == MenuRoute.more &&
        router.moreSection == MoreSection.quests;
    final homeMenuGrid =
        widget.home &&
        router.route == MenuRoute.more &&
        !router.homeAtSub &&
        !questBoard;
    // Full height above the shared bottom bar — same for every tab so GOLD /
    // SHOP / ESSENCE / KEY / MORE match GEAR (never cover the bar; OverlayScrim
    // lives only inside the Expanded scene stack).
    final navOwnedClose = widget.home && _homeNavOwnsClose(router.route);
    // Home ESSENCE tiles: the hub is always "ESSENCE", whichever panel was
    // last open (RELICS / PETS used to retitle the same tile grid).
    final essenceHub =
        widget.home && router.route == MenuRoute.essence && !router.homeAtSub;
    final goal = widget.home
        ? ChaseContract.goalLine(state, inDungeon: state.inDungeon)
        : null;
    String sheetSubtitle() {
      // Each sheet names itself. The chase line stays on the town card and
      // the fight coach, not under GEAR / SHOP / SETTINGS.
      if (homeMenuGrid) return HomeMenuGrid.hint;
      if (essenceHub) return MenuSurface.essenceHubHint;
      final own = router.jobHintFor(state);
      if (own.isNotEmpty) return own;
      if (goal != null && goal.isNotEmpty) return goal;
      return '';
    }

    return OverlayScrim(
      title: homeMenuGrid
          ? 'MENU'
          : essenceHub
          ? 'ESSENCE'
          : router.title,
      subtitle: sheetSubtitle(),
      heightFactor: 1,
      // Home keeps the top bar (essence, gold, gold/min) above every sheet,
      // so the sheet header does not repeat the wallet.
      gold: widget.home ? null : state.gold,
      essence: widget.home ? null : state.essence,
      showEssence: MenuTabs.showCamp(state),
      showClose: !navOwnedClose,
      onClose: router.close,
      child: switch (router.route) {
        // Home: GEAR / BAG / MERGE / ROSTER sit under the title, not as a
        // second tab row on top of the bottom nav (audit F046).
        MenuRoute.gear =>
          widget.home
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _gearTabs(),
                    Expanded(child: _inventoryDock()),
                  ],
                )
              : _inventoryDock(),
        MenuRoute.gold => GoldDock(
          director: d,
          panel: router.goldPanel,
          onPanelChanged: (panel) => router.goldPanel = panel,
        ),
        MenuRoute.shop => ShopDock(director: d, homeCompact: widget.home),
        MenuRoute.essence =>
          widget.home
              ? EssenceTilesScreen(director: d, router: router)
              : EssenceDock(
                  director: d,
                  router: router,
                  panel: router.essencePanel,
                  onPanelChanged: (panel) => router.essencePanel = panel,
                ),
        MenuRoute.key => KeystoneSheet(director: d, router: router),
        MenuRoute.map =>
          widget.home
              ? MapScreen(director: d, router: router)
              : const SizedBox.shrink(),
        MenuRoute.more =>
          questBoard
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: JobsOverlay(director: d),
                )
              : homeMenuGrid
              ? HomeMenuGrid(director: d, router: router)
              : MoreList(
                  director: d,
                  section: router.moreSection,
                  initialInfoPane: router.moreInfoPane,
                  showSectionRail: !widget.home,
                  showPatchNotes: !widget.home,
                  onSectionChanged: (sec) => router.moreSection = sec,
                  onOpenWhatsNew: () => WhatsNewOverlay.show(context, d),
                  onClose: router.close,
                ),
        MenuRoute.none => const SizedBox.shrink(),
      },
    );
  }
}
