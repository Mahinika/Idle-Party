import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/class_ability.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/pet.dart';
import '../spatial/spatial_combat.dart';
import 'confirm_dialogs.dart';
import 'character_equip_panel.dart';
import 'cave_atmosphere.dart';
import 'custom_assets.dart';
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
  equip,
  settings,
  market,
  beast,
  achievements,
  codex,
  loadouts,
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
  String? _petMergeA;
  String? _petMergeB;

  GameState get state => widget.director.state;

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
    });
  }

  Widget _inventoryDock() {
    final d = widget.director;
    return _InventoryDock(
      state: state,
      selectedId: _selectedId,
      combineA: _combineA,
      combineB: _combineB,
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
      onHatchPet: d.hatchPet,
      onSetPet: d.setActivePet,
      onLevelUpPet: (id) {
        d.levelUpPet(id);
      },
      onTogglePetMerge: (id) {
        setState(() {
          if (_petMergeA == id) {
            _petMergeA = null;
            return;
          }
          if (_petMergeB == id) {
            _petMergeB = null;
            return;
          }
          if (_petMergeA == null) {
            _petMergeA = id;
          } else if (_petMergeB == null) {
            _petMergeB = id;
          } else {
            _petMergeA = _petMergeB;
            _petMergeB = id;
          }
        });
      },
      petMergeA: _petMergeA,
      petMergeB: _petMergeB,
      onConfirmPetMerge: () {
        if (_petMergeA == null || _petMergeB == null) return;
        d.mergePets(_petMergeA!, _petMergeB!);
        setState(() {
          _petMergeA = null;
          _petMergeB = null;
        });
      },
      onFavoritePet: (species) => d.setFavoritePetSpecies(species),
      onBondPet: d.bondPet,
      onBuyPetFrame: (id, frame) => d.buyPetFrame(id, frame),
      onUseConsumable: () => d.useConsumable(heroIndex: _equipHeroIndex),
      onBindSoulbound: () => d.bindSoulbound(heroIndex: _equipHeroIndex),
      onUpgradeGodHand: d.upgradeGodHand,
      onAutoSell: d.autoSellJunk,
    );
  }

  void _openBag() => setState(
        () => _overlay = _overlay == Is2Overlay.inventory
            ? Is2Overlay.none
            : Is2Overlay.inventory,
      );
  void _openEquip() => setState(
        () => _overlay = _overlay == Is2Overlay.equip
            ? Is2Overlay.none
            : Is2Overlay.equip,
      );
  void _openOverlay(Is2Overlay overlay) => setState(() => _overlay = overlay);

  void _showMoreMenu(BuildContext context) {
    final claimable = state.missions.where((m) => m.isComplete).length;
    final items = <({String label, VoidCallback onTap})>[
      (
        label: 'FORGE',
        onTap: () => _openOverlay(Is2Overlay.forge),
      ),
      (
        label: claimable > 0 ? 'JOBS ($claimable)' : 'JOBS',
        onTap: () => _openOverlay(Is2Overlay.jobs),
      ),
      (
        label: 'SANCTUARY',
        onTap: () => _openOverlay(Is2Overlay.sanctuary),
      ),
      (
        label: 'MARKET',
        onTap: () => _openOverlay(Is2Overlay.market),
      ),
      (
        label: 'BEAST PEN',
        onTap: () => _openOverlay(Is2Overlay.beast),
      ),
      (
        label: 'PRESTIGE SHOP',
        onTap: () => _openOverlay(Is2Overlay.prestigeShop),
      ),
      (
        label: 'LOADOUTS',
        onTap: () => _openOverlay(Is2Overlay.loadouts),
      ),
      (
        label: 'ACHIEVEMENTS',
        onTap: () => _openOverlay(Is2Overlay.achievements),
      ),
      (
        label: 'CODEX',
        onTap: () => _openOverlay(Is2Overlay.codex),
      ),
      (
        label: 'GUIDES',
        onTap: () => _openOverlay(Is2Overlay.guides),
      ),
      (
        label: 'SETTINGS',
        onTap: () => _openOverlay(Is2Overlay.settings),
      ),
      if (widget.onLeaveDungeon != null)
        (
          label: 'RETURN TO HUB',
          onTap: () => confirmLeaveDungeon(context, widget.onLeaveDungeon!),
        ),
    ];
    MenuChrome.showMenuSheet(
      context: context,
      title: 'MORE',
      items: items,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_overlay != Is2Overlay.none) {
        setState(() => _overlay = Is2Overlay.none);
        return KeyEventResult.handled;
      }
      if (widget.hubMode && widget.onLeaveDungeon != null) {
        widget.onLeaveDungeon!();
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
        widget.director.godHandAt(0.5, 0.5);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
    if (widget.hubMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CaveAtmosphere.fullBleedScene(
            CustomAssets.hubScene,
            alignment: const Alignment(0, -0.08),
          ),
          CaveAtmosphere.readabilityScrim(top: 0.45, bottom: 0.5),
          Column(
            children: [
              _TopHud(
                state: state,
                director: d,
                onOpenSettings: () => _openOverlay(Is2Overlay.settings),
                onOpenMore: () => _showMoreMenu(context),
              ),
              Expanded(child: _inventoryDock()),
              _BottomNav(
                stashCount: state.gearStash.length,
                active: _overlay == Is2Overlay.equip
                    ? _BottomNavTab.party
                    : _overlay == Is2Overlay.inventory
                        ? _BottomNavTab.bag
                        : _BottomNavTab.none,
                onParty: _openEquip,
                onBag: _openBag,
                onMore: () => _showMoreMenu(context),
              ),
            ],
          ),
          if (_overlay != Is2Overlay.none &&
              _overlay != Is2Overlay.inventory &&
              _overlay != Is2Overlay.equip)
            _metaOverlay(d),
          FirstSessionTips(director: d),
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
        Column(
          children: [
            _TopHud(
              state: state,
              director: d,
              onOpenSettings: () => _openOverlay(Is2Overlay.settings),
              onOpenMore: () => _showMoreMenu(context),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SpatialDungeonView(director: d),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _DpsMeter(director: d),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 8,
                    child: _PartyCornerHud(
                      director: d,
                      selectedHeroIndex: _abilityHeroIndex,
                      onSelectHero: (i) =>
                          setState(() => _abilityHeroIndex = i),
                      onOpenEquip: _openEquip,
                      onUseConsumable: d.useConsumable,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 8,
                    child: _TargetCornerHud(director: d),
                  ),
                ],
              ),
            ),
            _BottomNav(
              stashCount: state.gearStash.length,
              active: _overlay == Is2Overlay.equip
                  ? _BottomNavTab.party
                  : _overlay == Is2Overlay.inventory
                      ? _BottomNavTab.bag
                      : _BottomNavTab.none,
              onParty: _openEquip,
              onBag: _openBag,
              onMore: () => _showMoreMenu(context),
            ),
          ],
        ),
        if (_overlay != Is2Overlay.none) _metaOverlay(d),
        FirstSessionTips(director: d),
      ],
    );
  }

  Widget _metaOverlay(GameDirector d) {
    return _OverlayScrim(
      title: switch (_overlay) {
        Is2Overlay.forge => 'FORGE & RELICS',
        Is2Overlay.jobs => 'CONTRACTS',
        Is2Overlay.sanctuary => 'SANCTUARY',
        Is2Overlay.inventory => 'INVENTORY',
        Is2Overlay.equip => 'EQUIP PARTY',
        Is2Overlay.settings => 'SETTINGS',
        Is2Overlay.market => 'MARKET',
        Is2Overlay.beast => 'BEAST PEN',
        Is2Overlay.achievements => 'ACHIEVEMENTS',
        Is2Overlay.codex => 'CODEX',
        Is2Overlay.loadouts => 'GEAR LOADOUTS',
        Is2Overlay.guides => 'GUIDES',
        Is2Overlay.prestigeShop => 'PRESTIGE SHOP',
        Is2Overlay.none => '',
      },
      onClose: () => setState(() => _overlay = Is2Overlay.none),
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
        Is2Overlay.equip => _EquipOverlay(
          director: d,
          selectedId: _selectedId,
          selectedHeroIndex: _equipHeroIndex,
          onSelectHero: (i) => setState(() => _equipHeroIndex = i),
          onSelect: _select,
          onUnequip: (heroIndex, slot) {
            d.unequipSlot(slot, heroIndex: heroIndex);
            setState(() {});
          },
          onEquipSelected: () {
            if (_selectedId == null) return;
            _equipSelectedTo(_equipHeroIndex);
          },
          onEquipToHero: _equipSelectedTo,
          onAutoEquip: () {
            d.autoEquipBetterGear();
            setState(() => _selectedId = null);
          },
          onOpenBag: () => setState(() => _overlay = Is2Overlay.inventory),
        ),
        Is2Overlay.settings => _SettingsOverlay(director: d),
        Is2Overlay.market => _MarketOverlay(director: d),
        Is2Overlay.beast => SingleChildScrollView(
          child: _BeastOverlay(director: d),
        ),
        Is2Overlay.achievements => AchievementsOverlay(director: d),
        Is2Overlay.codex => CodexOverlay(director: d),
        Is2Overlay.loadouts => LoadoutsOverlay(director: d),
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
    required this.onOpenMore,
  });

  final GameState state;
  final GameDirector director;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenMore;

  void _claimFirstMission() {
    for (final mission in state.missions) {
      if (mission.isComplete) {
        director.claimMission(mission.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dungeonName =
        GameLogic.dungeonNames[state.dungeonId] ?? state.dungeonId;
    final claimable = state.missions.where((m) => m.isComplete).length;
    final floor = state.currentRoom.floorNumber;
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
        border: const Border(
          bottom: BorderSide(color: Color(0x665A5040)),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IDLE PARTY',
                  style: GameTheme.pixel(size: GameTheme.hudPixel),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dungeonName · F$floor${state.hardmodeLevel > 0 ? '  HM+${state.hardmodeLevel}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 14,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
          if (claimable > 0) ...[
            _MissionClaimChip(
              count: claimable,
              onTap: _claimFirstMission,
            ),
            const SizedBox(width: 5),
          ],
          _Chip(icon: KenneyAssets.coinGold, label: '${state.gold}'),
          const SizedBox(width: 5),
          _Chip(icon: KenneyAssets.vialBlue, label: '${state.essence}'),
          SizedBox(
            width: GameTheme.minTouch,
            height: GameTheme.minTouch,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onOpenMore,
              icon: Text(
                '???',
                style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
              ),
              tooltip: 'More',
            ),
          ),
          SizedBox(
            width: GameTheme.minTouch,
            height: GameTheme.minTouch,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onOpenSettings,
              icon: KenneySprite(asset: KenneyAssets.iconSkull, size: 18),
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }
}

enum _BottomNavTab { none, party, bag, more }

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.stashCount,
    required this.active,
    required this.onParty,
    required this.onBag,
    required this.onMore,
  });

  final int stashCount;
  final _BottomNavTab active;
  final VoidCallback onParty;
  final VoidCallback onBag;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameTheme.ink.withValues(alpha: 0.78),
      child: SafeArea(
        top: false,
        child: Container(
          height: GameTheme.minTouch + 10,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x665A5040))),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: 'PARTY',
                  icon: KenneyAssets.iconCrown,
                  selected: active == _BottomNavTab.party,
                  onTap: onParty,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'BAG $stashCount',
                  icon: KenneyAssets.chestClosed,
                  selected: active == _BottomNavTab.bag,
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
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? GameTheme.torchHot : GameTheme.parchmentDim;
    return InkWell(
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
    );
  }
}

