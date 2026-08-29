
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/chase_contract.dart';
import '../../core/keystone.dart';
import '../../core/local_season.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Keystone run prefs — set before entering a dungeon (Mythic+-style).
class ChallengeToggles extends StatefulWidget {
  const ChallengeToggles({
    super.key,
    required this.director,
    this.collapsed = false,
  });
  final GameDirector director;
  final bool collapsed;

  @override
  State<ChallengeToggles> createState() => _ChallengeTogglesState();
}

class _ChallengeTogglesState extends State<ChallengeToggles> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final keyOn = widget.director.state.hardmodeLevel > 0 ||
        GameLogic.endgameUnlocked(widget.director.state) ||
        widget.director.state.challengeBossRush ||
        widget.director.state.challengeNoFlask ||
        widget.director.state.challengeTiny;
    _expanded = !widget.collapsed || keyOn;
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final state = director.state;
    final md = state.metaDepth;
    final maxKey = state.effectiveMaxHardmode;
    final vaultReady = GameLogic.canClaimDailyVault(state);
    final affixes = Keystone.previewAffixes(state);
    final vaultE = GameLogic.dailyVaultClaimPreviewEssence(state);
    final weekKey = md.weeklyKey.isNotEmpty
        ? md.weeklyKey
        : GameLogic.isoWeekKey(DateTime.now().toUtc());
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    final weekClaimed = LocalSeasonCatalog.weekGoalClaimed(state, week);
    final weekReady = LocalSeasonCatalog.weekGoalReady(state, week);
    final weekAlmost = LocalSeasonCatalog.weekGoalAlmost(state, week);
    final month = LocalSeasonCatalog.forMonthKey(
      md.seasonKey.contains('·')
          ? md.seasonKey.split('·').last.trim()
          : GameLogic.isoMonthKey(DateTime.now().toUtc()),
    );
    final activeBits = <String>[
      if (state.hardmodeLevel > 0) 'KEY+${state.hardmodeLevel}',
      if (state.challengeBossRush) 'Boss Rush',
      if (state.challengeNoFlask) 'No Flask',
      if (state.challengeTiny) 'Tiny',
      if (vaultReady) 'Vault ready',
    ];
    final chase = ChaseContract.fromState(state);

    final headerLabel = _expanded
        ? (activeBits.isEmpty
              ? '▾ KEYSTONE off'
              : '▾ KEYSTONE ${activeBits.join(' · ')}')
        : (activeBits.isEmpty
              ? '▸ KEYSTONE off'
              : '▸ KEYSTONE ${activeBits.join(' · ')}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebClickScope(
          label: headerLabel,
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Semantics(
            button: true,
            label: headerLabel,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _expanded ? '▾ KEYSTONE' : '▸ KEYSTONE',
                      style: GameTheme.body(size: 12, color: GameTheme.torchHot),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeBits.isEmpty ? 'off' : activeBits.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 4),
          _HardmodeStepper(
            level: state.hardmodeLevel,
            maxLevel: maxKey,
            onChanged: director.setHardmodeLevel,
          ),
          const SizedBox(height: 4),
          Text(
            state.hardmodeLevel <= 0
                ? 'KEY +0 (normal) · no key loot bonus · max KEY +$maxKey'
                : 'KEY +${state.hardmodeLevel} · loot +${Keystone.lootItemLevelBonus(state.hardmodeLevel)} iLvl · ${Keystone.goldMulLabel(state.hardmodeLevel)}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          if (affixes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in affixes)
                  _KeyAffixChip(
                    label: Keystone.label(a),
                    blurb: Keystone.blurb(a),
                    risk: Keystone.riskTier(a),
                  ),
              ],
            ),
          ],
          if (week.hasGoal) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: MenuChrome.cardBox(selected: weekReady || weekAlmost),
              child: Column(
                children: [
                  Text(
                    weekReady
                        ? 'WEEK GOAL READY'
                        : weekAlmost
                        ? 'WEEK GOAL ALMOST'
                        : 'WEEK GOAL',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 12,
                      color: weekReady || weekAlmost
                          ? GameTheme.torchHot
                          : GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    week.name,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 13, color: GameTheme.parchment),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekClaimed
                        ? 'Claimed · ${week.titleReward ?? week.name}'
                        : '${week.blurb}\n'
                              '${LocalSeasonCatalog.weekProgressLabel(state, week)}'
                              '${weekReady ? ' · auto-claims on hub sync' : ''}',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ChallengeChip(
                  label: 'BOSS RUSH',
                  active: state.challengeBossRush,
                  onTap: () =>
                      director.setChallengeBossRush(!state.challengeBossRush),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChallengeChip(
                  label: 'NO FLASK',
                  active: state.challengeNoFlask,
                  onTap: () =>
                      director.setChallengeNoFlask(!state.challengeNoFlask),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Boss Rush: bosses only · No Flask: healing flasks disabled',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
          const SizedBox(height: 6),
          _ChallengeChip(
            label: 'TINY (3 heroes)',
            active: state.challengeTiny,
            onTap: () => director.setChallengeTiny(!state.challengeTiny),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Tiny: run with 3 heroes max — harder, smaller party',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
          if (state.metaDepth.challengeBestBossRushKey > 0 ||
              state.metaDepth.challengeBestNoFlaskKey > 0 ||
              state.metaDepth.challengeBestTinyKey > 0) ...[
            const SizedBox(height: 4),
            Text(
              'PB · Rush +${state.metaDepth.challengeBestBossRushKey} · '
              'Flask +${state.metaDepth.challengeBestNoFlaskKey} · '
              'Tiny +${state.metaDepth.challengeBestTinyKey}',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ],
          Text(
            'Power ${GameLogic.partyPowerScore(state)} · sheet score (not a clear guarantee)',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: MenuChrome.cardBox(selected: vaultReady),
            child: Column(
              children: [
                Text(
                  'DAILY VAULT',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: vaultReady
                        ? GameTheme.torchHot
                        : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  md.dailyVaultClaimed
                      ? 'Today: claimed'
                      : 'Today: clears ${md.dailyVaultClears}/'
                            '${GameLogic.dailyVaultClearTarget}'
                            ' · best timed KEY +${md.dailyBestTimedKey}'
                            '${vaultReady ? ' · ready' : ''}',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  md.seasonKey.isEmpty
                      ? 'Season: rotating…'
                      : 'Season: ${month.name} · '
                            '+${GameLogic.seasonWeeklyBonusEssence}e '
                            'first vault claim',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                if (vaultReady) ...[
                  const SizedBox(height: 6),
                  KenneyButton(
                    label: 'CLAIM VAULT  +${vaultE}e',
                    onPressed: director.claimDailyVault,
                  ),
                ],
              ],
            ),
          ),
          if (GameLogic.endgameUnlocked(state)) ...[
            const SizedBox(height: 6),
            Text(
              'TODAY · ${chase.title}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            !GameLogic.endgameUnlocked(state)
                ? 'KEYSTONE unlocks at party level ${GameLogic.maxHeroLevel} with Gauntlet and Rift.'
                : 'Timed boss under par upgrades KEY. Vault: 1 clear or timed KEY+2.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }
}

class _HardmodeStepper extends StatelessWidget {
  const _HardmodeStepper({
    required this.level,
    required this.maxLevel,
    required this.onChanged,
  });
  final int level;
  final int maxLevel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: MenuChrome.cardBox(selected: level > 0),
      child: Row(
        children: [
          MenuChrome.stepperButton(
            label: 'KEYSTONE -',
            sign: '-',
            onPressed: level > 0 ? () => onChanged(level - 1) : null,
            size: 36,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  level <= 0 ? 'KEYSTONE  OFF' : 'KEYSTONE  +$level',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: level > 0
                        ? GameTheme.torchHot
                        : GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '0 = normal  ·  max +$maxLevel (AL)',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
          MenuChrome.stepperButton(
            label: 'KEYSTONE +',
            sign: '+',
            onPressed: level < maxLevel ? () => onChanged(level + 1) : null,
            size: 36,
          ),
        ],
      ),
    );
  }
}

class _KeyAffixChip extends StatelessWidget {
  const _KeyAffixChip({
    required this.label,
    required this.blurb,
    required this.risk,
  });

  final String label;
  final String blurb;
  final String risk;

  Color get _riskColor => switch (risk) {
    'Soft' => GameTheme.mossLit,
    'Brutal' => GameTheme.bloodLit,
    _ => GameTheme.accentWarn,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GameTheme.panelInset,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        border: Border.all(color: _riskColor.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              risk,
              style: GameTheme.pixel(size: 8, color: _riskColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label · $blurb',
            style: GameTheme.body(size: 11, color: GameTheme.parchment),
          ),
        ],
      ),
    );
  }
}

class _ChallengeChip extends StatelessWidget {
  const _ChallengeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
              alignment: Alignment.center,
              decoration: MenuChrome.listCard(selected: active),
              child: Text(
                label,
                style: GameTheme.body(
                  size: 14,
                  color: active ? GameTheme.torchHot : GameTheme.parchmentDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
