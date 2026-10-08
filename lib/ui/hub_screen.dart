import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/debug_play_log.dart';
import '../core/menu_alerts.dart';
import '../core/chase_dispatcher.dart';
import '../core/ad_boost.dart';
import '../core/away_fight_tip.dart';
import '../core/game_director.dart';
import '../core/game_guides.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/gold_income.dart';
import '../core/greater_rift.dart';
import '../core/hub_chase.dart';
import '../core/hub_endgame_act.dart';
import '../core/hub_primary_cta.dart';
import '../core/keystone.dart';
import '../core/local_reminders.dart';
import '../core/meta_systems.dart';
import '../models/dungeon_def.dart';
import '../models/vfx_quality.dart';
import 'confirm_dialogs.dart';
import 'chase_bind.dart';
import 'cave_atmosphere.dart';
import 'dungeon_art_warmup.dart';
import 'dungeon_environment.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';
import 'meta/offline_welcome.dart';
import 'meta/notify_opt_in.dart';
import 'meta/play_review_ask_overlay.dart';
import '../core/menu_router.dart';
import 'coach_pulse.dart';
import 'first_session_tips.dart';
import 'shell/discord_thanks_overlay.dart';
import 'shell/whats_new_overlay.dart';
import 'hub/hub_endgame_map.dart';
import 'hub/hub_header.dart';
import 'hub/hub_powerups.dart';
import 'hub/hub_ranks.dart';
import 'shell/scroll_buff_stack.dart';
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
  static List<Offset> get endgameMapMarkerNorm => HubEndgameMap.markerNorm;
  static int get endgameMapMarkerCount => HubEndgameMap.markerNorm.length;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedId;
  HubEndgameHunt? _selectedHunt;
  late final AnimationController _torch;
  bool _offlineDialogShown = false;
  bool _offeredWhatsNew = false;
  bool _offeredDiscordThanks = false;
  bool _offeredNotifyOptIn = false;
  bool _notifyWatch = false;
  bool _offeredPlayReview = false;
  bool _userPickedZone = false;
  bool _showEndgameMap = false;
  int? _trackedAscension;
  int? _trackedHighestCleared;

  GameDirector get director => widget.director;
  MenuRouter get router => widget.router;
  GameState get state => director.state;

  /// Zone the night's chase wants on the map (KEY), else null.
  String? _chaseMapZoneId() {
    final chase = HubChase.forState(state);
    if (chase.kind == HubChaseKind.keystone && chase.zoneId != null) {
      return chase.zoneId;
    }
    return null;
  }

  void _syncSelection({required bool force}) {
    final chaseZone = _chaseMapZoneId();
    final preferred = chaseZone ?? GameLogic.recommendedDungeonId(state);
    if (force) {
      _userPickedZone = false;
      _selectedHunt = HubEndgameAct.huntForChase(HubChase.forState(state).kind);
      _selectedId = _selectedHunt != null
          ? HubEndgameAct.nodeFor(_selectedHunt!).portraitDungeonId
          : preferred;
      _showEndgameMap = _selectedHunt != null;
      return;
    }
    if (_userPickedZone) {
      // FEEL 078: keep CLEAR selection — no silent jump to NEXT.
      return;
    }
    // KEY night: HERE follows chase zone, not frontier recommended.
    if (chaseZone != null) {
      _selectedHunt = null;
      _showEndgameMap = false;
      if (_selectedId != chaseZone) _selectedId = chaseZone;
      return;
    }
    final hunt = HubEndgameAct.huntForChase(HubChase.forState(state).kind);
    if (hunt != null) {
      _selectedHunt = hunt;
      _showEndgameMap = true;
      _selectedId = HubEndgameAct.nodeFor(hunt).portraitDungeonId;
      return;
    }
    // Spire / GR / Rift nights handled above; leftover endgame leaves HERE.
    if (hubChaseOwnsEndgameRow(HubChase.forState(state).kind)) {
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
    );
    // First hub paint stays static — torch starts after two frames so the
    // world map / TODAY card are not fighting animation ticks on cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (director.state.vfxQuality == VfxQuality.minimal) return;
        _torch.repeat(reverse: true);
      });
    });
    director.addListener(_onDirectorForNotify);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(DungeonArtWarmup.warm(director.state.dungeonId));
      director.ensureMarketListings();
      director.armAwayPromise();
      await _maybeShowOffline();
      // FEEL 298
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      // One overlay card per hub visit after offline summary.
      if (await _maybeShowWhatsNew()) {
        _notifyWatch = true;
        return;
      }
      if (await _maybeShowDiscordThanks()) {
        _notifyWatch = true;
        return;
      }
      if (await _maybeShowNotifyOptIn()) {
        _notifyWatch = true;
        return;
      }
      _notifyWatch = true;
      await _maybeShowPlayReview();
    });
  }

  Future<void> _maybeShowOffline() async {
    if (_offlineDialogShown || !mounted || director.offlineSummary == null) {
      return;
    }
    _offlineDialogShown = true;
    await showOfflineProgressDialog(context, director);
  }

  Future<bool> _maybeShowWhatsNew() async {
    if (_offeredWhatsNew || !mounted) return false;
    if (director.state.inDungeon) return false;
    if (!MetaSystems.hasUnseenChangelog(director.state)) return false;
    // Don't cover READY claimables — let TODAY breathe first.
    final chase = HubChase.forState(director.state);
    if (chase.urgency == HubChaseUrgency.ready) return false;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _offeredWhatsNew) return false;
    if (director.state.inDungeon) return false;
    if (!MetaSystems.hasUnseenChangelog(director.state)) return false;
    _offeredWhatsNew = true;
    await WhatsNewOverlay.show(context, director);
    return true;
  }

  Future<bool> _maybeShowDiscordThanks() async {
    if (_offeredDiscordThanks || !mounted) return false;
    if (director.state.inDungeon) return false;
    if (!DiscordThanksOverlay.shouldOffer(director)) return false;
    _offeredDiscordThanks = true;
    await DiscordThanksOverlay.show(context, director);
    return true;
  }

  void _onDirectorForNotify() {
    if (!_notifyWatch || !mounted || _offeredNotifyOptIn) return;
    if (director.offlineSummary != null) return;
    if (!LocalReminders.shouldOfferOptIn(director.state)) return;
    unawaited(_maybeShowNotifyOptIn());
  }

  Future<bool> _maybeShowNotifyOptIn() async {
    if (_offeredNotifyOptIn || !mounted) return false;
    if (director.state.inDungeon) return false;
    if (director.offlineSummary != null) return false;
    if (!NotifyOptInOverlay.shouldOffer(director)) return false;
    _offeredNotifyOptIn = true;
    await NotifyOptInOverlay.show(context, director);
    return true;
  }

  Future<bool> _maybeShowPlayReview() async {
    if (_offeredPlayReview || !mounted) return false;
    if (director.state.inDungeon) return false;
    if (!PlayReviewAskOverlay.shouldOffer(director)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _offeredPlayReview) return false;
    if (director.state.inDungeon) return false;
    if (!PlayReviewAskOverlay.shouldOffer(director)) return false;
    _offeredPlayReview = true;
    DebugPlayLog.event('funnel', 'review_offer');
    await PlayReviewAskOverlay.show(context, director);
    return true;
  }

  @override
  void dispose() {
    director.removeListener(_onDirectorForNotify);
    _torch.dispose();
    super.dispose();
  }

  (String?, VoidCallback?) _chaseAction(BuildContext context, HubChase chase) {
    final plan = ChaseDispatcher.plan(
      chase,
      state: director.state,
      selectedZoneId: _selectedId,
    );
    if (plan.op == ChaseOp.none && plan.label == null) {
      return (null, null);
    }
    if (chase.kind == HubChaseKind.unlockZone && chase.zoneId == null) {
      return (null, null);
    }
    return (
      plan.label,
      () => runChasePlan(
        context: context,
        director: director,
        router: router,
        plan: plan,
        onEnterDungeon: widget.onEnterDungeon,
        onPickZone: (id) => setState(() {
          _userPickedZone = true;
          _showEndgameMap = false;
          _selectedHunt = null;
          _selectedId = id;
        }),
      ),
    );
  }

  /// Short AL-pill hunt tag from TODAY kind (phone width).
  String _shortHuntHint(HubChase chase) {
    switch (chase.kind) {
      case HubChaseKind.keystone:
        final k = chase.keyLevel ?? state.hardmodeLevel;
        return k > 0 ? 'KEY +$k' : 'KEY';
      case HubChaseKind.gauntletMilestone:
        return 'Gauntlet';
      case HubChaseKind.greaterRiftMilestone:
        return 'Ranked';
      case HubChaseKind.riftMilestone:
        return 'Farm';
      case HubChaseKind.ashenCrown:
        return 'Ashen';
      case HubChaseKind.doneForToday:
        return 'rest';
      case HubChaseKind.claimDailyVault:
      case HubChaseKind.claimMissions:
      case HubChaseKind.equipBag:
      case HubChaseKind.marketUpgrade:
      case HubChaseKind.meetHero:
      case HubChaseKind.ascend:
        return 'claim';
      case HubChaseKind.clearFloors:
        final t = chase.title.toLowerCase();
        if (t.contains('level the party') || t.contains('almost party')) {
          return 'to Lv${GameLogic.maxHeroLevel}';
        }
        if (t.length <= 14) return chase.title;
        return chase.title.split(' ').take(2).join(' ');
      default:
        final t = chase.title;
        if (t.length <= 14) return t;
        return t.split(' ').take(2).join(' ');
    }
  }

  Widget _hubActionColumn(
    BuildContext context, {
    required bool short,
    required bool unlockedSelected,
    required bool canAscend,
  }) {
    final contract = ChaseContract.fromState(state);
    final chase = contract.chase;
    // FEEL 040: KEY enter zone matches map HERE.
    if (chase.kind == HubChaseKind.keystone &&
        chase.zoneId != null &&
        !_userPickedZone &&
        _selectedId != chase.zoneId) {
      _selectedHunt = null;
      _showEndgameMap = false;
      _selectedId = chase.zoneId!;
    }
    final (actionLabel, onAction) = _chaseAction(context, chase);
    final chaseActionLabel = actionLabel;
    final ready = chase.urgency == HubChaseUrgency.ready;
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: chaseActionLabel,
      hasChaseAction: onAction != null && chaseActionLabel != null,
      unlockedSelected: unlockedSelected,
      hardmodeLevel: state.hardmodeLevel,
      showKeystoneJargon: GameLogic.showKeystoneJargon(state),
      endgameUnlocked: GameLogic.endgameUnlocked(state),
      mapHunt: _showEndgameMap ? _selectedHunt : null,
      showEndgameMap: _showEndgameMap,
      grBestTier: state.metaDepth.grBestTier,
    );
    final enterAction = unlockedSelected
        ? () => widget.onEnterDungeon(_selectedId)
        : null;
    VoidCallback? huntAction(HubEndgameHunt hunt) {
      switch (hunt) {
        case HubEndgameHunt.gauntlet:
          return () => confirmGauntletRun(context, director);
        case HubEndgameHunt.farmRift:
          return () => confirmRiftRun(context, director);
        case HubEndgameHunt.rankedGr:
          return () => confirmGreaterRiftRun(context, director);
        case HubEndgameHunt.ashen:
          return () => confirmAshenCrown(context, director, practice: false);
      }
    }

    VoidCallback? actionFor(String? label) {
      if (label == null) return null;
      for (final node in HubEndgameAct.nodes) {
        if (HubEndgameAct.enterLabelFor(
              node.hunt,
              grBestTier: state.metaDepth.grBestTier,
            ) ==
            label) {
          return huntAction(node.hunt);
        }
        if (node.hunt == HubEndgameHunt.rankedGr &&
            GreaterRift.isHubEnterLabel(label)) {
          return huntAction(node.hunt);
        }
        if (node.enterLabel == label) return huntAction(node.hunt);
      }
      if (HubPrimaryCta.isEnterFamilyLabel(label)) {
        if (label.startsWith('ENTER KEY')) {
          final key =
              HubPrimaryCta.keyLevelFromLabel(label) ??
              chase.keyLevel ??
              state.hardmodeLevel;
          return () {
            if (enterAction == null) return;
            if (director.state.hardmodeLevel != key) {
              director.setHardmodeLevel(key);
            }
            enterAction();
          };
        }
        return enterAction;
      }
      return onAction;
    }

    final primaryLabel = cta.primaryLabel;
    final primaryAction =
        actionFor(primaryLabel) ??
        (cta.hideInlineChaseAction ? onAction : enterAction);
    final String? secondaryLabel = cta.secondaryLabel;
    final VoidCallback? secondaryAction;
    if (secondaryLabel == null) {
      secondaryAction = null;
    } else if (cta.ashenPracticeSecondary) {
      secondaryAction = () =>
          confirmAshenCrown(context, director, practice: true);
    } else {
      secondaryAction = actionFor(secondaryLabel) ?? enterAction;
    }
    final showMetaKeyLink =
        cta.showKeyDial && !primaryLabel.contains('KEY');
    final endgameHunt =
        GameLogic.endgameUnlocked(state) &&
        (hubChaseOwnsEndgameRow(chase.kind) ||
            chase.kind == HubChaseKind.keystone);
    final vaultOwnedByChase =
        chase.kind == HubChaseKind.claimDailyVault ||
        chase.kind == HubChaseKind.dailyVaultProgress;
    // Ascend stays a button even when TODAY is gear, KEY, or a ready claim.
    final showAscendButton = HubUrgentRow.wantsAscendButton(
      canAscend: canAscend,
      chaseKind: chase.kind,
    );
    final showUrgentRow =
        showAscendButton ||
        (chase.urgency != HubChaseUrgency.ready &&
            !(endgameHunt && !canAscend));

    final keyDialLevel = chase.kind == HubChaseKind.keystone
        ? (chase.keyLevel ?? state.hardmodeLevel)
        : state.hardmodeLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubTodayCard(
          chase: chase,
          compact: short,
          hideDetail: short,
          hideWhy: true,
        ),
        SizedBox(height: short ? 4 : 6),
        Builder(
          builder: (context) {
            final coachEnter = FirstSessionTips.lineFor(
              state,
              CoachTarget.enter,
              inDungeon: false,
            );
            final awayLine = AwayFightTip.shouldShow(
              state,
              bossStairs: false,
            )
                ? AwayFightTip.lineFor(state)
                : null;
            final enterFamily = HubPrimaryCta.isEnterFamilyLabel(primaryLabel);
            final showCoach = coachEnter != null && enterFamily;
            final readyContract = ChaseContract(chase: chase);
            final readyTip = ready
                ? (readyContract.readyActionLabel ?? 'Do this first')
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (awayLine != null) CoachLine(awayLine, maxLines: 2),
                if (showCoach) CoachLine(coachEnter),
                AnimatedBuilder(
                  animation: _torch,
                  builder: (context, child) => Transform.scale(
                    scale: 1.0 + (_torch.value * 0.012),
                    child: child,
                  ),
                  child: CoachPulse(
                    active: showCoach,
                    child: GameButton(
                      label: primaryLabel,
                      tip: showCoach
                          ? coachEnter
                          : chase.kind == HubChaseKind.keystone &&
                                _selectedHunt == null
                          ? 'Starts your preferred KEY on this zone'
                          : readyTip ??
                              'Enter the selected dungeon',
                      style: GameButtonStyle.brown,
                      primary: true,
                      onPressed: primaryAction,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (showMetaKeyLink ||
            (secondaryLabel != null && secondaryAction != null)) ...[
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              if (showMetaKeyLink)
                GameButton(
                  label: 'KEY +$keyDialLevel',
                  style: GameButtonStyle.ghost,
                  expanded: false,
                  dense: true,
                  onPressed: () {
                    if (chase.kind == HubChaseKind.keystone) {
                      final key = chase.keyLevel ?? state.hardmodeLevel;
                      if (director.state.hardmodeLevel != key) {
                        director.setHardmodeLevel(key);
                      }
                    }
                    router.open(MenuRoute.key);
                  },
                ),
              if (secondaryLabel != null && secondaryAction != null)
                GameButton(
                  label: secondaryLabel,
                  style: GameButtonStyle.ghost,
                  expanded: false,
                  dense: true,
                  onPressed: secondaryAction,
                ),
            ],
          ),
        ],
        if (showUrgentRow) ...[
          const SizedBox(height: 4),
          HubUrgentRow(
            claimable: state.missions.where((m) => m.canClaim).length,
            canAscend: canAscend,
            ascendLabel: canAscend ? _ascendHubButtonLabel(state) : null,
            hideAscend: chase.kind == HubChaseKind.ascend,
            hideVaultClaim: vaultOwnedByChase,
            hideVaultProgress: vaultOwnedByChase,
            hideMissionClaim: chase.kind == HubChaseKind.claimMissions,
            hideDaily:
                chase.kind == HubChaseKind.dailyRun ||
                chase.kind == HubChaseKind.keystone ||
                chase.kind == HubChaseKind.dailyVaultProgress ||
                chase.kind == HubChaseKind.meetHero ||
                !GameLogic.showDailyRunOnHub(state),
            onContracts: () {
              router.open(MenuRoute.more, more: MoreSection.quests);
            },
            onAscend: () => confirmAscend(context, director),
            dailyClaimed: director.isDailyClaimedToday,
            onDaily: () => confirmDailyRun(context, director),
            weeklyReady: GameLogic.canClaimDailyVault(state),
            weeklyProgress: state.metaDepth.dailyVaultClears,
            weeklyClaimed: state.metaDepth.dailyVaultClaimed,
            weeklyBestTimedKey: state.metaDepth.dailyBestTimedKey,
            vaultClaimEssence: GameLogic.dailyVaultClaimPreviewEssence(state),
            onClaimDailyVault: director.claimDailyVault,
          ),
        ],
      ],
    );
  }

  bool _showPowerupsFab() =>
      MenuTabs.showScrolls(state) && AdBoost.showHubFab(state.metaDepth);

  String _ascendHubButtonLabel(GameState state) {
    final reward =
        GameLogic.ascendEssenceReward(state.ascensionLevel + 1) +
        MetaSystems.ascendMilestoneReward(
          state.ascensionLevel,
          state.ascensionLevel + 1,
        ) +
        MetaSystems.ascendStreakEssence(state);
    return 'ASCEND  +${reward}e';
  }

  /// Party line plus bosses left this run. The count stays visible when the
  /// place name is long.
  Widget _hubAscendTrack(GameState state) {
    final track = GameLogic.ascendTrackLabel(state);
    final place =
        '${state.partyName} · Boss on F${GameLogic.bossFloorFor(state)}';
    final placeStyle = GameTheme.body(size: 12, color: GameTheme.parchmentDim);
    if (track.isEmpty) {
      return Text(
        place,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: placeStyle,
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            place,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: placeStyle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '·',
          style: placeStyle,
        ),
        const SizedBox(width: 8),
        Text(
          track,
          maxLines: 1,
          style: GameTheme.body(size: 12, color: GameTheme.torchHot),
        ),
      ],
    );
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
    } else if (!_userPickedZone) {
      _syncSelection(force: false);
    }
    final canAscend = GameLogic.canAscend(state);
    final unlockedSelected = _selectedHunt != null
        ? GameLogic.endgameUnlocked(state)
        : DungeonCatalog.isUnlocked(
            _selectedId,
            GameLogic.partyMeanLevel(state),
            state.highestDungeonCleared,
          );
    final short = GameTheme.isShortHeight(context);
    final selectedDungeon = DungeonCatalog.byId(_selectedId);
    final chase = HubChase.forState(state);
    final endgameUnlocked = GameLogic.endgameUnlocked(state);
    final showEndgameLayer =
        endgameUnlocked || GameGuides.showEndgameBridgeGuides(state);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: const HubSceneBackdrop()),
        MenuChrome.playSafeArea(
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
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Torch bloom animates alone above — header must
                              // not rebuild 60×/s (wallet + HubChase.forState).
                              HubHeader(
                                ascensionLevel: state.ascensionLevel,
                                gold: state.gold,
                                essence: state.essence,
                                willRank: state.willRankTitle,
                                collectionScore: state.collectionScore,
                                displayTitle: state.displayTitle,
                                onOpenSettings: () => router.open(
                                  MenuRoute.more,
                                  more: MoreSection.settings,
                                ),
                                incomeLine: GoldIncome.hubRateLine(state),
                                hubGoldRate: hubChaseOwnsEndgameRow(chase.kind)
                                    ? null
                                    : GoldIncome.hubRateCompact(state),
                                multiplierLine: GoldIncome.multiplierLine(
                                  state,
                                ),
                                plainChrome: GameLogic.plainPlayerChrome(state),
                                showEssence: MenuTabs.showCamp(state),
                                dimIncome: hubChaseOwnsEndgameRow(chase.kind),
                                huntHint: _shortHuntHint(chase),
                                blessingStacks: state.metaDepth.ascendBlessings,
                                showBlessingStacks: MenuTabs.showKeep(state),
                              ),
                              const SizedBox(height: 2),
                              _hubAscendTrack(state),
                              if (director.offlineSummary != null) ...[
                                SizedBox(height: short ? 4 : 8),
                                HubOfflineBanner(
                                  compact: short,
                                  text: director.offlineSummary!.headline,
                                  onDismiss: () => showOfflineProgressDialog(
                                    context,
                                    director,
                                  ),
                                ),
                              ],
                              if (director.showPlayUpdateNotice) ...[
                                SizedBox(height: short ? 4 : 8),
                                HubPlayUpdateBanner(
                                  compact: short,
                                  onUpdate: director.openPlayUpdate,
                                  onLater: director.dismissPlayUpdateNotice,
                                ),
                              ],
                              SizedBox(height: short ? 4 : 6),
                              if (showEndgameLayer) ...[
                                HubMapModeTabs(
                                  showEndgame: _showEndgameMap,
                                  onSelectPath: () => setState(() {
                                    _userPickedZone = true;
                                    _showEndgameMap = false;
                                    if (_selectedHunt != null) {
                                      _selectedId =
                                          GameLogic.recommendedDungeonId(state);
                                    }
                                    _selectedHunt = null;
                                  }),
                                  onSelectEndgame: () => setState(() {
                                    _userPickedZone = true;
                                    _showEndgameMap = true;
                                    _selectedHunt ??=
                                        HubEndgameAct.huntForChase(
                                          chase.kind,
                                        ) ??
                                        HubEndgameHunt.gauntlet;
                                    _selectedId = HubEndgameAct.nodeFor(
                                      _selectedHunt!,
                                    ).portraitDungeonId;
                                  }),
                                ),
                                SizedBox(height: short ? 4 : 6),
                              ],
                              // PATH or ENDGAME board; only HERE-ring listens to torch.
                              Expanded(
                                flex: short ? 7 : 1,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: RepaintBoundary(
                                        child:
                                            _showEndgameMap && showEndgameLayer
                                            ? HubEndgameMap(
                                                selectedHunt: _selectedHunt,
                                                pulse: _torch,
                                                locked: !endgameUnlocked,
                                                grBestTier:
                                                    state.metaDepth.grBestTier,
                                                gauntletBestFloor: state
                                                    .metaDepth.gauntletBestFloor,
                                                riftBestTier:
                                                    state.metaDepth.riftBestTier,
                                                onSelectHunt: endgameUnlocked
                                                    ? (hunt) =>
                                                        setState(() {
                                                          _userPickedZone =
                                                              true;
                                                          _showEndgameMap =
                                                              true;
                                                          _selectedHunt = hunt;
                                                          _selectedId =
                                                              HubEndgameAct
                                                                  .nodeFor(
                                                                    hunt,
                                                                  )
                                                                  .portraitDungeonId;
                                                        })
                                                    : null,
                                              )
                                            : ZonePathMap(
                                                dungeons: DungeonCatalog.all,
                                                selectedId: _selectedId,
                                                partyLevel:
                                                    GameLogic.partyMeanLevel(
                                                      state,
                                                    ),
                                                highestCleared:
                                                    state.highestDungeonCleared,
                                                pulse: _torch,
                                                onSelect: (id) => setState(() {
                                                  _userPickedZone = true;
                                                  _showEndgameMap = false;
                                                  _selectedHunt = null;
                                                  _selectedId = id;
                                                }),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          ScrollBuffStack(
                                            meta: state.metaDepth,
                                            maxHeight: 88,
                                          ),
                                          HubRanksFab(
                                            onOpen: () => openHubRanksSheet(
                                              context,
                                              director,
                                            ),
                                          ),
                                          if (_showPowerupsFab())
                                            HubPowerupsFab(
                                              state: state,
                                              onOpen: () => openPowerupsSheet(
                                                context,
                                                director,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!short) ...[
                                const SizedBox(height: 4),
                                if (_selectedHunt != null)
                                  SelectedHuntCaption(
                                    hunt: _selectedHunt!,
                                    grBestTier: state.metaDepth.grBestTier,
                                  )
                                else
                                  SelectedZoneCaption(
                                    dungeon: selectedDungeon,
                                    unlocked: unlockedSelected,
                                    partyLevel: GameLogic.partyMeanLevel(state),
                                    // KEY chase detail already lists affixes · par.
                                    keyLevel:
                                        GameLogic.showKeystoneJargon(state) &&
                                            chase.kind != HubChaseKind.keystone
                                        ? state.hardmodeLevel
                                        : 0,
                                    keyAffixLine:
                                        GameLogic.showKeystoneJargon(state) &&
                                            chase.kind !=
                                                HubChaseKind.keystone &&
                                            state.hardmodeLevel > 0
                                        ? Keystone.previewAffixes(state)
                                              .take(2)
                                              .map(Keystone.label)
                                              .join(' · ')
                                        : null,
                                    hideBlurb:
                                        chase.urgency == HubChaseUrgency.ready,
                                  ),
                              ],
                              if (short)
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    child: _hubActionColumn(
                                      context,
                                      short: short,
                                      unlockedSelected: unlockedSelected,
                                      canAscend: canAscend,
                                    ),
                                  ),
                                )
                              else ...[
                                const SizedBox(height: 6),
                                _hubActionColumn(
                                  context,
                                  short: short,
                                  unlockedSelected: unlockedSelected,
                                  canAscend: canAscend,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
