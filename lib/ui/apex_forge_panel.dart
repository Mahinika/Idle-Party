import 'package:flutter/material.dart';

import '../core/apex_forge.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/apex_craft.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import 'character_equip_panel.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// Materials + craft + vault in one station (POWER → Craft).
/// Goal-first: party goals → recipe + CRAFT → farm meter → collapsed bag/pickers.
class ApexHubPanel extends StatefulWidget {
  const ApexHubPanel({super.key, required this.director});

  final GameDirector director;

  @override
  State<ApexHubPanel> createState() => _ApexHubPanelState();
}

class _ApexHubPanelState extends State<ApexHubPanel> {
  HeroClassId _apexClass = HeroClassId.warrior;
  SpecRoleTag _apexRole = SpecRoleTag.tank;
  EquipmentSlot _apexSlot = EquipmentSlot.weapon;

  GameDirector get director => widget.director;

  @override
  void initState() {
    super.initState();
    _loadCraftGoalFromState();
  }

  void _loadCraftGoalFromState() {
    final goal = ApexForge.craftGoalFromState(director.state);
    if (goal != null) {
      _apexClass = goal.classId;
      _apexRole = goal.role;
      _apexSlot = goal.slot;
      return;
    }
    _defaultFromParty();
  }

  void _defaultFromParty() {
    final heroes = director.state.heroes;
    if (heroes.isEmpty) return;
    final h = heroes.first;
    _apexClass = h.spec.classId;
    _apexRole = h.spec.roleTag;
    _apexSlot = ApexForge.nextSlotForPair(
          director.state,
          _apexClass,
          _apexRole,
        ) ??
        EquipmentSlot.weapon;
    _syncApexRole();
  }

  void _syncApexRole() {
    final roles = ApexCraft.validRolesFor(_apexClass).toList();
    if (roles.isEmpty) return;
    if (!roles.contains(_apexRole)) {
      _apexRole = roles.first;
    }
    final slots = ApexCraft.craftSlotsFor(_apexClass, _apexRole);
    if (!slots.contains(_apexSlot)) {
      _apexSlot = slots.first;
    }
  }

  void _setCraftGoal(HeroClassId classId, SpecRoleTag role, EquipmentSlot slot) {
    setState(() {
      _apexClass = classId;
      _apexRole = role;
      _apexSlot = slot;
      _syncApexRole();
    });
    director.setApexCraftGoal(classId: classId, role: role, slot: slot);
  }

