import 'package:flutter/material.dart';

import '../core/apex_forge.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/apex_craft.dart';
import '../models/dungeon_def.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import 'character_equip_panel.dart';
import 'game_icon.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';

/// MORE → CRAFT: pick a hero, pick a slot, then CRAFT / UPGRADE.
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
    if (ApexForge.craftGoalFromState(director.state) != null) return;
    if (director.state.heroes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ApexForge.craftGoalFromState(director.state) != null) return;
      director.setApexCraftGoal(
        classId: _apexClass,
        role: _apexRole,
        slot: _apexSlot,
      );
    });
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
    _apexSlot =
        ApexForge.nextSlotForPair(director.state, _apexClass, _apexRole) ??
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

  void _setCraftGoal(
    HeroClassId classId,
    SpecRoleTag role,
    EquipmentSlot slot,
  ) {
    setState(() {
      _apexClass = classId;
      _apexRole = role;
      _apexSlot = slot;
      _syncApexRole();
    });
    director.setApexCraftGoal(classId: classId, role: role, slot: slot);
  }

  static String _matIcon(CraftMatFamily family) => switch (family) {
    CraftMatFamily.shard => UiIcon.ring,
    CraftMatFamily.core => UiIcon.shieldRound,
    CraftMatFamily.catalyst => UiIcon.flaskBlue,
    CraftMatFamily.slag => UiIcon.gold,
  };

  /// Drop line plus the meter. Slag drops are not the same as the meter.
  static String _farmSources(GameState state, String matId) {
    final def = ApexCraft.materialsById[matId];
    if (def == null) return 'boss drop';
    const meter = 'Any boss fills the meter once this is the target.';
    if (matId == ApexCraft.shardAnyId) {
      return 'Any boss fills the meter. It grants this cave\'s shard.';
    }
    if (matId != ApexCraft.slagId) return '${def.bossSources}. $meter';
    final crystalOpen = DungeonCatalog.isUnlocked(
      'crystal',
      GameLogic.partyMeanLevel(state),
      state.highestDungeonCleared,
    );
    if (GameLogic.endgameUnlocked(state)) {
      return 'Drops: Gauntlet and Crystal Spire bosses. $meter';
    }
    if (crystalOpen) {
      return 'Drops: Crystal Spire bosses. Gauntlet after party '
          'Lv${GameLogic.maxHeroLevel}. $meter';
    }
    final need = DungeonCatalog.unlockHeroLevel(DungeonCatalog.byId('crystal'));
    return 'Drops after Crystal Spire (party mean Lv$need). $meter';
  }

  static int _haveForMat(GameState state, String matId) {
    if (matId == ApexCraft.shardAnyId) {
      return ApexCraft.ownedShardCount(state.craftMaterials);
    }
    return state.craftMaterials[matId] ?? 0;
  }

  static EquipmentItem? _existingPiece(
    GameState state,
    HeroClassId classId,
    SpecRoleTag role,
    EquipmentSlot slot,
  ) {
    return ApexForge.findOwnedApex(
      state,
      ApexCraft.pieceId(classId: classId, role: role, slot: slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final md = state.metaDepth;
    final roles = ApexCraft.validRolesFor(_apexClass).toList();
    final existingItem = _existingPiece(
      state,
      _apexClass,
      _apexRole,
      _apexSlot,
    );
    final ownedRank = existingItem?.apexRank ?? 0;
    final pricingRank = existingItem == null
        ? 1
        : (ownedRank < ApexCraft.maxRank ? ownedRank + 1 : ownedRank);
    final fromRank = existingItem == null ? 0 : ownedRank;
    final recipeCosts = existingItem == null
        ? ApexCraft.absoluteCost(
            classId: _apexClass,
            role: _apexRole,
            slot: _apexSlot,
            rank: 1,
          )
        : ownedRank >= ApexCraft.maxRank
        ? const <String, int>{}
        : ApexCraft.upgradeDeltaCost(
            classId: _apexClass,
            role: _apexRole,
            slot: _apexSlot,
            fromRank: ownedRank,
            toRank: pricingRank,
          );
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
      rank: existingItem == null ? 1 : pricingRank,
      fromRank: fromRank,
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
        '${existingItem == null ? 'R1' : 'R$ownedRank'}';
    final String primaryLabel;
    final VoidCallback? primaryAction;
    if (existingItem == null) {
      primaryLabel = 'CRAFT R1';
      primaryAction = canCraft
          ? () {
              director.craftApex(
                classId: _apexClass,
                role: _apexRole,
                slot: _apexSlot,
              );
              setState(() {});
            }
          : null;
    } else if (ownedRank >= ApexCraft.maxRank) {
      primaryLabel = 'MAX RANK';
      primaryAction = null;
    } else {
      primaryLabel = 'UPGRADE → R$pricingRank';
      primaryAction = canUpgrade
          ? () {
              director.upgradeApex(existingItem.id);
              setState(() {});
            }
          : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tap a hero, pick a slot, then CRAFT. Opening this sheet saves that goal '
          'so bosses fill the meter. Weapon R1 first. Keeps through Ascend. '
          'DPS roll Crit + Haste; healers Mp5 + Crit + Haste.',
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabelScoped('HERO'),
        _heroPicker(state),
        const SizedBox(height: 8),
        MenuChrome.sectionLabelScoped('SLOT'),
        _slotPicker(state),
        const SizedBox(height: 10),
        MenuChrome.sectionLabelScoped('RECIPE'),
        Text(
          '$goalLabel${_pieceWhere(state, existingItem)}',
          style: GameTheme.readable(color: GameTheme.torchHot),
        ),
        if (existingItem != null && ownedRank < ApexCraft.maxRank) ...[
          const SizedBox(height: 2),
          Text(
            'Upgrade cost → R$pricingRank',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
        ],
        ..._rankPreview(state, existingItem, pricingRank),
        const SizedBox(height: 6),
        for (final e in recipeCosts.entries)
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
            style: GameTheme.hint(color: GameTheme.bloodLit),
          ),
        ],
        if (shortages.isNotEmpty && targetDef != null) ...[
          const SizedBox(height: 8),
          _farmMeter(
            state: state,
            targetDef: targetDef,
            targetProgress: targetProgress,
            targetRequired: targetRequired,
            bossesLeft: bossesLeft,
            manualTarget: manualTarget,
          ),
        ],
        const SizedBox(height: 8),
        GameButton(label: primaryLabel, onPressed: primaryAction),
        if (_craftBlockReason(
              existing: existingItem,
              ownedRank: ownedRank,
              canAct: primaryAction != null,
              weaponGate: weaponGate,
            )
            case final reason?) ...[
          const SizedBox(height: 4),
          Text(
            reason,
            style: GameTheme.hint(color: GameTheme.bloodLit),
          ),
        ],
        const SizedBox(height: 8),
        _materialsBag(state),
        const SizedBox(height: 4),
        _changeGoalSection(roles),
        const SizedBox(height: 4),
        _vaultSection(state),
        if (GameLogic.endgameUnlocked(state)) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              final month = GameLogic.isoMonthKey(DateTime.now().toUtc());
              final clearedThisMonth =
                  state.metaDepth.apexTrialMonthKey == month &&
                  state.metaDepth.apexTrialCleared;
              final apexNames = <String>[
                for (final hero in state.heroes)
                  for (final item in hero.equipped.values)
                    if (item.isApex) item.name,
              ];
              final apexLine = apexNames.isEmpty
                  ? 'This month the trial counts Apex only. None is worn yet.'
                  : 'This month the trial counts ${apexNames.take(2).join(', ')}.';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    apexLine,
                    textAlign: TextAlign.center,
                    style: GameTheme.hint(color: GameTheme.torchHot),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Worn gear that is not Apex counts as empty. Forge and blessings still apply.',
                    textAlign: TextAlign.center,
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                  const SizedBox(height: 6),
                  GameButton(
                    label: clearedThisMonth
                        ? 'CRAFT TRIAL · cleared this month'
                        : 'START CRAFT TRIAL',
                    style: GameButtonStyle.grey,
                    onPressed: clearedThisMonth || state.inDungeon
                        ? null
                        : director.startApexTrial,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  static String _pieceWhere(GameState state, EquipmentItem? item) {
    if (item == null) return '';
    for (final hero in state.heroRoster) {
      for (final worn in hero.equipped.values) {
        if (worn.id == item.id && worn.isApex) return ' · worn';
      }
    }
    if (state.gearStash.any((g) => g.id == item.id && g.isApex)) {
      return ' · in bag';
    }
    if (state.apexVault.any((g) => g.id == item.id && g.isApex)) {
      return ' · in vault';
    }
    return '';
  }

  List<Widget> _rankPreview(
    GameState state,
    EquipmentItem? existing,
    int pricingRank,
  ) {
    if (existing != null && existing.apexRank >= ApexCraft.maxRank) {
      return [
        const SizedBox(height: 4),
        Text(
          existing.statsLine,
          style: GameTheme.hint(color: GameTheme.parchment),
        ),
      ];
    }
    final next = ApexCraft.buildItem(
      classId: _apexClass,
      role: _apexRole,
      slot: _apexSlot,
      rank: pricingRank,
      ascensionLevel: state.ascensionLevel,
    );
    if (existing == null) {
      return [
        const SizedBox(height: 4),
        Text(
          'Crafts at AL${state.ascensionLevel}',
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
        Text(
          next.statsLine,
          style: GameTheme.hint(color: GameTheme.parchment),
        ),
      ];
    }
    return [
      const SizedBox(height: 4),
      Text(
        'Now · ${existing.statsLine}',
        style: GameTheme.hint(color: GameTheme.parchmentDim),
      ),
      Text(
        'Next · ${_statDelta(existing, next)}',
        style: GameTheme.hint(color: GameTheme.parchment),
      ),
    ];
  }

  static String _statDelta(EquipmentItem from, EquipmentItem to) {
    final bits = <String>[];
    if (from.itemLevel != to.itemLevel) {
      bits.add('i${from.itemLevel}→i${to.itemLevel}');
    } else {
      bits.add('i${to.itemLevel}');
    }
    void add(String name, int before, int after) {
      final delta = after - before;
      if (delta == 0) return;
      bits.add('${delta > 0 ? '+' : ''}$delta $name');
    }

    add('Str', from.strengthBonus, to.strengthBonus);
    add('Agi', from.agilityBonus, to.agilityBonus);
    add('Sta', from.staminaBonus, to.staminaBonus);
    add('Int', from.intellectBonus, to.intellectBonus);
    add('Spi', from.spiritBonus, to.spiritBonus);
    add('SP', from.spellPowerBonus, to.spellPowerBonus);
    add('Armor', from.armorBonus, to.armorBonus);
    add('AP', from.attackBonus, to.attackBonus);
    add('Mp5', from.mp5Bonus, to.mp5Bonus);
    add('CRIT', from.critChanceBonus, to.critChanceBonus);
    add('Mastery', from.masteryBonus, to.masteryBonus);
    add('Haste', from.attackSpeedBonus, to.attackSpeedBonus);
    return bits.join(' · ');
  }

  static String? _craftBlockReason({
    required EquipmentItem? existing,
    required int ownedRank,
    required bool canAct,
    required bool weaponGate,
  }) {
    if (canAct || weaponGate) return null;
    if (existing != null && ownedRank >= ApexCraft.maxRank) return null;
    return 'Need the materials above.';
  }

  Widget _heroPicker(GameState state) {
    final heroes = [
      for (final h in state.heroes)
        if (ApexCraft.isValidPair(h.spec.classId, h.spec.roleTag)) h,
    ];
    if (heroes.isEmpty) {
      return Text(
        'No active heroes for craft. Open Other classes below.',
        style: GameTheme.section(color: GameTheme.parchmentDim),
      );
    }
    return SizedBox(
      height: GameTheme.minTouch,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: heroes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final h = heroes[i];
          final classId = h.spec.classId;
          final role = h.spec.roleTag;
          final selected = _apexClass == classId && _apexRole == role;
          return MenuChrome.chip(
            label: h.roleLabel,
            selected: selected,
            onTap: () {
              final keepSlot =
                  selected &&
                  ApexCraft.craftSlotsFor(classId, role).contains(_apexSlot);
              final slot = keepSlot
                  ? _apexSlot
                  : (ApexForge.nextSlotForPair(state, classId, role) ??
                        EquipmentSlot.weapon);
              _setCraftGoal(classId, role, slot);
            },
          );
        },
      ),
    );
  }

  Widget _slotPicker(GameState state) {
    final slots = ApexCraft.craftSlotsFor(_apexClass, _apexRole);
    return SizedBox(
      height: GameTheme.minTouch,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final slot = slots[i];
          final rank =
              _existingPiece(state, _apexClass, _apexRole, slot)?.apexRank ?? 0;
          final next = ApexForge.nextSlotForPair(state, _apexClass, _apexRole);
          return MenuChrome.chip(
            label: _slotLabel(slot, _apexClass, _apexRole),
            value: rank > 0 ? 'R$rank' : (slot == next ? 'NEXT' : null),
            selected: _apexSlot == slot,
            onTap: () => _setCraftGoal(_apexClass, _apexRole, slot),
          );
        },
      ),
    );
  }

  Widget _farmMeter({
    required GameState state,
    required CraftMatDef targetDef,
    required int targetProgress,
    required int targetRequired,
    required int bossesLeft,
    required bool manualTarget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: MenuChrome.cardBox(selected: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            manualTarget
                ? 'Farm locked: ${targetDef.name}'
                : 'Farm: ${targetDef.name}',
            style: GameTheme.section(color: GameTheme.torchHot),
          ),
          Text(
            _farmSources(state, targetDef.id),
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(GameTheme.radiusHud),
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
            style: GameTheme.hint(color: GameTheme.mossLit),
          ),
          if (manualTarget) ...[
            const SizedBox(height: 4),
            GameButton(
              label: 'Use auto target',
              style: GameButtonStyle.grey,
              onPressed: () {
                director.clearApexTargetMatOverride();
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _vaultSection(GameState state) {
    return MenuChrome.fold(
      title: 'VAULT (${state.apexVault.length})',
      subtitle: state.apexVault.isEmpty
          ? 'Empty — craft to fill'
          : 'Equip crafted Apex',
      children: [
        if (state.apexVault.isEmpty)
          Text(
            'Empty — craft to fill. Auto-equip runs after craft when a hero matches.',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          )
        else ...[
          GameButton(
            label: 'EQUIP ALL',
            style: GameButtonStyle.grey,
            onPressed: () {
              director.autoEquipAllApex();
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          for (final item in state.apexVault) _vaultCard(state, item),
        ],
      ],
    );
  }

  Widget _materialsBag(GameState state) {
    final owned = ApexCraft.materials
        .where(
          (m) =>
              m.id != ApexCraft.shardAnyId &&
              (state.craftMaterials[m.id] ?? 0) > 0,
        )
        .toList();
    final top = owned.isEmpty
        ? null
        : owned.reduce(
            (a, b) =>
                (state.craftMaterials[a.id] ?? 0) >=
                    (state.craftMaterials[b.id] ?? 0)
                ? a
                : b,
          );
    final subtitle = owned.isEmpty
        ? 'Empty — clear bosses in PUSH'
        : '${owned.length} type${owned.length == 1 ? '' : 's'}'
              '${top == null ? '' : ' · ${top.name} ×${state.craftMaterials[top.id] ?? 0}'}';

    return MenuChrome.fold(
      title: 'MATERIALS (${owned.length})',
      subtitle: subtitle,
      children: [
        if (owned.isEmpty)
          Text(
            'No materials yet — clear bosses in PUSH.',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          )
        else
          for (final m in owned)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: MenuChrome.cardBox(),
              child: Row(
                children: [
                  GameIcon.asset(_matIcon(m.family), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.name,
                      style: GameTheme.section(color: GameTheme.parchment),
                    ),
                  ),
                  Text(
                    '×${state.craftMaterials[m.id] ?? 0}',
                    style: GameTheme.section(color: GameTheme.torchHot),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _changeGoalSection(List<SpecRoleTag> roles) {
    return MenuChrome.fold(
      title: 'Other classes',
      subtitle:
          '${HeroSpecs.classLabel(_apexClass)} · ${_roleLabel(_apexRole)}',
      children: [
        Text(
          'Craft for a class that is not in the active party. Slots stay in the row above.',
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in HeroClassId.values)
                MenuChrome.chip(
                  label: HeroSpecs.classLabel(c),
                  selected: _apexClass == c,
                  onTap: () {
                    _setCraftGoal(
                      c,
                      ApexCraft.validRolesFor(c).first,
                      EquipmentSlot.weapon,
                    );
                  },
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
                MenuChrome.chip(
                  label: _roleLabel(r),
                  selected: _apexRole == r,
                  onTap: () {
                    final slots = ApexCraft.craftSlotsFor(_apexClass, r);
                    final slot = slots.contains(_apexSlot)
                        ? _apexSlot
                        : EquipmentSlot.weapon;
                    _setCraftGoal(_apexClass, r, slot);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _matProgressRow(
    GameState state,
    String matId,
    int need, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final have = _haveForMat(state, matId);
    final def = ApexCraft.materialsById[matId];
    final family = def?.family ?? CraftMatFamily.shard;
    final label = matId == ApexCraft.shardAnyId
        ? 'Zone Shards (any)'
        : (def?.name ?? matId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: MenuChrome.listCard(selected: selected),
          child: Row(
            children: [
              GameIcon.asset(_matIcon(family), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label  $have/$need',
                      style: GameTheme.section(color: have >= need
                            ? GameTheme.clear
                            : GameTheme.bloodLit),
                    ),
                    if (have < need)
                      Text(
                        _farmSources(state, matId),
                        style: GameTheme.hint(color: GameTheme.parchmentDim),
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
            style: GameTheme.section(color: GameTheme.torchHot),
          ),
          Text(
            status,
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          if (inVault) ...[
            const SizedBox(height: 4),
            GameButton(
              label: bestHero != null
                  ? 'Equip on ${state.heroes[bestHero].roleLabel}'
                  : (GameLogic.apexEquipBlockReason(state, item.id) ??
                        'No matching hero in party'),
              onPressed: bestHero != null
                  ? () {
                      director.equipFromApexVault(item.id, heroIndex: bestHero);
                      setState(() {});
                    }
                  : null,
            ),
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
