import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/dungeon_generator.dart';
import '../core/game_state.dart';
import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';
import 'game_theme.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_panel.dart';
import 'kenney_sprite.dart';

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

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedId;
  late final AnimationController _torch;

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
  }

  @override
  void dispose() {
    _torch.dispose();
    super.dispose();
  }

  String _dungeonIcon(DungeonDef def) => KenneyAssets.dungeonIconFor(def.id);

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

    return AnimatedBuilder(
      animation: _torch,
      builder: (context, _) {
        final flicker = 0.55 + (_torch.value * 0.45);
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.15,
                  colors: [
                    Color.lerp(
                      const Color(0xFF2A2214),
                      const Color(0xFF3A2E18),
                      flicker,
                    )!,
                    GameTheme.ink,
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _HubAtmospherePainter(pulse: _torch.value),
              ),
            ),
            SafeArea(
              child: Padding(
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
                      torch: flicker,
                    ),
                    if (director.offlineSummary != null) ...[
                      const SizedBox(height: 8),
                      _OfflineBanner(
                        text: director.offlineSummary!.headline,
                        onDismiss: director.dismissOfflineSummary,
                      ),
                    ],
                    if (director.toast != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        director.toast!,
                        textAlign: TextAlign.center,
                        style: GameTheme.pixel(
                          size: GameTheme.hudPixel,
                          color: GameTheme.mossLit,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: KenneyPanel(
                        style: KenneyPanelStyle.brown,
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                  'BF $bossFloor',
                                  style: GameTheme.body(
                                    size: 14,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return _ZonePathMap(
                                    dungeons: DungeonCatalog.all,
                                    selectedId: _selectedId,
                                    lifetimeGold: state.lifetimeGoldEarned,
                                    highestCleared: state.highestDungeonCleared,
                                    ascensionLevel: state.ascensionLevel,
                                    pulse: _torch.value,
                                    iconFor: _dungeonIcon,
                                    onSelect: (id) =>
                                        setState(() => _selectedId = id),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    KenneyPanel(
                      style: KenneyPanelStyle.inset,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          KenneySprite(
                            asset: KenneyAssets.dungeonPortraitFor(_selectedId),
                            size: 44,
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
                                const SizedBox(height: 4),
                                Text(
                                  unlockedSelected
                                      ? 'Boss: ${selected.bossName}'
                                      : 'Locked · ${selected.unlockPrice}g',
                                  style: GameTheme.body(
                                    size: 14,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                                Text(
                                  'Layout ${selected.layout.name}',
                                  style: GameTheme.body(
                                    size: 13,
                                    color: GameTheme.mossLit,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
                    KenneyButton(
                      label: canAscend
                          ? 'ASCEND  +${GameLogic.ascendEssenceReward(state.ascensionLevel + 1)}e'
                          : 'ASCEND',
                      style: canAscend
                          ? KenneyButtonStyle.red
                          : KenneyButtonStyle.grey,
                      onPressed: canAscend ? director.ascend : null,
                    ),
                    if (!canAscend) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${GameLogic.bossesRequiredForAscension(state.ascensionLevel)} bosses needed',
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => _showHubMore(context),
                        child: Text(
                          'MORE · bag forge jobs…',
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
            ),
          ],
        );
      },
    );
  }

  void _showHubMore(BuildContext context) {
    final items = <({String label, VoidCallback onTap})>[
      (label: 'BAG', onTap: widget.onOpenInventory),
      (label: 'FORGE', onTap: widget.onOpenForge),
      (label: 'JOBS', onTap: widget.onOpenJobs),
      (label: 'SANCTUARY', onTap: widget.onOpenSanctuary),
      (label: 'MARKET', onTap: widget.onOpenMarket),
      (label: 'BEAST PEN', onTap: widget.onOpenBeast),
      (label: 'SETTINGS', onTap: widget.onOpenSettings),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameTheme.stoneDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: GameTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'HUB',
                  style: GameTheme.pixel(size: GameTheme.hudPixelComfort),
                ),
                const SizedBox(height: 8),
                for (final item in items)
                  _HubMoreRow(
                    label: item.label,
                    onTap: () {
                      Navigator.pop(ctx);
                      item.onTap();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HubMoreRow extends StatelessWidget {
  const _HubMoreRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [GameTheme.stoneRaised, GameTheme.stone],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: GameTheme.borderLit.withValues(alpha: 0.7),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: GameTheme.pixel(size: GameTheme.hudPixel),
            ),
          ),
        ),
      ),
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
      color: const Color(0xEE1A2030),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onDismiss,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: GameTheme.mossLit),
          ),
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
                style: GameTheme.pixel(
                  size: 7,
                  color: GameTheme.parchmentDim,
                ),
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
    required this.torch,
  });

  final int ascensionLevel;
  final int bossFloor;
  final int gold;
  final int essence;
  final int soulbound;
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
          'Hero\'s Keep',
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
          ],
        ),
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
        color: GameTheme.stone.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: GameTheme.border),
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
    required this.ascensionLevel,
    required this.pulse,
    required this.iconFor,
    required this.onSelect,
  });

  final List<DungeonDef> dungeons;
  final String selectedId;
  final int lifetimeGold;
  final int highestCleared;
  final int ascensionLevel;
  final double pulse;
  final String Function(DungeonDef) iconFor;
  final ValueChanged<String> onSelect;

  static List<({int floor, RoomType type})> _notableFloors(
    String dungeonId,
    int ascensionLevel,
  ) {
    final boss = DungeonGenerator.bossFloorFor(ascensionLevel);
    final out = <({int floor, RoomType type})>[];
    for (var f = 1; f <= boss + 1; f++) {
      final room = DungeonGenerator.generateFloorRoom(
        floorNumber: f,
        ascensionLevel: ascensionLevel,
        dungeonId: dungeonId,
      );
      if (room.type != RoomType.normal) {
        out.add((floor: f, type: room.type));
      }
    }
    return out;
  }

  /// Zigzag path positions as fractions of width/height.
  static const List<Offset> _anchors = <Offset>[
    Offset(0.22, 0.88),
    Offset(0.72, 0.74),
    Offset(0.28, 0.58),
    Offset(0.70, 0.42),
    Offset(0.30, 0.26),
    Offset(0.66, 0.10),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final points = <Offset>[
          for (var i = 0; i < dungeons.length; i++)
            Offset(
              _anchors[i].dx * size.width,
              _anchors[i].dy * size.height,
            ),
        ];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ZoneTrailPainter(
                  points: points,
                  unlockedThrough: highestCleared,
                  pulse: pulse,
                ),
              ),
            ),
            for (var i = 0; i < dungeons.length; i++)
              _ZoneNode(
                left: points[i].dx - 34,
                top: points[i].dy - 28,
                def: dungeons[i],
                icon: iconFor(dungeons[i]),
                notableFloors: _notableFloors(dungeons[i].id, ascensionLevel),
                unlocked: DungeonCatalog.isUnlocked(
                  dungeons[i].id,
                  lifetimeGold,
                  highestCleared,
                ),
                selected: dungeons[i].id == selectedId,
                cleared: highestCleared >= dungeons[i].number,
                isFrontier:
                    DungeonCatalog.isUnlocked(
                      dungeons[i].id,
                      lifetimeGold,
                      highestCleared,
                    ) &&
                    highestCleared < dungeons[i].number &&
                    dungeons[i].number == highestCleared + 1,
                pulse: pulse,
                onTap: DungeonCatalog.isUnlocked(
                      dungeons[i].id,
                      lifetimeGold,
                      highestCleared,
                    )
                    ? () => onSelect(dungeons[i].id)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _ZoneNode extends StatelessWidget {
  const _ZoneNode({
    required this.left,
    required this.top,
    required this.def,
    required this.icon,
    required this.notableFloors,
    required this.unlocked,
    required this.selected,
    required this.cleared,
    required this.isFrontier,
    required this.pulse,
    this.onTap,
  });

  final double left;
  final double top;
  final DungeonDef def;
  final String icon;
  final List<({int floor, RoomType type})> notableFloors;
  final bool unlocked;
  final bool selected;
  final bool cleared;
  final bool isFrontier;
  final double pulse;
  final VoidCallback? onTap;

  String _floorBadge(({int floor, RoomType type}) entry) {
    final tag = switch (entry.type) {
      RoomType.boss => 'B',
      RoomType.elite => 'E',
      RoomType.treasure => 'T',
      RoomType.normal => '',
    };
    return '$tag${entry.floor}';
  }

  Color _badgeColor(RoomType type) => switch (type) {
    RoomType.boss => GameTheme.bloodLit,
    RoomType.elite => GameTheme.torch,
    RoomType.treasure => GameTheme.clear,
    RoomType.normal => GameTheme.parchmentDim,
  };

  @override
  Widget build(BuildContext context) {
    final scale = selected
        ? 1.0 + pulse * 0.04
        : (isFrontier ? 1.0 + pulse * 0.08 : 1.0);
    return Positioned(
      left: left,
      top: top,
      child: Transform.scale(
        scale: scale,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: GameTheme.isCompactWidth(context) ? 76 : 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: GameTheme.isCompactWidth(context) ? 56 : 52,
                    height: GameTheme.isCompactWidth(context) ? 56 : 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF4A3420)
                          : GameTheme.stone.withValues(
                              alpha: unlocked ? 0.95 : 0.45,
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? GameTheme.torchHot
                            : (cleared
                                  ? GameTheme.clear
                                  : (isFrontier
                                        ? GameTheme.torch
                                        : (unlocked
                                              ? GameTheme.borderLit
                                              : const Color(0xFF3A3528)))),
                        width: selected ? 2.5 : (isFrontier ? 2.2 : 1.5),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: GameTheme.torch.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
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
                    child: Opacity(
                      opacity: unlocked ? 1 : 0.35,
                      child: Center(
                        child: KenneySprite(
                          asset: icon,
                          size: GameTheme.isCompactWidth(context) ? 36 : 34,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    def.name.split(' ').first,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.pixel(
                      size: 7,
                      color: unlocked
                          ? (selected ? GameTheme.torchHot : GameTheme.parchment)
                          : const Color(0xFF666055),
                    ),
                  ),
                  if (cleared)
                    Text(
                      'CLEAR',
                      style: GameTheme.pixel(size: 6, color: GameTheme.clear),
                    )
                  else if (!unlocked)
                    Text(
                      '${def.unlockPrice ~/ 1000}k',
                      style: GameTheme.pixel(
                        size: 6,
                        color: const Color(0xFF666055),
                      ),
                    ),
                  if (unlocked && notableFloors.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 1,
                      children: [
                        for (final entry in notableFloors.take(4))
                          Text(
                            _floorBadge(entry),
                            style: GameTheme.pixel(
                              size: 5,
                              color: _badgeColor(entry.type),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
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
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final lit = Paint()
      ..color = Color.lerp(
        const Color(0xFF6A5030),
        GameTheme.torch,
        0.25 + pulse * 0.35,
      )!
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dim = Paint()
      ..color = const Color(0xFF3A3528)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final mid = Offset(
        (a.dx + b.dx) / 2 + (i.isEven ? 18 : -18),
        (a.dy + b.dy) / 2,
      );
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      canvas.drawPath(path, ground);
      canvas.drawPath(path, i < unlockedThrough ? lit : dim);
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneTrailPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.unlockedThrough != unlockedThrough ||
      oldDelegate.points.length != points.length;
}

class _HubAtmospherePainter extends CustomPainter {
  _HubAtmospherePainter({required this.pulse});
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          GameTheme.ink.withValues(alpha: 0.55 + pulse * 0.1),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    final dust = Paint()..color = GameTheme.torch.withValues(alpha: 0.04);
    final rng = math.Random(7);
    for (var i = 0; i < 28; i++) {
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height + pulse * 12) % size.height;
      canvas.drawCircle(Offset(x, y), 1.2, dust);
    }
  }

  @override
  bool shouldRepaint(covariant _HubAtmospherePainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
