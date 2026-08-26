import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_router.dart';
import '../../models/loot.dart';
import '../meta_overlays.dart';
import '../web_click_bridge.dart';
import 'inventory_dock.dart';
import 'jobs_market_sanctuary.dart';
import 'overlay_scaffold.dart';
import 'power_meta_pillars.dart';

/// The one menu sheet, shared by hub and dungeon.
///
/// Whatever [MenuRouter] says is open gets drawn here, so PARTY looks and
/// behaves the same whether you opened it from the hub or mid-fight.
class MenuSurface extends StatefulWidget {
  const MenuSurface({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  @override
  State<MenuSurface> createState() => _MenuSurfaceState();
}

class _MenuSurfaceState extends State<MenuSurface> {
  bool _heldBridgeLayer = false;
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
    _ensureBridgeLayer(false);
    widget.director.setUiPaused(false);
    super.dispose();
  }

  void _onRouteChanged() {
    if (router.route != _lastRoute) _applyRoute();
    if (mounted) setState(() {});
  }

  /// Side effects that used to live in `Is2Shell._setOverlay`.
  void _applyRoute() {
    final route = router.route;
    final prev = _lastRoute;
    _lastRoute = route;
    if (route != MenuRoute.none && route != MenuRoute.party) {
      widget.director.clearToast();
    }
    // Ack Meet … after the player leaves PARTY (not on open) so kit fantasy can be read.
    if (prev == MenuRoute.party && route != MenuRoute.party) {
      widget.director.ackPendingHeroReveals();
    }
    _ensureBridgeLayer(route != MenuRoute.none);
    // Combat only runs in a dungeon; the hub has nothing to pause.
    widget.director.setUiPaused(
      route != MenuRoute.none && widget.director.state.inDungeon,
    );
  }

  void _ensureBridgeLayer(bool want) {
    if (want == _heldBridgeLayer) return;
    if (want) {
      WebClickBridge.pushLayer();
    } else {
      WebClickBridge.popLayer();
    }
    _heldBridgeLayer = want;
  }

  void _equipSelectedTo(int heroIndex) {
    final id = router.selectedItemId;
    if (id == null) return;
    if (!state.gearStash.any((g) => g.id == id)) {
      widget.director.showToast(
        'Already worn — use UNEQUIP, or pick a BAG item',
        life: 2.4,
      );
      return;
    }
    final item = GameLogic.findGear(state, id);
    EquipmentSlot? into;
    if (item != null && heroIndex >= 0 && heroIndex < state.heroes.length) {
      into = GameLogic.compareForHero(
        state.heroes[heroIndex],
        item,
        pairingStash: state.gearStash,
      ).intoSlot;
    }
    final beforeIds = state.gearStash.map((g) => g.id).toSet();
    widget.director.equipFromStash(id, heroIndex: heroIndex, intoSlot: into);
    final equipped =
        !widget.director.state.gearStash.any((g) => g.id == id) &&
        beforeIds.contains(id);
    if (!equipped) {
      widget.director.showToast(
        'Cannot equip on that hero (class / level / slot)',
        life: 2.6,
      );
      return;
    }
    router
      ..equipHeroIndex = heroIndex
      ..clearSelection()
      ..clearBagSlotFilter();
  }

  void _putInCombinator(String id) {
    // Merge is bag-only — equipped pieces must be unequipped first.
    if (GameLogic.findStashGear(state, id) == null) {
      widget.director.showToast('Unequip to bag before merging', life: 2.2);
      return;
    }
    final ready = router.putInCombinator(id);
    if (ready) {
      widget.director.showToast('Merge ready — check MERGE', life: 2.2);
    } else if (router.combineA != null && router.combineB == null) {
      widget.director.showToast(
        'Added to merge · pick another same-slot item',
        life: 2.4,
      );
    }
  }

  Widget _inventoryDock() {
    final d = widget.director;
    return InventoryDock(
      state: state,
      director: d,
      selectedId: router.selectedItemId,
      combineA: router.combineA,
      combineB: router.combineB,
      tab: router.partyTab,
      onTabChanged: (tab) => router.partyTab = tab,
      flatChrome: true,
      onSelect: router.selectItem,
      onPutCombine: _putInCombinator,
      onEquip: () {
        if (router.selectedItemId == null) return;
        _equipSelectedTo(router.equipHeroIndex);
      },
      onUnequip: (slot) {
        d.unequipSlot(slot, heroIndex: router.equipHeroIndex);
        router.clearSelection();
      },
      bagSlotFilter: router.bagSlotFilter,
      onBrowseBagSlot: router.browseBagSlot,
      onClearBagSlotFilter: router.clearBagSlotFilter,
      equipHeroIndex: router.equipHeroIndex,
      onEquipHeroChanged: (i) => router.equipHeroIndex = i,
      onEquipToHero: _equipSelectedTo,
      onAutoEquip: () {
        d.autoEquipBetterGear();
        router.clearSelection();
      },
      onClearCombineA: router.clearCombineA,
      onClearCombineB: router.clearCombineB,
      onCombine: () {
        if (router.combineA == null || router.combineB == null) return;
        d.combineGear(
          primaryId: router.combineA!,
          secondaryId: router.combineB!,
        );
        router.clearCombine();
      },
      onCleanBag: d.cleanBagJunk,
      onOpenFilters: router.openBagFilters,
      onAutoMerge: () {
        d.autoMergeJunk();
        router.dropMissingIds(d.state.gearStash.map((g) => g.id).toSet());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    if (router.route == MenuRoute.none) return const SizedBox.shrink();
    // Phone-first: short menus still need most of the screen (list + claims).
    final heightFactor = switch (router.route) {
      MenuRoute.party => 1.0,
      MenuRoute.jobs => 0.84,
      _ => 0.96,
    };
    return OverlayScrim(
      title: router.title,
      heightFactor: heightFactor,
      onClose: router.close,
      child: switch (router.route) {
        MenuRoute.party => _inventoryDock(),
        MenuRoute.power => PowerPillar(
          director: d,
          tab: router.powerTab,
          onTabChanged: (tab) => router.powerTab = tab,
        ),
        MenuRoute.meta || MenuRoute.settings => MetaPillar(
          director: d,
          tab: router.metaTab,
          onTabChanged: (tab) => router.metaTab = tab,
          onOpenWhatsNew: () => WhatsNewOverlay.show(context, d),
          onClose: router.close,
          bagFiltersScrollNonce: router.bagFiltersScrollNonce,
        ),
        MenuRoute.jobs => SingleChildScrollView(
          child: JobsOverlay(director: d),
        ),
        MenuRoute.none => const SizedBox.shrink(),
      },
    );
  }
}