  static String _matIcon(CraftMatFamily family) => switch (family) {
    CraftMatFamily.shard => KenneyAssets.ring,
    CraftMatFamily.core => KenneyAssets.shieldRound,
    CraftMatFamily.catalyst => KenneyAssets.potionBlue,
    CraftMatFamily.slag => KenneyAssets.coinGold,
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final md = state.metaDepth;
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
    EquipmentItem? existingItem;
    for (final i in state.apexVault) {
      if (i.id == pieceId) {
        existingItem = i;
        break;
      }
    }
    if (existingItem == null) {
      for (final h in state.heroRoster) {
        for (final i in h.equipped.values) {
          if (i.id == pieceId) {
            existingItem = i;
            break;
          }
        }
        if (existingItem != null) break;
      }
    }
    final canCraft = GameLogic.canCraftApex(
      state,
      classId: _apexClass,
      role: _apexRole,
      slot: _apexSlot,
    );
    final canUpgrade =
        existingItem != null &&
        GameLogic.canUpgradeApex(state, existingItem.id);
    final weaponGate =
        _apexSlot != EquipmentSlot.weapon &&
        !GameLogic.hasApexWeaponRank1(state, _apexClass, _apexRole);
    final shortages = GameLogic.apexSortedMatShortages(
      state,
      classId: _apexClass,
      role: _apexRole,
      slot: _apexSlot,
    );
    final targetMatId = GameLogic.resolveApexTargetMatId(state);
    final targetDef = targetMatId != null
        ? ApexCraft.materialsById[targetMatId]
        : null;
    final targetProgress = md.apexTargetProgress;
    final targetRequired = ApexCraft.targetMeterRequired;
    final bossesLeft = GameLogic.apexBossesUntilTargetGrant(state);
    final manualTarget = md.apexTargetMatId.isNotEmpty;
    final goalLabel =
        '${HeroSpecs.classLabel(_apexClass)} · '
        '${_slotLabel(_apexSlot, _apexClass, _apexRole)} · '
        '${existingItem == null ? 'R1' : 'R${existingItem.apexRank}'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Boss mats · weapon R1 first · survives Ascend. Tap a party goal.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabelScoped('PARTY GOALS'),
        ..._partyGoalCards(state),
        const SizedBox(height: 10),
        MenuChrome.sectionLabelScoped('NOW CRAFTING'),
        Text(
          goalLabel,
          style: GameTheme.body(size: 14, color: GameTheme.torchHot),
        ),
        if (shortages.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Next farm: ${ApexCraft.materialsById[shortages.first.key]?.name ?? shortages.first.key}'
            ' → ${ApexCraft.materialsById[shortages.first.key]?.bossSources ?? 'boss drop'}',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 6),
        for (final e in recipe.costs.entries)
          _matProgressRow(
            state,
            e.key,
            e.value,
            selected: e.key == targetMatId,
            onTap: () {
              director.setApexTargetMat(e.key);
              setState(() {});
            },
          ),
        if (weaponGate) ...[
          const SizedBox(height: 4),
          Text(
            'Craft weapon R1 first for this class/role.',
            style: GameTheme.body(size: 12, color: GameTheme.bloodLit),
          ),
        ],
        const SizedBox(height: 6),
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
          const SizedBox(height: 4),
          KenneyButton(
            label: existingItem.apexRank >= ApexCraft.maxRank
                ? 'MAX RANK'
                : 'UPGRADE → R${existingItem.apexRank + 1}',
            style: KenneyButtonStyle.grey,
            onPressed: canUpgrade
                ? () {
                    director.upgradeApex(existingItem!.id);
                    setState(() {});
                  }
                : null,
          ),
        ],
        const SizedBox(height: 10),
        MenuChrome.sectionLabelScoped('FARM TARGET'),
        if (targetDef == null)
          Text(
            'Tap a recipe mat above to lock a farm target.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: MenuChrome.cardBox(selected: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  manualTarget
                      ? 'Locked: ${targetDef.name}'
                      : 'Chasing: ${targetDef.name}',
                  style: GameTheme.body(size: 13, color: GameTheme.torchHot),
                ),
                Text(
                  targetDef.bossSources,
                  style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: targetRequired > 0
                        ? (targetProgress / targetRequired).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 6,
                    backgroundColor: GameTheme.panelInset,
                    color: GameTheme.mossLit,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$targetProgress / $targetRequired · '
                  '${bossesLeft <= 0 ? 'READY on next boss' : '~$bossesLeft boss${bossesLeft == 1 ? '' : 'es'}'}',
                  style: GameTheme.body(size: 11, color: GameTheme.mossLit),
                ),
                if (manualTarget) ...[
                  const SizedBox(height: 4),
                  KenneyButton(
                    label: 'Use auto target',
                    style: KenneyButtonStyle.grey,
                    onPressed: () {
                      director.clearApexTargetMatOverride();
                      setState(() {});
                    },
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        _materialsBag(state),
        const SizedBox(height: 4),
        _changeGoalSection(roles),
        const SizedBox(height: 10),
        MenuChrome.sectionLabelScoped(
          'VAULT (${state.apexVault.length})',
        ),
        if (state.apexVault.isNotEmpty) ...[
          KenneyButton(
            label: 'AUTO EQUIP ALL',
            style: KenneyButtonStyle.grey,
            onPressed: () {
              director.autoEquipAllApex();
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          for (final item in state.apexVault) _vaultCard(state, item),
        ] else
          Text(
            'Empty — craft to fill. Auto-equip runs after craft when a hero matches.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        if (GameLogic.endgameUnlocked(state)) ...[
          const SizedBox(height: 12),
          Builder(
            builder: (_) {
              final month = GameLogic.isoMonthKey(DateTime.now().toUtc());
              final clearedThisMonth =
                  state.metaDepth.apexTrialMonthKey == month &&
                  state.metaDepth.apexTrialCleared;
              return KenneyButton(
                label: clearedThisMonth
                    ? 'CRAFT TRIAL · cleared this month'
                    : 'START CRAFT TRIAL (craft gear only)',
                style: KenneyButtonStyle.grey,
                onPressed: clearedThisMonth || state.inDungeon
                    ? null
                    : director.startApexTrial,
              );
            },
          ),
        ],
      ],
    );
  }

  List<Widget> _partyGoalCards(GameState state) {
    final cards = <Widget>[];
    for (var i = 0; i < state.heroes.length; i++) {
      final h = state.heroes[i];
      final classId = h.spec.classId;
      final role = h.spec.roleTag;
      if (!ApexCraft.isValidPair(classId, role)) continue;
      final slot = ApexForge.nextSlotForPair(state, classId, role) ??
          EquipmentSlot.weapon;
      final shortages = GameLogic.apexSortedMatShortages(
        state,
        classId: classId,
        role: role,
        slot: slot,
      );
      final have = shortages.isEmpty;
      final selected =
          _apexClass == classId && _apexRole == role && _apexSlot == slot;
      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: MenuChrome.listCard(selected: selected),
          child: InkWell(
            onTap: () => _setCraftGoal(classId, role, slot),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${h.roleLabel} · ${_slotLabel(slot, classId, role)}',
                        style: GameTheme.body(
                          size: 14,
                          color:
                              selected ? GameTheme.torchHot : GameTheme.parchment,
                        ),
                      ),
                      Text(
                        have
                            ? 'Ready to craft'
                            : '${shortages.length} mat type${shortages.length == 1 ? '' : 's'} short',
                        style: GameTheme.body(
                          size: 12,
                          color: have
                              ? GameTheme.mossLit
                              : GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Text(
                    'NOW',
                    style: GameTheme.pixel(
                      size: 9,
                      color: GameTheme.torchHot,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (cards.isEmpty) {
      return [
        Text(
          'No active heroes for craft goals.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
      ];
    }
    return cards;
  }

  Widget _materialsBag(GameState state) {
    final owned = ApexCraft.materials
        .where((m) => (state.craftMaterials[m.id] ?? 0) > 0)
        .toList();
    final top = owned.isEmpty
        ? null
        : owned.reduce(
            (a, b) => (state.craftMaterials[a.id] ?? 0) >=
                    (state.craftMaterials[b.id] ?? 0)
                ? a
                : b,
          );
    final subtitle = owned.isEmpty
        ? 'Empty — clear bosses in PUSH'
        : '${owned.length} type${owned.length == 1 ? '' : 's'}'
            '${top == null ? '' : ' · ${top.name} ×${state.craftMaterials[top.id] ?? 0}'}';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          'MATERIALS (${owned.length})',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        subtitle: Text(
          subtitle,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        iconColor: GameTheme.parchmentDim,
        collapsedIconColor: GameTheme.parchmentDim,
        children: [
          if (owned.isEmpty)
            Text(
              'No materials yet — clear bosses in PUSH.',
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            )
          else
            for (final m in owned)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: MenuChrome.cardBox(),
                child: Row(
                  children: [
                    KenneySprite(asset: _matIcon(m.family), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.name,
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchment,
                        ),
                      ),
                    ),
                    Text(
                      '×${state.craftMaterials[m.id] ?? 0}',
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _changeGoalSection(List<SpecRoleTag> roles) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          'CHANGE GOAL',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        subtitle: Text(
          '${HeroSpecs.classLabel(_apexClass)} · ${_roleLabel(_apexRole)} · '
          '${_slotLabel(_apexSlot, _apexClass, _apexRole)}',
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        iconColor: GameTheme.parchmentDim,
        collapsedIconColor: GameTheme.parchmentDim,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in HeroClassId.values)
                  IntrinsicWidth(
                    child: ChoiceChip(
                      label: Text(
                        HeroSpecs.classLabel(c),
                        style: GameTheme.body(size: 11),
                      ),
                      selected: _apexClass == c,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) {
                        _setCraftGoal(
                          c,
                          ApexCraft.validRolesFor(c).first,
                          EquipmentSlot.weapon,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in roles)
                  IntrinsicWidth(
                    child: ChoiceChip(
                      label: Text(
                        _roleLabel(r),
                        style: GameTheme.body(size: 11),
                      ),
                      selected: _apexRole == r,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) {
                        final slots = ApexCraft.craftSlotsFor(_apexClass, r);
                        final slot = slots.contains(_apexSlot)
                            ? _apexSlot
                            : EquipmentSlot.weapon;
                        _setCraftGoal(_apexClass, r, slot);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in ApexCraft.craftSlotsFor(_apexClass, _apexRole))
                  IntrinsicWidth(
                    child: ChoiceChip(
                      label: Text(
                        _slotLabel(s, _apexClass, _apexRole),
                        style: GameTheme.body(size: 11),
                      ),
                      selected: _apexSlot == s,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) =>
                          _setCraftGoal(_apexClass, _apexRole, s),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matProgressRow(
    GameState state,
    String matId,
    int need, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final have = state.craftMaterials[matId] ?? 0;
    final def = ApexCraft.materialsById[matId];
    final family = def?.family ?? CraftMatFamily.shard;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: MenuChrome.listCard(selected: selected),
          child: Row(
            children: [
              KenneySprite(asset: _matIcon(family), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${def?.name ?? matId}  $have/$need',
                      style: GameTheme.body(
                        size: 13,
                        color:
                            have >= need ? GameTheme.clear : GameTheme.bloodLit,
                      ),
                    ),
                    if (have < need)
                      Text(
                        def?.bossSources ?? 'boss drop',
                        style: GameTheme.body(
                          size: 11,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vaultCard(GameState state, EquipmentItem item) {
    final inVault = state.apexVault.any((g) => g.id == item.id);
    String? wornBy;
    for (final h in state.heroes) {
      for (final e in h.equipped.entries) {
        if (e.value.id == item.id) {
          wornBy = h.roleLabel;
          break;
        }
      }
      if (wornBy != null) break;
    }
    final status = wornBy != null
        ? 'Equipped · $wornBy'
        : (inVault ? 'In vault' : 'Equipped');
    final canUpgrade = GameLogic.canUpgradeApex(state, item.id);
    final bestHero = GameLogic.apexBestHeroIndexForItem(state, item);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: MenuChrome.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.name}  R${item.apexRank}',
            style: GameTheme.body(size: 13, color: GameTheme.torchHot),
          ),
          Text(
            status,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          if (inVault) ...[
            const SizedBox(height: 4),
            KenneyButton(
              label: bestHero != null
                  ? 'Equip on ${state.heroes[bestHero].roleLabel}'
                  : 'Equip best hero',
              onPressed: bestHero != null
                  ? () {
                      director.equipFromApexVault(
                        item.id,
                        heroIndex: bestHero,
                      );
                      setState(() {});
                    }
                  : null,
            ),
            if (canUpgrade) ...[
              const SizedBox(height: 4),
              KenneyButton(
                label: 'Upgrade → R${item.apexRank + 1}',
                style: KenneyButtonStyle.grey,
                onPressed: () {
                  director.upgradeApex(item.id);
                  setState(() {});
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _roleLabel(SpecRoleTag r) => switch (r) {
    SpecRoleTag.tank => 'Tank',
    SpecRoleTag.healer => 'Healer',
    SpecRoleTag.meleeDps => 'Melee DPS',
    SpecRoleTag.rangedDps => 'Ranged DPS',
    SpecRoleTag.caster => 'Caster',
  };

  String _slotLabel(EquipmentSlot s, HeroClassId classId, SpecRoleTag role) {
    if (s == EquipmentSlot.offHand) {
      return switch (ApexCraft.apexOffHandKind(classId, role)) {
        OffHandKind.shield => 'SHIELD',
        OffHandKind.frill => 'TOME',
        OffHandKind.weapon => 'OFFHAND',
        null => 'OFFHAND',
      };
    }
    return CharacterEquipPanel.slotLabels[s] ?? s.name;
  }
}
