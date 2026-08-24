import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
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
  ForgeGoldSpendMode _spendMode = ForgeGoldSpendMode.one;

  GameDirector get director => widget.director;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
    final preview =
        GameLogic.previewForgeGoldSpend(state, type, _spendMode);
    final bonus = switch (type) {
      PartyUpgradeType.attack => '+${state.attackBonus}',
      PartyUpgradeType.defense => '+${state.defenseBonus}',
      PartyUpgradeType.vitality => '+${state.vitalityBonus} HP',
      PartyUpgradeType.moveSpeed =>
        '+${GameState.softForgePercent(state.moveSpeedBonus).round()}%',
      PartyUpgradeType.attackSpeed =>
        '+${GameState.softForgePercent(state.attackSpeedBonus).round()}%',
      PartyUpgradeType.crit =>
        '+${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%',
    };
    final speedHint = switch (type) {
      PartyUpgradeType.attack ||
      PartyUpgradeType.moveSpeed ||
      PartyUpgradeType.attackSpeed => ' · faster clears',
      _ => '',
    };
    final name = switch (type) {
      PartyUpgradeType.attack => 'ATK',
      PartyUpgradeType.defense => 'DEF',
      PartyUpgradeType.vitality => 'STA',
      PartyUpgradeType.moveSpeed => 'MOVE',
      PartyUpgradeType.attackSpeed => 'HASTE',
      PartyUpgradeType.crit => 'CRIT',
    };
    final String costPart;
    if (onPressed == null) {
      costPart = 'Need ${cost}g';
    } else if (_spendMode == ForgeGoldSpendMode.one) {
      costPart = '${cost}g';
    } else {
      costPart =
          '${_spendMode.chipLabel} · ${preview.buys}× · ${preview.spent}g';
    }
    final label = recommended
        ? 'BEST · $name $bonus$speedHint · $costPart'
        : '$name $bonus$speedHint · $costPart';
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
          tabs: [
            for (final entry in <(String, int)>[
              ('GOLD', 0),
              ('KEEP', 1),
              ('APEX', 2),
            ])
              MenuChrome.bridgedTab(
                entry.$1,
                onSelect: () {
                  _tabs.animateTo(entry.$2);
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _tabs.index,
            children: [
              SingleChildScrollView(child: _classicForgeBody()),
              SingleChildScrollView(child: _metaForgeBody()),
              SingleChildScrollView(child: ApexHubPanel(director: director)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    String title,
    String blurb, {
    MenuScope? scope,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabelScoped(title, scope: scope),
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
          'Hub / Run rates → POWER → INCOME.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (director.lastFloorClearSec != null)
          Text(
            'Last floor ${director.lastFloorClearSec}s — ATK / HASTE / MOVE '
            'make the next one faster.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        const SizedBox(height: 4),
        Text(
          'Bought: ATK +${state.attackBonus}  DEF +${state.defenseBonus}  '
          'STA +${state.vitalityBonus} HP  '
          'MOVE +${GameState.softForgePercent(state.moveSpeedBonus).round()}%  '
          'HASTE +${GameState.softForgePercent(state.attackSpeedBonus).round()}%  '
          'CRIT +${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          'Each hero gets these forge bonuses on top of their own gear.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _sectionTitle(
          'BONUSES (GOLD)',
          'One buy is meant to feel similar: +${GameLogic.forgeAttackGain} ATK, '
              '+${GameLogic.forgeDefenseGain} DEF (armor), '
              '+${GameLogic.forgeVitalityGain} HP, '
              '+${GameLogic.forgeHasteGain}% HASTE or CRIT. '
              'BEST marks the cheapest relative gain. All wipe when you Ascend.',
          scope: MenuScope.run,
        ),
        Text(
          'Spend amount (wallet gold):',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final mode in ForgeGoldSpendMode.values)
              ChoiceChip(
                label: Text(mode.chipLabel, style: GameTheme.body(size: 12)),
                selected: _spendMode == mode,
                onSelected: (_) => setState(() => _spendMode = mode),
              ),
          ],
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: GameLogic.canForgeGoldSpendEven(state)
              ? 'SPEND ALL · EVEN'
              : 'SPEND ALL · EVEN · Need gold',
          onPressed: GameLogic.canForgeGoldSpendEven(state)
              ? () {
                  director.upgradeSpendAllEvenly();
                  setState(() {});
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            'EVEN splits wallet gold round-robin across ATK / DEF / STA / '
            'MOVE / HASTE / CRIT until you cannot buy another step.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ),
        for (final type in PartyUpgradeType.values) ...[
          _upgradeButton(
            state: state,
            type: type,
            onPressed: GameLogic.canForgeGoldSpend(state, type, _spendMode)
                ? () {
                    director.upgradePartyTrack(type, mode: _spendMode);
                    setState(() {});
                  }
                : null,
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 8),
        _sectionTitle(
          'TRAIN (LEVELS)',
          'Pays gold · +1 level to every hero · levels survive Ascend.',
          scope: MenuScope.account,
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
          GameLogic.isMaxAscension(state)
              ? 'AL20 · max Ascension — endgame: KEY, Gauntlet, Rifts, vault'
              : canAscend
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
    final cdMaxed = state.metaDepth.godHandCdLevel >= 8;
    final cdLabel = cdMaxed
        ? 'Cooldown ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · MAX'
        : 'Cooldown ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · '
              '${GameLogic.godHandCdUpgradeCost(state.metaDepth.godHandCdLevel)}e';
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
              ? 'Ascend Blessing: none yet — each Ascend stacks '
                    '+${GameLogic.ascendBlessingAtk} ATK · '
                    '+${GameLogic.ascendBlessingDef} DEF · '
                    '+${GameLogic.ascendBlessingVit} STA · '
                    '+${GameLogic.ascendBlessingGoldPct}% gold'
              : 'Ascend Blessing ×${state.metaDepth.ascendBlessings}: '
                    '+${state.ascendBlessingAttackBonus} ATK · '
                    '+${state.ascendBlessingDefenseBonus} DEF · '
                    '+${state.ascendBlessingVitalityBonus} STA · '
                    '+${state.ascendBlessingGoldPercent}% gold',
          style: GameTheme.body(size: 13, color: GameTheme.mossLit),
        ),
        Builder(
          builder: (_) {
            if (GameLogic.isMaxAscension(state)) {
              return const SizedBox.shrink();
            }
            final hub = GoldIncome.hubGoldPerMinute(state);
            final run = director.runGoldPerMinute;
            final oldP = GoldIncome.goldFindPercent(state);
            final newP = oldP + GameLogic.ascendBlessingGoldPct;
            final hubGain = GoldIncome.goldFindDeltaOnRate(hub, oldP, newP);
            final runGain = GoldIncome.goldFindDeltaOnRate(run, oldP, newP);
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Next Blessing +${GameLogic.ascendBlessingGoldPct}% gold'
                ' · Hub +${hubGain}g/min'
                '${run > 0 ? ' · Run +${runGain}g/min' : ''}',
                style: GameTheme.body(
                  size: 12,
                  color: GameTheme.parchmentDim,
                ),
              ),
            );
          },
        ),
        if (state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
            !state.metaDepth.partySlot5Unlocked) ...[
          const SizedBox(height: 8),
          _sectionTitle(
            '5TH SLOT',
            'Extra fighter · survives Ascend. Also on PARTY → ROSTER.',
            scope: MenuScope.account,
          ),
          KenneyButton(
            label:
                'UNLOCK 5TH SLOT  ${GameLogic.partySlot5EssenceCost}e  '
                'AL${GameLogic.partySlot5MinAscension}+',
            onPressed: state.essence >= GameLogic.partySlot5EssenceCost
                ? director.unlockPartySlot5
                : null,
          ),
        ],
        const SizedBox(height: 8),
        _sectionTitle(
          'GOD HAND',
          'Tap in the dungeon to steer + smash. Soft knobs: damage, CD, style.',
          scope: MenuScope.account,
        ),
        Text(
          'Lv${state.godHandLevel} · smash ${state.godHandSmashDamage()} · '
          'blast ${state.godHandSmashRadius.toStringAsFixed(1)} · '
          'CD ${state.godHandCooldownSeconds.toStringAsFixed(2)}s',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'Damage Lv${state.godHandLevel} · '
              '${GameLogic.godHandUpgradeCost(state.godHandLevel)}e',
          onPressed:
              state.essence >= GameLogic.godHandUpgradeCost(state.godHandLevel)
              ? director.upgradeGodHand
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: cdLabel,
          onPressed: cdMaxed
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
          'BAL = default · FOCUS = harder, smaller blast · '
          'WIDE = bigger blast, softer hits',
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
                  label: state.metaDepth.godHandStyle == entry.$1
                      ? '${entry.$2} ✓'
                      : entry.$2,
                  style: state.metaDepth.godHandStyle == entry.$1
                      ? KenneyButtonStyle.brown
                      : KenneyButtonStyle.grey,
                  onPressed: () => director.setGodHandStyle(entry.$1),
                ),
              ),
            ],
          ],
        ),
        Divider(
          height: 16,
          color: GameTheme.rarityCommon.withValues(alpha: 0.4),
        ),
        _sectionTitle(
          'RELICS',
          'Buy once · upgrade tiers · permanent party auras.',
          scope: MenuScope.account,
        ),
        for (final relicId in GameLogic.relicOrder)
          _relicKeepCard(state, relicId),
        KenneyButton(
          label: 'RESPEC · no refund · ${GameLogic.respecRelicsCost(state)}e',
          style: KenneyButtonStyle.red,
          onPressed:
              (state.unlockedRelics.isNotEmpty ||
                      state.metaDepth.relicTiers.isNotEmpty) &&
                  state.essence >= GameLogic.respecRelicsCost(state)
              ? director.respecRelics
              : null,
        ),
        if (state.soulboundItem != null) ...[
          Divider(
            height: 16,
            color: GameTheme.rarityCommon.withValues(alpha: 0.4),
          ),
          _sectionTitle(
            'HEIRLOOM',
            'Older save. Apex is forever gear now — this still adds party power.',
            scope: MenuScope.account,
          ),
          Text(
            '${state.soulboundItem!.name}'
            '${state.metaDepth.soulboundRefine > 0 ? ' · refine ${state.metaDepth.soulboundRefine}' : ''}',
            style: GameTheme.body(size: 14, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _relicKeepCard(GameState state, String relicId) {
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
            : 'Permanent +${GameLogic.relicDefensePerTier} team defense per tier.',
      GameLogic.phoenixEmberRelic =>
        owned
            ? 'Permanent +${state.relicVitalityBonus} max HP per hero (T$tier).'
            : 'Permanent +${GameLogic.relicVitalityPerTier} max HP per hero per tier.',
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
            : '+${GameLogic.relicMitigatePerTier} flat mitigate per tier.',
      _ => GameLogic.relicDescriptions[relicId] ?? '',
    };
    final nextPayout = GameLogic.relicPerTierPayout(relicId);
    final nextTier = tier + 1;
    final tierCost = GameLogic.relicTierUpgradeCost(nextTier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(selected: owned),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.relicIconFor(relicId), size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owned ? '$name · T$tier' : name,
                      style: GameTheme.body(
                        size: 16,
                        color: GameTheme.parchment,
                      ),
                    ),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: GameTheme.body(
                          size: 13,
                          color: owned
                              ? GameTheme.mossLit
                              : GameTheme.parchmentDim,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!owned) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: '$name  ${cost}e',
              onPressed: state.essence < cost
                  ? null
                  : () => director.unlockRelic(relicId),
            ),
          ] else if (tier < 3) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: nextPayout.isEmpty
                  ? 'UPGRADE TIER  T$nextTier  ${tierCost}e'
                  : 'T$nextTier · $nextPayout · ${tierCost}e',
              style: KenneyButtonStyle.grey,
              onPressed: state.essence >= tierCost
                  ? () => director.upgradeRelicTier(relicId)
                  : null,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'T3 · MAX',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
            ),
        ],
      ),
    );
  }
}
