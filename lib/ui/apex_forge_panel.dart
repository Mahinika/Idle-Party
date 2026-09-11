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
    CraftMatFamily.shard => UiIcon.ring,
    CraftMatFamily.core => UiIcon.shieldRound,
    CraftMatFamily.catalyst => UiIcon.flaskBlue,
    CraftMatFamily.slag => UiIcon.gold,
  };

  /// Honest farm line — don't point at Gauntlet before party max level.
  static String _farmSources(GameState state, String matId) {
    final def = ApexCraft.materialsById[matId];
    if (def == null) return 'boss drop';
    if (matId == ApexCraft.shardAnyId) {
      return 'Any dungeon boss · meter grants the zone you clear';
    }
    if (matId != ApexCraft.slagId) return def.bossSources;
    final crystalOpen = DungeonCatalog.isUnlocked(
      'crystal',
      GameLogic.partyMeanLevel(state),
      state.highestDungeonCleared,
    );
    if (GameLogic.endgameUnlocked(state)) {
      return 'Gauntlet bosses · Crystal Spire boss';
    }
    if (crystalOpen) {
      return 'Crystal Spire boss · Gauntlet after party '
          'Lv${GameLogic.maxHeroLevel}';
    }
    return 'Unlock Crystal Spire for slag · Gauntlet later';
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
    final pieceId = ApexCraft.pieceId(
      classId: classId,
      role: role,
      slot: slot,
    );
    for (final i in state.apexVault) {
      if (i.id == pieceId) return i;
    }
    for (final h in state.heroRoster) {
      for (final i in h.equipped.values) {
        if (i.id == pieceId) return i;
      }
    }
    return null;
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
          'Tap a hero, pick a slot, then CRAFT. Weapon R1 first. Keeps through Ascend.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
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
          goalLabel,
          style: GameTheme.body(size: 14, color: GameTheme.torchHot),
        ),
        if (existingItem != null && ownedRank < ApexCraft.maxRank) ...[
          const SizedBox(height: 2),
          Text(
            'Upgrade cost → R$pricingRank',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
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
            style: GameTheme.body(size: 12, color: GameTheme.bloodLit),
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
              return GameButton(
                label: clearedThisMonth
                    ? 'CRAFT TRIAL · cleared this month'
                    : 'START CRAFT TRIAL (craft gear only)',
                style: GameButtonStyle.grey,
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

  Widget _heroPicker(GameState state) {
    final heroes = [
      for (final h in state.heroes)
        if (ApexCraft.isValidPair(h.spec.classId, h.spec.roleTag)) h,
    ];
    if (heroes.isEmpty) {
      return Text(
        'No active heroes for craft. Open OTHER CLASS below.',
        style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
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
              final keepSlot = selected &&
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
          final rank = _existingPiece(
                state,
                _apexClass,
                _apexRole,
                slot,
              )?.apexRank ??
              0;
          final next = ApexForge.nextSlotForPair(
            state,
            _apexClass,
            _apexRole,
          );
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
            style: GameTheme.body(size: 13, color: GameTheme.torchHot),
          ),
          Text(
            _farmSources(state, targetDef.id),
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
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
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
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
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          )
        else ...[
          GameButton(
            label: 'AUTO EQUIP ALL',
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
            (a, b) => (state.craftMaterials[a.id] ?? 0) >=
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
                  GameIcon.asset(_matIcon(m.family), size: 18),
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
    );
  }

  Widget _changeGoalSection(List<SpecRoleTag> roles) {
    return MenuChrome.fold(
      title: 'OTHER CLASS',
      subtitle:
          '${HeroSpecs.classLabel(_apexClass)} · ${_roleLabel(_apexRole)}',
      children: [
        Text(
          'Craft for a class that is not in the active party. Slots stay in the row above.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
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
                      style: GameTheme.body(
                        size: 13,
                        color:
                            have >= need ? GameTheme.clear : GameTheme.bloodLit,
                      ),
                    ),
                    if (have < need)
                      Text(
                        _farmSources(state, matId),
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
            GameButton(
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
