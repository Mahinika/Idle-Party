import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/hub_chase.dart';
import '../core/keystone.dart';
import '../core/menu_alerts.dart';
import '../core/meta_systems.dart';
import '../models/dungeon_def.dart';
import 'confirm_dialogs.dart';
import 'cave_atmosphere.dart';
import 'dungeon_environment.dart';
import 'feedback_toast.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'meta_overlays.dart';
import '../core/menu_router.dart';
import 'shell/app_bottom_bar.dart';
import 'hub/hub_header.dart';
import 'hub/hub_today_card.dart';
import 'hub/hub_world_map.dart';

/// Idle Party hub: dungeon select / meta / ascend.
class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.director,
    required this.router,
    required this.onEnterDungeon,
  });

  final GameDirector director;

  /// Which menu is open — shared with the dungeon shell.
  final MenuRouter router;
  final void Function(String dungeonId) onEnterDungeon;

  /// Honesty helpers for ship_smoke (World Path marker ↔ catalog).
  static List<Offset> get worldPathMarkerNorm => ZonePathMap.markerNorm;
  static int get worldPathMarkerCount => ZonePathMap.markerNorm.length;

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
  MenuRouter get router => widget.router;
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
      onOpenParty: () => router.open(MenuRoute.party),
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
            router.open(MenuRoute.party);
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
        return ('POWER', () => router.open(MenuRoute.power));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trackedAscension != state.ascensionLevel ||
        _trackedHighestCleared != state.highestDungeonCleared) {
      final ascended =
          _trackedAscension != null &&
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
        RepaintBoundary(child: const HubSceneBackdrop()),
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
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            GameTheme.isPhoneWidth(context) ? 12 : 16,
                            GameTheme.isPhoneWidth(context) ? 8 : 10,
                            GameTheme.isPhoneWidth(context) ? 12 : 16,
                            GameTheme.isPhoneWidth(context) ? 4 : 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HubHeader(
                                ascensionLevel: state.ascensionLevel,
                                bossFloor: bossFloor,
                                gold: state.gold,
                                essence: state.essence,
                                soulbound: state.soulboundFragments,
                                willRank: state.willRankTitle,
                                collectionScore: state.collectionScore,
                                displayTitle: state.displayTitle,
                                zoneTrophies:
                                    state.metaDepth.zoneTrophies.length,
                                torch: flicker,
                                onOpenSettings: () =>
                                    router.open(MenuRoute.settings),
                              ),
                              if (director.offlineSummary != null) ...[
                                const SizedBox(height: 8),
                                HubOfflineBanner(
                                  text: director.offlineSummary!.headline,
                                  onDismiss: () => showOfflineProgressDialog(
                                    context,
                                    director,
                                    onOpenParty: () =>
                                        router.open(MenuRoute.party),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              // World Path: painted campaign map + tappable rings.
                              Expanded(
                                child: ZonePathMap(
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
                              SelectedZoneCaption(
                                dungeon: DungeonCatalog.byId(_selectedId),
                                unlocked: unlockedSelected,
                                lifetimeGold: state.lifetimeGoldEarned,
                              ),
                              const SizedBox(height: 6),
                              Builder(
                                builder: (context) {
                                  final contract = ChaseContract.fromState(
                                    state,
                                  );
                                  final chase = contract.chase;
                                  final (actionLabel, onAction) = _chaseAction(
                                    context,
                                    chase,
                                  );
                                  final weekMod =
                                      state.metaDepth.weeklyModifier;
                                  final showWeekAffix =
                                      !short &&
                                      weekMod.isNotEmpty &&
                                      GameLogic.showKeystoneJargon(state);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                                      HubTodayCard(
                                        chase: chase,
                                        compact: true,
                                        actionLabel: actionLabel,
                                        onAction: onAction,
                                      ),
                                      HubMetaPulse(
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
                                              ? () => widget.onEnterDungeon(
                                                  _selectedId,
                                                )
                                              : null,
                                        ),
                                      ),
                                      ChallengeToggles(
                                        director: director,
                                        collapsed: true,
                                      ),
                                      HubUrgentRow(
                                        claimable: state.missions
                                            .where((m) => m.isComplete)
                                            .length,
                                        canAscend: canAscend,
                                        ascendLabel: canAscend
                                            ? 'ASCEND  +${GameLogic.ascendEssenceReward(state.ascensionLevel + 1) + MetaSystems.ascendMilestoneReward(state.ascensionLevel, state.ascensionLevel + 1)}e'
                                            : null,
                                        hideAscend:
                                            chase.kind == HubChaseKind.ascend,
                                        hideVaultClaim:
                                            chase.kind ==
                                            HubChaseKind.claimDailyVault,
                                        hideMissionClaim:
                                            chase.kind ==
                                            HubChaseKind.claimMissions,
                                        hideDaily:
                                            chase.kind ==
                                                HubChaseKind.dailyRun ||
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
                            ],
                          ),
                        ),
                      ),
                      // Same nav row as the dungeon — same words, same place.
                      AppBottomBar(
                        alerts: MenuAlerts.forState(state),
                        route: MenuRoute.none,
                        showReason: true,
                        onParty: () => router.open(MenuRoute.party),
                        onPower: () => router.open(MenuRoute.power),
                        onMeta: () => router.open(MenuRoute.meta),
                      ),
                    ],
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
