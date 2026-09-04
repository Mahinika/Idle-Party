import 'package:flutter/material.dart';

import '../core/chase_contract.dart';
import '../core/chase_dispatcher.dart';
import '../core/ad_boost.dart';
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
import 'chase_bind.dart';
import 'cave_atmosphere.dart';
import 'dungeon_environment.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'meta/offline_welcome.dart';
import '../core/menu_router.dart';
import 'shell/app_bottom_bar.dart';
import 'shell/discord_thanks_overlay.dart';
import 'shell/whats_new_overlay.dart';
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
          _selectedId = id;
        }),
      ),
    );
  }

  /// Short AL-pill hunt tag from TODAY title (phone width).
  String _shortHuntHint(HubChase chase) {
    final t = chase.title;
    if (t.startsWith('Time KEY') || t.startsWith('Run KEY')) return 'KEY';
    if (t.contains('Gauntlet') || t.contains('Spire') || t.contains('PB')) {
      return 'Spire';
    }
    if (t.contains('Greater Rift') || t.startsWith('GR')) return 'GR';
    if (t.contains('Rift')) return 'Rift';
    if (t.contains('Ashen')) return 'Ashen';
    if (t.contains('Done for today')) return 'rest';
    if (t.length <= 14) return t;
    return t.split(' ').take(2).join(' ');
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
        (hubChaseOwnsEndgameRow(chase.kind) ||
            (chaseActionLabel.contains('GAUNTLET')) ||
            (chaseActionLabel.contains('GREATER RIFT')) ||
            chaseActionLabel == '◈ RIFT');
    final readyPrimary =
        ready &&
        onAction != null &&
        chaseActionLabel != null &&
        !foldEnter;
    final keyFromChase = chase.keyLevel ??
        (foldEnter && (chaseActionLabel?.contains('ENTER KEY') ?? false)
            ? _keyLevelFromLabel(chaseActionLabel!)
            : null);
    final enterLabel = keyFromChase != null
        ? '🔑 ENTER KEY +$keyFromChase'
        : (chase.kind == HubChaseKind.keystone
            ? '🔑 ENTER KEY +${chase.keyLevel ?? state.hardmodeLevel}'
            : (chase.kind == HubChaseKind.dailyRun
                ? 'DAILY RUN'
                : 'ENTER DUNGEON'));
    final enterAction =
        unlockedSelected ? () => widget.onEnterDungeon(_selectedId) : null;
    final String primaryLabel;
    final VoidCallback? primaryAction;
    final String? secondaryLabel;
    final VoidCallback? secondaryAction;
    if (foldEnter || endgamePrimary) {
      // Prefer chase CTA when it already names KEY / hunt — don't swap to
      // bare ENTER DUNGEON (vault halfway / month KEY cliff).
      primaryLabel = foldEnter
          ? ((chaseActionLabel?.contains('ENTER KEY') ?? false)
              ? chaseActionLabel!
              : enterLabel)
          : chaseActionLabel!;
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
    // First hour: hide ads chrome until the first boss — ENTER stays the focus.
    final showPowerups = GameLogic.plainPlayerChrome(state)
        ? powerupsActive
        : endgameHunt
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
                ? 'KEY DIAL · +0'
                : 'KEY DIAL · +${state.hardmodeLevel}',
            tip: 'Open KEY for Soft/Hard/Brutal, Rifts, and boards',
            style: KenneyButtonStyle.grey,
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
    final chase = HubChase.forState(state);
    final selectedDungeon = DungeonCatalog.byId(_selectedId);

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
                                builder: (context, _) {
                                  final chaseNow = HubChase.forState(state);
                                  return HubHeader(
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
                                  onOpenSettings: () => router.open(
                                    MenuRoute.more,
                                    more: MoreSection.settings,
                                  ),
                                  incomeLine: GoldIncome.hubRateLine(state),
                                  multiplierLine:
                                      GoldIncome.multiplierLine(state),
                                  partyName: state.partyName,
                                  plainChrome: GameLogic.plainPlayerChrome(state),
                                  dimIncome: hubChaseOwnsEndgameRow(
                                    chaseNow.kind,
                                  ),
                                  huntHint: _shortHuntHint(chaseNow),
                                  blessingStacks:
                                      state.metaDepth.ascendBlessings,
                                );
                                },
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
                              // World Path: always the scrollable map (tap a ring to pick).
                              Expanded(
                                flex: short ? 7 : 1,
                                child: AnimatedBuilder(
                                  animation: _torch,
                                  builder: (context, _) => ZonePathMap(
                                    dungeons: DungeonCatalog.all,
                                    selectedId: _selectedId,
                                    partyLevel:
                                        GameLogic.partyMeanLevel(state),
                                    highestCleared:
                                        state.highestDungeonCleared,
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
                                  dungeon: selectedDungeon,
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
                        alerts: MenuAlerts.forHub(
                          state,
                          chaseKind: chase.kind,
                          urgency: chase.urgency,
                        ),
                        route: router.route,
                        destinations: DestinationGraph.hub(state).destinations,
                        showReason: chase.urgency != HubChaseUrgency.ready,
                        onSelect: (dest) => router.toggle(dest),
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

int? _keyLevelFromLabel(String label) {
  final match = RegExp(r'ENTER KEY \+(\d+)').firstMatch(label);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// Always-visible KEY / vault / week crumbs under TODAY (phone hub).
/// Skips bits that duplicate the active chase so the strip stays quiet.
