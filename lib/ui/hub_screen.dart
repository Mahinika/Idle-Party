import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/hub_chase.dart';
import '../core/keystone.dart';
import '../core/local_season.dart';
import '../core/meta_systems.dart';
import '../models/dungeon_def.dart';
import 'confirm_dialogs.dart';
import 'custom_assets.dart';
import 'cave_atmosphere.dart';
import 'dungeon_environment.dart';
import 'feedback_toast.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'meta_overlays.dart';
import 'web_click_bridge.dart';

/// Idle Party hub: dungeon select / meta / ascend.
class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.director,
    required this.onEnterDungeon,
    required this.onOpenParty,
    required this.onOpenPower,
    required this.onOpenMeta,
    required this.onOpenSettings,
  });

  final GameDirector director;
  final void Function(String dungeonId) onEnterDungeon;
  /// PARTY pillar (gear / bag / merge / loadouts / roster).
  final VoidCallback onOpenParty;
  /// POWER pillar (forge / sanctuary / market / essence).
  final VoidCallback onOpenPower;
  /// META pillar (keystone / contracts / info).
  final VoidCallback onOpenMeta;
  final VoidCallback onOpenSettings;

  /// Honesty helpers for ship_smoke (World Path marker ↔ catalog).
  static List<Offset> get worldPathMarkerNorm => _ZonePathMap.markerNorm;
  static int get worldPathMarkerCount => _ZonePathMap.markerNorm.length;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedId;
  late final AnimationController _torch;
  bool _offlineDialogShown = false;
  bool _offeredWhatsNew = false;
  bool _userPickedZone = false;
  int? _trackedAscension;
  int? _trackedHighestCleared;

  GameDirector get director => widget.director;
  GameState get state => director.state;

  /// Unlocked uncleared frontier zone (World Path NEXT), if any.
  static String? frontierDungeonId(GameState state) {
    final highest = state.highestDungeonCleared;
    for (final d in DungeonCatalog.all) {
      final unlocked = DungeonCatalog.isUnlocked(
        d.id,
        state.lifetimeGoldEarned,
        highest,
      );
      final cleared = highest >= d.number;
      if (unlocked && !cleared && d.number == highest + 1) {
        return d.id;
      }
    }
    return null;
  }

  void _syncSelection({required bool force}) {
    final preferred = GameLogic.recommendedDungeonId(state);
    if (force) {
      _userPickedZone = false;
      _selectedId = preferred;
      return;
    }
    if (_userPickedZone) {
      // Still snap off a CLEAR node when a NEXT frontier exists.
      final frontier = frontierDungeonId(state);
      if (frontier != null) {
        final sel = DungeonCatalog.byId(_selectedId);
        if (state.highestDungeonCleared >= sel.number &&
            _selectedId != frontier) {
          _selectedId = frontier;
          _userPickedZone = false;
        }
      }
      return;
    }
    if (_selectedId != preferred) {
      _selectedId = preferred;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedId = state.dungeonId;
    _trackedAscension = state.ascensionLevel;
    _trackedHighestCleared = state.highestDungeonCleared;
    _syncSelection(force: true);
    _torch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowOffline();
      await _maybeShowWhatsNew();
    });
  }

  Future<void> _maybeShowOffline() async {
    if (_offlineDialogShown || !mounted || director.offlineSummary == null) {
      return;
    }
    _offlineDialogShown = true;
    await showOfflineProgressDialog(
      context,
      director,
      onOpenParty: widget.onOpenParty,
    );
  }

  Future<void> _maybeShowWhatsNew() async {
    if (_offeredWhatsNew || !mounted) return;
    if (director.state.inDungeon) return;
    if (!MetaSystems.hasUnseenChangelog(director.state)) return;
    _offeredWhatsNew = true;
    await WhatsNewOverlay.show(context, director);
  }

  @override
  void dispose() {
    _torch.dispose();
    super.dispose();
  }

  (String?, VoidCallback?) _chaseAction(BuildContext context, HubChase chase) {
    switch (chase.kind) {
      case HubChaseKind.claimDailyVault:
        return ('CLAIM VAULT', director.claimWeekly);
      case HubChaseKind.claimMissions:
        return (
          'CLAIM JOBS',
          () {
            for (final m in director.state.missions) {
              if (m.isComplete) director.claimMission(m.id);
            }
          },
        );
      case HubChaseKind.meetHero:
        return (
          'PARTY',
          () {
            director.ackPendingHeroReveals();
            widget.onOpenParty();
          },
        );
      case HubChaseKind.ascend:
        return ('ASCEND', () => confirmAscend(context, director));
      case HubChaseKind.dailyRun:
        return ('DAILY', () => confirmDailyRun(context, director));
      case HubChaseKind.keystone:
        final id = chase.zoneId ?? _selectedId;
        return (
          'ENTER',
          () {
            director.setHardmodeLevel(chase.keyLevel ?? 1);
            if (chase.zoneId != null) {
              setState(() {
                _userPickedZone = true;
                _selectedId = chase.zoneId!;
              });
            }
            final unlocked = DungeonCatalog.isUnlocked(
              id,
              director.state.lifetimeGoldEarned,
              director.state.highestDungeonCleared,
            );
            if (unlocked) widget.onEnterDungeon(id);
          },
        );
      case HubChaseKind.gauntletMilestone:
        return ('GAUNTLET', () => confirmGauntletRun(context, director));
      case HubChaseKind.weekGoal:
        // Prefer ENTER for vault-style week goals; Gauntlet button if title hints.
        if (chase.title.toLowerCase().contains('gauntlet')) {
          return ('GAUNTLET', () => confirmGauntletRun(context, director));
        }
        return (
          'ENTER',
          () {
            final id = chase.zoneId ?? _selectedId;
            final unlocked = DungeonCatalog.isUnlocked(
              id,
              director.state.lifetimeGoldEarned,
              director.state.highestDungeonCleared,
            );
            if (unlocked) widget.onEnterDungeon(id);
          },
        );
      case HubChaseKind.dailyVaultProgress:
      case HubChaseKind.clearFloors:
        final id = chase.zoneId ?? _selectedId;
        return (
          'ENTER',
          () {
            if (chase.zoneId != null) {
              setState(() {
                _userPickedZone = true;
                _selectedId = chase.zoneId!;
              });
            }
            final unlocked = DungeonCatalog.isUnlocked(
              id,
              director.state.lifetimeGoldEarned,
              director.state.highestDungeonCleared,
            );
            if (unlocked) widget.onEnterDungeon(id);
          },
        );
      case HubChaseKind.unlockZone:
        final id = chase.zoneId;
        if (id == null) return (null, null);
        return (
          'PATH',
          () {
            setState(() {
              _userPickedZone = true;
              _selectedId = id;
            });
          },
        );
      case HubChaseKind.willRank:
        return ('POWER', widget.onOpenPower);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trackedAscension != state.ascensionLevel ||
        _trackedHighestCleared != state.highestDungeonCleared) {
      final ascended = _trackedAscension != null &&
          _trackedAscension != state.ascensionLevel;
      _trackedAscension = state.ascensionLevel;
      _trackedHighestCleared = state.highestDungeonCleared;
      // After Ascend / new clear, prefer NEXT (or deepest unlocked).
      _syncSelection(force: ascended || !_userPickedZone);
    } else if (!_userPickedZone &&
        _selectedId != GameLogic.recommendedDungeonId(state)) {
      // Keep detail panel aligned with glowing NEXT / recommended node.
      _selectedId = GameLogic.recommendedDungeonId(state);
    }
    final canAscend = GameLogic.canAscend(state);
    final bossFloor = GameLogic.bossFloorFor(state);
    final unlockedSelected = DungeonCatalog.isUnlocked(
      _selectedId,
      state.lifetimeGoldEarned,
      state.highestDungeonCleared,
    );

    final short = GameTheme.isShortHeight(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: const _HubSceneBackdrop(),
        ),
        SafeArea(
          child: AnimatedBuilder(
            animation: _torch,
            builder: (context, _) {
              final flicker = 0.55 + (_torch.value * 0.45);
              return Stack(
                fit: StackFit.expand,
                children: [
                  CaveAtmosphere.torchBloom(
                    intensity: flicker,
                    alignment: const Alignment(0, 0.15),
                    sizeFactor: 0.7,
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: DungeonEnvironment.atmosphereWash(_selectedId),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      GameTheme.isPhoneWidth(context) ? 12 : 16,
                      GameTheme.isPhoneWidth(context) ? 8 : 10,
                      GameTheme.isPhoneWidth(context) ? 12 : 16,
                      GameTheme.isPhoneWidth(context) ? 10 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HubHeader(
                          ascensionLevel: state.ascensionLevel,
                          bossFloor: bossFloor,
                          gold: state.gold,
                          essence: state.essence,
                          soulbound: state.soulboundFragments,
                          willRank: state.willRankTitle,
                          collectionScore: state.collectionScore,
                          displayTitle: state.displayTitle,
                          zoneTrophies: state.metaDepth.zoneTrophies.length,
                          torch: flicker,
                          onOpenSettings: widget.onOpenSettings,
                        ),
                        if (director.offlineSummary != null) ...[
                          const SizedBox(height: 8),
                          _OfflineBanner(
                            text: director.offlineSummary!.headline,
                            onDismiss: () => showOfflineProgressDialog(
                              context,
                              director,
                              onOpenParty: widget.onOpenParty,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // World Path: painted campaign map + tappable rings.
                        Expanded(
                          child: _ZonePathMap(
                            dungeons: DungeonCatalog.all,
                            selectedId: _selectedId,
                            lifetimeGold: state.lifetimeGoldEarned,
                            highestCleared: state.highestDungeonCleared,
                            pulse: _torch.value,
                            onSelect: (id) => setState(() {
                              _userPickedZone = true;
                              _selectedId = id;
                            }),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _SelectedZoneCaption(
                          dungeon: DungeonCatalog.byId(_selectedId),
                          unlocked: unlockedSelected,
                          lifetimeGold: state.lifetimeGoldEarned,
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final contract = ChaseContract.fromState(state);
                            final chase = contract.chase;
                            final (actionLabel, onAction) =
                                _chaseAction(context, chase);
                            final weekMod = state.metaDepth.weeklyModifier;
                            final showWeekAffix =
                                !short &&
                                weekMod.isNotEmpty &&
                                GameLogic.showKeystoneJargon(state);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showWeekAffix) ...[
                                  Text(
                                    'Week · ${Keystone.label(weekMod)} — ${Keystone.blurb(weekMod)}',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GameTheme.body(
                                      size: 12,
                                      color: GameTheme.mossLit,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                _HubTodayCard(
                                  chase: chase,
                                  compact: true,
                                  actionLabel: actionLabel,
                                  onAction: onAction,
                                ),
                                _HubMetaPulse(
                                  state: state,
                                  chaseKind: chase.kind,
                                ),
                                const SizedBox(height: 6),
                                Transform.scale(
                                  scale: 1.0 + (_torch.value * 0.012),
                                  child: KenneyButton(
                                    label: 'ENTER DUNGEON',
                                    style: KenneyButtonStyle.brown,
                                    primary: true,
                                    onPressed: unlockedSelected
                                        ? () =>
                                            widget.onEnterDungeon(_selectedId)
                                        : null,
                                  ),
                                ),
                                ChallengeToggles(
                                  director: director,
                                  collapsed: true,
                                ),
                                _HubUrgentRow(
                                  claimable: state.missions
                                      .where((m) => m.isComplete)
                                      .length,
                                  canAscend: canAscend,
                                  ascendLabel: canAscend
                                      ? 'ASCEND  +${GameLogic.ascendEssenceReward(state.ascensionLevel + 1) + MetaSystems.ascendMilestoneReward(state.ascensionLevel, state.ascensionLevel + 1)}e'
                                      : null,
                                  hideAscend:
                                      chase.kind == HubChaseKind.ascend,
                                  hideVaultClaim: chase.kind ==
                                      HubChaseKind.claimDailyVault,
                                  hideMissionClaim: chase.kind ==
                                      HubChaseKind.claimMissions,
                                  hideDaily:
                                      chase.kind == HubChaseKind.dailyRun ||
                                          chase.kind ==
                                              HubChaseKind.keystone ||
                                          chase.kind ==
                                              HubChaseKind.meetHero ||
                                          !GameLogic.showDailyChase(state),
                                  onContracts: () {
                                    for (final m
                                        in director.state.missions) {
                                      if (m.isComplete) {
                                        director.claimMission(m.id);
                                      }
                                    }
                                  },
                                  onAscend: () =>
                                      confirmAscend(context, director),
                                  dailyClaimed:
                                      director.isDailyClaimedToday,
                                  onDaily: () =>
                                      confirmDailyRun(context, director),
                                  showGauntlet:
                                      GameLogic.canEnterGauntlet(state) ||
                                          state.ascensionLevel >=
                                              GameLogic.gauntletMinAscension,
                                  gauntletBest:
                                      state.metaDepth.gauntletBestFloor,
                                  onGauntlet: () => confirmGauntletRun(
                                    context,
                                    director,
                                  ),
                                  weeklyReady:
                                      GameLogic.canClaimDailyVault(state),
                                  weeklyProgress:
                                      state.metaDepth.dailyVaultClears,
                                  weeklyClaimed:
                                      state.metaDepth.dailyVaultClaimed,
                                  weeklyBestTimedKey:
                                      state.metaDepth.dailyBestTimedKey,
                                  onClaimWeekly: director.claimWeekly,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: KenneyButton(
                                label: 'PARTY',
                                style: KenneyButtonStyle.grey,
                                onPressed: widget.onOpenParty,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: KenneyButton(
                                label: 'POWER',
                                style: KenneyButtonStyle.grey,
                                onPressed: widget.onOpenPower,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: KenneyButton(
                                label: () {
                                  final unseen =
                                      MetaSystems.hasUnseenChangelog(state);
                                  final readyJobs = state.missions
                                      .where((m) => m.isComplete)
                                      .length;
                                  final phone =
                                      GameTheme.isPhoneWidth(context);
                                  if (unseen) {
                                    return phone ? 'META ★' : 'META · NEW';
                                  }
                                  if (readyJobs > 0) {
                                    return phone ? 'META !' : 'META · !';
                                  }
                                  return 'META';
                                }(),
                                style: KenneyButtonStyle.grey,
                                onPressed: widget.onOpenMeta,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (director.toast != null)
          Positioned.fill(
            child: FeedbackToast(
              message: director.toast!,
              maxLines: 3,
              alignment: const Alignment(0, -0.72),
            ),
          ),
      ],
    );
  }

}

/// Always-visible KEY / vault / week crumbs under TODAY (phone hub).
/// Skips bits that duplicate the active chase so the strip stays quiet.
class _HubMetaPulse extends StatelessWidget {
  const _HubMetaPulse({
    required this.state,
    required this.chaseKind,
  });

  final GameState state;
  final HubChaseKind chaseKind;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[];
    final showKey = GameLogic.showKeystoneJargon(state);
    if (showKey &&
        chaseKind != HubChaseKind.keystone &&
        chaseKind != HubChaseKind.dailyVaultProgress &&
        chaseKind != HubChaseKind.claimDailyVault) {
      bits.add(
        state.hardmodeLevel <= 0
            ? 'KEY off'
            : 'KEY +${state.hardmodeLevel}',
      );
    }

    if (chaseKind != HubChaseKind.claimDailyVault &&
        chaseKind != HubChaseKind.dailyVaultProgress) {
      final clears = state.metaDepth.dailyVaultClears;
      final target = GameLogic.dailyVaultClearTarget;
      if (GameLogic.canClaimDailyVault(state)) {
        bits.add('Vault READY');
      } else {
        bits.add('Vault $clears/$target');
      }
    }

    if (chaseKind != HubChaseKind.weekGoal) {
      final weekKey = state.metaDepth.weeklyKey.isNotEmpty
          ? state.metaDepth.weeklyKey
          : GameLogic.isoWeekKey(DateTime.now().toUtc());
      final week = LocalSeasonCatalog.forWeekKey(weekKey);
      if (week.hasGoal) {
        if (LocalSeasonCatalog.weekGoalReady(state, week)) {
          bits.add('Week READY');
        } else if (!LocalSeasonCatalog.weekGoalClaimed(state, week)) {
          bits.add(LocalSeasonCatalog.weekProgressLabel(state, week));
        }
      }
    }

    if (bits.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Semantics(
        label: 'Meta: ${bits.join(', ')}',
        child: Text(
          bits.join(' · '),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(
            size: 11,
            color: GameTheme.parchmentDim,
          ),
        ),
      ),
    );
  }
}

class _HubTodayCard extends StatelessWidget {
  const _HubTodayCard({
    required this.chase,
    this.compact = false,
    this.actionLabel,
    this.onAction,
  });

  final HubChase chase;
  final bool compact;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ready = chase.urgency == HubChaseUrgency.ready;
    final almost = chase.urgency == HubChaseUrgency.almost;
    final accent = ready
        ? GameTheme.torchHot
        : almost
            ? GameTheme.accentWarn
            : GameTheme.parchmentDim;
    final chip = ready
        ? 'READY'
        : almost
            ? 'ALMOST'
            : null;
    // Text strip only — no fill box under ENTER.
    return Semantics(
      label: 'TODAY chase: ${chase.title}. ${chase.detail}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            KenneySprite(asset: KenneyAssets.iconStar, size: 14),
            const SizedBox(width: 6),
            Text(
              'TODAY',
              style: GameTheme.body(size: 12, color: accent),
            ),
            if (chip != null) ...[
              const SizedBox(width: 6),
              Text(chip, style: GameTheme.body(size: 12, color: accent)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                chase.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(
                  size: 13,
                  color: GameTheme.parchment,
                ),
              ),
            ),
            if (chase.progressLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                chase.progressLabel!,
                style: GameTheme.body(
                  size: 12,
                  color: ready || almost ? accent : GameTheme.mossLit,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 6),
              KenneyButton(
                label: actionLabel!,
                style: KenneyButtonStyle.brown,
                expanded: false,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubUrgentRow extends StatelessWidget {
  const _HubUrgentRow({
    required this.claimable,
    required this.canAscend,
    required this.ascendLabel,
    required this.onContracts,
    required this.onAscend,
    required this.dailyClaimed,
    required this.onDaily,
    required this.showGauntlet,
    required this.gauntletBest,
    required this.onGauntlet,
    required this.weeklyReady,
    required this.weeklyProgress,
    required this.weeklyClaimed,
    required this.weeklyBestTimedKey,
    required this.onClaimWeekly,
    this.hideAscend = false,
    this.hideVaultClaim = false,
    this.hideMissionClaim = false,
    this.hideDaily = false,
  });

  final int claimable;
  final bool canAscend;
  final String? ascendLabel;
  final VoidCallback onContracts;
  final VoidCallback onAscend;
  final bool dailyClaimed;
  final VoidCallback onDaily;
  final bool showGauntlet;
  final int gauntletBest;
  final VoidCallback onGauntlet;
  final bool weeklyReady;
  final int weeklyProgress;
  final bool weeklyClaimed;
  final int weeklyBestTimedKey;
  final VoidCallback onClaimWeekly;
  final bool hideAscend;
  final bool hideVaultClaim;
  final bool hideMissionClaim;
  final bool hideDaily;

  @override
  Widget build(BuildContext context) {
    final showVaultProgress = !weeklyClaimed &&
        weeklyProgress > 0 &&
        weeklyProgress < GameLogic.dailyVaultClearTarget &&
        weeklyBestTimedKey < 2;
    final showAscend = canAscend && ascendLabel != null && !hideAscend;
    final showVault = weeklyReady && !hideVaultClaim;
    final showMissions = claimable > 0 && !hideMissionClaim;
    final showDaily = !hideDaily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAscend) ...[
          KenneyButton(
            label: ascendLabel!,
            style: KenneyButtonStyle.red,
            primary: true,
            onPressed: onAscend,
          ),
          const SizedBox(height: 4),
        ],
        if (showVault) ...[
          KenneyButton(
            label:
                'CLAIM VAULT  +${Keystone.dailyVaultEssence(weeklyBestTimedKey)}e',
            style: KenneyButtonStyle.brown,
            primary: true,
            onPressed: onClaimWeekly,
          ),
          const SizedBox(height: 4),
        ] else if (showVaultProgress) ...[
          Text(
            'Daily vault · $weeklyProgress/${GameLogic.dailyVaultClearTarget}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
        ],
        if (showMissions || showDaily)
          Row(
            children: [
              if (showMissions) ...[
                Expanded(
                  child: KenneyButton(
                    label: 'CLAIM ($claimable)',
                    style: KenneyButtonStyle.brown,
                    onPressed: onContracts,
                  ),
                ),
                if (showDaily) const SizedBox(width: 6),
              ],
              if (showDaily)
                Expanded(
                  child: KenneyButton(
                    label: dailyClaimed ? 'DAILY · done' : 'DAILY RUN',
                    style: KenneyButtonStyle.grey,
                    onPressed: dailyClaimed ? null : onDaily,
                  ),
                ),
            ],
          ),
        if (showGauntlet) ...[
          const SizedBox(height: 6),
          KenneyButton(
            label: gauntletBest > 0
                ? 'GAUNTLET  ·  best F$gauntletBest'
                : 'INFINITY GAUNTLET',
            style: KenneyButtonStyle.red,
            onPressed: onGauntlet,
          ),
        ],
      ],
    );
  }
}

class _HubSceneBackdrop extends StatelessWidget {
  const _HubSceneBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CaveAtmosphere.fullBleedScene(
          CustomAssets.hubScene,
          alignment: const Alignment(0, -0.08),
        ),
        CaveAtmosphere.readabilityScrim(top: 0.38, bottom: 0.42),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDismiss,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: MenuChrome.cardBox(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GameTheme.pixel(
                    size: GameTheme.hudPixel,
                    color: GameTheme.mossLit,
                  ),
                ),
              ),
              Text(
                'TAP',
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.ascensionLevel,
    required this.bossFloor,
    required this.gold,
    required this.essence,
    required this.soulbound,
    required this.willRank,
    required this.collectionScore,
    required this.displayTitle,
    required this.zoneTrophies,
    required this.torch,
    required this.onOpenSettings,
  });

  final int ascensionLevel;
  final int bossFloor;
  final int gold;
  final int essence;
  final int soulbound;
  final String willRank;
  final int collectionScore;
  final String displayTitle;
  final int zoneTrophies;
  final double torch;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            Expanded(
              flex: 6,
              child: Text(
                'IDLE PARTY',
                textAlign: TextAlign.center,
                style: GameTheme.pixel(
                  size: 20,
                  color: Color.lerp(GameTheme.torch, GameTheme.torchHot, torch)!,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(
              width: GameTheme.minTouch,
              height: GameTheme.minTouch,
              child: WebClickScope(
                label: 'Settings',
                onPressed: onOpenSettings,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: onOpenSettings,
                  icon: KenneySprite(
                    asset: KenneyAssets.iconDoor,
                    size: 18,
                  ),
                  tooltip: 'Settings',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Hero\'s Keep · Boss F$bossFloor',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            _StatPill(icon: KenneyAssets.coinGold, label: '$gold'),
            _StatPill(icon: KenneyAssets.vialBlue, label: '$essence'),
            _StatPill(
              icon: KenneyAssets.iconCrown,
              label: 'Ascend $ascensionLevel',
            ),
            if (soulbound > 0)
              _StatPill(
                icon: KenneyAssets.iconTrophy,
                label: 'Bound $soulbound',
              ),
          ],
        ),
        if (displayTitle.isNotEmpty || collectionScore > 0) ...[
          const SizedBox(height: 3),
          Text(
            displayTitle.isEmpty
                ? '$willRank · $collectionScore'
                : '$willRank · $displayTitle',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        if (zoneTrophies > 0 && !GameTheme.isPhoneWidth(context)) ...[
          const SizedBox(height: 2),
          Text(
            'Zone trophies $zoneTrophies',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
          ),
        ],
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Loose chips — no framed inventory boxes on the keep.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KenneySprite(asset: icon, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
      ],
    );
  }
}

/// Painted campaign map with tappable zone markers (saga / idle path style).
class _SelectedZoneCaption extends StatelessWidget {
  const _SelectedZoneCaption({
    required this.dungeon,
    required this.unlocked,
    required this.lifetimeGold,
  });

  final DungeonDef dungeon;
  final bool unlocked;
  final int lifetimeGold;

  /// Compact lifetime-gold label (1.2M, 750k, …).
  static String compactGold(int n) {
    if (n >= 1000000) {
      final whole = n ~/ 1000000;
      final rem = n % 1000000;
      if (rem == 0) return '${whole}M';
      final tenths = (rem / 100000).floor();
      if (tenths == 0) return '${whole}M';
      return '$whole.${tenths}M';
    }
    if (n >= 1000) return '${n ~/ 1000}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked) {
      return Column(
        children: [
          Text(
            '${dungeon.name} · Boss: ${dungeon.bossName}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          if (dungeon.blurb.isNotEmpty)
            Text(
              dungeon.blurb,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
        ],
      );
    }
    final detail = dungeon.unlockPrice > 0
        ? '${compactGold(lifetimeGold)} / ${compactGold(dungeon.unlockPrice)} lifetime gold'
        : 'Locked';
    return Text(
      '${dungeon.name} · $detail',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
    );
  }
}

class _ZonePathMap extends StatefulWidget {
  const _ZonePathMap({
    required this.dungeons,
    required this.selectedId,
    required this.lifetimeGold,
    required this.highestCleared,
    required this.pulse,
    required this.onSelect,
  });

  final List<DungeonDef> dungeons;
  final String selectedId;
  final int lifetimeGold;
  final int highestCleared;
  final double pulse;
  final ValueChanged<String> onSelect;

  /// Marker centers on painted gold rings (zone 0…14 top→bottom).
  /// Upper path from Stormwake base; endgame rings detected on rebuilt footer.
  static const List<Offset> markerNorm = [
    Offset(0.491, 0.042), // sandy — cave mouth
    Offset(0.483, 0.088), // goblin — camp
    Offset(0.474, 0.146), // king — fort wall
    Offset(0.514, 0.197), // underworld — purple crystals
    Offset(0.454, 0.249), // dead — tombs
    Offset(0.479, 0.303), // hell — spiked gate
    Offset(0.465, 0.355), // crystal — ice peaks
    Offset(0.503, 0.403), // tide — sunken ruins
    Offset(0.466, 0.449), // ember — lava door
    Offset(0.478, 0.513), // grove — dark forest
    Offset(0.485, 0.570), // storm — purple chasm
    Offset(0.544, 0.635), // rime — ice-rift ring
    Offset(0.506, 0.736), // fen — mire ring
    Offset(0.507, 0.839), // brass — vault ring
    Offset(0.499, 0.963), // veil — moth-dust ring
  ];

  static const double mapAspect = 2532 / 1024;

  @override
  State<_ZonePathMap> createState() => _ZonePathMapState();
}

class _ZonePathMapState extends State<_ZonePathMap> {
  final ScrollController _scroll = ScrollController();
  String? _scrolledTo;
  bool _didInitialJump = false;
  double? _lastMapH;
  double? _lastViewH;

  @override
  void didUpdateWidget(covariant _ZonePathMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _scrolledTo = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _ensureSelectedVisible(double mapH, double viewH) {
    if (!_scroll.hasClients) return;
    if (_scrolledTo == widget.selectedId &&
        _lastMapH == mapH &&
        _lastViewH == viewH) {
      return;
    }
    final idx = widget.dungeons.indexWhere((d) => d.id == widget.selectedId);
    if (idx < 0 || idx >= _ZonePathMap.markerNorm.length) return;
    final y = _ZonePathMap.markerNorm[idx].dy * mapH;
    // Keep HERE near vertical center of the path viewport.
    final target =
        (y - viewH * 0.45).clamp(0.0, math.max(0.0, mapH - viewH)).toDouble();
    _scrolledTo = widget.selectedId;
    _lastMapH = mapH;
    _lastViewH = viewH;
    if (!_didInitialJump) {
      _didInitialJump = true;
      _scroll.jumpTo(target);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static String _statusWord({
    required bool unlocked,
    required bool cleared,
    required bool selected,
  }) {
    if (selected) return 'HERE';
    if (cleared) return 'CLEAR';
    if (unlocked) return 'OPEN';
    return 'LOCKED';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        if (mapW < 8 || viewH < 8) return const SizedBox.shrink();
        final mapH = mapW * _ZonePathMap.mapAspect;
        // Disc stays readable; hit box meets phone minTouch (44).
        final discSize = (mapW * 0.092).clamp(34.0, 40.0);
        final hitSize = math.max(discSize, GameTheme.minTouch);
        const statusH = 13.0;

        final needsScroll = _scrolledTo != widget.selectedId ||
            _lastMapH != mapH ||
            _lastViewH != viewH;
        if (needsScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureSelectedVisible(mapH, viewH);
          });
        }

        final dungeons = widget.dungeons;
        assert(
          dungeons.length == _ZonePathMap.markerNorm.length,
          'World Path markerNorm must match DungeonCatalog (${dungeons.length} vs ${_ZonePathMap.markerNorm.length})',
        );
        final n = math.min(dungeons.length, _ZonePathMap.markerNorm.length);

        final pathChildren = <Widget>[
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                CustomAssets.worldPathMap,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];

        for (var i = 0; i < n; i++) {
          final d = dungeons[i];
          final anchor = _ZonePathMap.markerNorm[i];
          final unlocked = DungeonCatalog.isUnlocked(
            d.id,
            widget.lifetimeGold,
            widget.highestCleared,
          );
          final cleared = widget.highestCleared >= d.number;
          final selected = d.id == widget.selectedId;
          final cx = anchor.dx * mapW;
          final cy = anchor.dy * mapH;
          final left = (cx - hitSize / 2).clamp(0.0, mapW - hitSize).toDouble();
          final top = (cy - hitSize / 2)
              .clamp(0.0, math.max(0.0, mapH - hitSize - statusH))
              .toDouble();
          pathChildren.add(
            Positioned(
              left: left,
              top: top,
              width: hitSize,
              height: hitSize + statusH,
              child: _MapZoneMarker(
                def: d,
                discSize: discSize,
                hitSize: hitSize,
                unlocked: unlocked,
                cleared: cleared,
                selected: selected,
                pulse: widget.pulse,
                statusWord: _statusWord(
                  unlocked: unlocked,
                  cleared: cleared,
                  selected: selected,
                ),
                onTap: () => widget.onSelect(d.id),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              width: mapW,
              height: mapH,
              child: Stack(
                clipBehavior: Clip.none,
                children: pathChildren,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapZoneMarker extends StatelessWidget {
  const _MapZoneMarker({
    required this.def,
    required this.discSize,
    required this.hitSize,
    required this.unlocked,
    required this.cleared,
    required this.selected,
    required this.pulse,
    required this.statusWord,
    required this.onTap,
  });

  final DungeonDef def;
  final double discSize;
  final double hitSize;
  final bool unlocked;
  final bool cleared;
  final bool selected;
  final double pulse;
  final String statusWord;
  final VoidCallback onTap;

  Color get _statusColor {
    if (selected) return GameTheme.torchHot;
    if (cleared) return GameTheme.mossLit;
    if (unlocked) return GameTheme.torch;
    return GameTheme.parchmentDim;
  }

  @override
  Widget build(BuildContext context) {
    final ring = selected
        ? Color.lerp(GameTheme.torch, GameTheme.torchHot, pulse)!
        : (cleared
            ? GameTheme.mossLit.withValues(alpha: 0.55)
            : (unlocked
                ? GameTheme.torch.withValues(alpha: 0.35)
                : Colors.transparent));
    final semanticsLabel =
        '${def.name}, $statusWord${selected ? ', selected' : ''}';
    final iconSize = discSize * 0.82;

    Widget portrait = KenneySprite(
      asset: KenneyAssets.dungeonPortraitFor(def.id),
      size: iconSize,
    );
    if (!unlocked) {
      portrait = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.35, 0.35, 0.35, 0, 0,
          0.35, 0.35, 0.35, 0, 0,
          0.35, 0.35, 0.35, 0, 0,
          0, 0, 0, 0.9, 0,
        ]),
        child: portrait,
      );
    }

    return WebClickScope(
      label: semanticsLabel,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: hitSize,
                height: hitSize,
                child: Center(
                  child: SizedBox(
                    width: discSize,
                    height: discSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1410).withValues(alpha: 0.75),
                        border: Border.all(
                          color: ring,
                          width: selected ? 2.5 : 1.2,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: GameTheme.torch.withValues(alpha: 0.45),
                                  blurRadius: 10 + pulse * 3,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: ClipOval(child: portrait),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                statusWord,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GameTheme.body(size: 11, color: _statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
