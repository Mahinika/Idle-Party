import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/gold_income.dart';
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
import 'menu_chrome.dart';
import 'meta_overlays.dart';
import '../core/menu_router.dart';
import 'shell/app_bottom_bar.dart';
import 'hub/hub_header.dart';
import 'hub/hub_powerups.dart';
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
  bool _offeredDiscordThanks = false;
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
        GameLogic.partyMeanLevel(state),
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
      director.ensureMarketListings();
      await _maybeShowOffline();
      await _maybeShowWhatsNew();
      await _maybeShowDiscordThanks();
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
      onOpenParty: (kind) =>
          router.openForHubChase(director.state, kind),
    );
  }

  Future<void> _maybeShowWhatsNew() async {
    if (_offeredWhatsNew || !mounted) return;
    if (director.state.inDungeon) return;
    if (!MetaSystems.hasUnseenChangelog(director.state)) return;
    _offeredWhatsNew = true;
    await WhatsNewOverlay.show(context, director);
  }

  Future<void> _maybeShowDiscordThanks() async {
    if (_offeredDiscordThanks || !mounted) return;
    if (director.state.inDungeon) return;
    if (!DiscordThanksOverlay.shouldOffer(director)) return;
    _offeredDiscordThanks = true;
    await DiscordThanksOverlay.show(context, director);
  }

  @override
  void dispose() {
    _torch.dispose();
    super.dispose();
  }

  (String?, VoidCallback?) _chaseAction(BuildContext context, HubChase chase) {
    switch (chase.kind) {
      case HubChaseKind.claimDailyVault:
        return ('CLAIM VAULT', director.claimDailyVault);
      case HubChaseKind.claimMissions:
        return (
          'CLAIM QUESTS',
          () {
            for (final m in director.state.missions) {
              if (m.canClaim) director.claimMission(m.id);
            }
          },
        );
      case HubChaseKind.meetHero:
        return (
          'PARTY',
          () {
            director.ackPendingHeroReveals();
            router.openForHubChase(director.state, HubChaseKind.meetHero);
          },
        );
      case HubChaseKind.equipBag:
        return (
          'PARTY',
          () => router.openForHubChase(director.state, HubChaseKind.equipBag),
        );
      case HubChaseKind.marketUpgrade:
        return (
          'MARKET',
          () => router.open(MenuRoute.power, power: PowerTab.market),
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
              GameLogic.partyMeanLevel(director.state),
              director.state.highestDungeonCleared,
            );
            if (unlocked) widget.onEnterDungeon(id);
          },
        );
      case HubChaseKind.gauntletMilestone:
        return ('GAUNTLET', () => confirmGauntletRun(context, director));
      case HubChaseKind.riftMilestone:
        return ('RIFT', () => confirmRiftRun(context, director));
      case HubChaseKind.greaterRiftMilestone:
        return ('GREATER', () => confirmGreaterRiftRun(context, director));
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
              GameLogic.partyMeanLevel(director.state),
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
              GameLogic.partyMeanLevel(director.state),
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
        return (
          MenuTabs.showCodex(state) ? 'CODEX' : 'META',
          () => router.open(
            MenuRoute.meta,
            meta: MenuTabs.showCodex(state) ? MetaTab.codex : null,
          ),
        );
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
      GameLogic.partyMeanLevel(state),
      state.highestDungeonCleared,
    );

    final short = GameTheme.isShortHeight(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: const HubSceneBackdrop()),
        SafeArea(
          child: Builder(
            builder: (context) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Only the flame redraws each frame — the map, TODAY card and
                  // buttons used to rebuild 60 times a second with it.
                  AnimatedBuilder(
                    animation: _torch,
                    builder: (context, _) => CaveAtmosphere.torchBloom(
                      intensity: 0.55 + (_torch.value * 0.45),
                      alignment: const Alignment(0, 0.15),
                      sizeFactor: 0.7,
                    ),
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
                              AnimatedBuilder(
                                animation: _torch,
                                builder: (context, _) => HubHeader(
                                  ascensionLevel: state.ascensionLevel,
                                  bossFloor: bossFloor,
                                  gold: state.gold,
                                  essence: state.essence,
                                  willRank: state.willRankTitle,
                                  collectionScore: state.collectionScore,
                                  displayTitle: state.displayTitle,
                                  zoneTrophies:
                                      state.metaDepth.zoneTrophies.length,
                                  torch: 0.55 + (_torch.value * 0.45),
                                  onOpenSettings: () =>
                                      router.open(MenuRoute.settings),
                                  incomeLine: GoldIncome.hubRateLine(state),
                                  multiplierLine:
                                      GoldIncome.multiplierLine(state),
                                  partyName: state.partyName,
                                ),
                              ),
                              if (director.offlineSummary != null) ...[
                                const SizedBox(height: 8),
                                HubOfflineBanner(
                                  text: director.offlineSummary!.headline,
                                  onDismiss: () => showOfflineProgressDialog(
                                    context,
                                    director,
                                    onOpenParty: (kind) => router.openForHubChase(
                                      director.state,
                                      kind,
                                    ),
                                  ),
                                ),
                              ],
                              if (director.showPlayUpdateNotice) ...[
                                const SizedBox(height: 8),
                                HubPlayUpdateBanner(
                                  onUpdate: director.openPlayUpdate,
                                  onLater: director.dismissPlayUpdateNotice,
                                ),
                              ],
                              const SizedBox(height: 6),
                              // World Path: painted campaign map + tappable rings.
                              Expanded(
                                child: AnimatedBuilder(
                                  animation: _torch,
                                  builder: (context, _) => ZonePathMap(
                                    dungeons: DungeonCatalog.all,
                                    selectedId: _selectedId,
                                    partyLevel: GameLogic.partyMeanLevel(state),
                                    highestCleared: state.highestDungeonCleared,
                                    pulse: _torch.value,
                                    onSelect: (id) => setState(() {
                                      _userPickedZone = true;
                                      _selectedId = id;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectedZoneCaption(
                                dungeon: DungeonCatalog.byId(_selectedId),
                                unlocked: unlockedSelected,
                                partyLevel: GameLogic.partyMeanLevel(state),
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
                                  final ready =
                                      chase.urgency == HubChaseUrgency.ready;
                                  // One primary CTA on phone: fold TODAY ENTER
                                  // into the big button so KEY/ENTER don't double.
                                  final foldEnter =
                                      onAction != null &&
                                      (actionLabel == 'ENTER' ||
                                          actionLabel == 'DAILY');
                                  final readyPrimary =
                                      ready &&
                                      onAction != null &&
                                      actionLabel != null &&
                                      !foldEnter;
                                  final enterLabel =
                                      chase.kind == HubChaseKind.keystone
                                      ? 'ENTER KEY +${chase.keyLevel ?? state.hardmodeLevel}'
                                      : (chase.kind == HubChaseKind.dailyRun
                                            ? 'DAILY RUN'
                                            : 'ENTER DUNGEON');
                                  final enterAction = unlockedSelected
                                      ? () => widget.onEnterDungeon(_selectedId)
                                      : null;
                                  final String primaryLabel;
                                  final VoidCallback? primaryAction;
                                  final String? secondaryLabel;
                                  final VoidCallback? secondaryAction;
                                  if (foldEnter) {
                                    primaryLabel = enterLabel;
                                    primaryAction = onAction;
                                    secondaryLabel = null;
                                    secondaryAction = null;
                                  } else if (readyPrimary) {
                                    primaryLabel = actionLabel;
                                    primaryAction = onAction;
                                    final showSecondaryEnter =
                                        enterAction != null &&
                                        chase.kind !=
                                            HubChaseKind.claimDailyVault &&
                                        chase.kind !=
                                            HubChaseKind.claimMissions &&
                                        chase.kind != HubChaseKind.ascend &&
                                        chase.kind != HubChaseKind.meetHero &&
                                        chase.kind != HubChaseKind.equipBag &&
                                        chase.kind != HubChaseKind.marketUpgrade &&
                                        chase.kind != HubChaseKind.dailyRun;
                                    secondaryLabel = showSecondaryEnter
                                        ? enterLabel
                                        : null;
                                    secondaryAction = showSecondaryEnter
                                        ? enterAction
                                        : null;
                                  } else if (chase.kind == HubChaseKind.marketUpgrade &&
                                      onAction != null &&
                                      actionLabel != null) {
                                    primaryLabel = actionLabel;
                                    primaryAction = onAction;
                                    secondaryLabel = enterAction != null
                                        ? enterLabel
                                        : null;
                                    secondaryAction = enterAction;
                                  } else {
                                    primaryLabel = enterLabel;
                                    primaryAction = enterAction;
                                    secondaryLabel = null;
                                    secondaryAction = null;
                                  }
                                  final chaseOwnsKeyChrome =
                                      chase.kind ==
                                          HubChaseKind.claimDailyVault ||
                                      chase.kind ==
                                          HubChaseKind.dailyVaultProgress ||
                                      chase.kind == HubChaseKind.keystone ||
                                      ready ||
                                      chase.urgency == HubChaseUrgency.almost;
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
                                        actionLabel:
                                            foldEnter || readyPrimary
                                            ? null
                                            : actionLabel,
                                        onAction:
                                            foldEnter || readyPrimary
                                            ? null
                                            : onAction,
                                      ),
                                      HubPowerupsCard(
                                        state: state,
                                        onOpen: () => openPowerupsSheet(
                                          context,
                                          director,
                                        ),
                                      ),
                                      HubMetaPulse(
                                        state: state,
                                        chaseKind: chase.kind,
                                        chaseUrgency: chase.urgency,
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedBuilder(
                                        animation: _torch,
                                        builder: (context, child) =>
                                            Transform.scale(
                                              scale:
                                                  1.0 + (_torch.value * 0.012),
                                              child: child,
                                            ),
                                        child: KenneyButton(
                                          label: primaryLabel,
                                          tip: chase.kind ==
                                                  HubChaseKind.keystone
                                              ? 'Starts your preferred KEY on this zone'
                                              : readyPrimary
                                              ? 'TODAY — do this first'
                                              : 'Enter the selected dungeon',
                                          style: KenneyButtonStyle.brown,
                                          primary: true,
                                          onPressed: primaryAction,
                                        ),
                                      ),
                                      if (secondaryLabel != null &&
                                          secondaryAction != null) ...[
                                        const SizedBox(height: 4),
                                        KenneyButton(
                                          label: secondaryLabel,
                                          tip: 'Skip TODAY for now',
                                          style: KenneyButtonStyle.grey,
                                          onPressed: secondaryAction,
                                        ),
                                      ],
                                      if (GameLogic.showKeystoneJargon(state) &&
                                          !chaseOwnsKeyChrome) ...[
                                        const SizedBox(height: 2),
                                        MenuChrome.textLink(
                                          label: 'META → KEY',
                                          onPressed: () => router.open(
                                            MenuRoute.meta,
                                            meta: MetaTab.key,
                                          ),
                                        ),
                                      ],
                                      if (chase.urgency !=
                                          HubChaseUrgency.ready)
                                        HubUrgentRow(
                                          claimable: state.missions
                                              .where((m) => m.canClaim)
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
                                            if (m.canClaim) {
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
                                            GameLogic.endgameUnlocked(state),
                                        gauntletBest:
                                            state.metaDepth.gauntletBestFloor,
                                        onGauntlet: () => confirmGauntletRun(
                                          context,
                                          director,
                                        ),
                                        showRift:
                                            GameLogic.canEnterRift(state) ||
                                            GameLogic.endgameUnlocked(state),
                                        riftBest:
                                            state.metaDepth.riftBestTier,
                                        onRift: () =>
                                            confirmRiftRun(context, director),
                                        showGreaterRift:
                                            GameLogic.canEnterGreaterRift(
                                                  state,
                                                ) ||
                                            GameLogic.endgameUnlocked(state),
                                        grBest: state.metaDepth.grBestTier,
                                        onGreaterRift: () =>
                                            confirmGreaterRiftRun(
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
                                        vaultClaimEssence:
                                            GameLogic.dailyVaultClaimPreviewEssence(
                                          state,
                                        ),
                                        onClaimDailyVault:
                                            director.claimDailyVault,
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
