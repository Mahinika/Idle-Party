import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_router.dart';
import '../../core/nav_intent.dart';
import 'essence_dock.dart';
import 'gold_dock.dart';
import 'inventory_dock.dart';
import 'overlay_scaffold.dart';
import 'power_meta_pillars.dart';
import 'shop_dock.dart';
import '../meta/keystone_sheet.dart';
import 'whats_new_overlay.dart';

/// The one menu sheet, shared by hub and dungeon.
/// All routes fill the stack above the shared [AppBottomBar] (full height).
class MenuSurface extends StatefulWidget {
  const MenuSurface({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  @override
  State<MenuSurface> createState() => _MenuSurfaceState();
}

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
        d.combineGear(
          primaryId: session.combineA!,
          secondaryId: session.combineB!,
        );
        session.clearCombine();
      },
      onCleanBag: d.cleanBagJunk,
      onOpenFilters: router.openBagFilters,
      onAutoMerge: () {
        d.autoMergeJunk();
        session.dropMissingIds(d.state.gearStash.map((g) => g.id).toSet());
      },
      onOpenMarket: () => router.apply(NavIntent.market),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    if (router.route == MenuRoute.none) return const SizedBox.shrink();
    // Full height above the shared bottom bar — same for every tab so GOLD /
    // SHOP / ESSENCE / KEY / MORE match GEAR (never cover the bar; OverlayScrim
    // lives only inside the Expanded scene stack).
    return OverlayScrim(
      title: router.title,
      subtitle: router.jobHint,
      heightFactor: 1,
      onClose: router.close,
      child: switch (router.route) {
        MenuRoute.gear => _inventoryDock(),
        MenuRoute.gold => GoldDock(
          director: d,
          panel: router.goldPanel,
          onPanelChanged: (panel) => router.goldPanel = panel,
        ),
        MenuRoute.shop => const ShopDock(),
        MenuRoute.essence => EssenceDock(
          director: d,
          panel: router.essencePanel,
          onPanelChanged: (panel) => router.essencePanel = panel,
        ),
        MenuRoute.key => KeystoneSheet(director: d),
        MenuRoute.more => MoreList(
          director: d,
          section: router.moreSection,
          onSectionChanged: (sec) => router.moreSection = sec,
          onOpenWhatsNew: () => WhatsNewOverlay.show(context, d),
          onClose: router.close,
          bagFiltersScrollNonce: router.session.bagFiltersScrollNonce,
        ),
        MenuRoute.none => const SizedBox.shrink(),
      },
    );
  }
}

