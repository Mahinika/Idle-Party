import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/keystone.dart';
import '../core/menu_alerts.dart';
import '../core/meta_systems.dart';
import '../models/class_ability.dart';
import '../models/dungeon_def.dart';
import '../models/dungeon_mode.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/pet.dart';
import '../spatial/spatial_combat.dart';
import 'apex_forge_panel.dart';
import 'confirm_dialogs.dart';
import 'character_equip_panel.dart';
import 'cave_atmosphere.dart';
import 'custom_assets.dart';
import 'feedback_toast.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'kenney_assets.dart';
import 'kenney_bar.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'meta_overlays.dart';
import 'spatial_dungeon_view.dart';
import 'first_session_tips.dart';
import 'guides_overlay.dart';
import 'item_tooltip.dart';
import 'web_click_bridge.dart';

Color _rarityBorderColor(LootRarity rarity) => switch (rarity) {
  LootRarity.common => const Color(0xFF5A5040),
  LootRarity.uncommon => const Color(0xFF70C050),
  LootRarity.rare => const Color(0xFF5090E0),
  LootRarity.epic => GameTheme.borderLit,
  LootRarity.legendary => const Color(0xFFFF8C40),
};

String _patternGlyph(ProjectilePattern pattern) => switch (pattern) {
  ProjectilePattern.single => 'S',
  ProjectilePattern.spread => 'P',
  ProjectilePattern.arc => 'A',
  ProjectilePattern.pierce => 'X',
};

String _formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  if (n >= 1000) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
  return '$n';
}

bool _isSoulboundItem(EquipmentItem item) => item.id.startsWith('soulbound_');

bool _isUpgradeForAny(GameState state, EquipmentItem item) {
  for (final hero in state.heroes) {
    if (GameLogic.compareForHero(
      hero,
      item,
      pairingStash: state.gearStash,
    ).isUpgrade) {
      return true;
    }
  }
  return false;
}

