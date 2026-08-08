import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
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
import 'kenney_panel.dart';
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
    required this.onOpenInventory,
    required this.onOpenSanctuary,
    required this.onOpenJobs,
    required this.onOpenForge,
    required this.onOpenMarket,
    required this.onOpenBeast,
    required this.onOpenSettings,
    this.onOpenAchievements,
    this.onOpenCodex,
    this.onOpenLoadouts,
    this.onOpenTeam,
    this.onOpenGuides,
    this.onOpenPrestigeShop,
  });

  final GameDirector director;
  final void Function(String dungeonId) onEnterDungeon;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenSanctuary;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenMarket;
  final VoidCallback onOpenBeast;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenAchievements;
  final VoidCallback? onOpenCodex;
  final VoidCallback? onOpenLoadouts;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenGuides;
  final VoidCallback? onOpenPrestigeShop;

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
    await showOfflineProgressDialog(context, director);
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

  String _dungeonIcon(DungeonDef def) =>
      KenneyAssets.dungeonPortraitFor(def.id);

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
    final selected = DungeonCatalog.byId(_selectedId);
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
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                            onDismiss: () =>
                                showOfflineProgressDialog(context, director),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 5,
                          child: KenneyPanel(
                            style: KenneyPanelStyle.brown,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                            child: LayoutBuilder(
                              builder: (context, panelConstraints) {
                                if (panelConstraints.maxHeight < 48) {
                                  return const SizedBox.shrink();
                                }
                                final showHeader =
                                    !short && panelConstraints.maxHeight > 72;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (showHeader) ...[
                                      Row(
                                        children: [
                                          KenneySprite(
                                            asset: KenneyAssets.iconDoor,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'WORLD PATH',
                                            style: GameTheme.pixel(
                                              size: GameTheme.hudPixel,
                                              color: GameTheme.torchHot,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Expanded(
                                      child: _ZonePathMap(
                                        dungeons: DungeonCatalog.all,
                                        selectedId: _selectedId,
                                        lifetimeGold: state.lifetimeGoldEarned,
                                        highestCleared:
                                            state.highestDungeonCleared,
                                        pulse: _torch.value,
                                        iconFor: _dungeonIcon,
                                        onSelect: (id) => setState(() {
                                          _userPickedZone = true;
                                          _selectedId = id;
                                        }),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        KenneyPanel(
                          style: KenneyPanelStyle.inset,
                          padding: EdgeInsets.fromLTRB(
                            10,
                            short ? 6 : 8,
                            10,
                            short ? 6 : 8,
                          ),
                          child: Row(
                            children: [
                              KenneySprite(
                                asset: KenneyAssets.dungeonPortraitFor(
                                  _selectedId,
                                ),
                                size: short ? 32 : 40,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selected.name,
                                      style: GameTheme.pixel(
                                        size: 9,
                                        color: GameTheme.torchHot,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      unlockedSelected
                                          ? 'Boss: ${selected.bossName}'
                                          : _lockedZoneHint(selected, state),
                                      style: GameTheme.body(
                                        size: 14,
                                        color: GameTheme.parchmentDim,
                                      ),
                                    ),
                                    if (!short &&
                                        unlockedSelected &&
                                        _goldUnlockedSkipClear(
                                          selected,
                                          state,
                                        )) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Gold unlock — clear prior zone for an easier path',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GameTheme.body(
                                          size: 13,
                                          color: GameTheme.torchHot,
                                        ),
                                      ),
                                    ] else if (!short &&
                                        unlockedSelected &&
                                        selected.blurb.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        selected.blurb,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GameTheme.body(
                                          size: 13,
                                          color: GameTheme.mossLit,
                                        ),
                                      ),
                                    ] else if (!short && !unlockedSelected) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _lockedZoneAlt(selected),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GameTheme.body(
                                          size: 13,
                                          color: GameTheme.mossLit,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Transform.scale(
                          scale: 1.0 + (_torch.value * 0.012),
                          child: KenneyButton(
                            label: 'ENTER DUNGEON',
                            style: KenneyButtonStyle.brown,
                            primary: true,
                            onPressed: unlockedSelected
                                ? () => widget.onEnterDungeon(_selectedId)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _HubUrgentRow(
                          claimable: state.missions
                              .where((m) => m.isComplete)
                              .length,
                          canAscend: canAscend,
                          ascendLabel: canAscend
                              ? 'ASCEND  +${GameLogic.ascendEssenceReward(state.ascensionLevel + 1) + MetaSystems.ascendMilestoneReward(state.ascensionLevel, state.ascensionLevel + 1)}e'
                              : null,
                          onContracts: () {
                            for (final m in director.state.missions) {
                              if (m.isComplete) {
                                director.claimMission(m.id);
                              }
                            }
                            widget.onOpenJobs();
                          },
                          onAscend: () => confirmAscend(context, director),
                          dailyClaimed: director.isDailyClaimedToday,
                          onDaily: () => confirmDailyRun(context, director),
                          showGauntlet: GameLogic.canEnterGauntlet(state) ||
                              state.ascensionLevel >=
                                  GameLogic.gauntletMinAscension,
                          gauntletBest: state.metaDepth.gauntletBestFloor,
                          onGauntlet: () =>
                              confirmGauntletRun(context, director),
                          weeklyReady: state.metaDepth.weeklyProgress >=
                                  GameLogic.weeklyClearTarget &&
                              !state.metaDepth.weeklyClaimed,
                          weeklyProgress: state.metaDepth.weeklyProgress,
                          weeklyClaimed: state.metaDepth.weeklyClaimed,
                          weeklyModifier: state.metaDepth.weeklyModifier,
                          onClaimWeekly: director.claimWeekly,
                        ),
                        if (!short && !canAscend) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Bosses ${state.bossVictories}/${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} · keep clearing',
                            textAlign: TextAlign.center,
                            style: GameTheme.body(
                              size: 13,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ],
                        if (!short) ...[
                          const SizedBox(height: 4),
                          ChallengeToggles(
                            director: director,
                            collapsed: true,
                          ),
                        ],
                        const SizedBox(height: 4),
                        KenneyButton(
                          label: () {
                            final unseen =
                                MetaSystems.hasUnseenChangelog(state);
                            final readyJobs = state.missions
                                .where((m) => m.isComplete)
                                .length;
                            final weeklyAlmost =
                                state.metaDepth.weeklyProgress > 0 &&
                                    !state.metaDepth.weeklyClaimed;
                            if (unseen) return 'MORE · NEW';
                            if (readyJobs > 0 || weeklyAlmost) {
                              return 'MORE · !';
                            }
                            return 'MORE';
                          }(),
                          style: KenneyButtonStyle.grey,
                          onPressed: () => _showHubMore(context),
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
              maxLines: 2,
              alignment: const Alignment(0, -0.72),
            ),
          ),
      ],
    );
  }

  void _showHubMore(BuildContext context) {
    final claimable =
        widget.director.state.missions.where((m) => m.isComplete).length;
    MenuChrome.showMenuSheet(
      context: context,
      title: 'HUB',
      sections: [
        (
          header: 'GEAR',
          items: [
            (label: 'BAG', onTap: widget.onOpenInventory),
            (label: 'FORGE', onTap: widget.onOpenForge),
            if (widget.onOpenLoadouts != null)
              (label: 'LOADOUTS', onTap: widget.onOpenLoadouts!),
            if (widget.onOpenTeam != null)
              (label: 'PARTY', onTap: widget.onOpenTeam!),
          ],
        ),
        (
          header: 'PROGRESS',
          items: [
            (
              label: claimable > 0 ? 'CONTRACTS ($claimable)' : 'CONTRACTS',
              onTap: widget.onOpenJobs,
            ),
            (label: 'SANCTUARY', onTap: widget.onOpenSanctuary),
            (label: 'MARKET', onTap: widget.onOpenMarket),
            (label: 'BEAST PEN', onTap: widget.onOpenBeast),
            if (widget.onOpenPrestigeShop != null)
              (label: 'ESSENCE SHOP', onTap: widget.onOpenPrestigeShop!),
          ],
        ),
        (
          header: 'INFO',
          items: [
            if (widget.onOpenAchievements != null)
              (label: 'ACHIEVEMENTS', onTap: widget.onOpenAchievements!),
            if (widget.onOpenCodex != null)
              (label: 'CODEX', onTap: widget.onOpenCodex!),
            if (widget.onOpenGuides != null)
              (label: 'GUIDES', onTap: widget.onOpenGuides!),
          ],
        ),
      ],
    );
  }

  static String _shortGold(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return '$n';
  }

  static String _lockedZoneHint(DungeonDef selected, GameState state) {
    final need = selected.unlockPrice;
    if (need <= 0) return 'Locked';
    final have = state.lifetimeGoldEarned;
    return 'Lifetime ${_shortGold(have)} / ${_shortGold(need)}';
  }

  /// OPEN via lifetime gold without clearing the prior zone.
  static bool _goldUnlockedSkipClear(DungeonDef selected, GameState state) {
    if (selected.number <= 0) return false;
    if (state.highestDungeonCleared >= selected.number - 1) return false;
    return state.lifetimeGoldEarned >= selected.unlockPrice;
  }

  static String _lockedZoneAlt(DungeonDef selected) {
    if (selected.number <= 0) return 'Start zone';
    DungeonDef? prev;
    for (final d in DungeonCatalog.all) {
      if (d.number == selected.number - 1) {
        prev = d;
        break;
      }
    }
    if (prev == null) return 'Clear the prior zone';
    return 'Or clear ${prev.name}';
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
    required this.weeklyModifier,
    required this.onClaimWeekly,
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
  final String weeklyModifier;
  final VoidCallback onClaimWeekly;

  @override
  Widget build(BuildContext context) {
    final mod = weeklyModifier.isEmpty ? 'weekly' : weeklyModifier;
    final showWeeklyProgress = !weeklyClaimed &&
        weeklyProgress > 0 &&
        weeklyProgress < GameLogic.weeklyClearTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canAscend && ascendLabel != null) ...[
          KenneyButton(
            label: ascendLabel!,
            style: KenneyButtonStyle.red,
            primary: true,
            onPressed: onAscend,
          ),
          const SizedBox(height: 4),
        ],
        if (weeklyReady) ...[
          KenneyButton(
            label: 'CLAIM WEEKLY  +${GameLogic.weeklyClaimEssence}e',
            style: KenneyButtonStyle.brown,
            primary: true,
            onPressed: onClaimWeekly,
          ),
          const SizedBox(height: 4),
        ] else if (showWeeklyProgress) ...[
          Text(
            'Weekly $mod · $weeklyProgress/${GameLogic.weeklyClearTarget}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            if (claimable > 0) ...[
              Expanded(
                child: KenneyButton(
                  label: 'CLAIM ($claimable)',
                  style: KenneyButtonStyle.brown,
                  onPressed: onContracts,
                ),
              ),
              const SizedBox(width: 6),
            ],
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
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Hero\'s Keep · Boss F$bossFloor',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 16, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _StatPill(icon: KenneyAssets.coinGold, label: '$gold'),
            _StatPill(icon: KenneyAssets.vialBlue, label: '$essence'),
            _StatPill(icon: KenneyAssets.iconCrown, label: 'AL$ascensionLevel'),
            if (soulbound > 0)
              _StatPill(
                icon: KenneyAssets.iconTrophy,
                label: 'SB $soulbound',
              ),
          ],
        ),
        if (displayTitle.isNotEmpty || collectionScore > 0) ...[
          const SizedBox(height: 4),
          Text(
            displayTitle.isEmpty
                ? '$willRank · $collectionScore'
                : '$willRank · $displayTitle',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
        ],
        if (zoneTrophies > 0) ...[
          const SizedBox(height: 4),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GameTheme.stone.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: GameTheme.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KenneySprite(asset: icon, size: 16),
          const SizedBox(width: 5),
          Text(label, style: GameTheme.body(size: 16)),
        ],
      ),
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
    required this.iconFor,
    required this.onSelect,
  });

  final List<DungeonDef> dungeons;
  final String selectedId;
  final int lifetimeGold;
  final int highestCleared;
  final double pulse;
  final String Function(DungeonDef) iconFor;
  final ValueChanged<String> onSelect;

  /// Horizontal wobble as fraction of width (±0.06). Alternating keeps labels clear.
  static const List<double> _xWobble = [
    0.00,
    0.06,
    -0.05,
    0.06,
    -0.05,
    0.06,
    0.00,
  ];

  @override
  State<_ZonePathMap> createState() => _ZonePathMapState();
}

class _ZonePathMapState extends State<_ZonePathMap> {
  final ScrollController _scroll = ScrollController();
  String? _scrolledTo;

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

  void _ensureSelectedVisible({
    required double gap,
    required double portrait,
    required double viewH,
    required double contentH,
  }) {
    if (!_scroll.hasClients) return;
    if (_scrolledTo == widget.selectedId) return;
    final idx = widget.dungeons.indexWhere((d) => d.id == widget.selectedId);
    if (idx < 0) return;
    final targetY = portrait * 0.5 + idx * gap - viewH * 0.35;
    final maxScroll = math.max(0.0, contentH - viewH);
    final offset = targetY.clamp(0.0, maxScroll);
    _scrolledTo = widget.selectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dungeons = widget.dungeons;
    final selectedId = widget.selectedId;
    final lifetimeGold = widget.lifetimeGold;
    final highestCleared = widget.highestCleared;
    final pulse = widget.pulse;
    final iconFor = widget.iconFor;
    final onSelect = widget.onSelect;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        if (w < 8 || viewH < 8) return const SizedBox.shrink();

        final n = dungeons.length;
        // Label column (name + status) — keep ≥40 to avoid 1px Text overflow banners.
        const labelBudget = 40.0;
        final narrow = w < 360;
        // Never crush nodes into each other — scroll when the panel is short.
        final portrait = narrow ? 48.0 : 56.0;
        final nodeH = portrait + labelBudget;
        final gap = nodeH;
        final bottomPad = 72.0;
        final contentH = math.max(viewH, nodeH + gap * (n - 1) + 28);
        final nodeW = math.min(
          w * (narrow ? 0.42 : 0.46),
          math.max(88.0, portrait + 44),
        );
        final wobbleScale = narrow ? 0.55 : 1.0;

        final unlockedThrough = dungeons
            .where(
              (d) => DungeonCatalog.isUnlocked(
                d.id,
                lifetimeGold,
                highestCleared,
              ),
            )
            .map((d) => d.number)
            .fold<int>(-1, (a, b) => a > b ? a : b);

        // Portrait centers — evenly spaced, never clamped into each other.
        final points = <Offset>[
          for (var i = 0; i < n; i++)
            Offset(
              w *
                  (0.5 +
                      _ZonePathMap._xWobble[
                              i.clamp(0, _ZonePathMap._xWobble.length - 1)] *
                          wobbleScale),
              portrait * 0.5 + i * gap,
            ),
        ];

        _ensureSelectedVisible(
          gap: gap,
          portrait: portrait,
          viewH: viewH,
          contentH: contentH,
        );

        Widget map = Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ZoneTrailPainter(
                  points: points,
                  unlockedThrough: unlockedThrough,
                  pulse: pulse,
                ),
              ),
            ),
            for (var i = 0; i < n; i++)
              Builder(
                builder: (_) {
                  final d = dungeons[i];
                  final unlocked = DungeonCatalog.isUnlocked(
                    d.id,
                    lifetimeGold,
                    highestCleared,
                  );
                  final cleared = highestCleared >= d.number;
                  final prevUnlocked = d.number == 0 ||
                      DungeonCatalog.isUnlocked(
                        dungeons[d.number - 1].id,
                        lifetimeGold,
                        highestCleared,
                      );
                  final isNext = !unlocked && prevUnlocked;
                  final isFrontier =
                      unlocked && !cleared && d.number == highestCleared + 1;
                  final selected = d.id == selectedId;
                  final pt = points[i];
                  return Positioned(
                    left: (pt.dx - nodeW / 2).clamp(0.0, w - nodeW),
                    top: pt.dy - portrait * 0.5,
                    width: nodeW,
                    height: nodeH,
                    child: SizedBox(
                      height: nodeH,
                      child: ClipRect(
                        child: _ZoneNode(
                          def: d,
                          icon: iconFor(d),
                          portraitSize: portrait,
                          unlocked: unlocked,
                          cleared: cleared,
                          isNext: isNext,
                          isFrontier: isFrontier,
                          selected: selected,
                          pulse: pulse,
                          compact: true,
                          onTap: () => onSelect(d.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );

        return SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.only(bottom: bottomPad),
          child: SizedBox(width: w, height: contentH, child: map),
        );
      },
    );
  }
}

class _ZoneNode extends StatelessWidget {
  const _ZoneNode({
    required this.def,
    required this.icon,
    required this.portraitSize,
    required this.unlocked,
    required this.cleared,
    required this.isNext,
    required this.isFrontier,
    required this.selected,
    required this.pulse,
    required this.onTap,
    this.compact = false,
  });

  final DungeonDef def;
  final String icon;
  final double portraitSize;
  final bool unlocked;
  final bool cleared;
  final bool isNext;
  final bool isFrontier;
  final bool selected;
  final double pulse;
  final VoidCallback onTap;
  final bool compact;

  static String shortName(DungeonDef def, {bool compact = false}) {
    if (compact) {
      // Compact path nodes — still derived from catalog names.
      final words = def.name.replaceAll("'s", '').split(RegExp(r'\s+'));
      return words.first;
    }
    return def.name;
  }

  static String unlockGoldLabel(int price) {
    if (price >= 1000) return '${price ~/ 1000}k gold';
    if (price <= 0) return 'NEXT';
    return '$price gold';
  }

  @override
  Widget build(BuildContext context) {
    final ring = selected
        ? Color.lerp(GameTheme.torch, GameTheme.torchHot, pulse)!
        : isFrontier
            ? GameTheme.torch
            : unlocked
                ? GameTheme.borderLit
                : GameTheme.stoneDeep;

    final status = cleared
        ? 'CLEAR'
        : isFrontier
            ? 'NEXT'
            : unlocked
                ? 'OPEN'
                : unlockGoldLabel(def.unlockPrice);

    final scale = selected
        ? 1.0 + pulse * 0.03
        : (isFrontier ? 1.0 + pulse * 0.06 : 1.0);

    final semanticsLabel =
        '${def.name}, $status${selected ? ', selected' : ''}';

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
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: portraitSize,
                  height: portraitSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameTheme.stone
                        .withValues(alpha: unlocked ? 0.92 : 0.55),
                    border: Border.all(
                      color: ring,
                      width: selected ? 2.5 : (isFrontier ? 2.2 : 1.5),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: GameTheme.torch.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : (isFrontier
                            ? [
                                BoxShadow(
                                  color: GameTheme.torch.withValues(
                                    alpha: 0.2 + pulse * 0.25,
                                  ),
                                  blurRadius: 8 + pulse * 4,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: unlocked ? 1 : 0.4,
                    child: ColorFiltered(
                      colorFilter: unlocked
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            )
                          : const ColorFilter.matrix(<double>[
                              0.22, 0.22, 0.22, 0, 8,
                              0.22, 0.22, 0.22, 0, 8,
                              0.22, 0.22, 0.22, 0, 8,
                              0, 0, 0, 0.85, 0,
                            ]),
                      child: KenneySprite(asset: icon, size: portraitSize),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shortName(def, compact: compact),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GameTheme.pixel(
                    size: 7,
                    color: unlocked
                        ? (selected ? GameTheme.torchHot : GameTheme.parchment)
                        : GameTheme.parchmentDim,
                    height: 1.1,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 11,
                    color: cleared
                        ? GameTheme.mossLit
                        : (isFrontier || isNext)
                            ? GameTheme.torchHot
                            : GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoneTrailPainter extends CustomPainter {
  _ZoneTrailPainter({
    required this.points,
    required this.unlockedThrough,
    required this.pulse,
  });

  final List<Offset> points;
  final int unlockedThrough;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final ground = Paint()
      ..color = const Color(0xFF2A2418)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final lit = Paint()
      ..color = Color.lerp(
        const Color(0xFF6A5030),
        GameTheme.torch,
        0.35 + pulse * 0.4,
      )!
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dim = Paint()
      ..color = const Color(0xFF3A3528).withValues(alpha: 0.7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Lit through the frontier (unlockedThrough + 1), dim past it.
    final litThrough = unlockedThrough + 1;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final wobble = i.isEven ? 8.0 : -8.0;
      final mid = Offset((a.dx + b.dx) / 2 + wobble, (a.dy + b.dy) / 2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      canvas.drawPath(path, ground);
      canvas.drawPath(path, i < litThrough ? lit : dim);
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneTrailPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.unlockedThrough != unlockedThrough ||
      oldDelegate.points.length != points.length;
}
