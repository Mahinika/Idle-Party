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
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_panel.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'meta_overlays.dart';

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

  GameDirector get director => widget.director;
  GameState get state => director.state;

  @override
  void initState() {
    super.initState();
    _selectedId = state.dungeonId;
    _torch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOffline());
  }

  Future<void> _maybeShowOffline() async {
    if (_offlineDialogShown || !mounted || director.offlineSummary == null) {
      return;
    }
    _offlineDialogShown = true;
    await showOfflineProgressDialog(context, director);
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
    final selected = DungeonCatalog.byId(_selectedId);
    final canAscend = GameLogic.canAscend(state);
    final bossFloor = GameLogic.bossFloorFor(state);
    final unlockedSelected = DungeonCatalog.isUnlocked(
      _selectedId,
      state.lifetimeGoldEarned,
      state.highestDungeonCleared,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: const _HubSceneBackdrop(),
        ),
        AnimatedBuilder(
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
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                        ),
                    if (director.offlineSummary != null) ...[
                      const SizedBox(height: 8),
                      _OfflineBanner(
                        text: director.offlineSummary!.headline,
                        onDismiss: () =>
                            showOfflineProgressDialog(context, director),
                      ),
                    ],
                    if (director.toast != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        director.toast!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.pixel(
                          size: GameTheme.hudPixel,
                          color: GameTheme.mossLit,
                        ),
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
                            final showHeader = panelConstraints.maxHeight > 72;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                          size: 9,
                                          color: GameTheme.torchHot,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Boss F $bossFloor',
                                        style: GameTheme.body(
                                          size: 14,
                                          color: GameTheme.parchmentDim,
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
                                    highestCleared: state.highestDungeonCleared,
                                    pulse: _torch.value,
                                    iconFor: _dungeonIcon,
                                    onSelect: (id) =>
                                        setState(() => _selectedId = id),
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
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Row(
                        children: [
                          KenneySprite(
                            asset: KenneyAssets.dungeonPortraitFor(_selectedId),
                            size: 40,
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
                                if (unlockedSelected &&
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
                                ] else if (!unlockedSelected) ...[
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
                      onContracts: widget.onOpenJobs,
                      onAscend: () => confirmAscend(context, director),
                      dailyClaimed: director.isDailyClaimedToday,
                      onDaily: director.enterDaily,
                    ),
                    if (!canAscend) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Bosses ${state.bossVictories}/${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} this run · Ascend when ready',
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    ChallengeToggles(director: director, collapsed: true),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => _showHubMore(context),
                        child: Text(
                          'MORE · bag forge sanctuary…',
                          style: GameTheme.body(
                            size: 16,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            );
          },
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
      items: [
        (label: 'BAG', onTap: widget.onOpenInventory),
        (label: 'FORGE', onTap: widget.onOpenForge),
        (
          label: claimable > 0 ? 'CONTRACTS ($claimable)' : 'CONTRACTS',
          onTap: widget.onOpenJobs,
        ),
        (label: 'SANCTUARY', onTap: widget.onOpenSanctuary),
        (label: 'MARKET', onTap: widget.onOpenMarket),
        (label: 'BEAST PEN', onTap: widget.onOpenBeast),
        if (widget.onOpenPrestigeShop != null)
          (label: 'PRESTIGE SHOP', onTap: widget.onOpenPrestigeShop!),
        if (widget.onOpenLoadouts != null)
          (label: 'GEAR SETS', onTap: widget.onOpenLoadouts!),
        if (widget.onOpenTeam != null)
          (label: 'TEAM', onTap: widget.onOpenTeam!),
        if (widget.onOpenAchievements != null)
          (label: 'ACHIEVEMENTS', onTap: widget.onOpenAchievements!),
        if (widget.onOpenCodex != null)
          (label: 'CODEX', onTap: widget.onOpenCodex!),
        if (widget.onOpenGuides != null)
          (label: 'GUIDES', onTap: widget.onOpenGuides!),
        (label: 'SETTINGS', onTap: widget.onOpenSettings),
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
    return 'Or clear ${_ZoneNode.shortName(prev)}';
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
  });

  final int claimable;
  final bool canAscend;
  final String? ascendLabel;
  final VoidCallback onContracts;
  final VoidCallback onAscend;
  final bool dailyClaimed;
  final VoidCallback onDaily;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canAscend && ascendLabel != null) ...[
          KenneyButton(
            label: ascendLabel!,
            style: KenneyButtonStyle.red,
            onPressed: onAscend,
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
                style: dailyClaimed
                    ? KenneyButtonStyle.grey
                    : KenneyButtonStyle.grey,
                onPressed: dailyClaimed ? null : onDaily,
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'IDLE PARTY',
          textAlign: TextAlign.center,
          style: GameTheme.pixel(
            size: 20,
            color: Color.lerp(GameTheme.torch, GameTheme.torchHot, torch)!,
            height: 1.25,
          ),
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
            _StatPill(icon: KenneyAssets.iconStar, label: 'SB $soulbound'),
            _StatPill(
              icon: KenneyAssets.iconTrophy,
              label: displayTitle.isEmpty
                  ? '$willRank · $collectionScore'
                  : '$willRank · $displayTitle · $collectionScore',
            ),
          ],
        ),
        if (zoneTrophies > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Zone trophies $zoneTrophies — clear every dungeon for more',
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

class _ZonePathMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        if (w < 8 || viewH < 8) return const SizedBox.shrink();

        final n = dungeons.length;
        const labelBudget = 38.0;

        // Fit all nodes without overlap; scroll if the panel is too short.
        var portrait = 64.0;
        var nodeH = portrait + labelBudget;
        // Gap between consecutive node tops must clear most of the portrait.
        var gap = nodeH * 0.92;
        final neededH = nodeH + gap * (n - 1);
        if (neededH > viewH && n > 1) {
          gap = ((viewH - labelBudget) / n).clamp(44.0, nodeH);
          portrait = (gap - 6).clamp(40.0, 64.0);
          nodeH = portrait + labelBudget;
        }
        final contentH = math.max(viewH, nodeH + gap * (n - 1));
        final nodeW = math.min(w * 0.46, math.max(96.0, portrait + 52));

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
              w * (0.5 + _xWobble[i.clamp(0, _xWobble.length - 1)]),
              portrait * 0.5 + i * gap,
            ),
        ];

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
                      onTap: () => onSelect(d.id),
                    ),
                  );
                },
              ),
          ],
        );

        if (contentH > viewH + 1) {
          return SingleChildScrollView(
            child: SizedBox(width: w, height: contentH, child: map),
          );
        }
        return SizedBox(width: w, height: viewH, child: map);
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

  static String shortName(DungeonDef def) {
    return switch (def.id) {
      'sandy' => 'Sandy',
      'goblin' => 'Goblin Hideout',
      'king' => "King's Fort",
      'underworld' => 'Underworld',
      'dead' => 'City of Dead',
      'hell' => 'Hell',
      'crystal' => 'Crystal',
      _ => def.name,
    };
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
        : unlocked
            ? 'NEXT'
            : unlockGoldLabel(def.unlockPrice);

    final scale = selected
        ? 1.0 + pulse * 0.03
        : (isFrontier ? 1.0 + pulse * 0.06 : 1.0);

    return GestureDetector(
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
                color: GameTheme.stone.withValues(alpha: unlocked ? 0.92 : 0.55),
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
            const SizedBox(height: 4),
            Text(
              shortName(def),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GameTheme.pixel(
                size: 7,
                color: unlocked
                    ? (selected ? GameTheme.torchHot : GameTheme.parchment)
                    : GameTheme.parchmentDim,
                height: 1.15,
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
