
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/loot.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'spatial_dungeon_view.dart';

/// Idle Sword 2-inspired fixed shell: dungeon stage on top, inventory dock below.
class Is2Shell extends StatefulWidget {
  const Is2Shell({
    super.key,
    required this.director,
    required this.pulse,
  });

  final GameDirector director;
  final double pulse;

  @override
  State<Is2Shell> createState() => _Is2ShellState();
}

enum _OverlayKind { none, forge, jobs, sanctuary }

class _Is2ShellState extends State<Is2Shell> {
  String? _selectedId;
  String? _combineA;
  String? _combineB;
  _OverlayKind _overlay = _OverlayKind.none;

  GameState get state => widget.director.state;

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

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    return Stack(
      children: [
        Column(
          children: [
            _TopHud(
              state: state,
              onReset: () async => d.reset(),
              onOpenForge: () => setState(() => _overlay = _OverlayKind.forge),
              onOpenJobs: () => setState(() => _overlay = _OverlayKind.jobs),
              onOpenSanctuary: () =>
                  setState(() => _overlay = _OverlayKind.sanctuary),
            ),
            Expanded(
              flex: 55,
              child: SpatialDungeonView(director: d),
            ),
            Expanded(
              flex: 45,
              child: _InventoryDock(
                state: state,
                selectedId: _selectedId,
                combineA: _combineA,
                combineB: _combineB,
                onSelect: _select,
                onPutCombine: _putInCombinator,
                onEquip: () {
                  if (_selectedId == null) return;
                  d.equipFromStash(_selectedId!);
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
                onUnequipWeapon: () => d.unequipSlot(EquipmentSlot.weapon),
                onUnequipArmor: () => d.unequipSlot(EquipmentSlot.armor),
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
              ),
            ),
          ],
        ),
        if (_overlay != _OverlayKind.none)
          _OverlayScrim(
            title: switch (_overlay) {
              _OverlayKind.forge => 'FORGE & RELICS',
              _OverlayKind.jobs => 'JOBS',
              _OverlayKind.sanctuary => 'SANCTUARY',
              _OverlayKind.none => '',
            },
            onClose: () => setState(() => _overlay = _OverlayKind.none),
            child: switch (_overlay) {
              _OverlayKind.forge => _ForgeOverlay(director: d),
              _OverlayKind.jobs => _JobsOverlay(director: d),
              _OverlayKind.sanctuary => _SanctuaryOverlay(director: d),
              _OverlayKind.none => const SizedBox.shrink(),
            },
          ),
      ],
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.state,
    required this.onReset,
    required this.onOpenForge,
    required this.onOpenJobs,
    required this.onOpenSanctuary,
  });

