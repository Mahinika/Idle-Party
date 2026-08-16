
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/menu_alerts.dart';
import '../models/loot.dart';
import 'confirm_dialogs.dart';
import 'cave_atmosphere.dart';
import 'custom_assets.dart';
import 'feedback_toast.dart';
import 'game_theme.dart';
import 'meta_overlays.dart';
import 'spatial_dungeon_view.dart';
import 'first_session_tips.dart';
import 'guides_overlay.dart';
import 'web_click_bridge.dart';
import 'shell/app_bottom_bar.dart';
import 'shell/beast_overlay.dart';
import 'shell/dungeon_party_hud.dart';
import 'shell/dungeon_target_hud.dart';
import 'shell/dungeon_top_hud.dart';
import 'shell/forge_overlay.dart';
import 'shell/inventory_dock.dart';
import 'shell/jobs_market_sanctuary.dart';
import 'shell/overlay_scaffold.dart';
import 'shell/power_meta_pillars.dart';
import 'shell/settings_overlay.dart';

/// Idle Party dungeon shell: full-bleed stage + corner HUD; bag/meta as overlays.
class Is2Shell extends StatefulWidget {
  const Is2Shell({
    super.key,
    required this.director,
    required this.pulse,
    this.onLeaveDungeon,
    this.initialOverlay = Is2Overlay.none,
    this.hubMode = false,
  });

  final GameDirector director;
  final double pulse;
  final VoidCallback? onLeaveDungeon;
  final Is2Overlay initialOverlay;
  final bool hubMode;

  @override
  State<Is2Shell> createState() => _Is2ShellState();
}

enum Is2Overlay {
  none,
  forge,
  jobs,
  sanctuary,
  inventory,
  settings,
  market,
  beast,
  achievements,
  codex,
  loadouts,
  teamComposition,
  guides,
  prestigeShop,
  /// Hub/dungeon POWER pillar: forge · sanctuary · market · essence.
  power,
  /// Hub/dungeon META pillar: keystone · contracts · beast · collection · help.
  meta,
}

class _Is2ShellState extends State<Is2Shell> {
  String? _selectedId;
  String? _combineA;
  String? _combineB;
  late Is2Overlay _overlay;
  int _equipHeroIndex = 0;
  int _abilityHeroIndex = 0;
  /// 0 = GEAR, 1 = BAG, 2 = TOOLS inside the inventory dock.
  int _inventoryTab = 1;
  /// When set, BAG only lists gear that can fill this paper-doll slot.
  EquipmentSlot? _bagSlotFilter;
  bool _heldBridgeLayer = false;

  GameState get state => widget.director.state;

  void _ensureBridgeLayer(bool want) {
    if (want == _heldBridgeLayer) return;
    if (want) {
      WebClickBridge.pushLayer();
    } else {
      WebClickBridge.popLayer();
    }
    _heldBridgeLayer = want;
  }

  bool _overlayHoldsBridge(Is2Overlay overlay) =>
      overlay != Is2Overlay.none;

  void _equipSelectedTo(int heroIndex) {
    final id = _selectedId;
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
    if (item != null &&
        heroIndex >= 0 &&
        heroIndex < state.heroes.length) {
      into = GameLogic.compareForHero(
        state.heroes[heroIndex],
        item,
        pairingStash: state.gearStash,
      ).intoSlot;
    }
    final beforeIds = state.gearStash.map((g) => g.id).toSet();
    widget.director.equipFromStash(
      id,
      heroIndex: heroIndex,
      intoSlot: into,
    );
    final equipped = !widget.director.state.gearStash.any((g) => g.id == id) &&
        beforeIds.contains(id);
    if (!equipped) {
      widget.director.showToast(
        'Cannot equip on that hero (class / level / slot)',
        life: 2.6,
      );
      return;
    }
    setState(() {
      _equipHeroIndex = heroIndex;
      _selectedId = null;
      _bagSlotFilter = null;
    });
  }

  void _browseBagSlot(EquipmentSlot slot) {
    setState(() {
      _bagSlotFilter = slot;
      _selectedId = null;
      // Stay on GEAR when the sheet shows an inline bag; jump to BAG otherwise.
      if (_inventoryTab != 0) {
        _inventoryTab = 1;
      }
    });
    _setOverlay(Is2Overlay.inventory);
  }

