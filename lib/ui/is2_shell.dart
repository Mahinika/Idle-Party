import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'spatial_dungeon_view.dart';

Color _rarityBorderColor(LootRarity rarity) => switch (rarity) {
  LootRarity.common => const Color(0xFF5A5040),
  LootRarity.uncommon => const Color(0xFF70C050),
  LootRarity.rare => const Color(0xFF5090E0),
  LootRarity.epic => GameTheme.borderLit,
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

enum Is2Overlay { none, forge, jobs, sanctuary, inventory, equip, settings, market, beast }

class _Is2ShellState extends State<Is2Shell> {
  String? _selectedId;
  String? _combineA;
  String? _combineB;
  late Is2Overlay _overlay;
  int _equipHeroIndex = 0;
  int _abilityHeroIndex = 0;

  GameState get state => widget.director.state;

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
        d.equipFromStash(_selectedId!, heroIndex: _equipHeroIndex);
        setState(() => _selectedId = null);
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
      onEquipToHero: (heroIndex) {
        if (_selectedId == null) return;
        d.equipFromStash(_selectedId!, heroIndex: heroIndex);
        setState(() {
          _equipHeroIndex = heroIndex;
          _selectedId = null;
        });
      },
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
        final leveled = d.state.ownedPets.where((p) => p.id == id);
        if (leveled.isNotEmpty) {
          d.showToast('${leveled.first.name} → Lv${leveled.first.level}!');
        }
      },
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
        label: 'SETTINGS',
        onTap: () => _openOverlay(Is2Overlay.settings),
      ),
      if (widget.onLeaveDungeon != null)
        (
          label: 'RETURN TO HUB',
          onTap: widget.onLeaveDungeon!,
        ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameTheme.stoneDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: GameTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'MORE',
                  style: GameTheme.pixel(size: GameTheme.hudPixelComfort),
                ),
                const SizedBox(height: 8),
                for (final item in items)
                  _MoreListRow(
                    label: item.label,
                    onTap: () {
                      Navigator.pop(ctx);
                      item.onTap();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;

    if (widget.hubMode) {
      return Stack(
        children: [
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
        ],
      );
    }

    return Stack(
      children: [
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
                  SpatialDungeonView(
                    director: d,
                    abilityHeroIndex: _abilityHeroIndex,
                    onAbilityHeroChanged: (i) =>
                        setState(() => _abilityHeroIndex = i),
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
            d.equipFromStash(_selectedId!, heroIndex: _equipHeroIndex);
            setState(() => _selectedId = null);
          },
          onEquipToHero: (heroIndex) {
            if (_selectedId == null) return;
            d.equipFromStash(_selectedId!, heroIndex: heroIndex);
            setState(() {
              _equipHeroIndex = heroIndex;
              _selectedId = null;
            });
          },
          onAutoEquip: () {
            d.autoEquipBetterGear();
            setState(() => _selectedId = null);
          },
          onOpenBag: () => setState(() => _overlay = Is2Overlay.inventory),
        ),
        Is2Overlay.settings => _SettingsOverlay(director: d),
        Is2Overlay.market => const _MarketOverlay(),
        Is2Overlay.beast => _BeastOverlay(director: d),
        Is2Overlay.none => const SizedBox.shrink(),
      },
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE24180E), Color(0xCC14110C)],
        ),
        border: Border(
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
                  '$dungeonName · F$floor',
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
              icon: const Icon(Icons.more_vert, color: GameTheme.torchHot),
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
      color: const Color(0xF214110C),
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

class _MoreListRow extends StatelessWidget {
  const _MoreListRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [GameTheme.stoneRaised, GameTheme.stone],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: GameTheme.borderLit.withValues(alpha: 0.7),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: GameTheme.pixel(size: GameTheme.hudPixel),
            ),
          ),
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

