import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../apex_forge_panel.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';

class ForgeOverlay extends StatefulWidget {
  const ForgeOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<ForgeOverlay> createState() => _ForgeOverlayState();
}

class _ForgeOverlayState extends State<ForgeOverlay>
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
    return KenneyButton(label: label, onPressed: onPressed);
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
              SingleChildScrollView(child: ApexCraftPanel(director: director)),
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
                GameLogic.warBannerRelic =>
                  owned
                      ? 'Permanent +${state.relicAttackBonus} team attack (T$tier).'
                      : 'Permanent +4 team attack per tier.',
                GameLogic.ironWardRelic =>
                  owned
                      ? 'Permanent +${state.relicDefenseBonus} team defense (T$tier).'
                      : 'Permanent +2 team defense per tier.',
                GameLogic.phoenixEmberRelic =>
                  owned
                      ? 'Permanent +${state.relicVitalityBonus} max HP per hero (T$tier).'
                      : 'Permanent +10 max HP per hero per tier.',
                GameLogic.godHandFocusRelic =>
                  owned
                      ? '+${state.relicGodHandDamageBonus} God Hand damage (T$tier).'
                      : '+3 God Hand damage per tier.',
                GameLogic.chamberLuckRelic =>
                  owned
                      ? '+${state.relicLootFindPercent}% loot find (T$tier).'
                      : '+5% loot find per tier.',
                GameLogic.ironWillRelic =>
                  owned
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
                          label: owned ? '$name  ·  T$tier' : '$name  ${cost}e',
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
          onPressed:
              (state.unlockedRelics.isNotEmpty ||
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
                label: state.metaDepth.soulboundIsArmor ? 'WEAPON' : 'WEAPON ✓',
                style: state.metaDepth.soulboundIsArmor
                    ? KenneyButtonStyle.grey
                    : KenneyButtonStyle.brown,
                onPressed: () => director.setSoulboundPreferArmor(false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: KenneyButton(
                label: state.metaDepth.soulboundIsArmor ? 'ARMOR ✓' : 'ARMOR',
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
            onPressed:
                state.soulboundFragments >=
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
          onPressed:
              state.essence >= GameLogic.godHandUpgradeCost(state.godHandLevel)
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