  @override
  void initState() {
    super.initState();
    _overlay = widget.initialOverlay;
    if (_overlay == Is2Overlay.inventory) {
      // PARTY pillar opens on GEAR (paper doll), not bag.
      _inventoryTab = 0;
    }
    // Hub meta shell sits over the live hub — isolate click bridge.
    // Dungeon meta overlays (forge etc.) do the same while open.
    _ensureBridgeLayer(
      widget.hubMode || _overlayHoldsBridge(_overlay),
    );
    _syncCombatPause();
  }

  @override
  void dispose() {
    _ensureBridgeLayer(false);
    widget.director.setUiPaused(false);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Is2Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOverlay != widget.initialOverlay) {
      _overlay = widget.initialOverlay;
      _syncCombatPause();
    }
  }

  void _select(String id) {
    setState(() => _selectedId = _selectedId == id ? null : id);
  }

  void _putInCombinator(String id) {
    // Merge is bag-only — equipped pieces must be unequipped first.
    if (GameLogic.findStashGear(widget.director.state, id) == null) {
      widget.director.showToast(
        'Unequip to bag before merging',
        life: 2.2,
      );
      return;
    }
    setState(() {
      if (_combineA == id) {
        _combineA = null;
        return;
      }
      if (_combineB == id) {
        _combineB = null;
        return;
      }
      if (_combineA == null) {
        _combineA = id;
      } else if (_combineB == null) {
        _combineB = id;
      } else {
        _combineA = _combineB;
        _combineB = id;
      }
      // After two items are loaded, show the merge panel.
      if (_combineA != null && _combineB != null) {
        _inventoryTab = 2;
        _overlay = Is2Overlay.inventory;
        _syncCombatPause();
      }
    });
    if (_combineA != null && _combineB != null) {
      widget.director.showToast('Merge ready — check MERGE', life: 2.2);
    } else if (_combineA != null && _combineB == null) {
      widget.director.showToast(
        'Added to merge · pick another same-slot item',
        life: 2.4,
      );
    }
  }

  Widget _inventoryDock({bool flatChrome = false}) {
    final d = widget.director;
    return InventoryDock(
      state: state,
      director: d,
      selectedId: _selectedId,
      combineA: _combineA,
      combineB: _combineB,
      initialTab: _inventoryTab,
      onTabChanged: (i) => setState(() => _inventoryTab = i),
      flatChrome: flatChrome,
      onSelect: _select,
      onPutCombine: _putInCombinator,
      onEquip: () {
        if (_selectedId == null) return;
        _equipSelectedTo(_equipHeroIndex);
      },
      onSell: () {
        final id = _selectedId ?? _combineA;
        if (id == null) return;
        if (!state.gearStash.any((g) => g.id == id)) {
          d.showToast('Unequip first — SELL only works from BAG', life: 2.4);
          return;
        }
        d.sellGear(id);
        setState(() {
          if (_selectedId == id) _selectedId = null;
          if (_combineA == id) _combineA = null;
          if (_combineB == id) _combineB = null;
        });
      },
      onUnequip: (slot) {
        d.unequipSlot(slot, heroIndex: _equipHeroIndex);
        setState(() => _selectedId = null);
      },
      bagSlotFilter: _bagSlotFilter,
      onBrowseBagSlot: _browseBagSlot,
      onClearBagSlotFilter: () => setState(() => _bagSlotFilter = null),
      equipHeroIndex: _equipHeroIndex,
      onEquipHeroChanged: (i) => setState(() => _equipHeroIndex = i),
      onEquipToHero: _equipSelectedTo,
      onAutoEquip: () {
        d.autoEquipBetterGear();
        setState(() => _selectedId = null);
      },
      onClearCombineA: () => setState(() => _combineA = null),
      onClearCombineB: () => setState(() => _combineB = null),
      onCombine: () {
        if (_combineA == null || _combineB == null) return;
        d.combineGear(primaryId: _combineA!, secondaryId: _combineB!);
        setState(() {
          _combineA = null;
          _combineB = null;
          _selectedId = null;
        });
      },
      onBindSoulbound: () => d.bindSoulbound(heroIndex: _equipHeroIndex),
      onAutoSell: d.autoSellJunk,
      onAutoDisassemble: d.autoDisassembleJunk,
      onCleanBag: d.cleanBagJunk,
      onOpenFilters: () => _openOverlay(Is2Overlay.settings),
      onAutoMerge: () {
        d.autoMergeJunk();
        setState(() {
          final ids = d.state.gearStash.map((g) => g.id).toSet();
          if (_combineA != null && !ids.contains(_combineA)) {
            _combineA = null;
          }
          if (_combineB != null && !ids.contains(_combineB)) {
            _combineB = null;
          }
          if (_selectedId != null && !ids.contains(_selectedId)) {
            _selectedId = null;
          }
        });
      },
    );
  }

  void _openBag() {
    if (!widget.hubMode &&
        _overlay == Is2Overlay.inventory &&
        _inventoryTab == 1) {
      _setOverlay(Is2Overlay.none);
      return;
    }
    setState(() {
      _inventoryTab = 1;
      // Fresh open from nav shows the full bag (slot browse sets filter itself).
      if (_overlay != Is2Overlay.inventory) {
        _bagSlotFilter = null;
      }
    });
    _setOverlay(Is2Overlay.inventory);
  }

  void _openGear() {
    if (!widget.hubMode &&
        _overlay == Is2Overlay.inventory &&
        _inventoryTab == 0) {
      _setOverlay(Is2Overlay.none);
      return;
    }
    setState(() => _inventoryTab = 0);
    _setOverlay(Is2Overlay.inventory);
  }

  void _openOverlay(Is2Overlay overlay) => _setOverlay(overlay);

  void _setOverlay(Is2Overlay overlay) {
    if (overlay != Is2Overlay.none &&
        overlay != Is2Overlay.inventory) {
      widget.director.clearToast();
    }
    if (overlay == Is2Overlay.inventory ||
        overlay == Is2Overlay.teamComposition) {
      widget.director.ackPendingHeroReveals();
    }
    setState(() {
      _overlay = overlay;
      if (overlay == Is2Overlay.none) {
        _bagSlotFilter = null;
      }
    });
    if (!widget.hubMode) {
      _ensureBridgeLayer(_overlayHoldsBridge(overlay));
    }
    _syncCombatPause();
  }

  void _syncCombatPause() {
    if (widget.hubMode) {
      widget.director.setUiPaused(false);
      return;
    }
    widget.director.setUiPaused(_overlay != Is2Overlay.none);
  }

  void _closeOverlayOrLeaveHub() {
    // Hub meta shell: CLOSE / scrim should exit to HubScreen (same as Escape),
    // not land on the inventory dock under an empty overlay.
    if (widget.hubMode) {
      widget.onLeaveDungeon?.call();
      return;
    }
    if (_overlay != Is2Overlay.none) {
      _setOverlay(Is2Overlay.none);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (widget.hubMode) {
        widget.onLeaveDungeon?.call();
        return KeyEventResult.handled;
      }
      if (_overlay != Is2Overlay.none) {
        _setOverlay(Is2Overlay.none);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyB) {
      _openBag();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      if (!widget.hubMode && widget.onLeaveDungeon != null) {
        confirmLeaveDungeon(context, widget.onLeaveDungeon!);
        return KeyEventResult.handled;
      }
      if (widget.hubMode && widget.onLeaveDungeon != null) {
        widget.onLeaveDungeon!();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.space) {
      if (!widget.hubMode &&
          state.inDungeon &&
          !state.isPartyDefeated &&
          _overlay == Is2Overlay.none) {
        widget.director.godHandAtFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  BottomNavTab _navActive() {
    // Hub + dungeon share PARTY / POWER / META pillars.
    return switch (_overlay) {
      Is2Overlay.inventory => _inventoryTab == 0
          ? BottomNavTab.gear
          : _inventoryTab == 1
              ? BottomNavTab.bag
              : BottomNavTab.party,
      Is2Overlay.power ||
      Is2Overlay.forge ||
      Is2Overlay.sanctuary ||
      Is2Overlay.market ||
      Is2Overlay.prestigeShop =>
        BottomNavTab.power,
      Is2Overlay.meta ||
      Is2Overlay.jobs ||
      Is2Overlay.beast ||
      Is2Overlay.achievements ||
      Is2Overlay.codex ||
      Is2Overlay.guides ||
      Is2Overlay.settings =>
        BottomNavTab.meta,
      _ => BottomNavTab.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: _buildBody(context, d),
    );
  }

  Widget _buildBody(BuildContext context, GameDirector d) {
    final hudSide = GameTheme.combatHudSide(context);
    final hudBottom = GameTheme.combatHudBottom(context);

    if (widget.hubMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CaveAtmosphere.fullBleedScene(
            CustomAssets.hubScene,
            alignment: const Alignment(0, -0.08),
          ),
          CaveAtmosphere.readabilityScrim(top: 0.45, bottom: 0.5),
          SafeArea(
            child: Column(
              children: [
                DungeonTopHud(
                  state: state,
                  director: d,
                  hubMode: true,
                  onOpenSettings: () => _openOverlay(Is2Overlay.settings),
                  onOpenContracts: () => _openOverlay(Is2Overlay.jobs),
                ),
                Expanded(
                  child: (_overlay == Is2Overlay.none ||
                          _overlay == Is2Overlay.inventory)
                      ? _inventoryDock()
                      : const SizedBox.shrink(),
                ),
                AppBottomBar(
                  stashCount: state.gearStash.length,
                  stashCap: GameLogic.maxGearStashFor(state),
                  hubPillars: true,
                  alerts: MenuAlerts.forState(state),
                  active: _navActive(),
                  onGear: () {
                    setState(() => _inventoryTab = 0);
                    _openOverlay(Is2Overlay.inventory);
                  },
                  onBag: () {
                    setState(() => _inventoryTab = 1);
                    _openOverlay(Is2Overlay.inventory);
                  },
                  onMore: () => _openOverlay(Is2Overlay.power),
                  onParty: () {
                    setState(() => _inventoryTab = 0);
                    _openOverlay(Is2Overlay.inventory);
                  },
                  onPower: () => _openOverlay(Is2Overlay.power),
                  onMeta: () => _openOverlay(Is2Overlay.meta),
                  onHubClose: () => widget.onLeaveDungeon?.call(),
                ),
              ],
            ),
          ),
          if (_overlay != Is2Overlay.none &&
              _overlay != Is2Overlay.inventory)
            _metaOverlay(d),
          FirstSessionTips(director: d),
          if (d.toast != null)
            Positioned.fill(
              child: FeedbackToast(
                message: d.toast!,
                alignment: _overlay != Is2Overlay.none
                    ? const Alignment(0, -0.82)
                    : const Alignment(0, -0.42),
              ),
            ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CaveAtmosphere.fullBleedScene(
            CustomAssets.dungeonBackdropFor(state.dungeonId),
          ),
        ),
        const RepaintBoundary(
          child: _DungeonScrimBloom(),
        ),
        SafeArea(
          child: Column(
            children: [
              DungeonTopHud(
                state: state,
                director: d,
                onOpenSettings: () => _openOverlay(Is2Overlay.settings),
                onOpenContracts: () => _openOverlay(Is2Overlay.jobs),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: d.combatFrame,
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        SpatialDungeonView(director: d),
                        if (!d.awaitingWipeChoice) ...[
                          // Calm map-first HUD: meter (tap), target chip, party strip.
                          Positioned(
                            left: hudSide,
                            top: GameTheme.clusterGap / 2,
                            child: DpsMeter(director: d),
                          ),
                          Positioned(
                            right: hudSide,
                            top: GameTheme.clusterGap / 2,
                            child: TargetCornerHud(director: d),
                          ),
                          Positioned(
                            left: hudSide,
                            bottom: hudBottom,
                            child: PartyCornerHud(
                              director: d,
                              selectedHeroIndex: _abilityHeroIndex,
                              onSelectHero: (i) =>
                                  setState(() => _abilityHeroIndex = i),
                              onOpenEquip: _openGear,
                              onUseConsumable: d.useConsumable,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              AppBottomBar(
                stashCount: state.gearStash.length,
                stashCap: GameLogic.maxGearStashFor(state),
                hubPillars: true,
                alerts: MenuAlerts.forState(state),
                active: _navActive(),
                onGear: _openGear,
                onBag: _openBag,
                onMore: () => _openOverlay(Is2Overlay.power),
                onParty: () {
                  setState(() => _inventoryTab = 0);
                  _openOverlay(Is2Overlay.inventory);
                },
                onPower: () => _openOverlay(Is2Overlay.power),
                onMeta: () => _openOverlay(Is2Overlay.meta),
                onHubClose: widget.onLeaveDungeon == null
                    ? null
                    : () => confirmLeaveDungeon(context, widget.onLeaveDungeon!),
              ),
            ],
          ),
        ),
        if (_overlay != Is2Overlay.none) _metaOverlay(d),
        FirstSessionTips(director: d),
        if (d.toast != null)
          Positioned.fill(
            child: FeedbackToast(
              message: d.toast!,
              alignment: _overlay != Is2Overlay.none
                  ? const Alignment(0, -0.82)
                  : const Alignment(0, -0.42),
            ),
          ),
      ],
    );
  }

  Widget _metaOverlay(GameDirector d) {
    final shortSheet = switch (_overlay) {
      Is2Overlay.jobs ||
      Is2Overlay.market ||
      Is2Overlay.beast ||
      Is2Overlay.prestigeShop =>
        true,
      _ => false,
    };
    // Phone-first: short menus still need most of the screen (list + claims).
    final heightFactor = switch (_overlay) {
      Is2Overlay.inventory => 1.0,
      Is2Overlay.power || Is2Overlay.meta => 0.96,
      _ when shortSheet => 0.84,
      _ => 0.96,
    };
    return OverlayScrim(
      title: switch (_overlay) {
        Is2Overlay.forge => 'FORGE',
        Is2Overlay.power => 'POWER',
        Is2Overlay.meta => 'META',
        Is2Overlay.jobs => 'CONTRACTS',
        Is2Overlay.sanctuary => 'SANCTUARY',
        Is2Overlay.inventory => switch (_inventoryTab) {
          0 => 'GEAR',
          1 => 'BAG',
          2 => 'MERGE',
          3 => 'LOADOUTS',
          4 => 'ROSTER',
          _ => 'PARTY',
        },
        Is2Overlay.settings => 'SETTINGS',
        Is2Overlay.market => 'MARKET',
        Is2Overlay.beast => 'BEAST PEN',
        Is2Overlay.achievements => 'ACHIEVEMENTS',
        Is2Overlay.codex => 'CODEX',
        Is2Overlay.loadouts => 'LOADOUTS',
        Is2Overlay.teamComposition => 'PARTY',
        Is2Overlay.guides => 'GUIDES',
        Is2Overlay.prestigeShop => 'ESSENCE SHOP',
        Is2Overlay.none => '',
      },
      heightFactor: heightFactor,
      onClose: _closeOverlayOrLeaveHub,
      child: switch (_overlay) {
        // Bounded sheet height — forge scrolls inside (no nested outer scroll).
        Is2Overlay.forge => ForgeOverlay(director: d),
        Is2Overlay.power => PowerPillar(director: d),
        Is2Overlay.meta => MetaPillar(
            director: d,
            onOpenWhatsNew: () => WhatsNewOverlay.show(context, d),
          ),
        Is2Overlay.jobs => SingleChildScrollView(
          child: JobsOverlay(director: d),
        ),
        Is2Overlay.sanctuary => SingleChildScrollView(
          child: SanctuaryOverlay(director: d),
        ),
        Is2Overlay.inventory => _inventoryDock(flatChrome: true),
        Is2Overlay.settings => SettingsOverlay(
              director: d,
              onClose: () => _setOverlay(Is2Overlay.none),
            ),
        Is2Overlay.market => SingleChildScrollView(
          child: MarketOverlay(director: d),
        ),
        Is2Overlay.beast => SingleChildScrollView(
          child: BeastOverlay(director: d),
        ),
        Is2Overlay.achievements => AchievementsOverlay(director: d),
        Is2Overlay.codex => CodexOverlay(director: d),
        Is2Overlay.loadouts => LoadoutsOverlay(director: d),
        Is2Overlay.teamComposition => SingleChildScrollView(
          child: TeamCompositionOverlay(director: d),
        ),
        Is2Overlay.guides => const GuidesOverlay(),
        Is2Overlay.prestigeShop => PrestigeShopOverlay(director: d),
        Is2Overlay.none => const SizedBox.shrink(),
      },
    );
  }
}

class _DungeonScrimBloom extends StatelessWidget {
  const _DungeonScrimBloom();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CaveAtmosphere.readabilityScrim(top: 0.25, bottom: 0.35),
        CaveAtmosphere.torchBloom(
          intensity: 0.65,
          alignment: const Alignment(0, 0.15),
          sizeFactor: 0.7,
        ),
      ],
    );
  }
}
