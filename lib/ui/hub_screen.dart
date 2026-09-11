import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/chase_dispatcher.dart';
import '../core/ad_boost.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/gold_income.dart';
import '../core/hub_chase.dart';
import '../core/hub_endgame_act.dart';
import '../core/hub_primary_cta.dart';
import '../core/keystone.dart';
import '../core/meta_systems.dart';
import '../models/dungeon_def.dart';
import '../models/vfx_quality.dart';
import 'confirm_dialogs.dart';
import 'chase_bind.dart';
import 'cave_atmosphere.dart';
import 'dungeon_environment.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'meta/offline_welcome.dart';
import '../core/menu_router.dart';
import 'shell/discord_thanks_overlay.dart';
import 'shell/whats_new_overlay.dart';
import 'hub/hub_endgame_map.dart';
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
    final preferred =
        chaseZone ?? GameLogic.recommendedDungeonId(state);
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      director.ensureMarketListings();
      await _maybeShowOffline();
      // FEEL 298
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      await _maybeShowWhatsNew();
      await _maybeShowDiscordThanks();
    });
  }

  Future<void> _maybeShowOffline() async {
    if (_offlineDialogShown || !mounted || director.offlineSummary == null) {
      return;
    }
    _offlineDialogShown = true;
    await showOfflineProgressDialog(context, director);
  }

  Future<void> _maybeShowWhatsNew() async {
    if (_offeredWhatsNew || !mounted) return;
    if (director.state.inDungeon) return;
    if (!MetaSystems.hasUnseenChangelog(director.state)) return;
    // Don't cover READY claimables — let TODAY breathe first.
    final chase = HubChase.forState(director.state);
    if (chase.urgency == HubChaseUrgency.ready) return;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _offeredWhatsNew) return;
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
      mapHunt: _userPickedZone ? _selectedHunt : null,
    );
    final enterAction =
        unlockedSelected ? () => widget.onEnterDungeon(_selectedId) : null;
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
        if (node.enterLabel == label) return huntAction(node.hunt);
      }
      if (HubPrimaryCta.isEnterFamilyLabel(label)) {
        return enterAction;
      }
      return onAction;
    }

    final primaryLabel = cta.primaryLabel;
    final primaryAction = actionFor(primaryLabel) ??
        (cta.hideInlineChaseAction ? onAction : enterAction);
    final String? secondaryLabel = cta.secondaryLabel;
    final VoidCallback? secondaryAction;
    if (secondaryLabel == null) {
      secondaryAction = null;
    } else if (cta.ashenPracticeSecondary) {
      secondaryAction = () => confirmAshenCrown(
            context,
            director,
            practice: true,
          );
    } else {
      secondaryAction = actionFor(secondaryLabel) ?? enterAction;
    }
    final showMetaKeyLink = cta.showKeyDial;
    final endgameHunt =
        GameLogic.endgameUnlocked(state) &&
        (hubChaseOwnsEndgameRow(chase.kind) ||
            chase.kind == HubChaseKind.keystone);
    final weekMod = state.metaDepth.weeklyModifier;
    final keyAffixLabels = state.hardmodeLevel > 0
        ? Keystone.previewAffixes(state).map(Keystone.label).toSet()
        : const <String>{};
    final showWeekAffix =
        !short &&
        weekMod.isNotEmpty &&
        GameLogic.showKeystoneJargon(state) &&
        // Don't repeat the same affix under KEY +N and as Week · …
        !keyAffixLabels.contains(Keystone.label(weekMod));
    final vaultOwnedByChase =
        chase.kind == HubChaseKind.claimDailyVault ||
        chase.kind == HubChaseKind.dailyVaultProgress;
    final showUrgentRow =
        chase.urgency != HubChaseUrgency.ready &&
        !(endgameHunt && !canAscend);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWeekAffix) ...[
          Text(
            'Week · ${Keystone.label(weekMod)} — ${Keystone.blurb(weekMod)}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
          ),
          const SizedBox(height: 4),
        ],
        HubTodayCard(
          chase: chase,
          compact: true,
          // Short phones still keep READY / ALMOST detail — that is the hunt.
          hideDetail: short && chase.urgency == HubChaseUrgency.normal,
          actionLabel: cta.hideInlineChaseAction ? null : chaseActionLabel,
          onAction: cta.hideInlineChaseAction ? null : onAction,
        ),
        if (!short)
          HubMetaPulse(
            state: state,
            chaseKind: chase.kind,
            chaseUrgency: chase.urgency,
          ),
        SizedBox(height: short ? 4 : 6),
        AnimatedBuilder(
          animation: _torch,
          builder: (context, child) => Transform.scale(
            scale: 1.0 + (_torch.value * 0.012),
            child: child,
          ),
          child: GameButton(
            label: primaryLabel,
            tip: chase.kind == HubChaseKind.keystone && _selectedHunt == null
                ? 'Starts your preferred KEY on this zone'
                : (ready || cta.hideInlineChaseAction)
                ? 'TODAY — do this first'
                : 'Enter the selected dungeon',
            style: GameButtonStyle.brown,
            primary: true,
            onPressed: primaryAction,
          ),
        ),
        if (secondaryLabel != null && secondaryAction != null) ...[
          const SizedBox(height: 4),
          GameButton(
            label: secondaryLabel,
            tip: secondaryLabel.startsWith('ENTER') ||
                    secondaryLabel == 'DAILY RUN'
                ? 'Farm the selected zone'
                : 'Also available',
            style: GameButtonStyle.grey,
            onPressed: secondaryAction,
          ),
        ],
        if (showMetaKeyLink) ...[
          const SizedBox(height: 4),
          GameButton(
            label: state.hardmodeLevel <= 0
                ? 'KEY DIAL · +0'
                : 'KEY DIAL · +${state.hardmodeLevel}',
            tip: 'Open KEY for Soft/Hard/Brutal, Rifts, and boards',
            style: GameButtonStyle.grey,
            onPressed: () => router.open(MenuRoute.key),
          ),
        ],
        if (showUrgentRow)
          HubUrgentRow(
            claimable: state.missions.where((m) => m.canClaim).length,
            canAscend: canAscend,
            ascendLabel: canAscend
                ? 'ASCEND  +${GameLogic.ascendEssenceReward(state.ascensionLevel + 1) + MetaSystems.ascendMilestoneReward(state.ascensionLevel, state.ascensionLevel + 1)}e'
                : null,
            hideAscend: // FEEL 050
                chase.kind == HubChaseKind.ascend ||
                chase.kind == HubChaseKind.dailyRun,
            hideVaultClaim: vaultOwnedByChase,
            hideVaultProgress: vaultOwnedByChase,
            hideMissionClaim: chase.kind == HubChaseKind.claimMissions,
            hideDaily:
                chase.kind == HubChaseKind.dailyRun ||
                chase.kind == HubChaseKind.keystone ||
                chase.kind == HubChaseKind.dailyVaultProgress ||
                chase.kind == HubChaseKind.meetHero ||
                !GameLogic.showDailyChase(state),
            onContracts: () {
              director.claimAllReadyMissions();
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
    );
  }

  bool _showPowerupsFab() {
    final md = state.metaDepth;
    final powerupsActive = AdBoost.anyBuffActive(md);
    final hasTickets = md.adTickets > 0;

    if (powerupsActive || hasTickets) return true;

    if (md.adFree) {
      return AdBoost.canClaimAdFreeDaily(md);
    }

    // First hour: keep hub calm until the first boss.
    if (GameLogic.plainPlayerChrome(state)) return false;

    // Always reachable on hub after first boss (phone + READY claims included).
    return true;
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
    final bossFloor = GameLogic.bossFloorFor(state);
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
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Torch bloom animates alone above — header must
                              // not rebuild 60×/s (wallet + HubChase.forState).
                              HubHeader(
                                ascensionLevel: state.ascensionLevel,
                                bossFloor: bossFloor,
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
                                multiplierLine:
                                    GoldIncome.multiplierLine(state),
                                partyName: state.partyName,
                                plainChrome:
                                    GameLogic.plainPlayerChrome(state),
                                dimIncome: hubChaseOwnsEndgameRow(
                                  chase.kind,
                                ),
                                huntHint: _shortHuntHint(chase),
                                blessingStacks:
                                    state.metaDepth.ascendBlessings,
                                powerupsFab: _showPowerupsFab()
                                    ? HubPowerupsFab(
                                        state: state,
                                        compact: true,
                                        onOpen: () => openPowerupsSheet(
                                          context,
                                          director,
                                        ),
                                      )
                                    : null,
                              ),
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
                              if (GameLogic.endgameUnlocked(state)) ...[
                                HubMapModeTabs(
                                  showEndgame: _showEndgameMap,
                                  onSelectPath: () => setState(() {
                                    _userPickedZone = true;
                                    _showEndgameMap = false;
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
                                child: RepaintBoundary(
                                  child: _showEndgameMap &&
                                          GameLogic.endgameUnlocked(state)
                                      ? HubEndgameMap(
                                          selectedHunt: _selectedHunt,
                                          pulse: _torch,
                                          onSelectHunt: (hunt) => setState(() {
                                            _userPickedZone = true;
                                            _showEndgameMap = true;
                                            _selectedHunt = hunt;
                                            _selectedId = HubEndgameAct
                                                .nodeFor(hunt)
                                                .portraitDungeonId;
                                          }),
                                        )
                                      : ZonePathMap(
                                          dungeons: DungeonCatalog.all,
                                          selectedId: _selectedId,
                                          partyLevel:
                                              GameLogic.partyMeanLevel(state),
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
                              if (!short) ...[
                                const SizedBox(height: 4),
                                if (_selectedHunt != null)
                                  SelectedHuntCaption(hunt: _selectedHunt!)
                                else
                                  SelectedZoneCaption(
                                    dungeon: selectedDungeon,
                                    unlocked: unlockedSelected,
                                    partyLevel: GameLogic.partyMeanLevel(state),
                                    // KEY chase detail already lists affixes · par.
                                    keyLevel: chase.kind == HubChaseKind.keystone
                                        ? 0
                                        : state.hardmodeLevel,
                                    keyAffixLine:
                                        chase.kind == HubChaseKind.keystone ||
                                                state.hardmodeLevel <= 0
                                            ? null
                                            : Keystone.previewAffixes(state)
                                                .take(2)
                                                .map(Keystone.label)
                                                .join(' · '),
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