  final GameState state;
  final VoidCallback onReset;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenSanctuary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: const BoxDecoration(
        color: Color(0xEE1A1610),
        border: Border(bottom: BorderSide(color: Color(0xFF6A5A38), width: 2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'IDLE PARTY',
                style: GoogleFonts.pressStart2p(
                  fontSize: 11,
                  color: const Color(0xFFFFE08A),
                ),
              ),
              const Spacer(),
              _Chip(icon: KenneyAssets.coinGold, label: '${state.gold}'),
              const SizedBox(width: 8),
              _Chip(icon: KenneyAssets.potionBlue, label: '${state.essence}'),
              const SizedBox(width: 8),
              _Chip(
                icon: KenneyAssets.iconCrown,
                label: 'AL${state.ascensionLevel}',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onReset,
                icon: KenneySprite(asset: KenneyAssets.iconSkull, size: 18),
                tooltip: 'Hard reset',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _HudLink(label: 'FORGE', onTap: onOpenForge),
              const SizedBox(width: 6),
              _HudLink(label: 'JOBS', onTap: onOpenJobs),
              const SizedBox(width: 6),
              _HudLink(label: 'SANCT', onTap: onOpenSanctuary),
              const Spacer(),
              Text(
                state.activePet == null
                    ? 'No pet'
                    : '${state.activePet!.name} +${state.petAttackBonus}',
                style: const TextStyle(fontSize: 14, color: Color(0xFFD7CAA0)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudLink extends StatelessWidget {
  const _HudLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2418),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF7A6840)),
        ),
        child: Text(
          label,
          style: GoogleFonts.pressStart2p(
            fontSize: 8,
            color: const Color(0xFFFFE8AA),
          ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KenneySprite(asset: icon, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.pressStart2p(
            fontSize: 9,
            color: const Color(0xFFFFF0C8),
          ),
        ),
      ],
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
    required this.onUnequipWeapon,
    required this.onUnequipArmor,
    required this.onClearCombineA,
    required this.onClearCombineB,
    required this.onCombine,
    required this.onHatchPet,
    required this.onSetPet,
  });

  final GameState state;
  final String? selectedId;
  final String? combineA;
  final String? combineB;
  final void Function(String id) onSelect;
  final void Function(String id) onPutCombine;
  final VoidCallback onEquip;
  final VoidCallback onSell;
  final VoidCallback onUnequipWeapon;
  final VoidCallback onUnequipArmor;
  final VoidCallback onClearCombineA;
  final VoidCallback onClearCombineB;
  final VoidCallback onCombine;
  final VoidCallback onHatchPet;
  final void Function(String id) onSetPet;

  EquipmentItem? _find(String? id) {
    if (id == null) return null;
    return GameLogic.findGear(state, id);
  }

  @override
  Widget build(BuildContext context) {
    final primary = _find(combineA);
    final secondary = _find(combineB);
    final canCombine = primary != null &&
        secondary != null &&
        GameLogic.canCombine(primary, secondary);
    final cost = canCombine ? GameLogic.combineCost(primary, secondary) : 0;
    final slots = List<EquipmentItem?>.generate(
      GameLogic.maxGearStash,
      (i) => i < state.gearStash.length ? state.gearStash[i] : null,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF214120E),
        border: Border(top: BorderSide(color: Color(0xFF6A5A38), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'EQUIP',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: const Color(0xFFFFE8AA),
                  ),
                ),
                const SizedBox(height: 4),
                _EquipTile(
                  label: 'WPN',
                  item: state.equippedWeapon,
                  selected: state.equippedWeapon?.id == selectedId,
                  onTap: state.equippedWeapon == null
                      ? null
                      : () => onSelect(state.equippedWeapon!.id),
                  onUnequip: state.equippedWeapon == null
                      ? null
                      : onUnequipWeapon,
                ),
                const SizedBox(height: 4),
                _EquipTile(
                  label: 'ARM',
                  item: state.equippedArmor,
                  selected: state.equippedArmor?.id == selectedId,
                  onTap: state.equippedArmor == null
                      ? null
                      : () => onSelect(state.equippedArmor!.id),
                  onUnequip:
                      state.equippedArmor == null ? null : onUnequipArmor,
                ),
                const Spacer(),
                KenneyButton(
                  label: 'EQUIP',
                  onPressed: selectedId == null ? null : onEquip,
                ),
                const SizedBox(height: 4),
                KenneyButton(
                  label: 'SELL',
                  onPressed: selectedId == null && combineA == null
                      ? null
                      : onSell,
                  style: KenneyButtonStyle.grey,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'BAG  ${state.gearStash.length}/${GameLogic.maxGearStash}',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: const Color(0xFFFFE8AA),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: GridView.builder(
                    itemCount: slots.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final item = slots[index];
                      final selected = item != null && item.id == selectedId;
                      final inCombine = item != null &&
                          (item.id == combineA || item.id == combineB);
                      return _BagSlot(
                        item: item,
                        highlight: selected || inCombine,
                        onTap: item == null ? null : () => onSelect(item.id),
                        onLongPress: item == null
                            ? null
                            : () => onPutCombine(item.id),
                      );
                    },
                  ),
                ),
                const Text(
                  'Tap select Â· Hold â†’ combinator',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A8E70)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'COMBINATOR',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: const Color(0xFFFFE8AA),
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
                KenneyButton(
                  label: canCombine && state.gold >= cost
                      ? 'MERGE $cost'
                      : 'MERGE',
                  onPressed:
                      canCombine && state.gold >= cost ? onCombine : null,
                  style: KenneyButtonStyle.red,
                ),
                const Spacer(),
                KenneyButton(
                  label: 'PET ${GameLogic.hatchPetCost(state)}e',
                  onPressed: state.essence >= GameLogic.hatchPetCost(state)
                      ? onHatchPet
                      : null,
                ),
                if (state.ownedPets.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final pet in state.ownedPets)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: InkWell(
                              onTap: () => onSetPet(pet.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
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
                                child: Text(
                                  pet.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipTile extends StatelessWidget {
  const _EquipTile({
    required this.label,
    required this.item,
    required this.selected,
    this.onTap,
    this.onUnequip,
  });

  final String label;
  final EquipmentItem? item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onUnequip,
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A3420) : const Color(0xFF1C1914),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFE0B050) : const Color(0xFF5A5040),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.pressStart2p(
                fontSize: 7,
                color: const Color(0xFFD7CAA0),
              ),
            ),
            const SizedBox(width: 4),
            if (item != null)
              Expanded(
                child: KenneySprite(
                  asset: KenneyAssets.equipmentIconFor(item!),
                  size: 28,
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

class _BagSlot extends StatelessWidget {
  const _BagSlot({
    required this.item,
    required this.highlight,
    this.onTap,
    this.onLongPress,
  });

  final EquipmentItem? item;
  final bool highlight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFF4A3420) : const Color(0xFF1C1914),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: highlight
                ? const Color(0xFFE0B050)
                : const Color(0xFF5A5040),
          ),
        ),
        child: item == null
            ? const SizedBox.expand()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KenneySprite(
                    asset: KenneyAssets.equipmentIconFor(item!),
                    size: 26,
                  ),
                  Text(
                    'P${item!.powerScore}',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 6,
                      color: const Color(0xFFD7CAA0),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CombineSlot extends StatelessWidget {
  const _CombineSlot({
    required this.label,
    required this.item,
    this.onClear,
  });

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
            Text(
              label,
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: const Color(0xFFFFE8AA),
              ),
            ),
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
    return Positioned.fill(
      child: Material(
        color: const Color(0xCC000000),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1610),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8A7848), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: const Color(0xFFFFE8AA),
                          ),
                        ),
                        const Spacer(),
                        KenneyButton(
                          label: 'CLOSE',
                          onPressed: onClose,
                          style: KenneyButtonStyle.grey,
                          expanded: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: SingleChildScrollView(child: child)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgeOverlay extends StatelessWidget {
  const _ForgeOverlay({required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final training = GameLogic.partyTrainingCostFor(state);
    final canAscend = GameLogic.canAscend(state);
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
              ? 'ASCEND â†’ AL${state.ascensionLevel + 1}'
              : 'ASCEND (need bosses)',
          onPressed: canAscend ? director.ascend : null,
          style: KenneyButtonStyle.red,
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'Train $training g',
          onPressed: state.gold >= training ? director.applyTraining : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'Attack ${GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)}',
          onPressed: state.gold >=
                  GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)
              ? director.upgradeAttack
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'Defense ${GameLogic.upgradeCostFor(state, PartyUpgradeType.defense)}',
          onPressed: state.gold >=
                  GameLogic.upgradeCostFor(state, PartyUpgradeType.defense)
              ? director.upgradeDefense
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'Vitality ${GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality)}',
          onPressed: state.gold >=
                  GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality)
              ? director.upgradeVitality
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          'RELICS',
          style: GoogleFonts.pressStart2p(
            fontSize: 8,
            color: const Color(0xFFFFE8AA),
          ),
        ),
        const SizedBox(height: 6),
        for (final relicId in GameLogic.relicOrder) ...[
          KenneyButton(
            label:
                '${GameLogic.relicNames[relicId]} ${GameLogic.relicCosts[relicId]}e',
            onPressed: state.hasRelic(relicId) ||
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
                      Text(
                        mission.title,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: const Color(0xFFFFE8AA),
                        ),
                      ),
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
          KenneyButton(
            label:
                '${GameLogic.sanctuaryNames[track]} Lv'
                '${switch (track) {
                  'gold' => state.sanctuaryGoldLevel,
                  'power' => state.sanctuaryPowerLevel,
                  _ => state.sanctuaryVitalityLevel,
                }}  '
                '${GameLogic.sanctuaryCost(switch (track) {
                  'gold' => state.sanctuaryGoldLevel,
                  'power' => state.sanctuaryPowerLevel,
                  _ => state.sanctuaryVitalityLevel,
                })}e',
            onPressed: state.essence >=
                    GameLogic.sanctuaryCost(switch (track) {
                      'gold' => state.sanctuaryGoldLevel,
                      'power' => state.sanctuaryPowerLevel,
                      _ => state.sanctuaryVitalityLevel,
                    })
                ? () => director.upgradeSanctuary(track)
                : null,
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