class _PartyCornerHud extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final state = director.state;
    final world = director.spatial;
    final canUseFlask = GameLogic.canUseConsumable(state);
    final compact = GameTheme.isCompactWidth(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 168 : 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < state.heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelectHero(i),
                onLongPress: onOpenEquip,
                borderRadius: BorderRadius.circular(4),
                child: _PartyRow(
                  index: i,
                  hero: state.heroes[i],
                  selected: selectedHeroIndex == i,
                  compact: compact,
                  liveHp: () {
                    if (world == null) return state.heroes[i].currentHp;
                    for (final a in world.heroes) {
                      if (!a.isPet && a.assetIndex == i) return a.hp;
                    }
                    return state.heroes[i].currentHp;
                  }(),
                  maxHp: () {
                    if (world == null) return state.heroes[i].maxHp;
                    for (final a in world.heroes) {
                      if (!a.isPet && a.assetIndex == i) return a.maxHp;
                    }
                    return state.heroes[i].maxHp;
                  }(),
                ),
              ),
            ),
          ],
          if (canUseFlask) ...[
            const SizedBox(height: 4),
            _FlaskQuickSlot(onTap: onUseConsumable),
          ],
        ],
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
  });

  final int index;
  final PartyHero hero;
  final int liveHp;
  final int maxHp;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final frac = maxHp <= 0 ? 0.0 : (liveHp / maxHp).clamp(0.0, 1.0);
    final roleShort = hero.roleLabel.length >= 3
        ? hero.roleLabel.substring(0, 3)
        : hero.roleLabel;
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
      child: Row(
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
                if (!compact &&
                    (hero.role == HeroRole.warrior ||
                        hero.role == HeroRole.healer ||
                        hero.role == HeroRole.mage ||
                        hero.role == HeroRole.rogue)) ...[
                  const SizedBox(height: 1),
                  Text(
                    hero.passiveLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 9,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: compact ? 5 : 5,
                    backgroundColor: const Color(0xFF2A2218),
                    color: liveHp <= 0 ? GameTheme.blood : GameTheme.clear,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: GameLogic.xpPoolForLevel(hero.level) <= 0
                          ? 0
                          : (hero.xp / GameLogic.xpPoolForLevel(hero.level))
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
  final VoidCallback onUseConsumable;
  final VoidCallback onBindSoulbound;
  final VoidCallback onUpgradeGodHand;
  final VoidCallback onAutoSell;

  EquipmentItem? _find(String? id) {
    if (id == null) return null;
    return GameLogic.findGear(state, id);
  }

  static const _slotLabels = <EquipmentSlot, String>{
    EquipmentSlot.weapon: 'WPN',
    EquipmentSlot.offHand: 'OH',
    EquipmentSlot.ranged: 'RNGD',
    EquipmentSlot.head: 'HEL',
    EquipmentSlot.shoulder: 'SHL',
    EquipmentSlot.chest: 'CST',
    EquipmentSlot.waist: 'BLT',
    EquipmentSlot.legs: 'LEG',
    EquipmentSlot.boots: 'BTS',
    EquipmentSlot.wrist: 'WRS',
    EquipmentSlot.hands: 'HND',
    EquipmentSlot.cloak: 'CLK',
    EquipmentSlot.neck: 'NCK',
    EquipmentSlot.ring: 'RN1',
    EquipmentSlot.ring2: 'RN2',
    EquipmentSlot.trinket: 'TRK',
    EquipmentSlot.trinket2: 'TR2',
    EquipmentSlot.consumable: 'CON',
  };

  Widget _equipTab() {
    final heroLabel =
        state.heroes[equipHeroIndex.clamp(0, state.heroes.length - 1)].roleLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'EQUIP → $heroLabel',
          style: GameTheme.pixel(size: GameTheme.hudPixel),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: GameTheme.minTouch,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < state.heroes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => onEquipHeroChanged(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: GameTheme.minTouch,
                        minWidth: GameTheme.minTouch,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: equipHeroIndex == i
                              ? const Color(0xFF5A3828)
                              : const Color(0xFF2A2418),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: equipHeroIndex == i
                                ? GameTheme.torch
                                : const Color(0xFF7A6840),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          state.heroes[i].roleLabel.substring(0, 3),
                          style: GameTheme.pixel(size: GameTheme.hudPixel),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: [
              for (final slot in EquipmentSlot.values) ...[
                _EquipTile(
                  label: _slotLabels[slot]!,
                  item: state.equippedOn(equipHeroIndex, slot),
                  state: state,
                  selected:
                      state.equippedOn(equipHeroIndex, slot)?.id == selectedId,
                  onTap: state.equippedOn(equipHeroIndex, slot) == null
                      ? null
                      : () => onSelect(
                          state.equippedOn(equipHeroIndex, slot)!.id,
                        ),
                  onUnequip: state.equippedOn(equipHeroIndex, slot) == null
                      ? null
                      : () => onUnequip(slot),
                ),
                const SizedBox(height: 3),
              ],
            ],
          ),
        ),
        KenneyButton(
          label: 'EQUIP',
          onPressed: selectedId == null ? null : onEquip,
        ),
        const SizedBox(height: 4),
        KenneyButton(
          label: 'AUTO EQUIP',
          onPressed: state.gearStash.isEmpty ? null : onAutoEquip,
          style: KenneyButtonStyle.grey,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: 'SELL',
                onPressed:
                    selectedId == null && combineA == null ? null : onSell,
                style: KenneyButtonStyle.grey,
              ),
            ),
            const SizedBox(width: 6),
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
          'BAG  ${state.gearStash.length}/${GameLogic.maxGearStash}',
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
            'Tap item → choose hero  ·  Hold → combinator',
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
            label: 'GH ${ghCost}e',
            onPressed: state.essence >= ghCost ? onUpgradeGodHand : null,
          ),
          const SizedBox(height: 4),
          KenneyButton(
            label: 'BIND SB',
            onPressed:
                state.soulboundFragments >= 3 &&
                    state.heroes.any(
                      (h) => h.itemIn(EquipmentSlot.weapon) != null,
                    )
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
          KenneyButton(
            label: 'PET ${GameLogic.hatchPetCost(state)}e',
            onPressed: state.essence >= GameLogic.hatchPetCost(state)
                ? onHatchPet
                : null,
          ),
          if (state.ownedPets.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: GameTheme.minTouch,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final pet in state.ownedPets)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () => onSetPet(pet.id),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: GameTheme.minTouch,
                            minWidth: GameTheme.minTouch,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: state.activePet?.id == pet.id
                                  ? const Color(0xFF5A3828)
                                  : const Color(0xFF2A2418),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: const Color(0xFF7A6840),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              pet.name,
                              style: GameTheme.body(size: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (state.activePet != null)
              KenneyButton(
                label:
                    'LEVEL UP ${GameLogic.petLevelUpCost(state.activePet!)}e',
                onPressed:
                    state.essence >=
                        GameLogic.petLevelUpCost(state.activePet!)
                    ? () => onLevelUpPet(state.activePet!.id)
                    : null,
                style: KenneyButtonStyle.grey,
              ),
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
      GameLogic.maxGearStash,
      (i) => i < state.gearStash.length ? state.gearStash[i] : null,
    );
    final ghCost = GameLogic.godHandUpgradeCost(state.godHandLevel);
    final fragmentsNeeded = state.soulboundFragments >= 3
        ? 0
        : 3 - state.soulboundFragments;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2221C14), GameTheme.stoneDeep],
        ),
        border: Border(top: BorderSide(color: GameTheme.borderLit, width: 2)),
        boxShadow: [
          BoxShadow(
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
              color: GameTheme.stone,
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

class _EquipTile extends StatelessWidget {
  const _EquipTile({
    required this.label,
    required this.item,
    required this.state,
    required this.selected,
    this.onTap,
    this.onUnequip,
  });

  final String label;
  final EquipmentItem? item;
  final GameState state;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    final rarityColor = item == null
        ? const Color(0xFF5A5040)
        : _rarityBorderColor(item!.rarity);
    return InkWell(
      onTap: onTap,
      onLongPress: onUnequip,
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A3420) : const Color(0xFF1C1914),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFE0B050) : rarityColor,
            width: item != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GameTheme.pixel(size: 7, color: GameTheme.parchmentDim),
            ),
            const SizedBox(width: 4),
            if (item != null)
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    KenneySprite(
                      asset: KenneyAssets.equipmentIconFor(item!),
                      size: 28,
                    ),
                    if (_isSoulboundItem(item!))
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Text(
                          '∞',
                          style: GameTheme.pixel(size: 7, color: GameTheme.torchHot),
                        ),
                      ),
                    if (item!.slot == EquipmentSlot.weapon)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Text(
                          _patternGlyph(item!.pattern),
                          style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.parchmentDim),
                        ),
                      ),
                  ],
                ),
              )
            else
              const Expanded(
                child: Text('-', style: TextStyle(color: Color(0xFF666055))),
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
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFF4A3420)
                : const Color(0xFF1C1914),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: highlight ? const Color(0xFFE0B050) : rarityColor,
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
                          '∞',
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
        decoration: BoxDecoration(
          color: const Color(0xFF1C1914),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF7A6840)),
        ),
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

  static const _displaySlots = <EquipmentSlot>[
    EquipmentSlot.weapon,
    EquipmentSlot.offHand,
    EquipmentSlot.ranged,
    EquipmentSlot.head,
    EquipmentSlot.shoulder,
    EquipmentSlot.chest,
    EquipmentSlot.hands,
    EquipmentSlot.waist,
    EquipmentSlot.legs,
    EquipmentSlot.boots,
    EquipmentSlot.wrist,
    EquipmentSlot.cloak,
    EquipmentSlot.neck,
    EquipmentSlot.ring,
    EquipmentSlot.ring2,
    EquipmentSlot.trinket,
  ];

  static const _slotShort = <EquipmentSlot, String>{
    EquipmentSlot.weapon: 'WPN',
    EquipmentSlot.offHand: 'OH',
    EquipmentSlot.ranged: 'RNGD',
    EquipmentSlot.head: 'HEL',
    EquipmentSlot.shoulder: 'SHL',
    EquipmentSlot.chest: 'CST',
    EquipmentSlot.hands: 'HND',
    EquipmentSlot.waist: 'BLT',
    EquipmentSlot.legs: 'LEG',
    EquipmentSlot.boots: 'BTS',
    EquipmentSlot.wrist: 'WRS',
    EquipmentSlot.cloak: 'CLK',
    EquipmentSlot.neck: 'NCK',
    EquipmentSlot.ring: 'RN1',
    EquipmentSlot.ring2: 'RN2',
    EquipmentSlot.trinket: 'TRK',
    EquipmentSlot.trinket2: 'TR2',
    EquipmentSlot.consumable: 'FLK',
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final selected = selectedId == null
        ? null
        : GameLogic.findGear(state, selectedId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Each hero wears their own gear. Tap bag item → Equip on hero.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (selected != null) ...[
          const SizedBox(height: 6),
          Text(
            '${selected.name}: ${selected.statsLine}',
            style: GameTheme.body(size: 13, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < state.heroes.length; i++)
                KenneyButton(
                  label: '→ ${state.heroes[i].roleLabel}',
                  onPressed: () => onEquipToHero(i),
                  expanded: false,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: state.heroes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final hero = state.heroes[index];
              return _HeroEquipCard(
                index: index,
                hero: hero,
                state: state,
                selectedId: selectedId,
                selected: selectedHeroIndex == index,
                slots: _displaySlots,
                slotShort: _slotShort,
                onSelectHero: () => onSelectHero(index),
                onSelect: onSelect,
                onUnequip: (slot) => onUnequip(index, slot),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: KenneyButton(
                label: selectedId == null
                    ? 'EQUIP'
                    : 'EQUIP → ${state.heroes[selectedHeroIndex.clamp(0, state.heroes.length - 1)].roleLabel}',
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

class _HeroEquipCard extends StatelessWidget {
  const _HeroEquipCard({
    required this.index,
    required this.hero,
    required this.state,
    required this.selectedId,
    required this.selected,
    required this.slots,
    required this.slotShort,
    required this.onSelectHero,
    required this.onSelect,
    required this.onUnequip,
  });

  final int index;
  final PartyHero hero;
  final GameState state;
  final String? selectedId;
  final bool selected;
  final List<EquipmentSlot> slots;
  final Map<EquipmentSlot, String> slotShort;
  final VoidCallback onSelectHero;
  final void Function(String id) onSelect;
  final void Function(EquipmentSlot slot) onUnequip;

  @override
  Widget build(BuildContext context) {
    final atk = state.effectiveHeroAttack(hero);
    final def = state.effectiveHeroDefense(hero);
    final maxHp = state.effectiveHeroMaxHp(hero);
    final ratings = state.ratingsFor(hero);
    final hpFrac =
        maxHp <= 0 ? 0.0 : (hero.currentHp / maxHp).clamp(0.0, 1.0);

    return InkWell(
      onTap: onSelectHero,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xEE2A2214)
              : const Color(0xEE1A1610),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected
                ? GameTheme.torch
                : GameTheme.borderLit.withValues(alpha: 0.55),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    HeroDollSprite(
                      hero: hero,
                      partyIndex: index,
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(hero.roleLabel, style: GameTheme.pixel(size: GameTheme.hudPixel)),
                    Text(
                      'L${hero.level}',
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: hpFrac,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF2A2218),
                          color: GameTheme.clear,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HP ${hero.currentHp}/$maxHp',
                        style: GameTheme.body(
                          size: 12,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                      if (hero.role == HeroRole.warrior ||
                          hero.role == HeroRole.healer ||
                          hero.role == HeroRole.mage ||
                          hero.role == HeroRole.rogue) ...[
                        const SizedBox(height: 4),
                        Text(
                          hero.passiveLabel,
                          style: GameTheme.body(
                            size: 10,
                            color: GameTheme.torch,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final slot in slots)
                            _EquipSlotChip(
                              label: slotShort[slot]!,
                              item: hero.itemIn(slot),
                              hero: hero,
                              selected: hero.itemIn(slot)?.id == selectedId,
                              onTap: hero.itemIn(slot) == null
                                  ? null
                                  : () => onSelect(hero.itemIn(slot)!.id),
                              onUnequip: hero.itemIn(slot) == null
                                  ? null
                                  : () => onUnequip(slot),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCell(label: 'STR', value: '${ratings.strength}'),
                _StatCell(label: 'AGI', value: '${ratings.agility}'),
                _StatCell(label: 'STA', value: '${ratings.stamina}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatCell(label: 'INT', value: '${ratings.intellect}'),
                _StatCell(label: 'SPI', value: '${ratings.spirit}'),
                _StatCell(label: 'DAMAGE', value: '$atk'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatCell(
                  label: 'ATK SPD',
                  value: state.effectiveHeroAttackSpeed(hero).toStringAsFixed(2),
                ),
                _StatCell(
                  label: 'CRIT',
                  value: '${state.effectiveHeroCrit(hero)}%',
                ),
                _StatCell(label: 'DEF', value: '$def'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatCell(
                  label: 'LIFESTEAL',
                  value: '${hero.gearLifestealPercent}%',
                ),
                _StatCell(
                  label: 'MOVE',
                  value: state.effectiveHeroMoveSpeed(hero).toStringAsFixed(1),
                ),
                _StatCell(label: 'HP', value: '$maxHp'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipSlotChip extends StatelessWidget {
  const _EquipSlotChip({
    required this.label,
    required this.item,
    required this.hero,
    required this.selected,
    this.onTap,
    this.onUnequip,
  });

  final String label;
  final EquipmentItem? item;
  final PartyHero hero;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    final rarityColor = item == null
        ? GameTheme.border
        : _rarityBorderColor(item!.rarity);
    return InkWell(
      onTap: onTap,
      onLongPress: onUnequip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4A3820)
              : const Color(0xFF12100C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? GameTheme.torch : rarityColor,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: item == null
            ? Center(
                child: Text(
                  label,
                  style: GameTheme.pixel(
                    size: 5,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              )
            : Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: KenneySprite(
                      asset: KenneyAssets.equipmentIconFor(item!),
                      size: 28,
                    ),
                  ),
                  if (_isSoulboundItem(item!))
                    Positioned(
                      top: 1,
                      right: 2,
                      child: Text(
                        '∞',
                        style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.torchHot),
                      ),
                    ),
                  if (item!.slot == EquipmentSlot.weapon)
                    Positioned(
                      bottom: 1,
                      left: 2,
                      child: Text(
                        _patternGlyph(item!.pattern),
                        style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.parchmentDim),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GameTheme.pixel(size: 7, color: GameTheme.parchmentDim),
          ),
          Text(value, style: GameTheme.body(size: 15)),
        ],
      ),
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
        color: const Color(0xCC050403),
        child: SafeArea(
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24180E), GameTheme.stoneDeep],
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(6),
          border: Border.all(color: GameTheme.borderLit, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: GameTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
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
              '◀ BEST',
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
              ? 'ASCEND → AL${state.ascensionLevel + 1}'
              : 'ASCEND (need bosses)',
          onPressed: canAscend ? director.ascend : null,
          style: KenneyButtonStyle.red,
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
          KenneyButton(
            label:
                '${GameLogic.relicNames[relicId]} ${GameLogic.relicCosts[relicId]}e',
            onPressed:
                state.hasRelic(relicId) ||
                    state.essence < GameLogic.relicCosts[relicId]!
                ? null
                : () => director.unlockRelic(relicId),
            style: KenneyButtonStyle.brown,
          ),
          const SizedBox(height: 6),
        ],
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
              color: const Color(0xFF14120D),
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
                  label: mission.isComplete ? 'CLAIM' : '...',
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
        for (final track in <String>['gold', 'power', 'vitality']) ...[
          Builder(
            builder: (context) {
              final level = switch (track) {
                'gold' => state.sanctuaryGoldLevel,
                'power' => state.sanctuaryPowerLevel,
                _ => state.sanctuaryVitalityLevel,
              };
              final nextLevel = level + 1;
              final cost = GameLogic.sanctuaryCost(level);
              final nextBonus =
                  GameLogic.sanctuaryBonusLabel(track, nextLevel);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (track == 'gold')
                    Text(
                      'Now +${state.sanctuaryGoldBonusPercent}% gold  →  '
                      '+${nextLevel * 5}% gold',
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.clear,
                      ),
                    ),
                  Text(
                    'Next: $nextBonus  ·  $cost essence',
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  KenneyButton(
                    label:
                        '${GameLogic.sanctuaryNames[track]} Lv$level  '
                        '$nextBonus  ${cost}e',
                    onPressed: state.essence >= cost
                        ? () => director.upgradeSanctuary(track)
                        : null,
                  ),
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
      builder: (context) => AlertDialog(
        backgroundColor: GameTheme.stoneDeep,
        title: Text('Reset game?', style: GameTheme.pixel(size: 8)),
        content: Text(
          'All progress will be wiped. This cannot be undone.',
          style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
    return Column(
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
        const SizedBox(height: 12),
        Text('Auto-sell drops ≤ iLvl', style: GameTheme.pixel(size: 7)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: state.autoSellMaxPower > 0
                  ? () => director.setAutoSellMaxPower(state.autoSellMaxPower - 1)
                  : null,
              icon: const Icon(Icons.remove, size: 18),
            ),
            Expanded(
              child: Slider(
                value: state.autoSellMaxPower.toDouble().clamp(0, 80),
                min: 0,
                max: 80,
                divisions: 80,
                label: 'i${state.autoSellMaxPower}',
                onChanged: (v) => director.setAutoSellMaxPower(v.round()),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: state.autoSellMaxPower < 80
                  ? () => director.setAutoSellMaxPower(state.autoSellMaxPower + 1)
                  : null,
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        Text(
          'Pickup: auto-sell drops at or below i${state.autoSellMaxPower} '
          'if not an upgrade (0 = off). Bag button sells all non-upgrades.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 16),
        KenneyButton(
          label: 'RESET GAME',
          style: KenneyButtonStyle.red,
          onPressed: _confirmReset,
        ),
      ],
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
        decoration: BoxDecoration(
          color: const Color(0xFF14120D),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: GameTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: GameTheme.body(size: 16)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: GameTheme.mossLit,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketOverlay extends StatelessWidget {
  const _MarketOverlay();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'TRAVELING MERCHANT',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 8),
        Text(
          'The caravan has not reached this dungeon yet. '
          'Gear still drops from foes and treasure rooms.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 15, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 14),
        _StubRoadmapCard(
          title: 'Planned stock',
          lines: const [
            'Buy / sell gear for gold',
            'Daily rotating rares',
            'Essence-priced curios',
          ],
        ),
      ],
    );
  }
}

class _BeastOverlay extends StatelessWidget {
  const _BeastOverlay({required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BEAST DEN',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(size: 8, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 8),
        if (state.ownedPets.isEmpty)
          Text(
            'No beasts yet. Hatch eggs from the bag dock — '
            'companions fight beside the party.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 15, color: GameTheme.parchmentDim),
          )
        else ...[
          for (final pet in state.ownedPets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFF14120D),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => director.setActivePet(pet.id),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: state.activePet?.id == pet.id
                            ? GameTheme.torch
                            : const Color(0xFF595033),
                      ),
                    ),
                    child: Row(
                      children: [
                        KenneySprite(asset: KenneyAssets.iconStar, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pet.name, style: GameTheme.pixel(size: 7)),
                              Text(
                                'Lv${pet.level}  ATK +${pet.totalAttackBonus}',
                                style: GameTheme.body(
                                  size: 14,
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                              Text(
                                'Tap to set active · level up in bag',
                                style: GameTheme.body(
                                  size: 12,
                                  color: GameTheme.mossLit,
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
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        _StubRoadmapCard(
          title: 'Coming later',
          lines: const [
            'Beast fusion & traits',
            'Den training board',
            'Rare egg finds',
          ],
        ),
      ],
    );
  }
}

class _StubRoadmapCard extends StatelessWidget {
  const _StubRoadmapCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14120D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF595033)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GameTheme.pixel(size: GameTheme.hudPixel, color: GameTheme.parchmentDim)),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $line',
                style: GameTheme.body(size: 14, color: GameTheme.parchment),
              ),
            ),
        ],
      ),
    );
  }
}