bool _isBestStashItem(GameState state, EquipmentItem item) {
  if (!_isUpgradeForAny(state, item)) return false;
  var bestDelta = 0;
  for (final stashItem in state.gearStash) {
    for (final hero in state.heroes) {
      final cmp = GameLogic.compareForHero(
        hero,
        stashItem,
        pairingStash: state.gearStash,
      );
      if (cmp.isUpgrade && cmp.powerDelta > bestDelta) {
        bestDelta = cmp.powerDelta;
      }
    }
  }
  for (final hero in state.heroes) {
    final cmp = GameLogic.compareForHero(
      hero,
      item,
      pairingStash: state.gearStash,
    );
    if (cmp.isUpgrade && cmp.powerDelta >= bestDelta) return true;
  }
  return false;
}

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
    return _InventoryDock(
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

  _BottomNavTab _navActive() {
    // Hub + dungeon share PARTY / POWER / META pillars.
    return switch (_overlay) {
      Is2Overlay.inventory => _inventoryTab == 0
          ? _BottomNavTab.gear
          : _inventoryTab == 1
              ? _BottomNavTab.bag
              : _BottomNavTab.party,
      Is2Overlay.power ||
      Is2Overlay.forge ||
      Is2Overlay.sanctuary ||
      Is2Overlay.market ||
      Is2Overlay.prestigeShop =>
        _BottomNavTab.power,
      Is2Overlay.meta ||
      Is2Overlay.jobs ||
      Is2Overlay.beast ||
      Is2Overlay.achievements ||
      Is2Overlay.codex ||
      Is2Overlay.guides ||
      Is2Overlay.settings =>
        _BottomNavTab.meta,
      _ => _BottomNavTab.none,
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
                _TopHud(
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
                _BottomNav(
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
              _TopHud(
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
                            child: _DpsMeter(director: d),
                          ),
                          Positioned(
                            right: hudSide,
                            top: GameTheme.clusterGap / 2,
                            child: _TargetCornerHud(director: d),
                          ),
                          Positioned(
                            left: hudSide,
                            bottom: hudBottom,
                            child: _PartyCornerHud(
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
              _BottomNav(
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
    return _OverlayScrim(
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
        Is2Overlay.forge => _ForgeOverlay(director: d),
        Is2Overlay.power => _PowerPillar(director: d),
        Is2Overlay.meta => _MetaPillar(
            director: d,
            onOpenWhatsNew: () => WhatsNewOverlay.show(context, d),
          ),
        Is2Overlay.jobs => SingleChildScrollView(
          child: _JobsOverlay(director: d),
        ),
        Is2Overlay.sanctuary => SingleChildScrollView(
          child: _SanctuaryOverlay(director: d),
        ),
        Is2Overlay.inventory => _inventoryDock(flatChrome: true),
        Is2Overlay.settings => _SettingsOverlay(
              director: d,
              onClose: () => _setOverlay(Is2Overlay.none),
            ),
        Is2Overlay.market => SingleChildScrollView(
          child: _MarketOverlay(director: d),
        ),
        Is2Overlay.beast => SingleChildScrollView(
          child: _BeastOverlay(director: d),
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

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.state,
    required this.director,
    required this.onOpenSettings,
    required this.onOpenContracts,
    this.hubMode = false,
  });

  final GameState state;
  final GameDirector director;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenContracts;
  final bool hubMode;

  void _claimAllReadyMissions() {
    for (final mission in state.missions) {
      if (mission.isComplete) {
        director.claimMission(mission.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dungeonName =
        GameLogic.dungeonNames[state.dungeonId] ?? state.dungeonId;
    final claimable = state.missions.where((m) => m.isComplete).length;
    final floor = state.currentRoom.floorNumber;
    final world = director.spatial;
    final farm = state.dungeonMode == DungeonMode.farm;
    final compact = GameTheme.isCompactWidth(context);
    // CLAIM stays visible mid-fight so contracts aren't buried in MORE.
    final showClaimChip = claimable > 0;
    final softcap = hubMode ? 0 : GameLogic.levelsUntilSoftcap(state);

    if (hubMode) {
      final phone = GameTheme.isPhoneWidth(context);
      return Container(
        padding: EdgeInsets.fromLTRB(10, phone ? 4 : 8, 6, phone ? 4 : 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GameTheme.ink.withValues(alpha: 0.82),
              GameTheme.stoneDeep.withValues(alpha: 0.55),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: GameTheme.border.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                phone ? 'KEEP' : "HERO'S KEEP",
                overflow: TextOverflow.ellipsis,
                style: GameTheme.pixel(size: GameTheme.hudPixel),
              ),
            ),
            _Chip(icon: KenneyAssets.coinGold, label: _formatCount(state.gold)),
            const SizedBox(width: 5),
            _Chip(
              icon: KenneyAssets.vialBlue,
              label: _formatCount(state.essence),
            ),
            SizedBox(
              width: GameTheme.minTouch,
              height: GameTheme.minTouch,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onOpenSettings,
                icon: KenneySprite(
                  asset: KenneyAssets.iconDoor,
                  size: 18,
                ),
                tooltip: 'Settings',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        compact ? 4 : 6,
        4,
        compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.ink.withValues(alpha: 0.82),
            GameTheme.stoneDeep.withValues(alpha: 0.55),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: GameTheme.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          compact
          ? Row(
              children: [
                if (state.inGauntlet)
                  DungeonModeChip(
                    label: 'GAUNTLET',
                    selected: true,
                    dense: true,
                    onTap: () {},
                  )
                else ...[
                  DungeonModeChip(
                    label: 'FARM',
                    selected: farm,
                    dense: true,
                    onTap: () => director.setDungeonMode(DungeonMode.farm),
                  ),
                  const SizedBox(width: 3),
                  DungeonModeChip(
                    label: 'PUSH',
                    selected: !farm,
                    dense: true,
                    onTap: () => director.setDungeonMode(DungeonMode.push),
                  ),
                ],
                if (world != null) ...[
                  const SizedBox(width: 4),
                  ChamberDots(world: world),
                  const SizedBox(width: 4),
                  GodHandRing(
                    cooldown: world.godHandCooldown,
                    onTap: () => director.godHandAtFocus(),
                  ),
                ],
                const Spacer(),
                if (showClaimChip) ...[
                  _MissionClaimChip(
                    count: claimable,
                    dense: true,
                    onTap: _claimAllReadyMissions,
                    onLongPress: onOpenContracts,
                  ),
                  const SizedBox(width: 2),
                ],
                SizedBox(
                  width: GameTheme.minTouch,
                  height: GameTheme.minTouch,
                  child: Semantics(
                    button: true,
                    label: 'Floor / settings',
                    excludeSemantics: true,
                    child: PopupMenuButton<String>(
                    tooltip: 'Floor / settings',
                    padding: EdgeInsets.zero,
                    color: GameTheme.stoneDeep,
                    onSelected: (value) {
                      switch (value) {
                        case 'down':
                          director.travelToFloor(floor - 1);
                        case 'up':
                          director.travelToFloor(floor + 1);
                        case 'settings':
                          onOpenSettings();
                        case 'contracts':
                          onOpenContracts();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'F$floor'
                          '${state.keystoneRunActive ? ' KEY+${state.keystoneRunLevel}' : ''}'
                          ' · ${_formatCount(state.gold)}g',
                          style: GameTheme.pixel(
                            size: GameTheme.hudPixel,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: GameLogic.canTravelToFloor(state, floor - 1),
                        child: Text(
                          'FLOOR −1',
                          style: GameTheme.pixel(size: GameTheme.hudPixel),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'up',
                        enabled: GameLogic.canTravelToFloor(state, floor + 1),
                        child: Text(
                          'FLOOR +1',
                          style: GameTheme.pixel(size: GameTheme.hudPixel),
                        ),
                      ),
                      if (claimable > 0)
                        PopupMenuItem(
                          value: 'contracts',
                          child: Text(
                            'CONTRACTS ($claimable)',
                            style: GameTheme.pixel(size: GameTheme.hudPixel),
                          ),
                        ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Text(
                          'SETTINGS',
                          style: GameTheme.pixel(size: GameTheme.hudPixel),
                        ),
                      ),
                    ],
                    child: const Center(
                      child: Icon(
                        Icons.more_horiz,
                        size: 22,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$dungeonName  F$floor'
                        '${state.keystoneRunActive ? '  KEY+${state.keystoneRunLevel}' : ''}'
                        '${state.keystoneRunActive ? '  ${Keystone.formatTimer(state.keystoneTimerMs)}/${Keystone.formatTimer(state.keystoneParMs)}' : ''}'
                        '${state.keystoneOutcome == 'timed' ? '  TIMED' : state.keystoneOutcome == 'depleted' ? '  DEPLETED' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.pixel(size: GameTheme.hudPixel),
                      ),
                    ),
                    if (showClaimChip) ...[
                      const SizedBox(width: 4),
                      _MissionClaimChip(
                        count: claimable,
                        onTap: _claimAllReadyMissions,
                        onLongPress: onOpenContracts,
                      ),
                    ],
                    const SizedBox(width: 4),
                    _Chip(
                      icon: KenneyAssets.coinGold,
                      label: _formatCount(state.gold),
                    ),
                    const SizedBox(width: 4),
                    _Chip(
                      icon: KenneyAssets.vialBlue,
                      label: _formatCount(state.essence),
                    ),
                    SizedBox(
                      width: GameTheme.minTouch,
                      height: GameTheme.minTouch,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onOpenSettings,
                        icon: KenneySprite(
                          asset: KenneyAssets.iconDoor,
                          size: 18,
                        ),
                        tooltip: 'Settings',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (state.inGauntlet)
                      DungeonModeChip(
                        label: 'GAUNTLET F$floor',
                        selected: true,
                        onTap: () {},
                      )
                    else ...[
                      DungeonModeChip(
                        label: 'FARM',
                        selected: farm,
                        onTap: () => director.setDungeonMode(DungeonMode.farm),
                      ),
                      const SizedBox(width: 4),
                      DungeonModeChip(
                        label: 'PUSH',
                        selected: !farm,
                        onTap: () => director.setDungeonMode(DungeonMode.push),
                      ),
                    ],
                    const SizedBox(width: 6),
                    if (world != null) ...[
                      ChamberDots(world: world),
                      const SizedBox(width: 6),
                      GodHandRing(
                        cooldown: world.godHandCooldown,
                        onTap: () => director.godHandAtFocus(),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: GameTheme.minTouch,
                      height: GameTheme.minTouch,
                      child: Semantics(
                        button: true,
                        label: 'Floor travel',
                        excludeSemantics: true,
                        child: PopupMenuButton<String>(
                        tooltip: 'Floor travel',
                        padding: EdgeInsets.zero,
                        color: GameTheme.stoneDeep,
                        onSelected: (value) {
                          switch (value) {
                            case 'down':
                              director.travelToFloor(floor - 1);
                            case 'up':
                              director.travelToFloor(floor + 1);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'down',
                            enabled:
                                GameLogic.canTravelToFloor(state, floor - 1),
                            child: Text(
                              'FLOOR −1',
                              style:
                                  GameTheme.pixel(size: GameTheme.hudPixel),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'up',
                            enabled:
                                GameLogic.canTravelToFloor(state, floor + 1),
                            child: Text(
                              'FLOOR +1',
                              style:
                                  GameTheme.pixel(size: GameTheme.hudPixel),
                            ),
                          ),
                        ],
                        child: Center(
                            child: Text(
                              'F±',
                              style: GameTheme.pixel(
                                size: GameTheme.hudPixel,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ),
                      ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (softcap > 0 && !state.inGauntlet)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Underleveled · train ~$softcap lvl or farm gear',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 11, color: GameTheme.torchHot),
              ),
            ),
        ],
      ),
    );
  }
}

enum _BottomNavTab { none, gear, bag, more, party, power, meta }

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.stashCount,
    required this.active,
    required this.onGear,
    required this.onBag,
    required this.onMore,
    this.stashCap,
    this.hubPillars = false,
    this.alerts = MenuAlerts.none,
    this.onParty,
    this.onPower,
    this.onMeta,
    this.onHubClose,
  });

  final int stashCount;
  final int? stashCap;

  /// Shared "something waits here" marks (see [MenuAlerts]).
  final MenuAlerts alerts;
  final _BottomNavTab active;
  final VoidCallback onGear;
  final VoidCallback onBag;
  final VoidCallback onMore;
  /// Unified pillars: PARTY / POWER / META / HUB (hub shell + dungeon).
  final bool hubPillars;
  final VoidCallback? onParty;
  final VoidCallback? onPower;
  final VoidCallback? onMeta;
  final VoidCallback? onHubClose;

  @override
  Widget build(BuildContext context) {
    final full = stashCap != null && stashCount >= stashCap!;
    final nearlyFull = !full &&
        stashCap != null &&
        stashCount >= (stashCap! * 0.9).ceil();
    final bagLabel = stashCap == null
        ? 'BAG $stashCount'
        : full
            ? 'BAG FULL $stashCount/$stashCap'
            : nearlyFull
                ? 'BAG $stashCount/$stashCap!'
                : 'BAG $stashCount/$stashCap';
    return Material(
      color: Colors.transparent,
      child: Container(
        height: GameTheme.bottomNavHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GameTheme.stone.withValues(alpha: 0.96),
              GameTheme.ink.withValues(alpha: 0.98),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: GameTheme.borderLit.withValues(alpha: 0.35),
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: hubPillars
            ? Row(
                children: [
                  Expanded(
                    child: _BottomNavItem(
                      label: 'PARTY',
                      icon: KenneyAssets.helmet,
                      badge: alerts.party.badge,
                      selected: active == _BottomNavTab.party ||
                          active == _BottomNavTab.gear ||
                          active == _BottomNavTab.bag,
                      onTap: onParty ?? onGear,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: 'POWER',
                      icon: CustomAssets.iconAxe,
                      badge: alerts.power.badge,
                      selected: active == _BottomNavTab.power,
                      onTap: onPower ?? onMore,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: 'META',
                      icon: KenneyAssets.book,
                      badge: alerts.meta.badge,
                      selected: active == _BottomNavTab.meta,
                      onTap: onMeta ?? onMore,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: 'HUB',
                      icon: KenneyAssets.iconDoor,
                      selected: false,
                      onTap: onHubClose ?? onMore,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _BottomNavItem(
                      label: 'GEAR',
                      icon: KenneyAssets.iconSword,
                      selected: active == _BottomNavTab.gear,
                      onTap: onGear,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: bagLabel,
                      icon: KenneyAssets.chestClosed,
                      selected: active == _BottomNavTab.bag,
                      urgent: full || nearlyFull,
                      onTap: onBag,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      label: 'MORE',
                      icon: KenneyAssets.iconDoor,
                      selected: active == _BottomNavTab.more,
                      onTap: onMore,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.urgent = false,
    this.badge = '',
  });

  final String label;
  final String icon;
  final bool selected;
  final bool urgent;

  /// Small count / star drawn on the icon when something waits inside.
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? GameTheme.accentWarn
        : (selected ? GameTheme.torchHot : GameTheme.parchmentDim);
    final semanticsLabel = badge.isEmpty ? label : '$label $badge waiting';
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: GameTheme.minTouch + 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? GameTheme.torch.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  ),
                  child: badge.isEmpty
                      ? KenneySprite(asset: icon, size: 18)
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            KenneySprite(asset: icon, size: 18),
                            Positioned(
                              right: -7,
                              top: -6,
                              child: _NavBadge(text: badge),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 13, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab controller whose length can grow as menus unlock (progressive tabs).
class _FlexTabs {
  _FlexTabs({
    required this.vsync,
    required int length,
    required this.onChanged,
    int initialIndex = 0,
  }) {
    _build(length, initialIndex);
  }

  final TickerProvider vsync;
  final ValueChanged<int> onChanged;
  late TabController controller;

  int get index => controller.index;

  /// Call from build once the visible tab count is known.
  void sync(int length) {
    if (length < 1 || controller.length == length) return;
    final keep = controller.index.clamp(0, length - 1);
    final old = controller;
    _build(length, keep);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void animateTo(int index) {
    controller.animateTo(index.clamp(0, controller.length - 1));
  }

  void _build(int length, int initialIndex) {
    controller = TabController(
      length: length,
      vsync: vsync,
      initialIndex: initialIndex.clamp(0, length - 1),
    );
    controller.addListener(() {
      if (!controller.indexIsChanging) onChanged(controller.index);
    });
  }

  void dispose() => controller.dispose();
}

/// Count / star drawn on a nav icon when that menu has something to do.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 15),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: GameTheme.torchHot,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameTheme.ink, width: 1),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 10, color: GameTheme.ink),
      ),
    );
  }
}

class _MissionClaimChip extends StatelessWidget {
  const _MissionClaimChip({
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.dense = false,
  });
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 1 ? 'Claim 1 mission' : 'Claim $count missions',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 6 : 8,
                vertical: dense ? 4 : 6,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3A5018),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: GameTheme.clear),
              ),
              child: Text(
                dense ? 'C$count' : 'CLAIM $count',
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: GameTheme.clear,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyCornerHud extends StatefulWidget {
  const _PartyCornerHud({
    required this.director,
    required this.selectedHeroIndex,
    required this.onSelectHero,
    required this.onOpenEquip,
    required this.onUseConsumable,
  });
  final GameDirector director;
  final int selectedHeroIndex;
  final ValueChanged<int> onSelectHero;
  final VoidCallback onOpenEquip;
  final VoidCallback onUseConsumable;

  @override
  State<_PartyCornerHud> createState() => _PartyCornerHudState();
}

class _PartyCornerHudState extends State<_PartyCornerHud> {
  static const _idleFade = Duration(seconds: 8);
  static const _idleFadePhone = Duration(seconds: 5);
  static const _fullOpacity = 1.0;
  static const _dimOpacity = 0.55;
  static const _dimOpacityPhone = 0.4;
  static const _hudScale = 1.0;

  Timer? _fadeTimer;
  double _opacity = _fullOpacity;
  /// Kit chips only when the player taps a strip (map stays clear by default).
  bool _kitOpen = false;

  @override
  void initState() {
    super.initState();
    _scheduleFade();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _bump() {
    _fadeTimer?.cancel();
    if (_opacity < _fullOpacity) {
      setState(() => _opacity = _fullOpacity);
    }
    final phone = mounted && GameTheme.isPhoneWidth(context);
    _scheduleFade(phone: phone);
  }

  void _scheduleFade({bool phone = false}) {
    _fadeTimer = Timer(phone ? _idleFadePhone : _idleFade, () {
      if (!mounted) return;
      setState(() => _opacity = phone ? _dimOpacityPhone : _dimOpacity);
    });
  }

  SpatialActor? _spatialFor(SpatialWorld? world, int i) {
    if (world == null) return null;
    for (final a in world.heroes) {
      if (!a.isPet && a.assetIndex == i) return a;
    }
    return null;
  }

  void _onHeroTap(int i) {
    _bump();
    if (widget.selectedHeroIndex == i && _kitOpen) {
      setState(() => _kitOpen = false);
      return;
    }
    widget.onSelectHero(i);
    setState(() => _kitOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final canUseFlask = GameLogic.canUseConsumable(state);
    final compact = GameTheme.isCompactWidth(context);
    final phone = GameTheme.isPhoneWidth(context);
    // Thin strip: reclaim map; kit expands in place when tapped.
    final fullWidth = phone ? 148.0 : (compact ? 188.0 : 228.0);
    var partyCritical = false;
    final bossFight = world != null &&
        world.enemies.any(
          (e) => e.hp > 0 && !e.dormant && e.role == EnemyRole.boss,
        );
    for (var i = 0; i < state.heroes.length; i++) {
      final s = _spatialFor(world, i);
      final hp = s?.hp ?? state.heroes[i].currentHp;
      final maxHp = s?.effectiveMaxHp ?? state.effectiveHeroMaxHp(state.heroes[i]);
      if (maxHp <= 0) continue;
      if (hp <= 0) {
        if (bossFight ||
            (world?.enemies.any((e) => e.hp > 0 && !e.dormant) ?? false)) {
          partyCritical = true;
          break;
        }
      }
      final threshold = bossFight ? 0.5 : 0.35;
      if (hp > 0 && hp / maxHp <= threshold) {
        partyCritical = true;
        break;
      }
    }

    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fullWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xCC14110C),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x665A5040)),
            ),
            padding: EdgeInsets.fromLTRB(
              phone ? 3 : 4,
              phone ? 3 : 4,
              phone ? 3 : 4,
              phone ? 3 : 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < state.heroes.length; i++) ...[
                  if (i > 0) SizedBox(height: phone ? 1.0 : 2.0),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onHeroTap(i),
                      onLongPress: () {
                        _bump();
                        widget.onOpenEquip();
                      },
                      borderRadius: BorderRadius.circular(3),
                      child: _PartyRow(
                        index: i,
                        hero: state.heroes[i],
                        selected: widget.selectedHeroIndex == i,
                        kitOpen: widget.selectedHeroIndex == i && _kitOpen,
                        compact: phone || compact || state.heroes.length >= 4,
                        phone: phone,
                        liveHp: () {
                          final s = _spatialFor(world, i);
                          return s?.hp ?? state.heroes[i].currentHp;
                        }(),
                        maxHp: () {
                          final s = _spatialFor(world, i);
                          return s?.effectiveMaxHp ??
                              state.effectiveHeroMaxHp(state.heroes[i]);
                        }(),
                        spatial: (widget.selectedHeroIndex == i && _kitOpen)
                            ? _spatialFor(world, i)
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canUseFlask) ...[
            SizedBox(height: phone ? 5 : 4),
            _FlaskQuickSlot(
              urgent: partyCritical,
              phone: phone,
              onTap: () {
                _bump();
                widget.onUseConsumable();
              },
            ),
          ],
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: partyCritical ? _fullOpacity : _opacity,
      duration: const Duration(milliseconds: 400),
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) {
          _fadeTimer?.cancel();
          if (_opacity < _fullOpacity) {
            setState(() => _opacity = _fullOpacity);
          }
          _scheduleFade(phone: phone);
        },
        child: SizedBox(
          width: fullWidth * _hudScale,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.bottomLeft,
            child: SizedBox(width: fullWidth, child: panel),
          ),
        ),
      ),
    );
  }
}

class _FlaskQuickSlot extends StatelessWidget {
  const _FlaskQuickSlot({
    required this.onTap,
    this.urgent = false,
    this.phone = false,
  });
  final VoidCallback onTap;
  final bool urgent;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final borderColor = urgent
        ? GameTheme.torchHot
        : GameTheme.bloodLit.withValues(alpha: 0.8);
    final semanticsLabel =
        urgent ? 'Use healing flask, party critical' : 'Use healing flask';
    return WebClickScope(
      label: semanticsLabel,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              constraints: BoxConstraints(
                minHeight: phone ? GameTheme.minTouch : 0,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: phone ? 10 : 8,
                vertical: phone ? 8 : 5,
              ),
              decoration: BoxDecoration(
                color: urgent
                    ? const Color(0xEE4A2010)
                    : const Color(0xDD2A1810),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: borderColor,
                  width: urgent ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneySprite(
                    asset: KenneyAssets.potionRed,
                    size: phone ? 18 : 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    urgent ? 'FLASK!' : 'FLASK',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: urgent ? GameTheme.torchHot : GameTheme.parchment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.index,
    required this.hero,
    required this.liveHp,
    required this.maxHp,
    this.selected = false,
    this.kitOpen = false,
    this.compact = false,
    this.phone = false,
    this.spatial,
  });

  final int index;
  final PartyHero hero;
  final int liveHp;
  final int maxHp;
  final bool selected;
  final bool kitOpen;
  final bool compact;
  final bool phone;
  final SpatialActor? spatial;

  bool _abilityBuffActive(ClassAbilityDef ability, SpatialActor s) {
    return switch (ability.id) {
      AbilityId.shieldBlock => s.shieldBlockTimer > 0,
      AbilityId.shieldWall => s.shieldWallTimer > 0,
      AbilityId.lastStand => s.lastStandTimer > 0,
      AbilityId.shieldSlam => s.queuedShieldSlam,
      AbilityId.shockwave => s.shockwaveFlash > 0,
      AbilityId.powerWordShield => s.absorbShield > 0,
      AbilityId.prayerOfMending => s.pomCharges > 0,
      AbilityId.painSuppression => s.painSuppressionTimer > 0,
      AbilityId.powerInfusion => s.powerInfusionTimer > 0,
      AbilityId.innerFire => s.innerFireActive,
      AbilityId.combustion => s.combustionTimer > 0,
      AbilityId.furyRecklessness => s.combustionTimer > 0,
      AbilityId.vendetta ||
      AbilityId.coldBlood ||
      AbilityId.arcanePower =>
        s.combustionTimer > 0,
      AbilityId.pyroblast => s.hotStreakReady,
      AbilityId.iceBlock ||
      AbilityId.arcaneIceBlock ||
      AbilityId.frostMageIceBlock =>
        s.iceBlockTimer > 0,
      AbilityId.livingBomb => s.livingBombArmed > 0,
      AbilityId.sliceAndDice => s.sliceAndDiceTimer > 0,
      AbilityId.bladeFlurry => s.bladeFlurryTimer > 0,
      AbilityId.sweepingStrikes => s.bladeFlurryTimer > 0,
      AbilityId.holyShield => s.shieldBlockTimer > 0,
      AbilityId.beaconOfLight => s.beaconTimer > 0,
      AbilityId.divineFavor => (s.buffTimers['favor'] ?? 0) > 0,
      AbilityId.sprint => s.sprintTimer > 0,
      AbilityId.vanish => s.vanishTimer > 0,
      AbilityId.killingSpree => s.killingSpreeTimer > 0,
      _ => ability.effect == AbilityEffectKind.selfBuff &&
          ((s.buffTimers['buff'] ?? 0) > 0 ||
              (s.buffTimers['shield'] ?? 0) > 0 ||
              s.powerInfusionTimer > 0 ||
              s.shieldBlockTimer > 0 ||
              s.combustionTimer > 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final frac = maxHp <= 0 ? 0.0 : (liveHp / maxHp).clamp(0.0, 1.0);
    final roleShort = hero.roleLabel.length <= 4
        ? hero.roleLabel
        : hero.roleLabel.substring(0, 3);
    final showKit = kitOpen && spatial != null && spatial!.isAlive;
    final resource =
        showKit ? spatial!.rage.clamp(0.0, 100.0).toDouble() : 0.0;
    final off = hero.itemIn(EquipmentSlot.offHand);
    final hasShield = off?.offHandKind == OffHandKind.shield;
    final abilities = showKit
        ? ClassKits.hudAbilitiesAtSpec(hero.specId, hero.level)
        : const <ClassAbilityDef>[];
    final visibleAbilities = showKit
        ? _prioritizeHudAbilities(
            abilities,
            spatial: spatial!,
            resource: resource,
            hasShield: hasShield,
            maxChips: phone ? 2 : (compact ? 3 : 4),
          )
        : const <ClassAbilityDef>[];

    final hpColor = () {
      final cb = SpatialCombat.colorblindMode;
      if (liveHp <= 0) {
        return cb ? const Color(0xFFD55E00) : GameTheme.blood;
      }
      if (frac <= 0.35) {
        return cb ? const Color(0xFFE69F00) : GameTheme.bloodLit;
      }
      return cb ? const Color(0xFF009E73) : GameTheme.clear;
    }();

    // Default: thin strip. Kit only when tapped open.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 3 : 4,
        vertical: showKit ? (phone ? 4 : 5) : (phone ? 2 : 3),
      ),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0x331C1812)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? GameTheme.torch.withValues(alpha: 0.85) : Colors.transparent,
          width: selected ? 1 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              HeroDollSprite(
                hero: hero,
                partyIndex: index,
                size: phone ? 12 : (compact ? 14 : 16),
              ),
              SizedBox(width: phone ? 4 : 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phone
                          ? roleShort
                          : (compact
                              ? '$roleShort L${hero.level}'
                              : '${hero.roleLabel}  L${hero.level}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: GameTheme.parchment,
                      ),
                    ),
                    SizedBox(height: phone ? 1 : 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: phone ? 2.5 : (compact ? 3.5 : 4.5),
                        backgroundColor: const Color(0xFF2A2218),
                        color: hpColor,
                      ),
                    ),
                    if (showKit) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            ClassKits.resourceLabelForSpec(hero.specId),
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: resource / 100,
                                minHeight: 3,
                                backgroundColor: const Color(0xFF2A1810),
                                color: Color(
                                  ClassKits.resourceColorForSpec(hero.specId),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${resource.round()}',
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                          if (hero.gearAffinity == HeroRole.rogue &&
                              spatial!.comboPoints > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'CP${spatial!.comboPoints}',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (spatial!.hotStreakReady) ...[
                            const SizedBox(width: 4),
                            Text(
                              'STREAK',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (spatial!.bladeFlurryTimer > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              hero.gearAffinity == HeroRole.rogue
                                  ? 'FLURRY'
                                  : 'SWEEP',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (spatial!.beaconTimer > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'BEACON',
                              style: GameTheme.pixel(
                                size: 6,
                                color: const Color(0xFFFFF0A8),
                              ),
                            ),
                          ],
                          if (spatial!.absorbShield > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'ABS${spatial!.absorbShield}',
                              style: GameTheme.pixel(
                                size: 6,
                                color: const Color(0xFF80C0FF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: phone ? 4 : 5),
              Text(
                phone ? '${(frac * 100).round()}' : '$liveHp',
                style: GameTheme.body(
                  size: phone ? 11 : 12,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
          if (showKit && visibleAbilities.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final ability in visibleAbilities)
                  _InlineAbilityChip(
                    ability: ability,
                    cdLeft: spatial!.abilityCd[ability.id.name] ?? 0,
                    rage: resource,
                    hasShield: hasShield,
                    activeBuff: _abilityBuffActive(ability, spatial!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Prefer active / ready chips so a 4-hero HUD stays readable.
  List<ClassAbilityDef> _prioritizeHudAbilities(
    List<ClassAbilityDef> abilities, {
    required SpatialActor spatial,
    required double resource,
    required bool hasShield,
    required int maxChips,
  }) {
    if (abilities.length <= maxChips) return abilities;
    int rank(ClassAbilityDef a) {
      if (_abilityBuffActive(a, spatial)) return 0;
      final gated = a.requiresShield && !hasShield;
      final cd = spatial.abilityCd[a.id.name] ?? 0;
      final noRage = resource + 0.001 < a.resourceCost;
      if (!gated && cd <= 0.05 && !noRage) return 1;
      if (cd > 0.05) return 2;
      return 3;
    }

    final ranked = [...abilities]..sort((a, b) {
        final cmp = rank(a).compareTo(rank(b));
        if (cmp != 0) return cmp;
        return a.shortLabel.compareTo(b.shortLabel);
      });
    return ranked.take(maxChips).toList();
  }
}

class _InlineAbilityChip extends StatelessWidget {
  const _InlineAbilityChip({
    required this.ability,
    required this.cdLeft,
    required this.rage,
    required this.hasShield,
    required this.activeBuff,
  });

  final ClassAbilityDef ability;
  final double cdLeft;
  final double rage;
  final bool hasShield;
  final bool activeBuff;

  @override
  Widget build(BuildContext context) {
    final gated = ability.requiresShield && !hasShield;
    final onCd = cdLeft > 0.05;
    final noRage = rage + 0.001 < ability.resourceCost;
    final ready = !gated && !onCd && !noRage;
    final border = activeBuff
        ? GameTheme.torchHot
        : ready
            ? GameTheme.clear
            : gated
                ? GameTheme.blood
                : GameTheme.border;
    final cdText = cdLeft < 10
        ? cdLeft.toStringAsFixed(1)
        : cdLeft.round().toString();
    final label = onCd ? '${ability.shortLabel} $cdText' : ability.shortLabel;
    return Tooltip(
      message: ability.tooltipMessage,
      waitDuration: const Duration(milliseconds: 350),
      child: Opacity(
        opacity: gated ? 0.4 : (ready || activeBuff ? 1 : 0.7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: activeBuff
                ? const Color(0xFF3A2A14)
                : const Color(0xFF221810),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: border,
              width: activeBuff || ready ? 1.2 : 1,
            ),
          ),
          child: Text(
            gated ? '${ability.shortLabel}!' : label,
            style: GameTheme.body(
              size: 13,
              color: gated
                  ? GameTheme.bloodLit
                  : onCd
                      ? GameTheme.parchmentDim
                      : GameTheme.parchment,
            ),
          ),
        ),
      ),
    );
  }
}

class _DpsMeter extends StatefulWidget {
  const _DpsMeter({required this.director});
  final GameDirector director;

  @override
  State<_DpsMeter> createState() => _DpsMeterState();
}

class _DpsMeterState extends State<_DpsMeter> {
  bool _open = false;

  static String _heroTag(SpatialActor h) {
    final specId = h.heroSpecId;
    final raw = specId != null
        ? HeroSpecs.def(specId).shortLabel
        : switch (h.heroRole) {
            HeroRole.warrior => 'WAR',
            HeroRole.healer => 'HEAL',
            HeroRole.mage => 'MAGE',
            HeroRole.rogue => 'ROG',
            null => '---',
          };
    return switch (raw) {
      'COMBAT' => 'COM',
      _ => raw.length <= 4 ? raw : raw.substring(0, 4),
    };
  }

  static SpecRoleTag? _roleTag(SpatialActor h) {
    final specId = h.heroSpecId;
    if (specId == null) return null;
    return HeroSpecs.def(specId).roleTag;
  }

  static String _compact(int n) {
    if (n >= 10000) return '${(n / 1000).round()}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static int _perSecond(int total, double elapsed) {
    final t = elapsed < 0.5 ? 0.5 : elapsed;
    return (total / t).round();
  }

  static ({int rate, String unit}) _metric(SpatialActor h, double elapsed) {
    final tag = _roleTag(h);
    if (tag == SpecRoleTag.tank) {
      return (rate: _perSecond(h.damageTaken, elapsed), unit: 'dtps');
    }
    if (tag == SpecRoleTag.healer) {
      return (rate: _perSecond(h.healingDone, elapsed), unit: 'hps');
    }
    return (rate: _perSecond(h.damageDealt, elapsed), unit: 'dps');
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.director.spatial;
    if (world == null) return const SizedBox.shrink();

    final elapsed = world.combatElapsed;
    final rows = <({String tag, String value, double bar, bool highlight})>[];
    var peak = 0;
    var peakUnit = 'dps';
    for (final h in world.heroes) {
      if (h.isPet) continue;
      final m = _metric(h, elapsed);
      if (m.rate > peak) {
        peak = m.rate;
        peakUnit = m.unit;
      }
    }
    if (peak == 0) {
      return const SizedBox.shrink();
    }
    final peakForBar = peak.clamp(1, 1 << 30);

    for (final h in world.heroes) {
      if (h.isPet) continue;
      final m = _metric(h, elapsed);
      if (m.rate < 1) continue;
      rows.add((
        tag: _heroTag(h),
        value: '${_compact(m.rate)} ${m.unit}',
        bar: m.rate / peakForBar,
        highlight: m.rate == peak,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC14110C),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x665A5040)),
      ),
      child: Text(
        _open
            ? 'METER ▴'
            : '${_compact(peak)} $peakUnit ▾',
        style: GameTheme.pixel(
          size: GameTheme.hudPixel,
          color: GameTheme.parchment,
        ),
      ),
    );

    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14110C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x665A5040)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'METER ▴',
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.parchmentDim,
              ),
            ),
            const SizedBox(height: 3),
            for (final row in rows) ...[
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      row.tag,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: row.highlight
                            ? GameTheme.torchHot
                            : GameTheme.parchment,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(size: GameTheme.hudPixel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: row.bar.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: const Color(0xFF2A241C),
                  color: row.highlight
                      ? GameTheme.torchHot
                      : GameTheme.mossLit,
                ),
              ),
              const SizedBox(height: 3),
            ],
          ],
        ),
      ),
    );

    return WebClickScope(
      label: _open ? 'Collapse party meter' : 'Expand party meter',
      onPressed: () => setState(() => _open = !_open),
      child: Semantics(
        button: true,
        label: _open ? 'Collapse party meter' : 'Expand party meter',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(3),
            child: _open ? panel : chip,
          ),
        ),
      ),
    );
  }
}

class _TargetCornerHud extends StatelessWidget {
  const _TargetCornerHud({required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final world = director.spatial;
    final state = director.state;
    SpatialActor? focus;
    if (world != null) {
      for (final e in world.enemies) {
        if (e.hp <= 0 || e.dormant) continue;
        if (e.livingBombTimer > 0) {
          focus = e;
          break;
        }
      }
      if (focus == null) {
        final leader = world.leader;
        final lx = leader?.x ?? 0;
        final ly = leader?.y ?? 0;
        double best = double.infinity;
        for (final e in world.enemies) {
          if (e.hp <= 0 || e.dormant) continue;
          final dx = e.x - lx;
          final dy = e.y - ly;
          final d = dx * dx + dy * dy;
          if (d < best) {
            best = d;
            focus = e;
          }
        }
      }
    }

    final enemy = focus;
    final awaitingExit = world?.awaitingExit == true;
    // Hide empty chrome — reclaim map until a foe / wipe / clear matters.
    if (enemy == null && !state.isPartyDefeated && !awaitingExit) {
      return const SizedBox.shrink();
    }

    final label = enemy == null
        ? (state.isPartyDefeated
            ? 'WIPED'
            : awaitingExit
                ? 'CLEAR'
                : '—')
        : enemy.name.toUpperCase();
    final role = enemy == null
        ? ''
        : switch (enemy.role) {
            EnemyRole.boss => 'BOSS',
            EnemyRole.elite => 'ELITE',
            EnemyRole.normal => '',
          };
    final hpFrac = enemy == null || enemy.maxHp <= 0
        ? 0.0
        : (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final phone = GameTheme.isPhoneWidth(context);
    // Name only — role is color/border so the chip stays one readable line.
    final titleColor = role == 'BOSS'
        ? GameTheme.bloodLit
        : (role == 'ELITE' ? GameTheme.torch : GameTheme.parchment);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: phone ? 128.0 : 148.0),
      child: Container(
        padding: EdgeInsets.fromLTRB(6, phone ? 3 : 4, 6, phone ? 4 : 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14110C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: role == 'BOSS'
                ? GameTheme.bloodLit.withValues(alpha: 0.7)
                : (role == 'ELITE'
                    ? GameTheme.torch.withValues(alpha: 0.55)
                    : const Color(0x665A5040)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (role.isNotEmpty) ...[
                  Text(
                    role == 'BOSS' ? 'B' : 'E',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: titleColor,
                    ),
                  ),
                ),
                if (enemy != null)
                  Text(
                    '${(hpFrac * 100).round()}%',
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ),
            if (enemy != null) ...[
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: hpFrac,
                  minHeight: phone ? 3 : 4,
                  backgroundColor: const Color(0xFF2A241C),
                  color: hpFrac > 0.35
                      ? GameTheme.bloodLit
                      : GameTheme.blood,
                ),
              ),
            ] else
              Text(
                state.isPartyDefeated
                    ? (state.inGauntlet ? 'End → hub' : 'Retry / Hub')
                    : 'Walk to stairs',
                style: GameTheme.body(
                  size: 11,
                  color: GameTheme.parchmentDim,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: GameTheme.stone.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: GameTheme.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KenneySprite(asset: icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GameTheme.pixel(
              size: GameTheme.hudPixel,
              color: GameTheme.torchHot,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryDock extends StatefulWidget {
  const _InventoryDock({
    required this.state,
    required this.director,
    required this.selectedId,
    required this.combineA,
    required this.combineB,
    required this.initialTab,
    required this.onTabChanged,
    required this.onSelect,
    required this.onPutCombine,
    required this.onEquip,
    required this.onSell,
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
    required this.onBindSoulbound,
    required this.onAutoSell,
    required this.onAutoDisassemble,
    required this.onCleanBag,
    required this.onOpenFilters,
    required this.onAutoMerge,
    this.flatChrome = false,
  });

  final GameState state;
  final GameDirector director;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
  final int initialTab;
  final ValueChanged<int> onTabChanged;
  final bool flatChrome;
  final void Function(String id) onSelect;
  final void Function(String id) onPutCombine;
  final VoidCallback onEquip;
  final VoidCallback onSell;
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
  final VoidCallback onBindSoulbound;
  final VoidCallback onAutoSell;
  final VoidCallback onAutoDisassemble;
  final VoidCallback onCleanBag;
  final VoidCallback onOpenFilters;
  final VoidCallback onAutoMerge;

  @override
  State<_InventoryDock> createState() => _InventoryDockState();
}

class _InventoryDockState extends State<_InventoryDock>
    with TickerProviderStateMixin {
  late final _FlexTabs _tabs;

  GameState get state => widget.state;
  String? get selectedId => widget.selectedId;
  String? get combineA => widget.combineA;
  String? get combineB => widget.combineB;
  void Function(String id) get onSelect => widget.onSelect;
  void Function(String id) get onPutCombine => widget.onPutCombine;
  VoidCallback get onEquip => widget.onEquip;
  VoidCallback get onSell => widget.onSell;
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
  VoidCallback get onBindSoulbound => widget.onBindSoulbound;
  VoidCallback get onAutoSell => widget.onAutoSell;
  VoidCallback get onAutoDisassemble => widget.onAutoDisassemble;
  VoidCallback get onCleanBag => widget.onCleanBag;
  VoidCallback get onOpenFilters => widget.onOpenFilters;
  VoidCallback get onAutoMerge => widget.onAutoMerge;

  bool _itemMatchesBagFilter(EquipmentItem item, EquipmentSlot filter) {
    return GameLogic.equipTargetsFor(item).contains(filter);
  }

  @override
  void initState() {
    super.initState();
    // GEAR / BAG always sit at 0 / 1; advanced tabs append as they unlock.
    _tabs = _FlexTabs(
      vsync: this,
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      onChanged: widget.onTabChanged,
    );
  }

  @override
  void didUpdateWidget(covariant _InventoryDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialTab.clamp(0, 4);
    if (oldWidget.initialTab != widget.initialTab && _tabs.index != next) {
      _tabs.animateTo(next);
    }
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
    final inStash = selectedId != null &&
        state.gearStash.any((g) => g.id == selectedId);
    final cap = GameLogic.maxGearStashFor(state);
    final bagSlots = List<EquipmentItem?>.generate(
      cap,
      (i) => i < state.gearStash.length ? state.gearStash[i] : null,
    );

    Widget actions() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: worn != null
                    ? KenneyButton(
                        label: 'UNEQUIP',
                        onPressed: () => onUnequip(worn.slot),
                        style: KenneyButtonStyle.grey,
                      )
                    : KenneyButton(
                        label: 'EQUIP',
                        onPressed: inStash ? onEquip : null,
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(child: _autoEquipButton()),
            ],
          ),
          const SizedBox(height: 4),
          KenneyButton(
            label: 'SELL',
            onPressed: inStash ? onSell : null,
            style: KenneyButtonStyle.grey,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final phone = GameTheme.isPhoneWidth(context) ||
            constraints.maxWidth <= 430;
        final bag = _gearInlineBag(bagSlots);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(child: sheet()),
                    ),
                    const SizedBox(height: 6),
                    actions(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: bag,
              ),
            ],
          );
        }
        // Phone: doll + actions only — bag has its own PARTY tab (readable taps).
        if (phone) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(child: sheet()),
              ),
              const SizedBox(height: 6),
              actions(),
              const SizedBox(height: 6),
              KenneyButton(
                label: 'OPEN BAG',
                onPressed: () => _tabs.animateTo(1),
                style: KenneyButtonStyle.grey,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 58,
              child: SingleChildScrollView(child: sheet()),
            ),
            const SizedBox(height: 6),
            actions(),
            const SizedBox(height: 8),
            Expanded(flex: 42, child: bag),
          ],
        );
      },
    );
  }

  /// Compact bag pane embedded in the GEAR sheet (reference: Items Bag).
  Widget _gearInlineBag(List<EquipmentItem?> slots) {
    final cap = GameLogic.maxGearStashFor(state);
    final filled = state.gearStash.length;
    final filter = bagSlotFilter;
    final filterLabel = filter == null
        ? null
        : (CharacterEquipPanel.slotLabels[filter] ?? filter.name);
    final filtered = filter == null
        ? slots
        : [
            for (final item in state.gearStash)
              if (_itemMatchesBagFilter(item, filter)) item,
          ];

    return Container(
      decoration: BoxDecoration(
        color: GameTheme.panelInset.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(GameTheme.radiusMd),
        border: Border.all(color: GameTheme.border.withValues(alpha: 0.75)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ITEMS BAG',
                  style: GameTheme.menuTitle(size: 16),
                ),
              ),
              Text(
                '$filled / $cap',
                style: GameTheme.body(
                  size: 13,
                  color: filled >= cap
                      ? GameTheme.accentWarn
                      : GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
          if (filter != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Slot: $filterLabel',
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.torchHot,
                    ),
                  ),
                ),
                KenneyButton(
                  label: 'CLEAR',
                  onPressed: onClearBagSlotFilter,
                  style: KenneyButtonStyle.grey,
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty && filter != null
                ? Center(
                    child: Text(
                      'No $filterLabel in bag',
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  )
                : GridView.builder(
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      mainAxisExtent: 56,
                    ),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final selected =
                          item != null && item.id == selectedId;
                      final hero = state.heroes.isEmpty
                          ? null
                          : state.heroes[equipHeroIndex.clamp(
                              0,
                              state.heroes.length - 1,
                            )];
                      return _BagSlot(
                        item: item,
                        state: state,
                        hero: hero,
                        highlight: selected,
                        onTap: item == null
                            ? null
                            : () => onSelect(item.id),
                        onLongPress: null,
                      );
                    },
                  ),
          ),
          if (selectedId != null) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final selected = GameLogic.findGear(state, selectedId!);
                if (selected == null) return const SizedBox.shrink();
                if (!state.gearStash.any((g) => g.id == selected.id)) {
                  return Text(
                    'Selected on hero — UNEQUIP to move to bag',
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  );
                }
                final hero = state.heroes.isEmpty
                    ? null
                    : state.heroes[equipHeroIndex.clamp(
                        0,
                        state.heroes.length - 1,
                      )];
                final cmp = hero == null
                    ? null
                    : GameLogic.compareForHero(
                        hero,
                        selected,
                        pairingStash: state.gearStash,
                      );
                final scoreLine = cmp == null || cmp.powerDelta == 0
                    ? null
                    : (cmp.isUpgrade
                        ? 'UP ${GameLogic.formatDelta(cmp.powerDelta)}'
                        : (cmp.powerDelta > 0
                            ? 'SCORE ${GameLogic.formatDelta(cmp.powerDelta)}'
                            : 'DN ${GameLogic.formatDelta(cmp.powerDelta)}'));
                // Phone GEAR: keep compare to one line so the bag grid stays usable.
                // Long-press an item for the full WoW-style tooltip sheet.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      [
                        selected.name,
                        'i${selected.effectiveItemLevel}',
                        ?scoreLine,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 12,
                        color: scoreLine != null &&
                                cmp != null &&
                                cmp.powerDelta < 0
                            ? GameTheme.bloodLit
                            : itemRarityColor(selected.rarity),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _equipHeroChipsFor(selected),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
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
            onTap: () => onEquipToHero(i),
          ),
      ],
    );
  }

  Widget _bagTab(List<EquipmentItem?> slots, EquipmentItem? primary) {
    final cap = GameLogic.maxGearStashFor(state);
    final filled = state.gearStash.length;
    final nearFull = filled >= (cap * 0.9).ceil();
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
                  color: nearFull ? GameTheme.accentWarn : GameTheme.parchmentDim,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Slot: $filterLabel'
                  '${filteredSlots.isEmpty ? ' · none in bag' : ' · ${filteredSlots.length}'}',
                  style: GameTheme.body(
                    size: 13,
                    color: GameTheme.torchHot,
                  ),
                ),
              ),
              KenneyButton(
                label: 'CLEAR',
                onPressed: onClearBagSlotFilter,
                style: KenneyButtonStyle.grey,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ] else
          Text(
            nearFull && filled >= cap
                ? 'CLEAN merges → sells gold → scraps essence'
                : 'junk→gold · scrap→essence · FILTERS set caps',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        const SizedBox(height: 6),
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
                    final phone = GameTheme.isPhoneWidth(context) ||
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
                        final inCombine = item != null &&
                            (item.id == combineA || item.id == combineB);
                        final combineFiltered = primary != null &&
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
          onPressed: state.gearStash.isEmpty ? null : onCleanBag,
          style: KenneyButtonStyle.brown,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'SELL JUNK',
                onPressed: state.gearStash.isEmpty ? null : onAutoSell,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: 'SCRAP',
                onPressed: state.gearStash.isEmpty ? null : onAutoDisassemble,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: 'FILTERS',
                onPressed: onOpenFilters,
                style: KenneyButtonStyle.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _autoEquipButton()),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: selectedId == null ? 'AUTO MERGE' : 'ADD TO MERGE',
                onPressed: selectedId != null
                    ? (GameLogic.findStashGear(state, selectedId!) == null
                        ? null
                        : () => onPutCombine(selectedId!))
                    : (state.gearStash.length < 2 ? null : onAutoMerge),
                style: KenneyButtonStyle.grey,
              ),
            ),
          ],
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
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equip on:',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
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
    required int fragmentsNeeded,
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
          MenuChrome.sectionLabel('COMBINATOR'),
          const SizedBox(height: 4),
          Text(
            'Sacrifice two bag items of the same slot for one upgraded result. Equipped gear is never used.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          if (slotLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Slot filter: $slotLabel',
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.torchHot,
              ),
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
              style: GameTheme.pixel(
                size: GameTheme.hudPixelComfort,
                color: GameTheme.parchmentDim,
              ),
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
                      : 'RESULT  ${GameLogic.rarityNames[preview.rarity]}'
                          '  i${preview.effectiveItemLevel}',
                  textAlign: TextAlign.center,
                  style: GameTheme.pixel(
                    size: GameTheme.hudPixel,
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
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.parchment,
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
            'Merges junk pairs of the same slot (skips upgrades / BiS). Uses gold.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          if (primary == null || secondary == null) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: 'OPEN BAG',
              onPressed: () => _tabs.animateTo(1),
              style: KenneyButtonStyle.grey,
            ),
          ],
          const SizedBox(height: 14),
          MenuChrome.sectionLabel('SOULBIND'),
          const SizedBox(height: 4),
          Text(
            'Lock a weapon or chest/cloak forever (3 fragments).',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          KenneyButton(
            label: 'SOULBIND  3 frag',
            onPressed:
                state.soulboundFragments >= 3 &&
                    state.heroes.any(
                      (h) =>
                          h.itemIn(EquipmentSlot.weapon) != null ||
                          h.itemIn(EquipmentSlot.chest) != null ||
                          h.itemIn(EquipmentSlot.cloak) != null,
                    )
                ? onBindSoulbound
                : null,
            style: KenneyButtonStyle.grey,
          ),
          const SizedBox(height: 4),
          Text(
            fragmentsNeeded == 0
                ? 'Have ${state.soulboundFragments} fragments'
                : 'Need $fragmentsNeeded more (have ${state.soulboundFragments})',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
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
    final fragmentsNeeded = state.soulboundFragments >= 3
        ? 0
        : 3 - state.soulboundFragments;

    final phone = GameTheme.isPhoneWidth(context);
    final alert = MenuAlerts.partyAlert(state);
    // Progressive menu: MERGE / LOADOUTS / ROSTER appear once they do something.
    final pages = <({String label, Widget body})>[
      (label: 'GEAR', body: _equipTab()),
      (label: 'BAG', body: _bagTab(slots, primary)),
      if (MenuTabs.showMerge(state))
        (
          label: 'MERGE',
          body: _toolsTab(
            primary: primary,
            secondary: secondary,
            canCombine: canCombine,
            cost: cost,
            preview: preview,
            fragmentsNeeded: fragmentsNeeded,
          ),
        ),
      if (MenuTabs.showLoadouts(state))
        (
          label: phone ? 'LOAD' : 'LOADOUTS',
          body: LoadoutsOverlay(director: widget.director),
        ),
      if (MenuTabs.showRoster(state))
        (
          label: 'ROSTER',
          body: SingleChildScrollView(
            child: TeamCompositionOverlay(director: widget.director),
          ),
        ),
    ];
    _tabs.sync(pages.length);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          tabs: [
            for (final page in pages) Tab(text: page.label),
          ],
        ),
        if (!alert.isQuiet)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              alert.reason,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs.controller,
            // Phone: no horizontal swipe between tabs (avoids mid-swipe overlap
            // and fights vertical bag scroll). Tap the tab rail instead.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final page in pages) page.body,
            ],
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
          top: BorderSide(
            color: GameTheme.borderLit.withValues(alpha: 0.4),
          ),
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
  });

  final PartyHero hero;
  final EquipmentItem candidate;
  final VoidCallback onTap;
  final List<EquipmentItem>? pairingStash;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final cmp = GameLogic.compareForHero(
      hero,
      candidate,
      pairingStash: pairingStash,
    );
    final deltaColor = cmp.powerDelta > 0
        ? GameTheme.clear
        : (cmp.powerDelta < 0 ? const Color(0xFFE07060) : GameTheme.parchmentDim);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cmp.isUpgrade
                ? const Color(0xFF2A3A1C)
                : const Color(0xFF3A2A18),
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
                    hero.roleLabel,
                    style: GameTheme.pixel(size: GameTheme.hudPixel),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 3),
                    Text(
                      'BEST',
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Score ${GameLogic.formatDelta(cmp.powerDelta)}',
                style: GameTheme.pixel(size: GameTheme.hudPixel, color: deltaColor),
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
                  style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
                ),
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
        ? const Color(0xFF5A5040)
        : _rarityBorderColor(item!.rarity);
    final isBest = item != null && _isBestStashItem(state, item!);
    final a11yLabel = item == null
        ? 'Empty bag slot'
        : '${item!.name}, item level ${item!.effectiveItemLevel}';
    final slot = Opacity(
      opacity: dimmed ? 0.25 : 1,
      child: Semantics(
        button: item != null,
        label: a11yLabel,
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
                      Color.lerp(
                        GameTheme.stoneRaised,
                        rarityColor,
                        0.18,
                      )!,
                      Color.lerp(
                        GameTheme.stoneDeep,
                        rarityColor,
                        0.1,
                      )!,
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
                    if (_isSoulboundItem(item!))
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
                        !_isSoulboundItem(item!))
                      Positioned(
                        bottom: 2,
                        right: 3,
                        child: Text(
                          _patternGlyph(item!.pattern),
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
    return ItemTooltipAnchor(
      item: item!,
      hero: hero,
      pairingStash: state.gearStash,
      child: slot,
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
        decoration: MenuChrome.cardBox(
          inset: true,
          selected: item != null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                label,
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
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
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: GameTheme.parchmentDim,
                ),
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

class _OverlayScrim extends StatelessWidget {
  const _OverlayScrim({
    required this.title,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.85,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: MenuChrome.scrim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Tap outside the sheet to dismiss.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: CaveAtmosphere.torchBloom(
                  intensity: 0.7,
                  alignment: const Alignment(0, 0.1),
                  sizeFactor: 0.85,
                ),
              ),
            ),
            // Phone product: full-width sheet (never the centered desktop card).
            _MobileSheet(
              title: title,
              onClose: onClose,
              heightFactor: heightFactor,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSheet extends StatelessWidget {
  const _MobileSheet({
    required this.title,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.85,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    // Absorb taps so scrim-dismiss behind the sheet does not fire.
    final sheet = GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: _OverlayPanel(
        title: title,
        onClose: onClose,
        margin: EdgeInsets.zero,
        borderRadius: MenuChrome.sheetRadius,
        // Full-height GEAR: skip drag handle — reclaim vertical space.
        showHandle: heightFactor < 0.99,
        child: child,
      ),
    );

    if (heightFactor >= 0.99) {
      // Phone GEAR: flush to the top of the view — no dead strip from
      // SafeArea / browser safe-area-inset. Keep a bottom home-bar pad only.
      final bottom = MediaQuery.viewPaddingOf(context).bottom;
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox.expand(child: sheet),
        ),
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          widthFactor: 1,
          child: sheet,
        ),
      ),
    );
  }
}

class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel({
    required this.title,
    required this.onClose,
    required this.child,
    this.margin = const EdgeInsets.all(16),
    this.borderRadius,
    this.showHandle,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final EdgeInsets margin;
  final BorderRadius? borderRadius;
  final bool? showHandle;

  @override
  Widget build(BuildContext context) {
    final handle = showHandle ?? borderRadius != null;
    final panel = Container(
      margin: margin,
      padding: EdgeInsets.fromLTRB(12, handle ? 6 : 6, 12, 8),
      decoration: MenuChrome.panel(borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (handle) MenuChrome.sheetHandle(),
          Row(
            children: [
              if (title.isNotEmpty)
                Expanded(
                  child: Text(
                    title,
                    style: GameTheme.menuTitle(size: 18),
                  ),
                )
              else
                const Spacer(),
              KenneyButton(
                label: 'CLOSE',
                onPressed: onClose,
                style: KenneyButtonStyle.grey,
                expanded: false,
                primary: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: GameTheme.borderLit.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
    // Mobile sheet already wraps SafeArea; avoid double bottom inset.
    if (margin == EdgeInsets.zero) return panel;
    return SafeArea(top: false, child: panel);
  }
}

/// POWER pillar — forge · sanctuary · market · essence shop.
class _PowerPillar extends StatefulWidget {
  const _PowerPillar({required this.director});
  final GameDirector director;

  @override
  State<_PowerPillar> createState() => _PowerPillarState();
}

class _PowerPillarState extends State<_PowerPillar>
    with TickerProviderStateMixin {
  late final _FlexTabs _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _FlexTabs(
      vsync: this,
      length: 2,
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    final s = d.state;
    final keepLine =
        'Keep · AL${s.ascensionLevel} · Bless ×${s.metaDepth.ascendBlessings} · '
        '${s.essence}e';
    final runLine =
        'This run · forge ATK +${s.attackBonus} · DEF +${s.defenseBonus} · '
        'STA +${s.vitalityBonus}';
    // Progressive menu: CAMP and SHOP appear once essence / Ascend exist.
    final pages = <({String label, String blurb, Widget body})>[
      (
        label: 'FORGE',
        blurb: 'Forge: gold this run (wipes) · KEEP forever · Apex mats',
        body: _ForgeOverlay(director: d),
      ),
      if (MenuTabs.showCamp(s))
        (
          label: 'CAMP',
          blurb: 'Camp: permanent essence tracks — survive Ascend',
          body: SingleChildScrollView(child: _SanctuaryOverlay(director: d)),
        ),
      (
        label: 'MARKET',
        blurb: 'Market: flasks for the run · sell stash for gold',
        body: SingleChildScrollView(child: _MarketOverlay(director: d)),
      ),
      if (MenuTabs.showShop(s))
        (
          label: 'SHOP',
          blurb: 'Shop: essence power that survives Ascend',
          body: PrestigeShopOverlay(director: d),
        ),
    ];
    _tabs.sync(pages.length);
    final alert = MenuAlerts.powerAlert(s);
    final blurb = pages[_tabs.index.clamp(0, pages.length - 1)].blurb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Column(
            children: [
              Text(
                keepLine,
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 12, color: GameTheme.torchHot),
              ),
              Text(
                runLine,
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (final page in pages) Tab(text: page.label),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          alert.isQuiet ? blurb : alert.reason,
          textAlign: TextAlign.center,
          style: GameTheme.body(
            size: 12,
            color:
                alert.isQuiet ? GameTheme.parchmentDim : GameTheme.torchHot,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          // Forge fills height and scrolls once (nested scroll hid MOVE/HASTE/CRIT).
          child: pages[_tabs.index.clamp(0, pages.length - 1)].body,
        ),
      ],
    );
  }
}

/// META pillar — keystone · contracts · beast · collection · help · settings.
class _MetaPillar extends StatefulWidget {
  const _MetaPillar({
    required this.director,
    required this.onOpenWhatsNew,
  });
  final GameDirector director;
  final VoidCallback onOpenWhatsNew;

  @override
  State<_MetaPillar> createState() => _MetaPillarState();
}

class _MetaPillarState extends State<_MetaPillar>
    with TickerProviderStateMixin {
  late final _FlexTabs _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _FlexTabs(
      vsync: this,
      length: 3,
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    final s = d.state;
    final alert = MenuAlerts.metaAlert(s);
    // Progressive menu: KEY / BEAST / CODEX appear once they mean something.
    final pages = <({String label, Widget body})>[
      if (MenuTabs.showKey(s))
        (
          label: 'KEY',
          body: SingleChildScrollView(child: ChallengeToggles(director: d)),
        ),
      (
        label: 'JOBS',
        body: SingleChildScrollView(child: _JobsOverlay(director: d)),
      ),
      if (MenuTabs.showBeast(s))
        (
          label: 'BEAST',
          body: SingleChildScrollView(child: _BeastOverlay(director: d)),
        ),
      if (MenuTabs.showCodex(s))
        (
          label: 'CODEX',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: CodexOverlay(director: d)),
              const Divider(height: 12, color: GameTheme.border),
              Expanded(child: AchievementsOverlay(director: d)),
            ],
          ),
        ),
      (
        label: 'GUIDE',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KenneyButton(
              label: MetaSystems.hasUnseenChangelog(s)
                  ? "WHAT'S NEW ★"
                  : "WHAT'S NEW",
              style: KenneyButtonStyle.grey,
              onPressed: widget.onOpenWhatsNew,
            ),
            const SizedBox(height: 8),
            const Expanded(child: GuidesOverlay()),
          ],
        ),
      ),
      (
        label: 'SET',
        body: SingleChildScrollView(
          child: _SettingsOverlay(director: d, onClose: () {}),
        ),
      ),
    ];
    _tabs.sync(pages.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (final page in pages) Tab(text: page.label),
          ],
        ),
        if (!alert.isQuiet)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              alert.reason,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: pages[_tabs.index.clamp(0, pages.length - 1)].body,
        ),
      ],
    );
  }
}

class _ForgeOverlay extends StatefulWidget {
  const _ForgeOverlay({required this.director});
  final GameDirector director;

  @override
  State<_ForgeOverlay> createState() => _ForgeOverlayState();
}

class _ForgeOverlayState extends State<_ForgeOverlay>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  GameDirector get director => widget.director;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _upgradeButton({
    required GameState state,
    required PartyUpgradeType type,
    required VoidCallback? onPressed,
  }) {
    final recommended = GameLogic.recommendedForgeUpgrade(state) == type.index;
    final cost = GameLogic.upgradeCostFor(state, type);
    final bonus = switch (type) {
      PartyUpgradeType.attack => '+${state.attackBonus}',
      PartyUpgradeType.defense => '+${state.defenseBonus}',
      PartyUpgradeType.vitality => '+${state.vitalityBonus}',
      PartyUpgradeType.moveSpeed => '+${state.moveSpeedBonus}%',
      PartyUpgradeType.attackSpeed => '+${state.attackSpeedBonus}%',
      PartyUpgradeType.crit => '+${state.critBonus}%',
    };
    final name = switch (type) {
      PartyUpgradeType.attack => 'ATK',
      PartyUpgradeType.defense => 'DEF',
      PartyUpgradeType.vitality => 'STA',
      PartyUpgradeType.moveSpeed => 'MOVE',
      PartyUpgradeType.attackSpeed => 'HASTE',
      PartyUpgradeType.crit => 'CRIT',
    };
    final costPart = onPressed != null ? '${cost}g' : 'Need ${cost}g';
    final label = recommended
        ? 'BEST · $name $bonus · $costPart'
        : '$name $bonus · $costPart';
    return KenneyButton(
      label: label,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'GOLD'),
            Tab(text: 'KEEP'),
            Tab(text: 'MATS'),
            Tab(text: 'APEX'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _tabs.index,
            children: [
              SingleChildScrollView(child: _classicForgeBody()),
              SingleChildScrollView(child: _metaForgeBody()),
              SingleChildScrollView(
                child: ApexMaterialsPanel(director: director),
              ),
              SingleChildScrollView(
                child: ApexCraftPanel(director: director),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String blurb) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabel(title),
          Text(
            blurb,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
      ),
    );
  }

  Widget _classicForgeBody() {
    final state = director.state;
    final training = GameLogic.partyTrainingCostFor(state);
    final canAscend = GameLogic.canAscend(state);
    final softcap = GameLogic.levelsUntilSoftcap(state);
    final meanLv = state.heroes.isEmpty
        ? 1
        : (state.heroes.fold<int>(0, (s, h) => s + h.level) /
                state.heroes.length)
            .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gold this run — forge upgrades wipe on Ascend. '
          'Train levels stay forever.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Text(
          'Bought: ATK +${state.attackBonus}  DEF +${state.defenseBonus}  '
          'STA +${state.vitalityBonus}  '
          'MOVE +${state.moveSpeedBonus}%  HASTE +${state.attackSpeedBonus}%  '
          'CRIT +${state.critBonus}%',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          'Party now: ATK +${state.totalAttackBonus}  DEF +${state.totalDefenseBonus}  '
          'STA +${state.totalVitalityBonus}',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _sectionTitle(
          'RUN BONUSES (GOLD)',
          'Cheapest relative gain shows BEST. All wipe when you Ascend.',
        ),
        for (final type in PartyUpgradeType.values) ...[
          _upgradeButton(
            state: state,
            type: type,
            onPressed: state.gold >= GameLogic.upgradeCostFor(state, type)
                ? () => switch (type) {
                      PartyUpgradeType.attack => director.upgradeAttack(),
                      PartyUpgradeType.defense => director.upgradeDefense(),
                      PartyUpgradeType.vitality => director.upgradeVitality(),
                      PartyUpgradeType.moveSpeed => director.upgradeMoveSpeed(),
                      PartyUpgradeType.attackSpeed =>
                        director.upgradeAttackSpeed(),
                      PartyUpgradeType.crit => director.upgradeCrit(),
                    }
                : null,
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 8),
        _sectionTitle(
          'TRAIN (LEVELS)',
          'Pays gold · +1 level to every hero · levels survive Ascend.',
        ),
        KenneyButton(
          label: state.gold >= training
              ? 'Train party +1 Lv · ${training}g'
              : 'Train · Need ${training}g',
          onPressed: state.gold >= training ? director.applyTraining : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            softcap > 0
                ? 'Avg Lv$meanLv · ~$softcap more level${softcap == 1 ? '' : 's'} to match floor'
                : 'Avg Lv$meanLv · party level matches this floor',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          canAscend
              ? (director.state.inDungeon
                  ? 'Ascend ready — return to Hub · AL${state.ascensionLevel + 1}'
                  : 'Ascend ready on Hub · AL${state.ascensionLevel + 1}')
              : 'Ascend ${state.bossVictories}/'
                  '${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} '
                  'bosses · claim on Hub (not here)',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _metaForgeBody() {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keep forever — essence spends survive Ascend. '
          'Run gold lives on the GOLD tab.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Text(
          '${state.essence} essence',
          style: GameTheme.body(size: 15, color: GameTheme.torchHot),
        ),
        Text(
          state.metaDepth.ascendBlessings <= 0
              ? 'Ascend Blessing: none yet — Ascend on Hub for permanent ATK/DEF/STA/gold'
              : 'Ascend Blessing ×${state.metaDepth.ascendBlessings}: '
                  '+${state.ascendBlessingAttackBonus} ATK · '
                  '+${state.ascendBlessingDefenseBonus} DEF · '
                  '+${state.ascendBlessingVitalityBonus} STA · '
                  '+${state.ascendBlessingGoldPercent}% gold',
          style: GameTheme.body(size: 13, color: GameTheme.mossLit),
        ),
        const SizedBox(height: 8),
        _sectionTitle(
          'RELICS',
          'Buy once · upgrade tiers · permanent party auras.',
        ),
        for (final relicId in GameLogic.relicOrder) ...[
          Builder(
            builder: (context) {
              final owned = state.hasRelic(relicId);
              final name = GameLogic.relicNames[relicId] ?? relicId;
              final cost = GameLogic.relicCosts[relicId] ?? 0;
              final tier = owned
                  ? (state.metaDepth.relicTierOf(relicId) < 1
                      ? 1
                      : state.metaDepth.relicTierOf(relicId))
                  : 0;
              final desc = switch (relicId) {
                GameLogic.warBannerRelic => owned
                    ? 'Permanent +${state.relicAttackBonus} team attack (T$tier).'
                    : 'Permanent +4 team attack per tier.',
                GameLogic.ironWardRelic => owned
                    ? 'Permanent +${state.relicDefenseBonus} team defense (T$tier).'
                    : 'Permanent +2 team defense per tier.',
                GameLogic.phoenixEmberRelic => owned
                    ? 'Permanent +${state.relicVitalityBonus} max HP per hero (T$tier).'
                    : 'Permanent +10 max HP per hero per tier.',
                GameLogic.godHandFocusRelic => owned
                    ? '+${state.relicGodHandDamageBonus} God Hand damage (T$tier).'
                    : '+3 God Hand damage per tier.',
                GameLogic.chamberLuckRelic => owned
                    ? '+${state.relicLootFindPercent}% loot find (T$tier).'
                    : '+5% loot find per tier.',
                GameLogic.ironWillRelic => owned
                    ? '+${state.relicMitigateFlat} flat mitigate (T$tier).'
                    : '+1 flat mitigate per tier.',
                _ => GameLogic.relicDescriptions[relicId] ?? '',
              };
              final nextTier = tier + 1;
              final tierCost = GameLogic.relicTierUpgradeCost(nextTier);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      KenneySprite(
                        asset: KenneyAssets.relicIconFor(relicId),
                        size: 36,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KenneyButton(
                          label: owned
                              ? '$name  ·  T$tier'
                              : '$name  ${cost}e',
                          onPressed: owned || state.essence < cost
                              ? null
                              : () => director.unlockRelic(relicId),
                          style: KenneyButtonStyle.brown,
                        ),
                      ),
                    ],
                  ),
                  if (owned && tier < 3) ...[
                    const SizedBox(height: 4),
                    KenneyButton(
                      label: 'UPGRADE TIER  T$nextTier  ${tierCost}e',
                      style: KenneyButtonStyle.grey,
                      onPressed: state.essence >= tierCost
                          ? () => director.upgradeRelicTier(relicId)
                          : null,
                    ),
                  ],
                  if (desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Text(
                        desc,
                        style: GameTheme.body(
                          size: 13,
                          color: owned
                              ? GameTheme.mossLit
                              : GameTheme.parchmentDim,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 6),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        KenneyButton(
          label: 'RESPEC RELICS  ${GameLogic.respecRelicsCost(state)}e',
          style: KenneyButtonStyle.grey,
          onPressed: (state.unlockedRelics.isNotEmpty ||
                  state.metaDepth.relicTiers.isNotEmpty) &&
                  state.essence >= GameLogic.respecRelicsCost(state)
              ? director.respecRelics
              : null,
        ),
        const Divider(height: 16, color: Color(0x665A5040)),
        _sectionTitle(
          'SOULBOUND',
          'One forever item for the whole party. Bind from a hero → TOOLS (3 fragments).',
        ),
        Text(
          'Prefer which slot BIND picks first:',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: state.metaDepth.soulboundIsArmor
                    ? 'WEAPON'
                    : 'WEAPON ✓',
                style: state.metaDepth.soulboundIsArmor
                    ? KenneyButtonStyle.grey
                    : KenneyButtonStyle.brown,
                onPressed: () => director.setSoulboundPreferArmor(false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: KenneyButton(
                label: state.metaDepth.soulboundIsArmor
                    ? 'ARMOR ✓'
                    : 'ARMOR',
                style: state.metaDepth.soulboundIsArmor
                    ? KenneyButtonStyle.brown
                    : KenneyButtonStyle.grey,
                onPressed: () => director.setSoulboundPreferArmor(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (state.soulboundItem == null)
          Text(
            'None yet. Equip a weapon or chest/cloak, open that hero → TOOLS → SOULBIND.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          )
        else ...[
          Text(
            '${state.soulboundItem!.name}\n'
            'Refine ${state.metaDepth.soulboundRefine} · each refine +1 ATK & +1 DEF',
            style: GameTheme.body(size: 14, color: GameTheme.mossLit),
          ),
          const SizedBox(height: 6),
          KenneyButton(
            label:
                'Refine +1 ATK/DEF · ${GameLogic.refineSoulboundCost(state.metaDepth.soulboundRefine)} frag',
            onPressed: state.soulboundFragments >=
                    GameLogic.refineSoulboundCost(
                      state.metaDepth.soulboundRefine,
                    )
                ? director.refineSoulbound
                : null,
          ),
        ],
        const Divider(height: 16, color: Color(0x665A5040)),
        _sectionTitle(
          'GOD HAND',
          'Tap in the dungeon to steer + burst. KEEP upgrades are soft knobs (damage, CD, style).',
        ),
        Text(
          'Lv${state.godHandLevel} · damage ${state.godHandBaseDamage} · '
          'radius ${state.godHandRadius.toStringAsFixed(1)}',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'Damage Lv${state.godHandLevel} · ${GameLogic.godHandUpgradeCost(state.godHandLevel)}e',
          onPressed: state.essence >=
                  GameLogic.godHandUpgradeCost(state.godHandLevel)
              ? director.upgradeGodHand
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.metaDepth.godHandCdLevel >= 8
              ? 'Cooldown Lv${state.metaDepth.godHandCdLevel} · MAX'
              : 'Cooldown Lv${state.metaDepth.godHandCdLevel} · '
                  '${GameLogic.godHandCdUpgradeCost(state.metaDepth.godHandCdLevel)}e',
          onPressed: state.metaDepth.godHandCdLevel >= 8
              ? null
              : (state.essence >=
                      GameLogic.godHandCdUpgradeCost(
                        state.metaDepth.godHandCdLevel,
                      )
                  ? director.upgradeGodHandCd
                  : null),
        ),
        const SizedBox(height: 8),
        Text(
          'Style: BAL = default · FOCUS = harder hits, smaller blast · WIDE = bigger blast, softer hits',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final entry in const <(int, String)>[
              (0, 'BAL'),
              (1, 'FOCUS'),
              (2, 'WIDE'),
            ]) ...[
              if (entry.$1 > 0) const SizedBox(width: 6),
              Expanded(
                child: KenneyButton(
                  label: entry.$2,
                  style: state.metaDepth.godHandStyle == entry.$1
                      ? KenneyButtonStyle.brown
                      : KenneyButtonStyle.grey,
                  onPressed: () => director.setGodHandStyle(entry.$1),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _JobsOverlay extends StatelessWidget {
  const _JobsOverlay({required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final ready = state.missions.where((m) => m.isComplete).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contracts — clear goals while you dungeon. Claim for gold + essence.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (ready > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$ready ready to claim',
              style: GameTheme.body(size: 13, color: GameTheme.mossLit),
            ),
          ),
        const SizedBox(height: 8),
        for (final mission in state.missions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: MenuChrome.listCard(
              borderColor: switch (mission.tier) {
                2 => GameTheme.bloodLit,
                1 => GameTheme.torchHot,
                _ => GameTheme.border.withValues(alpha: 0.9),
              },
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: GameTheme.body(
                          size: 16,
                          color: switch (mission.tier) {
                            2 => GameTheme.bloodLit,
                            1 => GameTheme.torchHot,
                            _ => GameTheme.parchment,
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mission.progress}/${mission.target}  '
                        '+${mission.goldReward}g +${mission.essenceReward}e',
                        style: GameTheme.body(size: 14),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                        child: LinearProgressIndicator(
                          value: mission.target <= 0
                              ? 0
                              : (mission.progress / mission.target)
                                  .clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: GameTheme.panelInset,
                          color: mission.isComplete
                              ? GameTheme.mossLit
                              : GameTheme.torchHot,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                KenneyButton(
                  label: mission.isComplete ? 'CLAIM' : 'IN PROGRESS',
                  onPressed: mission.isComplete
                      ? () => director.claimMission(mission.id)
                      : null,
                  style: KenneyButtonStyle.grey,
                  expanded: false,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SanctuaryOverlay extends StatelessWidget {
  const _SanctuaryOverlay({required this.director});
  final GameDirector director;

  int _prestigeOf(GameState state, String track) => switch (track) {
        'gold' => state.metaDepth.sanctuaryGoldPrestige,
        'power' => state.metaDepth.sanctuaryPowerPrestige,
        'vitality' => state.metaDepth.sanctuaryVitalityPrestige,
        'xp' => state.metaDepth.sanctuaryXpPrestige,
        _ => 0,
      };

  int _levelOf(GameState state, String track) => switch (track) {
        'gold' => state.sanctuaryGoldLevel,
        'power' => state.sanctuaryPowerLevel,
        'vitality' => state.sanctuaryVitalityLevel,
        'xp' => state.metaDepth.sanctuaryXpLevel,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Permanent essence tracks — survive Ascend. '
          'Upgrade forever; from Lv12 you can Prestige (reset level, keep a bonus).',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (state.metaDepth.ascendBlessings > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Ascend Blessing ×${state.metaDepth.ascendBlessings} · '
            '+${state.ascendBlessingAttackBonus} ATK · '
            '+${state.ascendBlessingDefenseBonus} DEF · '
            '+${state.ascendBlessingVitalityBonus} STA · '
            '+${state.ascendBlessingGoldPercent}% gold',
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 10),
        for (final track in <String>['gold', 'power', 'vitality', 'xp']) ...[
          Builder(
            builder: (context) {
              final level = _levelOf(state, track);
              final prestige = _prestigeOf(state, track);
              final nextLevel = level + 1;
              final cost = GameLogic.sanctuaryCost(level);
              final nextBonus = GameLogic.sanctuaryBonusLabel(
                track,
                nextLevel,
                prestige: prestige,
              );
              final currentBonus = GameLogic.sanctuaryBonusLabel(
                track,
                level,
                prestige: prestige,
              );
              final cycle = level <= 0 ? 0.0 : ((level - 1) % 12 + 1) / 12.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MenuChrome.sectionLabel(
                    GameLogic.sanctuaryNames[track] ?? track,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv$level  ·  $currentBonus'
                    '${prestige > 0 ? '  ·  Prestige $prestige' : ''}',
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  Text(
                    'Next: $nextBonus',
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.mossLit,
                    ),
                  ),
                  const SizedBox(height: 6),
                  KenneyProgressBar(
                    value: cycle.clamp(0.0, 1.0),
                    height: 12,
                    color: track == 'vitality'
                        ? KenneyBarColor.red
                        : track == 'power'
                            ? KenneyBarColor.yellow
                            : KenneyBarColor.green,
                  ),
                  const SizedBox(height: 6),
                  KenneyButton(
                    label: 'Upgrade · ${cost}e',
                    onPressed: state.essence >= cost
                        ? () => director.upgradeSanctuary(track)
                        : null,
                  ),
                  if (level >= 12) ...[
                    const SizedBox(height: 4),
                    KenneyButton(
                      label: 'Prestige reset · +${25 + level}e',
                      style: KenneyButtonStyle.brown,
                      onPressed: () =>
                          director.prestigeSanctuaryTrack(track),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SettingsOverlay extends StatefulWidget {
  const _SettingsOverlay({
    required this.director,
    required this.onClose,
  });
  final GameDirector director;
  final VoidCallback onClose;

  @override
  State<_SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<_SettingsOverlay> {
  GameDirector get director => widget.director;
  GameState get state => director.state;

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Reset game?',
        content: Text(
          'All progress will be wiped. This cannot be undone.',
          style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'RESET',
              style: GameTheme.body(size: 16, color: GameTheme.bloodLit),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await director.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsToggle(
          label: 'Mute sound',
          value: state.soundMuted,
          onChanged: director.setSoundMuted,
        ),
        const SizedBox(height: 8),
        _SettingsCycle(
          label: state.vfxQuality.settingsLabel,
          hint: state.vfxQuality.settingsHint,
          onCycle: director.cycleVfxQuality,
        ),
        const SizedBox(height: 8),
        _SettingsToggle(
          label: 'Colorblind-friendly floaters',
          value: state.colorblindMode,
          onChanged: director.setColorblindMode,
        ),
        const SizedBox(height: 12),
        Text('UI text scale', style: GameTheme.body(size: 13, color: GameTheme.parchmentDim)),
        const SizedBox(height: 6),
        Semantics(
          slider: true,
          label: 'UI text scale',
          value: '${(state.uiTextScale * 100).round()} percent',
          child: Row(
            children: [
              Expanded(
                child: _CaveSlider(
                  value: state.uiTextScale.clamp(0.85, 1.3),
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  onChanged: director.setUiTextScale,
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(state.uiTextScale * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: GameTheme.body(size: 15, color: GameTheme.parchmentDim),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MenuChrome.sectionLabel('BAG CLEANUP'),
        const SizedBox(height: 4),
        Text(
          'Near-full bag: merge → sell gold → scrap essence. '
          'BiS / upgrades are never cleaned. Bag → FILTERS opens these controls.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Text('Auto-sell (gold)', style: GameTheme.body(size: 13, color: GameTheme.parchmentDim)),
        const SizedBox(height: 6),
        _IlvlFilterRow(
          value: state.autoSellMaxPower,
          max: GameLogic.maxAutoSellIlvlCap(state),
          onChanged: director.setAutoSellMaxPower,
          offLabel: 'Off',
        ),
        const SizedBox(height: 6),
        _RarityFilterRow(
          value: state.autoSellMaxRarity,
          onChanged: director.setAutoSellMaxRarity,
          enabled: state.autoSellMaxPower > 0,
        ),
        const SizedBox(height: 12),
        Text('Auto-disassemble (essence)', style: GameTheme.body(size: 13, color: GameTheme.parchmentDim)),
        const SizedBox(height: 6),
        _IlvlFilterRow(
          value: state.autoDisassembleMaxIlvl,
          max: GameLogic.maxAutoSellIlvlCap(state),
          onChanged: director.setAutoDisassembleMaxIlvl,
          offLabel: 'Off',
        ),
        const SizedBox(height: 6),
        _RarityFilterRow(
          value: state.autoDisassembleMaxRarity,
          onChanged: director.setAutoDisassembleMaxRarity,
          enabled: state.autoDisassembleMaxIlvl > 0,
        ),
        const SizedBox(height: 8),
        Text(
          'Pickup & CLEAN BAG: sell gold first (≤iLvl + rarity), then scrap '
          'leftovers that match disassemble filters. Single-item SELL = essence. '
          'Market tap = gold.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 16),
        PlayGamesSection(director: director),
        const SizedBox(height: 16),
        SaveTransferSection(director: director),
        const SizedBox(height: 16),
        KenneyButton(
          label: MetaSystems.hasUnseenChangelog(state)
              ? "WHAT'S NEW ★"
              : "WHAT'S NEW",
          style: KenneyButtonStyle.grey,
          onPressed: () => WhatsNewOverlay.show(context, director),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          KenneyButton(
            label: director.debugTimeScale >= 9.5
                ? 'DEV: SPEED 10x (tap → 1x)'
                : 'DEV: SPEED 1x (tap → 10x)',
            style: KenneyButtonStyle.grey,
            onPressed: director.cycleDebugTimeScale,
          ),
          const SizedBox(height: 8),
          KenneyButton(
            label: 'DEV: ENTER GAUNTLET (AL10)',
            style: KenneyButtonStyle.grey,
            onPressed: state.inDungeon
                ? null
                : () {
                    widget.onClose();
                    director.devEnterGauntlet();
                  },
          ),
        ],
        const SizedBox(height: 8),
        KenneyButton(
          label: 'RESET GAME',
          style: KenneyButtonStyle.red,
          onPressed: _confirmReset,
        ),
      ],
      ),
    );
  }

}

class _IlvlFilterRow extends StatelessWidget {
  const _IlvlFilterRow({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.offLabel,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
            padding: EdgeInsets.zero,
            foregroundColor: GameTheme.parchment,
          ),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          child: Text('-', style: GameTheme.pixel(size: 10)),
        ),
        Expanded(
          child: _CaveSlider(
            value: value.toDouble().clamp(0, max.toDouble()),
            min: 0,
            max: max.toDouble(),
            divisions: max.clamp(1, 200),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
            padding: EdgeInsets.zero,
            foregroundColor: GameTheme.parchment,
          ),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          child: Text('+', style: GameTheme.pixel(size: 10)),
        ),
        SizedBox(
          width: 52,
          child: Text(
            value <= 0 ? offLabel : 'i$value',
            textAlign: TextAlign.right,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
        ),
      ],
    );
  }
}

class _RarityFilterRow extends StatelessWidget {
  const _RarityFilterRow({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = GameLogic.rarityFilterLabel(value);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          Text(
            'Max rarity',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
              padding: EdgeInsets.zero,
              foregroundColor: GameTheme.parchment,
            ),
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
            child: Text('-', style: GameTheme.pixel(size: 10)),
          ),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GameTheme.pixel(size: 7, color: GameTheme.torchHot),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(GameTheme.minTouch, GameTheme.minTouch),
              padding: EdgeInsets.zero,
              foregroundColor: GameTheme.parchment,
            ),
            onPressed:
                enabled && value < 4 ? () => onChanged(value + 1) : null,
            child: Text('+', style: GameTheme.pixel(size: 10)),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: label,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: MenuChrome.cardBox(),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: GameTheme.body(size: 16)),
              ),
              ExcludeSemantics(child: _CaveSwitch(value: value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCycle extends StatelessWidget {
  const _SettingsCycle({
    required this.label,
    required this.hint,
    required this.onCycle,
  });

  final String label;
  final String hint;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $hint. Tap to cycle',
      onTap: onCycle,
      child: InkWell(
        onTap: onCycle,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: MenuChrome.cardBox(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GameTheme.body(size: 16)),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'TAP',
                style: GameTheme.pixel(
                  size: 7,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveSwitch extends StatelessWidget {
  const _CaveSwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? GameTheme.mossLit.withValues(alpha: 0.55)
              : GameTheme.stone.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? GameTheme.torchHot : GameTheme.border,
            width: value ? 1.5 : 1,
          ),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: value ? GameTheme.torchHot : GameTheme.parchmentDim,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _CaveSlider extends StatelessWidget {
  const _CaveSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  void _setFromLocal(double localX, double width) {
    if (width <= 0) return;
    final t = (localX / width).clamp(0.0, 1.0);
    final raw = min + t * (max - min);
    final step = (max - min) / divisions;
    final snapped = (raw / step).round() * step;
    onChanged(snapped.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFromLocal(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _setFromLocal(d.localPosition.dx, w),
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: GameTheme.stone.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: GameTheme.border),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: t,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: GameTheme.torch.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: (w - 16) * t,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: GameTheme.torchHot,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: GameTheme.borderLit),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarketOverlay extends StatelessWidget {
  const _MarketOverlay({required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final flaskCost = GameLogic.marketFlaskCost(state);
    final stash = state.gearStash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gold ${_formatCount(state.gold)} · Essence ${_formatCount(state.essence)}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        Text(
          'Buy heals with gold. Tap a stash item here to sell it for gold.\n'
          'In the bag: SELL JUNK = gold · SCRAP = essence (Settings filters).',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        MenuChrome.sectionLabel('CONSUMABLES'),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= flaskCost
              ? 'Buy flask · ${flaskCost}g'
              : 'Buy flask · Need ${flaskCost}g',
          onPressed: state.gold >= flaskCost ? director.buyMarketFlask : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= flaskCost * 3
              ? 'Buy 3 flasks · ${flaskCost * 3}g'
              : 'Buy 3 flasks · Need ${flaskCost * 3}g',
          onPressed: state.gold >= flaskCost * 3
              ? () => director.buyMarketFlasks()
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= GameLogic.marketBandageCost(state)
              ? 'Buy bandage · ${GameLogic.marketBandageCost(state)}g'
              : 'Buy bandage · Need ${GameLogic.marketBandageCost(state)}g',
          onPressed: state.gold >= GameLogic.marketBandageCost(state)
              ? director.buyMarketBandage
              : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            KenneySprite(asset: KenneyAssets.potionRed, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flask: whole party (~30% HP). Bandage: lowest hero (~40% HP).',
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabel('SELL STASH (TAP = GOLD)'),
        const SizedBox(height: 6),
        if (stash.isEmpty)
          Text(
            'Bag empty. Clear rooms for gear, then sell extras here for gold.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: stash.length,
              itemBuilder: (context, i) {
                final item = stash[i];
                final gold = GameLogic.equipmentGoldValue(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                      onTap: () => director.sellGearForGold(item.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: MenuChrome.listCard(inset: true),
                        child: Row(
                          children: [
                            KenneySprite(
                              asset: KenneyAssets.equipmentIconFor(item),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: GameTheme.body(size: 14),
                              ),
                            ),
                            Text(
                              '+${gold}g',
                              style: GameTheme.body(
                                size: 14,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BeastOverlay extends StatefulWidget {
  const _BeastOverlay({required this.director});
  final GameDirector director;

  @override
  State<_BeastOverlay> createState() => _BeastOverlayState();
}

class _BeastOverlayState extends State<_BeastOverlay> {
  String? _mergeA;
  String? _mergeB;

  GameDirector get director => widget.director;
  GameState get state => director.state;

  void _toggleMerge(String petId) {
    setState(() {
      if (_mergeA == petId) {
        _mergeA = null;
        return;
      }
      if (_mergeB == petId) {
        _mergeB = null;
        return;
      }
      if (_mergeA == null) {
        _mergeA = petId;
      } else if (_mergeB == null) {
        _mergeB = petId;
      } else {
        _mergeA = _mergeB;
        _mergeB = petId;
      }
    });
  }

  void _doMerge() {
    final a = _mergeA;
    final b = _mergeB;
    if (a == null || b == null) return;
    director.mergePets(a, b);
    setState(() {
      _mergeA = null;
      _mergeB = null;
    });
  }

  PetFrame _nextFrame(PetFrame current) {
    final idx = (current.index + 1) % PetFrame.values.length;
    final next = PetFrame.values[idx == 0 ? 1 : idx];
    return next;
  }

  static String _passiveLabel(Pet pet) {
    if (pet.passive == PetPassive.attack) return '';
    final name = switch (pet.passive) {
      PetPassive.attack => 'ATK',
      PetPassive.goldFind => 'GOLD',
      PetPassive.lootFind => 'LOOT',
      PetPassive.xpFind => 'XP',
      PetPassive.mitigate => 'MIT',
      PetPassive.healBoost => 'HEAL',
    };
    final v = pet.passiveValue(dungeonId: pet.affinityDungeonId);
    return '$name${v > 0 ? ' +$v' : ''}';
  }

  static String _affinityLabel(String dungeonId) {
    if (dungeonId.isEmpty) return '';
    // Compact first word from catalog name (never invent aliases).
    final name = DungeonCatalog.byId(dungeonId).name;
    return name.replaceAll("'s", '').split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final cap = state.metaDepth.basePetRosterCap;
    final canMerge = _mergeA != null && _mergeB != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Roster ${state.ownedPets.length}/$cap',
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 16, color: GameTheme.torchHot),
        ),
        if (state.metaDepth.favoritePetSpecies.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Favorite: ${PetCatalog.byId(state.metaDepth.favoritePetSpecies)?.name ?? state.metaDepth.favoritePetSpecies}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 8),
        if (state.ownedPets.isEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: KenneySprite(asset: CustomAssets.petEgg, size: 56),
          ),
          const SizedBox(height: 10),
          Text(
            'No beasts yet',
            textAlign: TextAlign.center,
            style: GameTheme.menuTitle(size: 16, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 6),
          Text(
            'Hatch an egg with essence — companions fight beside the party '
            'and grant passives (gold, loot, mitigate…).',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Text(
            canMerge
                ? 'Tap MERGE to combine same-species pets'
                : 'Tap MERGE on two same-species pets',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          if (canMerge)
            KenneyButton(
              label: 'CONFIRM MERGE',
              style: KenneyButtonStyle.red,
              onPressed: _mergeA != null &&
                      _mergeB != null &&
                      GameLogic.canMergePets(state, _mergeA!, _mergeB!)
                  ? _doMerge
                  : null,
            ),
          const SizedBox(height: 8),
          for (final pet in state.ownedPets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: MenuChrome.listCard(
                  selected: pet.id == _mergeA ||
                      pet.id == _mergeB ||
                      state.activePet?.id == pet.id,
                  borderColor: pet.id == _mergeA || pet.id == _mergeB
                      ? GameTheme.clear
                      : state.activePet?.id == pet.id
                          ? GameTheme.torch
                          : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        KenneySprite(
                          asset: CustomAssets.petForInstanceId(pet.id),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final passive = _passiveLabel(pet);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${pet.name}  |  ${pet.rarity.name}'
                                      '${pet.frame != PetFrame.none ? '  [${pet.frame.name}]' : ''}',
                                      style: GameTheme.body(
                                        size: 15,
                                        color: GameTheme.parchment,
                                      ),
                                    ),
                                    Text(
                                      'Lv${pet.level}  ATK +${pet.totalAttackBonus}'
                                      '${passive.isEmpty ? '' : '  $passive'}'
                                      '  · aff ${_affinityLabel(pet.affinityDungeonId)}'
                                      '${pet.bondLevel > 0 ? '  bond${pet.bondLevel}' : ''}',
                                      style: GameTheme.body(
                                        size: 13,
                                        color: GameTheme.parchmentDim,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (state.activePet?.id == pet.id)
                            Text(
                              'ACTIVE',
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.torchHot,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: KenneyButton(
                              label: state.activePet?.id == pet.id
                                  ? 'ACTIVE'
                                  : 'SET ACTIVE',
                              style: KenneyButtonStyle.grey,
                              onPressed: state.activePet?.id == pet.id
                                  ? null
                                  : () => director.setActivePet(pet.id),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: KenneyButton(
                              label:
                                  'LEVEL ${GameLogic.petLevelUpCost(pet)}e',
                              onPressed: state.essence >=
                                      GameLogic.petLevelUpCost(pet)
                                  ? () => director.levelUpPet(pet.id)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: KenneyButton(
                              label: pet.id == _mergeA || pet.id == _mergeB
                                  ? 'MERGE ✓'
                                  : 'MERGE',
                              style: KenneyButtonStyle.grey,
                              onPressed: () => _toggleMerge(pet.id),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: KenneyButton(
                              label: state.metaDepth.favoritePetSpecies ==
                                      pet.resolvedSpecies
                                  ? 'FAV ✓'
                                  : 'FAVORITE',
                              style: KenneyButtonStyle.grey,
                              onPressed: () => director
                                  .setFavoritePetSpecies(pet.resolvedSpecies),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: KenneyButton(
                              label:
                                  'BOND ${GameLogic.bondPetCost(pet.bondLevel)}e',
                              style: KenneyButtonStyle.grey,
                              onPressed: state.essence >=
                                      GameLogic.bondPetCost(pet.bondLevel)
                                  ? () => director.bondPet(pet.id)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final next = _nextFrame(pet.frame);
                                final cost = GameLogic.petFrameCost(next);
                                return KenneyButton(
                                  label: pet.frame == PetFrame.crystal
                                      ? 'FRAME MAX'
                                      : 'FRAME ${next.name} ${cost}e',
                                  style: KenneyButtonStyle.grey,
                                  onPressed: pet.frame == PetFrame.crystal ||
                                          state.essence < cost
                                      ? null
                                      : () =>
                                          director.buyPetFrame(pet.id, next),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const KenneySprite(asset: CustomAssets.petEgg, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: KenneyButton(
                label: state.ownedPets.length >= cap
                    ? 'ROSTER FULL'
                    : 'HATCH ${GameLogic.hatchPetCost(state)}e',
                onPressed: state.ownedPets.length < cap &&
                        state.essence >= GameLogic.hatchPetCost(state)
                    ? director.hatchPet
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
