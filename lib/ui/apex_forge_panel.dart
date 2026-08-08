import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../models/apex_craft.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import 'character_equip_panel.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'kenney_assets.dart';
import 'menu_chrome.dart';

/// Materials Bag browser (boss-only craft mats).
class ApexMaterialsPanel extends StatelessWidget {
  const ApexMaterialsPanel({super.key, required this.director});

  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final owned = ApexCraft.materials
        .where((m) => (state.craftMaterials[m.id] ?? 0) > 0)
        .toList();
    final missing = ApexCraft.materials
        .where((m) => (state.craftMaterials[m.id] ?? 0) <= 0)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Boss mats for Apex craft. Survive Ascend. Not in the gear bag.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Text(
          'Zone shards from that boss · cores any boss · Slag from Gauntlet/Spire.',
          style: GameTheme.body(size: 12, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 10),
        if (owned.isEmpty)
          Text(
            'No materials yet — clear dungeon bosses in PUSH.',
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          )
        else ...[
          Text('OWNED', style: GameTheme.pixel(size: 7)),
          const SizedBox(height: 4),
          for (final m in owned) _matRow(m, state.craftMaterials[m.id] ?? 0),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('NOT FOUND YET', style: GameTheme.pixel(size: 7)),
          const SizedBox(height: 4),
          for (final m in missing) _matRow(m, 0),
        ],
      ],
    );
  }

  Widget _matRow(CraftMatDef m, int count) {
    final owned = count > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: MenuChrome.cardBox(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KenneySprite(
            asset: KenneyAssets.ring,
            size: 22,
            color: owned ? null : GameTheme.parchmentDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: GameTheme.pixel(
                    size: 7,
                    color: owned ? GameTheme.parchment : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.bossSources,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
          Text(
            owned ? '×$count' : '×0',
            style: GameTheme.pixel(
              size: 8,
              color: owned ? GameTheme.torchHot : GameTheme.parchmentDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Apex craft / upgrade / vault UI.
class ApexCraftPanel extends StatefulWidget {
  const ApexCraftPanel({super.key, required this.director});

  final GameDirector director;

  @override
  State<ApexCraftPanel> createState() => _ApexCraftPanelState();
}

class _ApexCraftPanelState extends State<ApexCraftPanel> {
  HeroClassId _apexClass = HeroClassId.warrior;
  SpecRoleTag _apexRole = SpecRoleTag.tank;
  EquipmentSlot _apexSlot = EquipmentSlot.weapon;

  GameDirector get director => widget.director;

  @override
  void initState() {
    super.initState();
    _syncApexRole();
  }

  void _syncApexRole() {
    final roles = ApexCraft.validRolesFor(_apexClass).toList();
    if (roles.isEmpty) return;
    if (!roles.contains(_apexRole)) {
      _apexRole = roles.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final roles = ApexCraft.validRolesFor(_apexClass).toList();
    final recipe = ApexCraft.recipe(
      classId: _apexClass,
      role: _apexRole,
      slot: _apexSlot,
      rank: 1,
    );
    final pieceId = ApexCraft.pieceId(
      classId: _apexClass,
      role: _apexRole,
      slot: _apexSlot,
    );
    dynamic existing;
    for (final i in state.apexVault) {
      if (i.id == pieceId) {
        existing = i;
        break;
      }
    }
    if (existing == null) {
      for (final h in state.heroRoster) {
        for (final i in h.equipped.values) {
          if (i.id == pieceId) {
            existing = i;
            break;
          }
        }
        if (existing != null) break;
      }
    }
    final existingItem = existing as EquipmentItem?;
    final canCraft = GameLogic.canCraftApex(
      state,
      classId: _apexClass,
      role: _apexRole,
      slot: _apexSlot,
    );
    final canUpgrade = existingItem != null &&
        GameLogic.canUpgradeApex(state, existingItem.id);
    final weaponGate = _apexSlot != EquipmentSlot.weapon &&
        !GameLogic.hasApexWeaponRank1(state, _apexClass, _apexRole);
    final missing = recipe.costs.entries
        .where((e) => (state.craftMaterials[e.key] ?? 0) < e.value)
        .toList();
    // Prefer the scarcest / most behind mat as the next farm target.
    missing.sort((a, b) {
      final aHave = state.craftMaterials[a.key] ?? 0;
      final bHave = state.craftMaterials[b.key] ?? 0;
      final aNeed = a.value - aHave;
      final bNeed = b.value - bHave;
      return bNeed.compareTo(aNeed);
    });
    final nextFarm = missing.isEmpty
        ? null
        : ApexCraft.materialsById[missing.first.key];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Craft Apex BiS from MATS (not gold). Weapon R1 unlocks armor · survives Ascend.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (nextFarm != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: MenuChrome.cardBox(selected: true),
            child: Text(
              'Next farm: ${nextFarm.name}\n→ ${nextFarm.bossSources}',
              style: GameTheme.body(size: 13, color: GameTheme.torchHot),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in HeroClassId.values)
              ChoiceChip(
                label: Text(
                  HeroSpecs.classLabel(c),
                  style: GameTheme.body(size: 12),
                ),
                selected: _apexClass == c,
                onSelected: (_) => setState(() {
                  _apexClass = c;
                  _syncApexRole();
                }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in roles)
              ChoiceChip(
                label: Text(_roleLabel(r), style: GameTheme.body(size: 12)),
                selected: _apexRole == r,
                onSelected: (_) => setState(() => _apexRole = r),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in ApexCraft.craftSlots)
              ChoiceChip(
                label: Text(_slotLabel(s), style: GameTheme.body(size: 12)),
                selected: _apexSlot == s,
                onSelected: (_) => setState(() => _apexSlot = s),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('RECIPE R1', style: GameTheme.pixel(size: 7)),
        const SizedBox(height: 4),
        for (final e in recipe.costs.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${ApexCraft.materialsById[e.key]?.name ?? e.key}  '
                  '${state.craftMaterials[e.key] ?? 0}/${e.value}',
                  style: GameTheme.body(
                    size: 13,
                    color: (state.craftMaterials[e.key] ?? 0) >= e.value
                        ? GameTheme.clear
                        : GameTheme.bloodLit,
                  ),
                ),
                if ((state.craftMaterials[e.key] ?? 0) < e.value)
                  Text(
                    '  → ${ApexCraft.materialsById[e.key]?.bossSources ?? 'boss drop'}',
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ),
          ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Need ${missing.length} more mat type${missing.length == 1 ? '' : 's'}. '
            'Clear the listed bosses in PUSH (Farm still ticks pity slowly).',
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Sources: ${recipe.bossSources.join(' · ')}',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (weaponGate) ...[
          const SizedBox(height: 6),
          Text(
            'Craft weapon R1 first for this class/role.',
            style: GameTheme.body(size: 13, color: GameTheme.bloodLit),
          ),
        ],
        const SizedBox(height: 8),
        KenneyButton(
          label: existingItem == null
              ? 'CRAFT R1'
              : 'OWNED R${existingItem.apexRank}',
          onPressed: canCraft
              ? () {
                  director.craftApex(
                    classId: _apexClass,
                    role: _apexRole,
                    slot: _apexSlot,
                  );
                  setState(() {});
                }
              : null,
        ),
        if (existingItem != null) ...[
          const SizedBox(height: 6),
          KenneyButton(
            label: existingItem.apexRank >= ApexCraft.maxRank
                ? 'MAX RANK'
                : 'UPGRADE → R${existingItem.apexRank + 1}',
            onPressed: canUpgrade
                ? () {
                    director.upgradeApex(existingItem.id);
                    setState(() {});
                  }
                : null,
          ),
          if (state.apexVault.any((i) => i.id == existingItem.id)) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: 'EQUIP FROM VAULT',
              onPressed: () {
                director.equipFromApexVault(existingItem.id);
                setState(() {});
              },
            ),
          ],
        ],
        const SizedBox(height: 12),
        Text(
          'VAULT (${state.apexVault.length})',
          style: GameTheme.pixel(size: 7),
        ),
        const SizedBox(height: 4),
        if (state.apexVault.isEmpty)
          Text(
            'Empty — craft to fill.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          )
        else
          for (final item in state.apexVault)
            Text(
              '${item.name}  R${item.apexRank}',
              style: GameTheme.body(size: 13, color: GameTheme.torchHot),
            ),
      ],
    );
  }

  static String _roleLabel(SpecRoleTag r) => switch (r) {
        SpecRoleTag.tank => 'Tank',
        SpecRoleTag.healer => 'Healer',
        SpecRoleTag.meleeDps => 'Melee DPS',
        SpecRoleTag.rangedDps => 'Ranged DPS',
        SpecRoleTag.caster => 'Caster',
      };

  static String _slotLabel(EquipmentSlot s) =>
      CharacterEquipPanel.slotLabels[s] ?? s.name;
}
