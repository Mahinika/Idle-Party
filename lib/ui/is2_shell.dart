import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/meta_systems.dart';
import '../models/class_ability.dart';
import '../models/dungeon_def.dart';
import '../models/dungeon_mode.dart';
import '../models/enemy.dart';
import '../models/gear_set.dart';
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

String _archetypeLabel(EnemyArchetype archetype) => switch (archetype) {
  EnemyArchetype.swarm => 'SWARM',
  EnemyArchetype.brute => 'BRUTE',
  EnemyArchetype.tank => 'TANK',
  EnemyArchetype.ranged => 'RANGED',
  EnemyArchetype.glass => 'GLASS',
  EnemyArchetype.support => 'SUPPORT',
};

bool _isSoulboundItem(EquipmentItem item) => item.id.startsWith('soulbound_');

bool _isUpgradeForAny(GameState state, EquipmentItem item) {
  for (final hero in state.heroes) {
    if (GameLogic.compareForHero(hero, item).isUpgrade) return true;
  }
  return false;
}

bool _isBestStashItem(GameState state, EquipmentItem item) {
  if (!_isUpgradeForAny(state, item)) return false;
  var bestDelta = 0;
  for (final stashItem in state.gearStash) {
    for (final hero in state.heroes) {
      final d = GameLogic.compareForHero(hero, stashItem).powerDelta;
      if (d > bestDelta) bestDelta = d;
    }
  }
  for (final hero in state.heroes) {
    final d = GameLogic.compareForHero(hero, item).powerDelta;
    if (d > 0 && d >= bestDelta) return true;
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
    final item = GameLogic.findGear(state, id);
    EquipmentSlot? into;
    if (item != null &&
        heroIndex >= 0 &&
        heroIndex < state.heroes.length) {
      into = GameLogic.compareForHero(state.heroes[heroIndex], item).intoSlot;
    }
    widget.director.equipFromStash(
      id,
      heroIndex: heroIndex,
      intoSlot: into,
    );
    setState(() {
      _equipHeroIndex = heroIndex;
      _selectedId = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _overlay = widget.initialOverlay;
    if (_overlay == Is2Overlay.inventory) {
      _inventoryTab = 1;
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
      widget.director.showToast('Merge ready — check TOOLS', life: 2.2);
    } else if (_combineA != null && _combineB == null) {
      widget.director.showToast(
        'Added to merge · pick another same-slot item',
        life: 2.4,
      );
    }
  }

  Widget _inventoryDock() {
    final d = widget.director;
    return _InventoryDock(
      state: state,
      selectedId: _selectedId,
      combineA: _combineA,
      combineB: _combineB,
      initialTab: _inventoryTab,
      onTabChanged: (i) => setState(() => _inventoryTab = i),
      onSelect: _select,
      onPutCombine: _putInCombinator,
      onEquip: () {
        if (_selectedId == null) return;
        _equipSelectedTo(_equipHeroIndex);
      },
      onSell: () {
        final id = _selectedId ?? _combineA;
        if (id == null) return;
        d.sellGear(id);
        setState(() {
          if (_selectedId == id) _selectedId = null;
          if (_combineA == id) _combineA = null;
          if (_combineB == id) _combineB = null;
        });
      },
      onUnequip: (slot) => d.unequipSlot(slot, heroIndex: _equipHeroIndex),
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
    setState(() => _inventoryTab = 1);
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
    setState(() => _overlay = overlay);
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

  List<
          ({
            String header,
            List<({String label, VoidCallback onTap, String? icon})> items,
          })>
      _moreSections() {
    final claimable = state.missions.where((m) => m.isComplete).length;
    return [
      (
        header: 'GEAR',
        items: [
          (
            label: 'FORGE',
            icon: CustomAssets.iconAxe,
            onTap: () => _openOverlay(Is2Overlay.forge),
          ),
          (
            label: 'LOADOUTS',
            icon: KenneyAssets.shield,
            onTap: () => _openOverlay(Is2Overlay.loadouts),
          ),
          (
            label: 'PARTY',
            icon: KenneyAssets.helmet,
            onTap: () => _openOverlay(Is2Overlay.teamComposition),
          ),
        ],
      ),
      (
        header: 'PROGRESS',
        items: [
          (
            label: claimable > 0 ? 'CONTRACTS ($claimable)' : 'CONTRACTS',
            icon: KenneyAssets.book,
            onTap: () => _openOverlay(Is2Overlay.jobs),
          ),
          (
            label: 'SANCTUARY',
            icon: CustomAssets.iconCampfire,
            onTap: () => _openOverlay(Is2Overlay.sanctuary),
          ),
          (
            label: 'MARKET',
            icon: KenneyAssets.coinGold,
            onTap: () => _openOverlay(Is2Overlay.market),
          ),
          (
            label: 'BEAST PEN',
            icon: CustomAssets.petEgg,
            onTap: () => _openOverlay(Is2Overlay.beast),
          ),
          (
            label: 'ESSENCE SHOP',
            icon: KenneyAssets.vialBlue,
            onTap: () => _openOverlay(Is2Overlay.prestigeShop),
          ),
        ],
      ),
      (
        header: 'INFO',
        items: [
          (
            label: MetaSystems.hasUnseenChangelog(state)
                ? "WHAT'S NEW ★"
                : "WHAT'S NEW",
            icon: CustomAssets.iconTome,
            onTap: () => WhatsNewOverlay.show(context, widget.director),
          ),
          (
            label: 'SETTINGS',
            icon: KenneyAssets.iconDoor,
            onTap: () => _openOverlay(Is2Overlay.settings),
          ),
          (
            label: 'ACHIEVEMENTS',
            icon: KenneyAssets.iconTrophy,
            onTap: () => _openOverlay(Is2Overlay.achievements),
          ),
          (
            label: 'CODEX',
            icon: KenneyAssets.book,
            onTap: () => _openOverlay(Is2Overlay.codex),
          ),
          (
            label: 'GUIDES',
            icon: KenneyAssets.iconStar,
            onTap: () => _openOverlay(Is2Overlay.guides),
          ),
        ],
      ),
    ];
  }

  void _showMoreMenu(BuildContext context) {
    // Hub meta shell already came from Hub → MORE; don't re-list the same menu.
    if (widget.hubMode) {
      widget.onLeaveDungeon?.call();
      return;
    }
    widget.director.clearToast();
    // EXIT first so RETURN TO HUB is not buried under INFO rows.
    final sections = [
      if (widget.onLeaveDungeon != null)
        (
          header: 'EXIT',
          items: [
            (
              label: 'RETURN TO HUB',
              icon: KenneyAssets.iconDoor,
              onTap: () =>
                  confirmLeaveDungeon(context, widget.onLeaveDungeon!),
            ),
          ],
        ),
      ..._moreSections(),
    ];
    MenuChrome.showMenuSheet(
      context: context,
      title: 'MORE',
      sections: sections,
    ).whenComplete(_syncCombatPause);
    widget.director.setUiPaused(true);
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
    final dockVisible = _overlay == Is2Overlay.inventory ||
        (widget.hubMode &&
            (_overlay == Is2Overlay.none ||
                _overlay == Is2Overlay.inventory));
    if (widget.hubMode &&
        _overlay != Is2Overlay.none &&
        _overlay != Is2Overlay.inventory) {
      return _BottomNavTab.none;
    }
    if (!dockVisible) return _BottomNavTab.none;
    return switch (_inventoryTab) {
      0 => _BottomNavTab.gear,
      1 => _BottomNavTab.bag,
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
                  hubClose: true,
                  active: _navActive(),
                  onGear: _openGear,
                  onBag: _openBag,
                  onMore: () => _showMoreMenu(context),
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
                          Positioned(
                            left: hudSide,
                            top: GameTheme.clusterGap / 2,
                            child: _DpsMeter(director: d),
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
                          Positioned(
                            right: hudSide,
                            bottom: GameTheme.isCompactWidth(context)
                                ? hudBottom + 118
                                : hudBottom,
                            child: _TargetCornerHud(director: d),
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
                active: _navActive(),
                onGear: _openGear,
                onBag: _openBag,
                onMore: () => _showMoreMenu(context),
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
    return _OverlayScrim(
      title: switch (_overlay) {
        Is2Overlay.forge => 'FORGE',
        Is2Overlay.jobs => 'CONTRACTS',
        Is2Overlay.sanctuary => 'SANCTUARY',
        Is2Overlay.inventory => switch (_inventoryTab) {
          0 => 'GEAR',
          1 => 'BAG',
          _ => 'TOOLS',
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
      heightFactor: shortSheet ? 0.58 : 0.85,
      onClose: _closeOverlayOrLeaveHub,
      child: switch (_overlay) {
        Is2Overlay.forge => SingleChildScrollView(
          child: _ForgeOverlay(director: d),
        ),
        Is2Overlay.jobs => SingleChildScrollView(
          child: _JobsOverlay(director: d),
        ),
        Is2Overlay.sanctuary => SingleChildScrollView(
          child: _SanctuaryOverlay(director: d),
        ),
        Is2Overlay.inventory => _inventoryDock(),
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
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
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
                "HERO'S KEEP",
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
                          '${state.hardmodeLevel > 0 ? ' HM+${state.hardmodeLevel}' : ''}'
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
                        '${state.hardmodeLevel > 0 ? '  HM+${state.hardmodeLevel}' : ''}',
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

enum _BottomNavTab { none, gear, bag, more }

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.stashCount,
    required this.active,
    required this.onGear,
    required this.onBag,
    required this.onMore,
    this.stashCap,
    this.hubClose = false,
  });

  final int stashCount;
  final int? stashCap;
  final _BottomNavTab active;
  final VoidCallback onGear;
  final VoidCallback onBag;
  final VoidCallback onMore;
  /// Hub meta shell: third tab closes back to hub instead of another MORE sheet.
  final bool hubClose;

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
      color: GameTheme.ink.withValues(alpha: 0.78),
      child: Container(
          height: GameTheme.bottomNavHeight,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x665A5040))),
          ),
          child: Row(
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
                  label: hubClose ? 'HUB' : 'MORE',
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
  });

  final String label;
  final String icon;
  final bool selected;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? GameTheme.torchHot
        : (selected ? GameTheme.torchHot : GameTheme.parchmentDim);
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: GameTheme.minTouch,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KenneySprite(asset: icon, size: 18),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GameTheme.pixel(size: GameTheme.hudPixel, color: color),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  width: selected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: GameTheme.torchHot,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  static const _fullOpacity = 1.0;
  static const _dimOpacity = 0.55;
  static const _hudScale = 1.0;

  Timer? _fadeTimer;
  double _opacity = _fullOpacity;

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
    _scheduleFade();
  }

  void _scheduleFade() {
    _fadeTimer = Timer(_idleFade, () {
      if (!mounted) return;
      setState(() => _opacity = _dimOpacity);
    });
  }

  SpatialActor? _spatialFor(SpatialWorld? world, int i) {
    if (world == null) return null;
    for (final a in world.heroes) {
      if (!a.isPet && a.assetIndex == i) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final canUseFlask = GameLogic.canUseConsumable(state);
    final compact = GameTheme.isCompactWidth(context);
    final fullWidth = compact ? 196.0 : 240.0;
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
        // Downed ally mid-fight — flask urgency.
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
          for (var i = 0; i < state.heroes.length; i++) ...[
            if (i > 0) SizedBox(height: state.heroes.length >= 4 ? 2.0 : 3.0),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _bump();
                  widget.onSelectHero(i);
                },
                onLongPress: () {
                  _bump();
                  widget.onOpenEquip();
                },
                borderRadius: BorderRadius.circular(4),
                child: _PartyRow(
                  index: i,
                  hero: state.heroes[i],
                  selected: widget.selectedHeroIndex == i,
                  compact: compact || state.heroes.length >= 4,
                  liveHp: () {
                    final s = _spatialFor(world, i);
                    return s?.hp ?? state.heroes[i].currentHp;
                  }(),
                  maxHp: () {
                    final s = _spatialFor(world, i);
                    return s?.effectiveMaxHp ??
                        state.effectiveHeroMaxHp(state.heroes[i]);
                  }(),
                  spatial: widget.selectedHeroIndex == i
                      ? _spatialFor(world, i)
                      : null,
                ),
              ),
            ),
          ],
          if (canUseFlask) ...[
            const SizedBox(height: 4),
            _FlaskQuickSlot(
              urgent: partyCritical,
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
        onPointerDown: (_) => _bump(),
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
  const _FlaskQuickSlot({required this.onTap, this.urgent = false});
  final VoidCallback onTap;
  final bool urgent;

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                  KenneySprite(asset: KenneyAssets.potionRed, size: 16),
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
    this.compact = false,
    this.spatial,
  });

  final int index;
  final PartyHero hero;
  final int liveHp;
  final int maxHp;
  final bool selected;
  final bool compact;
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
      AbilityId.iceBlock => s.iceBlockTimer > 0,
      AbilityId.livingBomb => s.livingBombArmed > 0,
      AbilityId.sliceAndDice => s.sliceAndDiceTimer > 0,
      AbilityId.bladeFlurry => s.bladeFlurryTimer > 0,
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
    final showKit = selected && spatial != null && spatial!.isAlive;
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
            maxChips: compact ? 3 : 4,
          )
        : const <ClassAbilityDef>[];

    return Container(
      constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
      padding: EdgeInsets.fromLTRB(4, compact ? 3 : 5, 6, compact ? 3 : 5),
      decoration: BoxDecoration(
        color: const Color(0xDD14110C),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? GameTheme.torch : const Color(0x665A5040),
          width: selected ? 1.5 : 1,
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
                size: compact ? 16 : 18,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact
                          ? '$roleShort L${hero.level}'
                          : '${hero.roleLabel}  L${hero.level}',
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: GameTheme.parchment,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: compact ? 4 : 5,
                        backgroundColor: const Color(0xFF2A2218),
                        color: () {
                          final cb = SpatialCombat.colorblindMode;
                          if (liveHp <= 0) {
                            return cb
                                ? const Color(0xFFD55E00)
                                : GameTheme.blood;
                          }
                          if (frac <= 0.35) {
                            return cb
                                ? const Color(0xFFE69F00)
                                : GameTheme.bloodLit;
                          }
                          return cb
                              ? const Color(0xFF009E73)
                              : GameTheme.clear;
                        }(),
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
                                minHeight: 4,
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
                    ] else if (!compact) ...[
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: GameLogic.xpPoolForLevel(hero.level) <= 0
                              ? 0
                              : (hero.xp /
                                      GameLogic.xpPoolForLevel(hero.level))
                                  .clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: const Color(0xFF2A2218),
                          color: GameTheme.torch,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$liveHp',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
            ],
          ),
          if (showKit && visibleAbilities.isNotEmpty) ...[
            const SizedBox(height: 4),
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

class _DpsMeter extends StatelessWidget {
  const _DpsMeter({required this.director});
  final GameDirector director;

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
    // Keep meter tags one line on phone HUD.
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

  /// Rate from cumulative total over fight time (min 0.5s avoids startup spikes).
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
    // Meter is HUD chrome — keep visible under Lite/Minimal VFX.
    final world = director.spatial;
    if (world == null) return const SizedBox.shrink();

    final elapsed = world.combatElapsed;
    final rows = <({String tag, String value, double bar, bool highlight})>[];
    var peak = 0;
    for (final h in world.heroes) {
      if (h.isPet) continue;
      final m = _metric(h, elapsed);
      if (m.rate > peak) peak = m.rate;
    }
    if (peak == 0) {
      return const SizedBox.shrink();
    }
    peak = peak.clamp(1, 1 << 30);

    for (final h in world.heroes) {
      if (h.isPet) continue;
      final m = _metric(h, elapsed);
      if (m.rate < 1) continue;
      rows.add((
        tag: _heroTag(h),
        value: '${_compact(m.rate)} ${m.unit}',
        bar: m.rate / peak,
        highlight: m.rate == peak,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Semantics(
        label: 'Party combat meter',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
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
                  'PARTY',
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
                        width: 44,
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
      // Prefer Living Bomb target (matches the orange map ring), then nearest.
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
    final label = enemy == null
        ? (state.isPartyDefeated
            ? 'WIPED'
            : awaitingExit
                ? 'FLOOR CLEAR'
                : 'NO TARGET')
        : enemy.name.toUpperCase();
    final role = enemy == null
        ? ''
        : switch (enemy.role) {
            EnemyRole.boss => 'BOSS',
            EnemyRole.elite => 'ELITE',
            EnemyRole.normal => 'NORMAL',
          };
    final hpFrac = enemy == null || enemy.maxHp <= 0
        ? 0.0
        : (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final archetype = enemy == null ? '' : _archetypeLabel(enemy.archetype);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: GameTheme.isCompactWidth(context) ? 168 : 188,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
        decoration: BoxDecoration(
          color: const Color(0xDD14110C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x665A5040)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.pixel(size: GameTheme.hudPixel),
            ),
            if (role.isNotEmpty || archetype.isNotEmpty)
              Text(
                [
                  if (role.isNotEmpty) role,
                  if (archetype.isNotEmpty) archetype,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: role == 'BOSS'
                      ? GameTheme.bloodLit
                      : (role == 'ELITE'
                            ? GameTheme.torch
                            : GameTheme.parchmentDim),
                ),
              ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: hpFrac,
                minHeight: 5,
                backgroundColor: const Color(0xFF2A241C),
                color: hpFrac > 0.35
                    ? GameTheme.bloodLit
                    : GameTheme.blood,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              enemy == null
                  ? (state.isPartyDefeated
                        ? (state.inGauntlet
                            ? 'End run → hub'
                            : 'Open Retry / Hub')
                        : awaitingExit
                            ? 'Walk to the stairs'
                            : 'Seek a foe')
                  : '${(hpFrac * 100).round()}% HP  ATK ${enemy.attack}',
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
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
  });

  final GameState state;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
  final int initialTab;
  final ValueChanged<int> onTabChanged;
  final void Function(String id) onSelect;
  final void Function(String id) onPutCombine;
  final VoidCallback onEquip;
  final VoidCallback onSell;
  final void Function(EquipmentSlot slot) onUnequip;
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
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  GameState get state => widget.state;
  String? get selectedId => widget.selectedId;
  String? get combineA => widget.combineA;
  String? get combineB => widget.combineB;
  void Function(String id) get onSelect => widget.onSelect;
  void Function(String id) get onPutCombine => widget.onPutCombine;
  VoidCallback get onEquip => widget.onEquip;
  VoidCallback get onSell => widget.onSell;
  void Function(EquipmentSlot slot) get onUnequip => widget.onUnequip;
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        widget.onTabChanged(_tabs.index);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InventoryDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialTab.clamp(0, 2);
    if (oldWidget.initialTab != widget.initialTab && _tabs.index != next) {
      _tabs.animateTo(next);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  EquipmentItem? _find(String? id) {
    if (id == null) return null;
    return GameLogic.findGear(state, id);
  }

  Widget _equipTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: CharacterEquipPanel(
              state: state,
              heroIndex: equipHeroIndex,
              onSelectHero: onEquipHeroChanged,
              selectedItemId: selectedId,
              onSelectItem: onSelect,
              onUnequip: onUnequip,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'EQUIP',
                onPressed: selectedId == null ? null : onEquip,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: 'AUTO EQUIP',
                onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
                style: KenneyButtonStyle.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        KenneyButton(
          label: 'SELL',
          onPressed: selectedId == null && combineA == null ? null : onSell,
          style: KenneyButtonStyle.grey,
        ),
      ],
    );
  }

  Widget _bagTab(List<EquipmentItem?> slots, EquipmentItem? primary) {
    final cap = GameLogic.maxGearStashFor(state);
    final filled = state.gearStash.length;
    final nearFull = filled >= (cap * 0.9).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          nearFull && filled >= cap
              ? 'FULL $filled/$cap · CLEAN merges → sells gold → scraps'
              : nearFull
                  ? '$filled/$cap nearly full · CLEAN uses Settings filters'
                  : '$filled/$cap · junk→gold · scrap→essence · FILTERS for caps',
          style: GameTheme.pixel(
            size: GameTheme.hudPixel,
            color: nearFull ? GameTheme.torchHot : GameTheme.parchment,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            itemCount: slots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              mainAxisExtent: 56,
            ),
            itemBuilder: (context, index) {
              final item = slots[index];
              final selected = item != null && item.id == selectedId;
              final inCombine =
                  item != null && (item.id == combineA || item.id == combineB);
              final combineFiltered =
                  primary != null && item != null && item.slot != primary.slot;
              return _BagSlot(
                item: item,
                state: state,
                highlight: selected || inCombine,
                dimmed: combineFiltered,
                onTap: item == null || combineFiltered
                    ? null
                    : () => onSelect(item.id),
                onLongPress: item == null || combineFiltered
                    ? null
                    : () => onPutCombine(item.id),
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
            Expanded(
              child: KenneyButton(
                label: 'AUTO EQUIP',
                onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: selectedId == null ? 'AUTO MERGE' : 'ADD TO MERGE',
                onPressed: selectedId != null
                    ? () => onPutCombine(selectedId!)
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
                    selected.statsLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  if (selected.setId != null && selected.setId!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      () {
                        final best = state.heroes
                            .map(
                              (h) => (
                                h,
                                GearSets.wornCount(h.equipped, selected.setId!),
                              ),
                            )
                            .reduce((a, b) => a.$2 >= b.$2 ? a : b);
                        final n = best.$2;
                        final label = selected.setLabel;
                        if (n <= 0) return '$label · 0/4';
                        final bonus = n >= 4
                            ? '4pc active'
                            : (n >= 2 ? '2pc active' : 'set');
                        return '$label · $n/4 · $bonus';
                      }(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                  if (_isSoulboundItem(selected)) ...[
                    const SizedBox(height: 2),
                    Text(
                      'BOUND FOREVER',
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Equip on:',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Builder(
                    builder: (context) {
                      var bestIndex = -1;
                      var bestDelta = 0;
                      for (var i = 0; i < state.heroes.length; i++) {
                        final delta = GameLogic.compareForHero(
                          state.heroes[i],
                          selected,
                        ).powerDelta;
                        if (delta > 0 && delta > bestDelta) {
                          bestDelta = delta;
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
                              isBest: i == bestIndex,
                              onTap: () => onEquipToHero(i),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ] else
          Text(
            'Tap item to equip · long-press / ADD TO MERGE for TOOLS.',
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
        return 'Load two same-slot items from BAG (ADD TO MERGE or long-press).';
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
          Text('COMBINATOR', style: GameTheme.pixel(size: GameTheme.hudPixel)),
          const SizedBox(height: 4),
          Text(
            'Sacrifice two items of the same slot for one upgraded result.',
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
          Text('SOULBIND', style: GameTheme.pixel(size: GameTheme.hudPixel)),
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
            'Flask: party HUD · Pets: MORE → Beast Pen · God Hand: Forge',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = _find(combineA);
    final secondary = _find(combineB);
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.panel.withValues(alpha: 0.82),
            GameTheme.stoneDeep.withValues(alpha: 0.88),
          ],
        ),
        border: Border(
          top: BorderSide(color: GameTheme.borderLit.withValues(alpha: 0.85), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: GameTheme.torch.withValues(alpha: 0.08),
            blurRadius: 0,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: GameTheme.stone.withValues(alpha: 0.55),
            child: TabBar(
              controller: _tabs,
              labelStyle: GameTheme.pixel(size: GameTheme.hudPixel),
              unselectedLabelStyle:
                  GameTheme.pixel(size: GameTheme.hudPixel),
              indicatorColor: GameTheme.torchHot,
              labelColor: GameTheme.torchHot,
              unselectedLabelColor: GameTheme.parchmentDim,
              dividerColor: GameTheme.border.withValues(alpha: 0.5),
              tabs: const [
                Tab(text: 'GEAR'),
                Tab(text: 'BAG'),
                Tab(text: 'TOOLS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _equipTab(),
                _bagTab(slots, primary),
                _toolsTab(
                  primary: primary,
                  secondary: secondary,
                  canCombine: canCombine,
                  cost: cost,
                  preview: preview,
                  fragmentsNeeded: fragmentsNeeded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipHeroChip extends StatelessWidget {
  const _EquipHeroChip({
    required this.hero,
    required this.candidate,
    required this.onTap,
    this.isBest = false,
  });

  final PartyHero hero;
  final EquipmentItem candidate;
  final VoidCallback onTap;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final cmp = GameLogic.compareForHero(hero, candidate);
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
                  'raw A${GameLogic.formatDelta(cmp.atkDelta)} '
                  'D${GameLogic.formatDelta(cmp.defDelta)} '
                  'V${GameLogic.formatDelta(cmp.vitDelta)}',
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
    this.dimmed = false,
    this.onTap,
    this.onLongPress,
  });

  final EquipmentItem? item;
  final GameState state;
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
    return Opacity(
      opacity: dimmed ? 0.25 : 1,
      child: Semantics(
        button: item != null,
        label: a11yLabel,
        excludeSemantics: true,
        child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: MenuChrome.cardBox(selected: highlight).copyWith(
            border: Border.all(
              color: highlight ? GameTheme.torchHot : rarityColor,
              width: item != null ? 1.5 : 1,
            ),
            color: item == null
                ? null
                : Color.lerp(
                    const Color(0xFF1A1612),
                    rarityColor,
                    0.12,
                  ),
          ),
          clipBehavior: Clip.hardEdge,
          child: item == null
              ? const SizedBox.expand()
              : Stack(
                  fit: StackFit.expand,
                  children: [
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
                      top: 1,
                      left: 2,
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
                      bottom: 1,
                      left: 2,
                      child: ExcludeSemantics(
                        child: Text(
                          'i${item!.effectiveItemLevel}',
                          style: GameTheme.body(
                            size: 11,
                            color: GameTheme.parchment,
                          ),
                        ),
                      ),
                    ),
                    if (isBest)
                      Positioned(
                        top: 1,
                        right: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 0,
                          ),
                          color: const Color(0xDD2A5018),
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
                        bottom: 1,
                        right: 2,
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
                        bottom: 1,
                        right: 2,
                        child: Text(
                          _patternGlyph(item!.pattern),
                          style: GameTheme.pixel(
                            size: 4,
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
    final compact = GameTheme.isCompactWidth(context);
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
            compact
                ? _MobileSheet(
                    title: title,
                    onClose: onClose,
                    heightFactor: heightFactor,
                    child: child,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        maxHeight: heightFactor < 0.7 ? 420 : 560,
                      ),
                      child: SizedBox(
                        width: 520,
                        height: heightFactor < 0.7 ? 420 : 560,
                        child: _OverlayPanel(
                          title: title,
                          onClose: onClose,
                          child: child,
                        ),
                      ),
                    ),
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
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        widthFactor: 1,
        // Absorb taps so scrim-dismiss behind the sheet does not fire.
        child: GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: _OverlayPanel(
            title: title,
            onClose: onClose,
            margin: EdgeInsets.zero,
            borderRadius: MenuChrome.sheetRadius,
            child: child,
          ),
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
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final EdgeInsets margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final showHandle = borderRadius != null;
    return SafeArea(
      top: false,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: MenuChrome.panel(borderRadius: borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) MenuChrome.sheetHandle(),
            Row(
              children: [
                if (title.isNotEmpty)
                  Expanded(
                    child: Text(
                      title,
                      style: GameTheme.pixel(size: GameTheme.hudPixelComfort),
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
            const SizedBox(height: 10),
            Expanded(child: child),
          ],
        ),
      ),
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
      PartyUpgradeType.attack => 'Attack',
      PartyUpgradeType.defense => 'Defense',
      PartyUpgradeType.vitality => 'Vitality',
      PartyUpgradeType.moveSpeed => 'Move',
      PartyUpgradeType.attackSpeed => 'Haste',
      PartyUpgradeType.crit => 'Crit',
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
        Material(
          color: GameTheme.stone.withValues(alpha: 0.55),
          child: TabBar(
            controller: _tabs,
            onTap: (_) => setState(() {}),
            labelStyle: GameTheme.pixel(size: GameTheme.hudPixel),
            unselectedLabelStyle: GameTheme.pixel(size: GameTheme.hudPixel),
            indicatorColor: GameTheme.torchHot,
            labelColor: GameTheme.torchHot,
            unselectedLabelColor: GameTheme.parchmentDim,
            dividerColor: GameTheme.border.withValues(alpha: 0.5),
            tabs: const [
              Tab(text: 'FORGE'),
              Tab(text: 'META'),
              Tab(text: 'MATS'),
              Tab(text: 'APEX'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 560,
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
          Text(title, style: GameTheme.pixel(size: 8)),
          const SizedBox(height: 2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gold upgrades this run (wipe on Ascend). Essence spends → META.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Text(
          'ATK +${state.totalAttackBonus}  DEF +${state.totalDefenseBonus}  '
          'VIT +${state.totalVitalityBonus}\n'
          'MOVE +${state.moveSpeedBonus}%  HASTE +${state.attackSpeedBonus}%  '
          'CRIT +${state.critBonus}%',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        const SizedBox(height: 6),
        Text(
          canAscend
              ? (director.state.inDungeon
                  ? 'Ascend ready on Hub · AL${state.ascensionLevel + 1}'
                  : 'Ascend ready · AL${state.ascensionLevel + 1}')
              : (director.state.inDungeon
                  ? 'Ascend on Hub · '
                      '${state.bossVictories}/${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} bosses'
                  : 'Ascend ${state.bossVictories}/${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} bosses · keep clearing'),
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _sectionTitle(
          'GOLD UPGRADES',
          'Infinite · wipe on Ascend. BEST = cheapest relative gain.',
        ),
        KenneyButton(
          label: state.gold >= training
              ? 'Train $training g'
              : 'Need $training g',
          onPressed: state.gold >= training ? director.applyTraining : null,
        ),
        if (softcap > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Train: need ~$softcap level${softcap == 1 ? '' : 's'} to match floor',
              style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
            ),
          ),
        const SizedBox(height: 6),
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
      ],
    );
  }

  Widget _metaForgeBody() {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.essence} essence · permanent (survives Ascend)',
          style: GameTheme.body(size: 14, color: GameTheme.torchHot),
        ),
        Text(
          'Relics · Soulbound · God Hand. Run gold stays on FORGE tab.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _sectionTitle(
          'RELICS',
          'Permanent party auras.',
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
                    ? 'Permanent +${state.relicAttackBonus} team attack aura (T$tier).'
                    : 'Permanent +4 team attack aura per tier.',
                GameLogic.ironWardRelic => owned
                    ? 'Permanent +${state.relicDefenseBonus} team defense aura (T$tier).'
                    : 'Permanent +2 team defense aura per tier.',
                GameLogic.phoenixEmberRelic => owned
                    ? 'Permanent +${state.relicVitalityBonus} max HP for every hero (T$tier).'
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
          'Bind one weapon or armor from bag TOOLS · survives Ascend. '
              'Prefer picks the slot when you tap BIND on a hero.',
        ),
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
            'No soulbound yet. Open a hero → TOOLS → BIND (3 fragments). '
            'Preference: ${state.metaDepth.soulboundIsArmor ? 'armor' : 'weapon'}.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          )
        else ...[
          Text(
            '${state.soulboundItem!.name}  ·  refine '
            '${state.metaDepth.soulboundRefine}',
            style: GameTheme.body(size: 14, color: GameTheme.mossLit),
          ),
          const SizedBox(height: 6),
          KenneyButton(
            label:
                'REFINE  ${GameLogic.refineSoulboundCost(state.metaDepth.soulboundRefine)} frag',
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
          'Essence · tap AOE in dungeon. Survives Ascend.',
        ),
        Text(
          'Lv${state.godHandLevel}  AOE ${state.godHandBaseDamage}  '
          'r${state.godHandRadius.toStringAsFixed(1)}',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'POWER Lv${state.godHandLevel}  ${GameLogic.godHandUpgradeCost(state.godHandLevel)}e',
          onPressed: state.essence >=
                  GameLogic.godHandUpgradeCost(state.godHandLevel)
              ? director.upgradeGodHand
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.metaDepth.godHandCdLevel >= 8
              ? 'CD Lv${state.metaDepth.godHandCdLevel}  MAX'
              : 'CD Lv${state.metaDepth.godHandCdLevel}  '
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
          'Style · BAL / FOCUS / WIDE (tip: God Hand styles)',
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
    return Column(
      children: [
        for (final mission in state.missions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GameTheme.menuCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: switch (mission.tier) {
                  2 => GameTheme.bloodLit,
                  1 => GameTheme.torchHot,
                  _ => const Color(0xFF595033),
                },
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: GameTheme.pixel(
                          size: 8,
                          color: switch (mission.tier) {
                            2 => GameTheme.bloodLit,
                            1 => GameTheme.torchHot,
                            _ => GameTheme.torchHot,
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
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: mission.target <= 0
                              ? 0
                              : (mission.progress / mission.target)
                                  .clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFF5A5040),
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
          'Permanent essence tracks (infinite · survive Ascend). '
          'From Lv12 you can prestige a track for bonus.',
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
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
                  Text(
                    GameLogic.sanctuaryNames[track] ?? track,
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: GameTheme.torchHot,
                    ),
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
                    'Next $nextBonus',
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
                    label: 'UPGRADE  ${cost}e',
                    onPressed: state.essence >= cost
                        ? () => director.upgradeSanctuary(track)
                        : null,
                  ),
                  if (level >= 12) ...[
                    const SizedBox(height: 4),
                    KenneyButton(
                      label: 'PRESTIGE RESET  +${25 + level}e',
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
        Text('UI text scale', style: GameTheme.pixel(size: 7)),
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
        Text('BAG CLEANUP', style: GameTheme.pixel(size: 8)),
        const SizedBox(height: 4),
        Text(
          'Near-full bag: merge → sell gold → scrap essence. '
          'BiS / upgrades are never cleaned. Bag → FILTERS opens these controls.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Text('Auto-sell (gold)', style: GameTheme.pixel(size: 7)),
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
        Text('Auto-disassemble (essence)', style: GameTheme.pixel(size: 7)),
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
          'Gold ${_formatCount(state.gold)} / Essence ${_formatCount(state.essence)}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        Text(
          'Flasks for gold · tap stash to sell for gold. '
          'Bag SELL JUNK = gold · SCRAP = essence (Settings filters).',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        KenneyButton(
          label: state.gold >= flaskCost
              ? 'BUY FLASK  ${flaskCost}g'
              : 'BUY FLASK  ${flaskCost}g · need gold',
          onPressed: state.gold >= flaskCost ? director.buyMarketFlask : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= flaskCost * 3
              ? 'BUY 3 FLASKS  ${flaskCost * 3}g'
              : 'BUY 3 FLASKS  ${flaskCost * 3}g · need gold',
          onPressed: state.gold >= flaskCost * 3
              ? () => director.buyMarketFlasks()
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= GameLogic.marketBandageCost(state)
              ? 'BUY BANDAGE  ${GameLogic.marketBandageCost(state)}g'
              : 'BUY BANDAGE  ${GameLogic.marketBandageCost(state)}g · need gold',
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
        Text(
          'SELL STASH (tap for gold)',
          style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        if (stash.isEmpty)
          Text(
            'Bag is empty. Clear rooms for gear. Sell here for gold, or SELL JUNK in the bag for essence.',
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
                    color: GameTheme.menuCard,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => director.sellGearForGold(item.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
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
                              style: GameTheme.pixel(
                                size: 6,
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
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
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
            style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
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
              child: Material(
                color: GameTheme.menuCard,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: pet.id == _mergeA || pet.id == _mergeB
                          ? GameTheme.clear
                          : state.activePet?.id == pet.id
                              ? GameTheme.torch
                              : const Color(0xFF595033),
                    ),
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
                                      style: GameTheme.pixel(size: 8),
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
                              style: GameTheme.pixel(
                                size: 5,
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
