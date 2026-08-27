import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/ad_boost.dart';
import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/gold_income.dart';
import '../core/hub_chase.dart';
import '../core/local_season.dart';
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
  // Kept for map / tests; selection no longer auto-snaps CLEAR → NEXT (FEEL 078).
  // ignore: unused_element
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
      // FEEL 078: keep CLEAR selection — no silent jump to NEXT.
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
            director.claimAllReadyMissions();
            router.open(MenuRoute.meta, meta: MetaTab.jobs);
          },
        );
      case HubChaseKind.monthGoal:
        return ('CLAIM MONTH', director.claimMonthPass);
      case HubChaseKind.meetHero:
        return (
          'PARTY',
          () {
            // Ack when leaving PARTY (menu_surface) so kit fantasy can be read first.
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
          '🔑 ENTER KEY +${chase.keyLevel ?? 1}',
          () {
            final key = chase.keyLevel ?? 1;
            director.setHardmodeLevel(key);
            if (chase.zoneId != null) {
              setState(() {
                _userPickedZone = true;
                _selectedId = chase.zoneId!;
              });
            }
            final affixes = Keystone.previewAffixes(director.state);
            final affixBit = affixes.isEmpty
                ? 'no affixes'
                : affixes.map(Keystone.label).join(' · ');
            final par = Keystone.formatTimer(
              Keystone.parTimeMs(
                bossFloor: GameLogic.bossFloorFor(director.state),
                key: key,
              ),
            );
            director.showToast(
              'KEY +$key · $affixBit · par $par',
              life: 2.8,
            );
            final unlocked = DungeonCatalog.isUnlocked(
              id,
              GameLogic.partyMeanLevel(director.state),
              director.state.highestDungeonCleared,
            );
            if (unlocked) widget.onEnterDungeon(id);
          },
        );
      case HubChaseKind.gauntletMilestone:
        return ('⚔ GAUNTLET', () => confirmGauntletRun(context, director));
      case HubChaseKind.riftMilestone:
        return ('◈ RIFT', () => confirmRiftRun(context, director));
      case HubChaseKind.greaterRiftMilestone:
        return ('◆ GREATER RIFT', () => confirmGreaterRiftRun(context, director));
      case HubChaseKind.ashenCrown:
        return (
          'ASHEN CROWN',
          () => confirmAshenCrown(context, director, practice: false),
        );
      case HubChaseKind.weekGoal:
        // FEEL 067: prefer Gauntlet when week target is a floor climb.
        final weekKey = director.state.metaDepth.weeklyKey.isNotEmpty
            ? director.state.metaDepth.weeklyKey
            : GameLogic.isoWeekKey(DateTime.now().toUtc());
        final week = LocalSeasonCatalog.forWeekKey(weekKey);
        if (chase.urgency == HubChaseUrgency.ready) {
          return (
            'CLAIM WEEK',
            () {
              // Week goals settle through GameLogic.syncMetaPayoffs on hub ticks.
              director.syncMetaPayoffs();
            },
          );
        }
        if (week.gauntletFloorTarget > 0) {
          return ('⚔ GAUNTLET', () => confirmGauntletRun(context, director));
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
        final lockedId = chase.zoneId;
        if (lockedId == null) return (null, null);
        // Farm the recommended (usually prior) zone — PATH alone felt empty.
        final enterId = GameLogic.recommendedDungeonId(director.state);
        return (
          'PATH',
          () {
            setState(() {
              _userPickedZone = true;
              _selectedId = enterId;
            });
            final unlocked = DungeonCatalog.isUnlocked(
              enterId,
              GameLogic.partyMeanLevel(director.state),
              director.state.highestDungeonCleared,
            );
            if (unlocked) widget.onEnterDungeon(enterId);
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
      _selectedId = chase.zoneId!;
    }
    final (actionLabel, onAction) = _chaseAction(context, chase);
    final chaseActionLabel = actionLabel;
    final ready = chase.urgency == HubChaseUrgency.ready;
    // One primary CTA on phone: fold TODAY ENTER into the big button.
    final foldEnter =
        onAction != null &&
        (chaseActionLabel == 'ENTER' ||
            chaseActionLabel == 'DAILY' ||
            (chaseActionLabel?.contains('ENTER KEY') ?? false));
    final endgamePrimary =
        onAction != null &&
        chaseActionLabel != null &&
        hubChaseOwnsEndgameRow(chase.kind);
    final readyPrimary =
        ready &&
        onAction != null &&
        chaseActionLabel != null &&
        !foldEnter;
    final enterLabel = chase.kind == HubChaseKind.keystone
        ? '🔑 ENTER KEY +${chase.keyLevel ?? state.hardmodeLevel}'
        : (chase.kind == HubChaseKind.dailyRun ? 'DAILY RUN' : 'ENTER DUNGEON');
    final enterAction =
        unlockedSelected ? () => widget.onEnterDungeon(_selectedId) : null;
    final String primaryLabel;
    final VoidCallback? primaryAction;
    final String? secondaryLabel;
    final VoidCallback? secondaryAction;
    if (foldEnter || endgamePrimary) {
      primaryLabel = foldEnter ? enterLabel : chaseActionLabel!;
      primaryAction = onAction;
      if (chase.kind == HubChaseKind.ashenCrown &&
          GameLogic.endgameUnlocked(state)) {
        secondaryLabel = 'PRACTICE';
        secondaryAction = () => confirmAshenCrown(
          context,
          director,
          practice: true,
        );
      } else if (endgamePrimary && enterAction != null) {
        // Gauntlet / Rift / … suggested — ENTER DUNGEON stays optional.
        secondaryLabel = enterLabel;
        secondaryAction = enterAction;
      } else {
        secondaryLabel = null;
        secondaryAction = null;
      }
    } else if (readyPrimary) {
      primaryLabel = chaseActionLabel;
      primaryAction = onAction;
      // Never trap on Ascend / Meet kit / BAG / vault — ENTER stays a choice.
      secondaryLabel = enterAction != null ? enterLabel : null;
      secondaryAction = enterAction;
    } else if (chase.kind == HubChaseKind.marketUpgrade &&
        onAction != null &&
        chaseActionLabel != null) {
      primaryLabel = chaseActionLabel;
      primaryAction = onAction;
      secondaryLabel = enterAction != null ? enterLabel : null;
      secondaryAction = enterAction;
    } else {
      primaryLabel = enterLabel;
      primaryAction = enterAction;
      secondaryLabel = null;
      secondaryAction = null;
    }
    final showMetaKeyLink = GameLogic.showKeystoneJargon(state);
    final endgameHunt =
        GameLogic.endgameUnlocked(state) &&
        (hubChaseOwnsEndgameRow(chase.kind) ||
            chase.kind == HubChaseKind.keystone);
    final weekMod = state.metaDepth.weeklyModifier;
    final showWeekAffix =
        !short && weekMod.isNotEmpty && GameLogic.showKeystoneJargon(state);
    final powerupsActive =
        AdBoost.isActive(state.metaDepth.adBoostUntilMs);
    // Endgame hunt night: hide idle POWERUPS chrome unless a boost is running.
    final showPowerups = endgameHunt
        ? powerupsActive
        : (!short || powerupsActive);
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
          hideDetail: short,
          actionLabel: foldEnter || readyPrimary ? null : chaseActionLabel,
          onAction: foldEnter || readyPrimary ? null : onAction,
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
          child: KenneyButton(
            label: primaryLabel,
            tip: chase.kind == HubChaseKind.keystone
                ? 'Starts your preferred KEY on this zone'
                : readyPrimary
                ? 'TODAY — do this first'
                : 'Enter the selected dungeon',
            style: KenneyButtonStyle.brown,
            primary: true,
            onPressed: primaryAction,
          ),
        ),
        if (secondaryLabel != null && secondaryAction != null) ...[
          const SizedBox(height: 4),
          KenneyButton(
            label: secondaryLabel,
            tip: secondaryLabel.startsWith('ENTER') ||
                    secondaryLabel == 'DAILY RUN'
                ? 'Farm the selected zone'
                : 'Also available',
            style: KenneyButtonStyle.grey,
            onPressed: secondaryAction,
          ),
        ],
        if (showPowerups)
          HubPowerupsCard(
            state: state,
            onOpen: () => openPowerupsSheet(context, director),
          ),
        if (showMetaKeyLink) ...[
          const SizedBox(height: 4),
          KenneyButton(
            label: state.hardmodeLevel <= 0
                ? 'KEY DIAL · off'
                : 'KEY DIAL · +${state.hardmodeLevel}',
            tip: 'Open META → KEY for Soft/Hard/Brutal, Rifts, and boards',
            style: KenneyButtonStyle.grey,
            onPressed: () =>
                router.open(MenuRoute.meta, meta: MetaTab.key),
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
                                  dimIncome: hubChaseOwnsEndgameRow(
                                    HubChase.forState(state).kind,
                                  ),
                                ),
                              ),
                              if (director.offlineSummary != null) ...[
                                SizedBox(height: short ? 4 : 8),
                                HubOfflineBanner(
                                  compact: short,
                                  text: director.offlineSummary!.headline,
                                  onDismiss: () => showOfflineProgressDialog(
                                    context,
                                    director,
                                    onOpenParty: (kind) => router.openForHubChase(
                                      director.state,
                                      kind,
                                    ),
                                    onOpenMarket: () => router.open(
                                      MenuRoute.power,
                                      power: PowerTab.market,
                                    ),
                                    onEnterDungeon: widget.onEnterDungeon,
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
                              // World Path: painted campaign map + tappable rings.
                              Expanded(
                                flex: short ? 7 : 1,
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
                              if (!short) ...[
                                const SizedBox(height: 4),
                                SelectedZoneCaption(
                                  dungeon: DungeonCatalog.byId(_selectedId),
                                  unlocked: unlockedSelected,
                                  partyLevel: GameLogic.partyMeanLevel(state),
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
                      // Same nav row as the dungeon — same words, same place.
                      AppBottomBar(
                        alerts: MenuAlerts.forState(state),
                        route: MenuRoute.none,
                        showReason: true,
                        onParty: () => router.open(MenuRoute.party),
                        onPower: () => router.open(MenuRoute.power),
                        onMeta: () => router.open(MenuRoute.meta, state: state),
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
              alignment: const Alignment(0, -0.55),
            ),
          ),
      ],
    );
  }
}

/// Always-visible KEY / vault / week crumbs under TODAY (phone hub).
/// Skips bits that duplicate the active chase so the strip stays quiet.