class _MissionClaimChip extends StatelessWidget {
  const _MissionClaimChip({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3A5018),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: GameTheme.clear),
            ),
            child: Text(
              'CLAIM $count',
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.clear,
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
  static const _idleFade = Duration(seconds: 5);
  static const _fullOpacity = 1.0;
  static const _dimOpacity = 0.1;
  static const _hudScale = 0.5;

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

    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fullWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < state.heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
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
                  compact: compact,
                  liveHp: () {
                    final s = _spatialFor(world, i);
                    return s?.hp ?? state.heroes[i].currentHp;
                  }(),
                  maxHp: () {
                    final s = _spatialFor(world, i);
                    return s?.maxHp ?? state.heroes[i].maxHp;
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
      opacity: _opacity,
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
  const _FlaskQuickSlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xDD2A1810),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GameTheme.bloodLit.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KenneySprite(asset: KenneyAssets.potionRed, size: 16),
              const SizedBox(width: 5),
              Text('FLASK', style: GameTheme.pixel(size: GameTheme.hudPixel)),
            ],
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
      AbilityId.fireball => s.queuedFireball,
      AbilityId.pyroblast => s.queuedPyroblast,
      AbilityId.livingBomb => s.livingBombArmed > 0,
      AbilityId.sliceAndDice => s.sliceAndDiceTimer > 0,
      AbilityId.bladeFlurry => s.bladeFlurryTimer > 0,
      AbilityId.sprint => s.sprintTimer > 0,
      AbilityId.vanish => s.vanishTimer > 0,
      AbilityId.killingSpree => s.killingSpreeTimer > 0,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final frac = maxHp <= 0 ? 0.0 : (liveHp / maxHp).clamp(0.0, 1.0);
    final roleShort = hero.roleLabel.length >= 3
        ? hero.roleLabel.substring(0, 3)
        : hero.roleLabel;
    final showKit = selected && spatial != null && spatial!.isAlive;
    final resource =
        showKit ? spatial!.rage.clamp(0.0, 100.0).toDouble() : 0.0;
    final off = hero.itemIn(EquipmentSlot.offHand);
    final hasShield = off?.offHandKind == OffHandKind.shield;
    final abilities = showKit
        ? ClassKits.hudAbilitiesAt(hero.role, hero.level)
        : const <ClassAbilityDef>[];

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 36 : 40),
      padding: EdgeInsets.fromLTRB(4, compact ? 4 : 5, 6, compact ? 4 : 5),
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
                        size: compact ? 7 : GameTheme.hudPixel,
                        color: GameTheme.parchment,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 5,
                        backgroundColor: const Color(0xFF2A2218),
                        color:
                            liveHp <= 0 ? GameTheme.blood : GameTheme.clear,
                      ),
                    ),
                    if (showKit) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            ClassKits.resourceLabel(hero.role),
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
                                  ClassKits.resourceColor(hero.role),
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
                          if (hero.role == HeroRole.rogue &&
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
          if (showKit && abilities.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final ability in abilities)
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
    final label = onCd
        ? (cdLeft < 10
            ? cdLeft.toStringAsFixed(1)
            : cdLeft.round().toString())
        : ability.shortLabel;
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
            style: GameTheme.pixel(
              size: 5,
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

  static String _roleTag(HeroRole? role) => switch (role) {
        HeroRole.warrior => 'WAR',
        HeroRole.healer => 'DISC',
        HeroRole.mage => 'MAGE',
        HeroRole.rogue => 'ROG',
        null => '???',
      };

  static String _fmt(num n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final world = director.spatial;
    if (world == null) return const SizedBox.shrink();

    final rows = <({String tag, int dmg, double dps})>[
      for (final h in world.heroes)
        if (!h.isPet)
          (
            tag: _roleTag(h.heroRole),
            dmg: h.damageDealt,
            dps: world.combatElapsed > 0.25
                ? h.damageDealt / world.combatElapsed
                : 0.0,
          ),
    ];
    if (rows.every((r) => r.dmg == 0)) return const SizedBox.shrink();

    rows.sort((a, b) => b.dmg.compareTo(a.dmg));
    final peak = rows.first.dmg.clamp(1, 1 << 30);

    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
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
                'DPS',
                style: GameTheme.pixel(
                  size: 7,
                  color: GameTheme.parchmentDim,
                ),
              ),
              const SizedBox(height: 3),
              for (final row in rows) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        row.tag,
                        style: GameTheme.pixel(
                          size: GameTheme.hudPixel,
                          color: row.dmg == peak
                              ? GameTheme.torchHot
                              : GameTheme.parchment,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _fmt(row.dps),
                        textAlign: TextAlign.right,
                        style: GameTheme.pixel(size: GameTheme.hudPixel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: (row.dmg / peak).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: const Color(0xFF2A241C),
                    color: row.dmg == peak
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

    final enemy = focus;
    final label = enemy == null
        ? (state.isPartyDefeated ? 'WIPED' : 'NO TARGET')
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
      constraints: const BoxConstraints(maxWidth: 168),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.pixel(size: GameTheme.hudPixel),
                  ),
                ),
                if (role.isNotEmpty)
                  Text(
                    role,
                    style: GameTheme.pixel(
                      size: 5,
                      color: role == 'BOSS'
                          ? GameTheme.bloodLit
                          : GameTheme.torch,
                    ),
                  ),
              ],
            ),
            if (archetype.isNotEmpty)
              Text(
                archetype,
                style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
              ),
            if (enemy != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: hpFrac,
                  minHeight: 5,
                  backgroundColor: const Color(0xFF2A2218),
                  color: GameTheme.bloodLit,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${(hpFrac * 100).round()}% HP',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
              Text(
                'ATK ${enemy.attack}',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
            ] else
              Text(
                state.isPartyDefeated ? 'Tap stage to revive' : 'Clear chamber',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
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

class _InventoryDock extends StatelessWidget {
  const _InventoryDock({
    required this.state,
    required this.selectedId,
    required this.combineA,
    required this.combineB,
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
    required this.onHatchPet,
    required this.onSetPet,
    required this.onLevelUpPet,
    required this.onTogglePetMerge,
    required this.petMergeA,
    required this.petMergeB,
    required this.onConfirmPetMerge,
    required this.onFavoritePet,
    required this.onBondPet,
    required this.onBuyPetFrame,
    required this.onUseConsumable,
    required this.onBindSoulbound,
    required this.onUpgradeGodHand,
    required this.onAutoSell,
  });

  final GameState state;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
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
  final VoidCallback onHatchPet;
  final void Function(String id) onSetPet;
  final void Function(String id) onLevelUpPet;
  final void Function(String id) onTogglePetMerge;
  final String? petMergeA;
  final String? petMergeB;
  final VoidCallback onConfirmPetMerge;
  final void Function(String speciesId) onFavoritePet;
  final void Function(String petId) onBondPet;
  final void Function(String petId, PetFrame frame) onBuyPetFrame;
  final VoidCallback onUseConsumable;
  final VoidCallback onBindSoulbound;
  final VoidCallback onUpgradeGodHand;
  final VoidCallback onAutoSell;

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
                label: 'AUTO',
                onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: 'SELL',
                onPressed:
                    selectedId == null && combineA == null ? null : onSell,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: KenneyButton(
                label: 'JUNK',
                onPressed: state.gearStash.isEmpty ? null : onAutoSell,
                style: KenneyButtonStyle.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bagTab(List<EquipmentItem?> slots, EquipmentItem? primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BAG  ${state.gearStash.length}/${GameLogic.maxGearStashFor(state)}',
          style: GameTheme.pixel(size: GameTheme.hudPixel),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            itemCount: slots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              mainAxisExtent: GameTheme.minTouch,
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
          label: 'COMBINE',
          onPressed: selectedId == null
              ? null
              : () => onPutCombine(selectedId!),
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
                    selected.statsLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.torchHot,
                    ),
                  ),
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
            'Tap item · choose hero  ·  Hold · combinator',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
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
    required int ghCost,
    required int fragmentsNeeded,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('COMBINATOR', style: GameTheme.pixel(size: GameTheme.hudPixel)),
          if (primary != null)
            Text(
              'Same slot only (${primary.slot.name})',
              style: GameTheme.body(
                size: 10,
                color: GameTheme.parchmentDim,
              ),
            ),
          const SizedBox(height: 4),
          _CombineSlot(
            label: 'A',
            item: primary,
            onClear: combineA == null ? null : onClearCombineA,
          ),
          const SizedBox(height: 4),
          _CombineSlot(
            label: 'B',
            item: secondary,
            onClear: combineB == null ? null : onClearCombineB,
          ),
          const SizedBox(height: 6),
          if (preview != null) ...[
            Text(
              '→ ${GameLogic.rarityNames[preview.rarity]} i${preview.effectiveItemLevel}',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.torchHot),
            ),
            const SizedBox(height: 4),
          ],
          KenneyButton(
            label: canCombine && state.gold >= cost ? 'MERGE $cost' : 'MERGE',
            onPressed: canCombine && state.gold >= cost ? onCombine : null,
            style: KenneyButtonStyle.red,
          ),
          const SizedBox(height: 4),
          if (GameLogic.canUseConsumable(state)) ...[
            KenneyButton(
              label: 'FLASK / USE',
              onPressed: onUseConsumable,
            ),
            const SizedBox(height: 4),
          ],
          KenneyButton(
            label:
                'GOD HAND Lv${state.godHandLevel}  '
                'CD Lv${state.metaDepth.godHandCdLevel}  ${ghCost}e',
            onPressed: state.essence >= ghCost ? onUpgradeGodHand : null,
          ),
          Text(
            'AOE ${state.godHandBaseDamage} · r${state.godHandRadius.toStringAsFixed(1)}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          KenneyButton(
            label: 'SOULBIND  3 frag',
            onPressed:
                state.soulboundFragments >= 3 &&
                    state.heroes.any((h) {
                      if (state.metaDepth.soulboundIsArmor) {
                        return h.itemIn(EquipmentSlot.chest) != null ||
                            h.itemIn(EquipmentSlot.cloak) != null;
                      }
                      return h.itemIn(EquipmentSlot.weapon) != null;
                    })
                ? onBindSoulbound
                : null,
            style: KenneyButtonStyle.grey,
          ),
          Text(
            'Need $fragmentsNeeded fragments (have ${state.soulboundFragments})',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const KenneySprite(asset: CustomAssets.petEgg, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: KenneyButton(
                  label: state.ownedPets.length >=
                          state.metaDepth.basePetRosterCap
                      ? 'ROSTER FULL'
                      : 'HATCH PET  ${GameLogic.hatchPetCost(state)}e',
                  onPressed: state.ownedPets.length <
                              state.metaDepth.basePetRosterCap &&
                          state.essence >= GameLogic.hatchPetCost(state)
                      ? onHatchPet
                      : null,
                ),
              ),
            ],
          ),
          Text(
            'Pets ${state.ownedPets.length}/'
            '${state.metaDepth.basePetRosterCap}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          if (state.ownedPets.isNotEmpty) ...[
            const SizedBox(height: 4),
            if (petMergeA != null && petMergeB != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: KenneyButton(
                  label: 'CONFIRM MERGE',
                  style: KenneyButtonStyle.red,
                  onPressed: onConfirmPetMerge,
                ),
              ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final pet in state.ownedPets)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () => onSetPet(pet.id),
                        onLongPress: () => onTogglePetMerge(pet.id),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: GameTheme.minTouch,
                            minWidth: GameTheme.minTouch,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: MenuChrome.cardBox(
                              selected: state.activePet?.id == pet.id ||
                                  pet.id == petMergeA ||
                                  pet.id == petMergeB,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    KenneySprite(
                                      asset: CustomAssets.petForInstanceId(
                                        pet.id,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      pet.name,
                                      style: GameTheme.body(size: 11),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${pet.rarity.name} · '
                                  '${pet.passive.name} · '
                                  '${pet.affinityDungeonId}',
                                  style: GameTheme.body(
                                    size: 9,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (state.activePet != null) ...[
              Builder(
                builder: (context) {
                  final pet = state.activePet!;
                  final nextFrameIdx =
                      (pet.frame.index + 1) % PetFrame.values.length;
                  final nextFrame = PetFrame.values[
                      nextFrameIdx == 0 ? 1 : nextFrameIdx];
                  final frameCost = GameLogic.petFrameCost(nextFrame);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.petGoldFindPercent > 0 ||
                          state.petLootFindPercent > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Passive: +${state.petGoldFindPercent}% gold'
                            ' · +${state.petLootFindPercent}% loot find',
                            textAlign: TextAlign.center,
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: KenneyButton(
                              label:
                                  'LVL ${GameLogic.petLevelUpCost(pet)}e',
                              onPressed: state.essence >=
                                      GameLogic.petLevelUpCost(pet)
                                  ? () => onLevelUpPet(pet.id)
                                  : null,
                              style: KenneyButtonStyle.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: KenneyButton(
                              label: 'MERGE',
                              style: KenneyButtonStyle.grey,
                              onPressed: () => onTogglePetMerge(pet.id),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: KenneyButton(
                              label: 'FAV',
                              style: KenneyButtonStyle.grey,
                              onPressed: () =>
                                  onFavoritePet(pet.resolvedSpecies),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: KenneyButton(
                              label:
                                  'BOND ${GameLogic.bondPetCost(pet.bondLevel)}e',
                              style: KenneyButtonStyle.grey,
                              onPressed: state.essence >=
                                      GameLogic.bondPetCost(pet.bondLevel)
                                  ? () => onBondPet(pet.id)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: KenneyButton(
                              label: pet.frame == PetFrame.crystal
                                  ? 'FRAME MAX'
                                  : 'FRAME ${frameCost}e',
                              style: KenneyButtonStyle.grey,
                              onPressed: pet.frame == PetFrame.crystal ||
                                      state.essence < frameCost
                                  ? null
                                  : () =>
                                      onBuyPetFrame(pet.id, nextFrame),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
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
    final ghCost = GameLogic.godHandUpgradeCost(state.godHandLevel);
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
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: GameTheme.stone.withValues(alpha: 0.55),
              child: TabBar(
                labelStyle: GameTheme.pixel(size: GameTheme.hudPixel),
                unselectedLabelStyle:
                    GameTheme.pixel(size: GameTheme.hudPixel),
                indicatorColor: GameTheme.torchHot,
                labelColor: GameTheme.torchHot,
                unselectedLabelColor: GameTheme.parchmentDim,
                dividerColor: GameTheme.border.withValues(alpha: 0.5),
                tabs: const [
                  Tab(text: 'EQUIP'),
                  Tab(text: 'BAG'),
                  Tab(text: 'TOOLS'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _equipTab(),
                  _bagTab(slots, primary),
                  _toolsTab(
                    primary: primary,
                    secondary: secondary,
                    canCombine: canCombine,
                    cost: cost,
                    preview: preview,
                    ghCost: ghCost,
                    fragmentsNeeded: fragmentsNeeded,
                  ),
                ],
              ),
            ),
          ],
        ),
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
                'P ${GameLogic.formatDelta(cmp.powerDelta)}',
                style: GameTheme.pixel(size: GameTheme.hudPixel, color: deltaColor),
              ),
              Text(
                'A${GameLogic.formatDelta(cmp.atkDelta)} '
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

  @override
  Widget build(BuildContext context) {
    final rarityColor = item == null
        ? const Color(0xFF5A5040)
        : _rarityBorderColor(item!.rarity);
    final isBest = item != null && _isBestStashItem(state, item!);
    return Opacity(
      opacity: dimmed ? 0.25 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: MenuChrome.cardBox(selected: highlight).copyWith(
            border: Border.all(
              color: highlight ? GameTheme.torchHot : rarityColor,
              width: item != null ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: item == null
              ? const SizedBox.expand()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: KenneySprite(
                        asset: KenneyAssets.equipmentIconFor(item!),
                        size: 22,
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      left: 2,
                      child: Text(
                        'i${item!.effectiveItemLevel}',
                        style: GameTheme.pixel(
                          size: 4,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ),
                    if (isBest)
                      Positioned(
                        top: 1,
                        left: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 0,
                          ),
                          color: const Color(0xDD2A5018),
                          child: Text(
                            'BEST',
                            style: GameTheme.pixel(
                              size: 4,
                              color: GameTheme.clear,
                            ),
                          ),
                        ),
                      ),
                    if (_isSoulboundItem(item!))
                      Positioned(
                        top: 0,
                        right: 2,
                        child: Text(
                          '8',
                          style: GameTheme.pixel(
                            size: 5,
                            color: GameTheme.torchHot,
                          ),
                        ),
                      ),
                    if (item!.slot == EquipmentSlot.weapon)
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
    );
  }
}

class _CombineSlot extends StatelessWidget {
  const _CombineSlot({required this.label, required this.item, this.onClear});

  final String label;
  final EquipmentItem? item;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onClear,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: MenuChrome.cardBox(inset: true),
        child: Row(
          children: [
            Text(label, style: GameTheme.pixel(size: 8)),
            const SizedBox(width: 6),
            if (item != null) ...[
              KenneySprite(
                asset: KenneyAssets.equipmentIconFor(item!),
                size: 24,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ] else
              const Expanded(
                child: Text(
                  'empty',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666055)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EquipOverlay extends StatelessWidget {
  const _EquipOverlay({
    required this.director,
    required this.selectedId,
    required this.selectedHeroIndex,
    required this.onSelectHero,
    required this.onSelect,
    required this.onUnequip,
    required this.onEquipSelected,
    required this.onEquipToHero,
    required this.onAutoEquip,
    required this.onOpenBag,
  });

  final GameDirector director;
  final String? selectedId;
  final int selectedHeroIndex;
  final void Function(int index) onSelectHero;
  final void Function(String id) onSelect;
  final void Function(int heroIndex, EquipmentSlot slot) onUnequip;
  final VoidCallback onEquipSelected;
  final void Function(int heroIndex) onEquipToHero;
  final VoidCallback onAutoEquip;
  final VoidCallback onOpenBag;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final selected = selectedId == null
        ? null
        : GameLogic.findGear(state, selectedId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: CharacterEquipPanel(
              state: state,
              heroIndex: selectedHeroIndex,
              onSelectHero: onSelectHero,
              selectedItemId: selectedId,
              onSelectItem: onSelect,
              onUnequip: (slot) => onUnequip(selectedHeroIndex, slot),
            ),
          ),
        ),
        if (selected != null &&
            state.gearStash.any((i) => i.id == selected.id)) ...[
          const SizedBox(height: 6),
          Text(
            'Equip on:',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < state.heroes.length; i++)
                KenneyButton(
                  label: '? ${state.heroes[i].roleLabel}',
                  onPressed: () => onEquipToHero(i),
                  expanded: false,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: selectedId == null
                    ? 'EQUIP'
                    : 'EQUIP · ${state.heroes[selectedHeroIndex.clamp(0, state.heroes.length - 1)].roleLabel}',
                onPressed: selectedId == null ? null : onEquipSelected,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: KenneyButton(
                label: 'AUTO',
                onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: KenneyButton(
                label: 'BAG',
                onPressed: onOpenBag,
                style: KenneyButtonStyle.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverlayScrim extends StatelessWidget {
  const _OverlayScrim({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = GameTheme.isCompactWidth(context);
    return Positioned.fill(
      child: Material(
        color: MenuChrome.scrim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CaveAtmosphere.torchBloom(
              intensity: 0.7,
              alignment: const Alignment(0, 0.1),
              sizeFactor: 0.85,
            ),
            SafeArea(
              child: compact
                  ? _MobileSheet(title: title, onClose: onClose, child: child)
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 520,
                          maxHeight: 560,
                        ),
                        child: SizedBox(
                          width: 520,
                          height: 560,
                          child: _OverlayPanel(
                            title: title,
                            onClose: onClose,
                            child: child,
                          ),
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
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.94,
        widthFactor: 1,
        child: _OverlayPanel(
          title: title,
          onClose: onClose,
          margin: EdgeInsets.zero,
          borderRadius: MenuChrome.sheetRadius,
          child: child,
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
                Expanded(
                  child: Text(
                    title,
                    style: GameTheme.pixel(size: GameTheme.hudPixelComfort),
                  ),
                ),
                KenneyButton(
                  label: 'CLOSE',
                  onPressed: onClose,
                  style: KenneyButtonStyle.grey,
                  expanded: false,
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

class _ForgeOverlay extends StatelessWidget {
  const _ForgeOverlay({required this.director});
  final GameDirector director;

  Widget _upgradeButton({
    required GameState state,
    required int index,
    required String label,
    required int cost,
    required VoidCallback? onPressed,
  }) {
    final recommended = GameLogic.recommendedForgeUpgrade(state) == index;
    return Row(
      children: [
        if (recommended)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              '? BEST',
              style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.clear),
            ),
          ),
        Expanded(
          child: KenneyButton(
            label: label,
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final training = GameLogic.partyTrainingCostFor(state);
    final canAscend = GameLogic.canAscend(state);
    final softcap = GameLogic.levelsUntilSoftcap(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ATK +${state.totalAttackBonus}  DEF +${state.totalDefenseBonus}  '
          'VIT +${state.totalVitalityBonus}',
          style: const TextStyle(fontSize: 16, color: Color(0xFFD7CAA0)),
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: canAscend
              ? 'ASCEND · AL${state.ascensionLevel + 1}'
              : 'ASCEND  ${state.bossVictories}/${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} bosses',
          onPressed: canAscend
              ? () => confirmAscend(context, director)
              : null,
          style: KenneyButtonStyle.red,
        ),
        if (!canAscend)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Defeat ${GameLogic.bossesRequiredForAscension(state.ascensionLevel) - state.bossVictories} more boss'
              '${GameLogic.bossesRequiredForAscension(state.ascensionLevel) - state.bossVictories == 1 ? '' : 'es'} this run',
              style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
            ),
          ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'Train $training g',
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
        _upgradeButton(
          state: state,
          index: 0,
          label:
              'Attack ${GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)}',
          cost: GameLogic.upgradeCostFor(state, PartyUpgradeType.attack),
          onPressed:
              state.gold >=
                  GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)
              ? director.upgradeAttack
              : null,
        ),
        const SizedBox(height: 6),
        _upgradeButton(
          state: state,
          index: 1,
          label:
              'Defense ${GameLogic.upgradeCostFor(state, PartyUpgradeType.defense)}',
          cost: GameLogic.upgradeCostFor(state, PartyUpgradeType.defense),
          onPressed:
              state.gold >=
                  GameLogic.upgradeCostFor(state, PartyUpgradeType.defense)
              ? director.upgradeDefense
              : null,
        ),
        const SizedBox(height: 6),
        _upgradeButton(
          state: state,
          index: 2,
          label:
              'Vitality ${GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality)}',
          cost: GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality),
          onPressed:
              state.gold >=
                  GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality)
              ? director.upgradeVitality
              : null,
        ),
        const SizedBox(height: 10),
        Text('RELICS', style: GameTheme.pixel(size: 8)),
        const SizedBox(height: 6),
        for (final relicId in GameLogic.relicOrder) ...[
          Builder(
            builder: (context) {
              final owned = state.hasRelic(relicId);
              final name = GameLogic.relicNames[relicId] ?? relicId;
              final cost = GameLogic.relicCosts[relicId] ?? 0;
              final desc =
                  GameLogic.relicDescriptions[relicId] ?? '';
              final tier = owned
                  ? (state.metaDepth.relicTierOf(relicId) < 1
                      ? 1
                      : state.metaDepth.relicTierOf(relicId))
                  : 0;
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
        const SizedBox(height: 10),
        Text('SOULBOUND', style: GameTheme.pixel(size: 8)),
        const SizedBox(height: 6),
        if (state.soulboundItem == null)
          Text(
            'Bind a weapon in the bag Tools tab (3 fragments).',
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
        const SizedBox(height: 10),
        Text('GOD HAND CD', style: GameTheme.pixel(size: 8)),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'CD Lv${state.metaDepth.godHandCdLevel}  '
              '${GameLogic.godHandCdUpgradeCost(state.metaDepth.godHandCdLevel)}e',
          onPressed: state.essence >=
                  GameLogic.godHandCdUpgradeCost(
                    state.metaDepth.godHandCdLevel,
                  )
              ? director.upgradeGodHandCd
              : null,
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
              border: Border.all(color: const Color(0xFF595033)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mission.title, style: GameTheme.pixel(size: 8)),
                      const SizedBox(height: 4),
                      Text(
                        '${mission.progress}/${mission.target}  '
                        '+${mission.goldReward}g +${mission.essenceReward}e',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                KenneyButton(
                  label: mission.isComplete ? 'CLAIM' : 'WAIT',
                  onPressed: mission.isComplete
                      ? () => director.claimMission(mission.id)
                      : null,
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
        const Text(
          'Permanent upgrades. Survive Ascend.',
          style: TextStyle(fontSize: 15, color: Color(0xFFD7CAA0)),
        ),
        const SizedBox(height: 10),
        for (final track in <String>['gold', 'power', 'vitality', 'xp']) ...[
          Builder(
            builder: (context) {
              final level = _levelOf(state, track);
              final prestige = _prestigeOf(state, track);
              final nextLevel = level + 1;
              final cost = GameLogic.sanctuaryCost(level);
              final nextBonus =
                  GameLogic.sanctuaryBonusLabel(track, nextLevel);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (track == 'gold')
                    Text(
                      'Now +${state.sanctuaryGoldBonusPercent}% gold  ·  '
                      '+${nextLevel * 5}% gold',
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.clear,
                      ),
                    )
                  else if (track == 'power')
                    Text(
                      'Now +${state.sanctuaryAttackBonus} ATK  ·  '
                      '+$nextLevel party attack',
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.clear,
                      ),
                    )
                  else if (track == 'vitality')
                    Text(
                      'Now +${state.sanctuaryVitalityBonus} HP  ·  '
                      '+${nextLevel * 2} max HP',
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.clear,
                      ),
                    )
                  else if (track == 'xp')
                    Text(
                      'Now +${state.sanctuaryXpBonusPercent}% XP  ·  '
                      '+${nextLevel * 4}% XP find',
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.clear,
                      ),
                    ),
                  Text(
                    'Prestige $prestige  ·  Next: $nextBonus  ·  $cost essence',
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 6),
                  KenneyProgressBar(
                    value: (level / 12).clamp(0.0, 1.0),
                    height: 12,
                    color: track == 'vitality'
                        ? KenneyBarColor.red
                        : track == 'power'
                            ? KenneyBarColor.yellow
                            : KenneyBarColor.green,
                  ),
                  const SizedBox(height: 6),
                  KenneyButton(
                    label:
                        '${GameLogic.sanctuaryNames[track]} Lv$level  '
                        '$nextBonus  ${cost}e',
                    onPressed: state.essence >= cost
                        ? () => director.upgradeSanctuary(track)
                        : null,
                  ),
                  if (level >= 12) ...[
                    const SizedBox(height: 4),
                    KenneyButton(
                      label: 'PRESTIGE  +${25 + level}e  reset Lv0',
                      style: KenneyButtonStyle.brown,
                      onPressed: () =>
                          director.prestigeSanctuaryTrack(track),
                    ),
                  ],
                  const SizedBox(height: 6),
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
  const _SettingsOverlay({required this.director});
  final GameDirector director;

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
            child: const Text('Cancel'),
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
        _SettingsToggle(
          label: 'Reduced VFX',
          value: state.reducedVfx,
          onChanged: director.setReducedVfx,
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
        Row(
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
        const SizedBox(height: 12),
        Text('Auto-sell drops = iLvl', style: GameTheme.pixel(size: 7)),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                foregroundColor: GameTheme.parchment,
              ),
              onPressed: state.autoSellMaxPower > 0
                  ? () => director.setAutoSellMaxPower(state.autoSellMaxPower - 1)
                  : null,
              child: Text('-', style: GameTheme.pixel(size: 10)),
            ),
            Expanded(
              child: _CaveSlider(
                value: state.autoSellMaxPower.toDouble().clamp(0, 80),
                min: 0,
                max: 80,
                divisions: 80,
                onChanged: (v) => director.setAutoSellMaxPower(v.round()),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                foregroundColor: GameTheme.parchment,
              ),
              onPressed: state.autoSellMaxPower < 80
                  ? () => director.setAutoSellMaxPower(state.autoSellMaxPower + 1)
                  : null,
              child: Text('+', style: GameTheme.pixel(size: 10)),
            ),
          ],
        ),
        Text(
          'Pickup: auto-sell drops at or below i${state.autoSellMaxPower} '
          'if not an upgrade (0 = off). Bag button sells all non-upgrades.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 16),
        SaveTransferSection(director: director),
        const SizedBox(height: 16),
        KenneyButton(
          label: "WHAT'S NEW",
          style: KenneyButtonStyle.grey,
          onPressed: () => _showWhatsNew(context),
        ),
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

  void _showWhatsNew(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DecoratedBox(
          decoration: MenuChrome.panel(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 420,
              height: 420,
              child: WhatsNewOverlay(director: director),
            ),
          ),
        ),
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
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: MenuChrome.cardBox(),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: GameTheme.body(size: 16)),
            ),
            _CaveSwitch(value: value),
          ],
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
    return AnimatedContainer(
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
          'TRAVELING MERCHANT',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 6),
        Text(
          'Gold ${state.gold}  ?  Essence ${state.essence}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        KenneyButton(
          label: 'BUY FLASK  ${flaskCost}g',
          onPressed: state.gold >= flaskCost ? director.buyMarketFlask : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            KenneySprite(asset: KenneyAssets.potionRed, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Restores party HP mid-run. Price scales with purchases.',
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'SELL STASH (gold)',
          style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        if (stash.isEmpty)
          Text(
            'Bag is empty. Clear rooms for gear, then sell junk here.',
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

  @override
  Widget build(BuildContext context) {
    final cap = state.metaDepth.basePetRosterCap;
    final canMerge = _mergeA != null && _mergeB != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BEAST PEN  ${state.ownedPets.length}/$cap',
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
        if (state.ownedPets.isEmpty)
          Text(
            'No beasts yet. Hatch an egg with essence — '
            'companions fight beside the party.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 15, color: GameTheme.parchmentDim),
          )
        else ...[
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
              onPressed: _doMerge,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pet.name}  ·  ${pet.rarity.name}'
                                  '${pet.frame != PetFrame.none ? '  [${pet.frame.name}]' : ''}',
                                  style: GameTheme.pixel(size: 7),
                                ),
                                Text(
                                  'Lv${pet.level}  ATK +${pet.totalAttackBonus}  '
                                  '${_passiveLabel(pet)}  ·  '
                                  '${pet.affinityDungeonId}'
                                  '${pet.bondLevel > 0 ? '  bond${pet.bondLevel}' : ''}',
                                  style: GameTheme.body(
                                    size: 13,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
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
